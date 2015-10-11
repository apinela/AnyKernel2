# AnyKernel 2.0 Ramdisk Mod Script 
# osm0sis @ xda-developers

## AnyKernel setup
# EDIFY properties
kernel.string=grouper-3.4-dev_sheffzor-scenne
do.devicecheck=1
do.initd=0
do.modules=0
do.cleanup=1
device.name1=grouper
device.name2=tilapia
device.name3=
device.name4=
device.name5=

# shell variables
block=/dev/block/platform/sdhci-tegra.3/by-name/LNX;

## end setup


## AnyKernel methods (DO NOT CHANGE)
# set up extracted files and directories
ramdisk=/tmp/anykernel/ramdisk;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;

chmod -R 755 $bin;
mkdir -p $ramdisk $split_img;
cd $ramdisk;

OUTFD=`ps | grep -v "grep" | grep -oE "update(.*)" | cut -d" " -f3`;
ui_print() { echo "ui_print $1" >&$OUTFD; echo "ui_print" >&$OUTFD; }

# dump boot and extract ramdisk
dump_boot() {
  dd if=$block of=/tmp/anykernel/boot.img;
  $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Dumping/unpacking image failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode; exit;
  fi;
  gunzip -c $split_img/boot.img-ramdisk.gz | cpio -i;
}

# repack ramdisk then build and write image
write_boot() {
  cd $split_img;
  cmdline=`cat *-cmdline`;
  board=`cat *-board`;
  base=`cat *-base`;
  pagesize=`cat *-pagesize`;
  kerneloff=`cat *-kerneloff`;
  ramdiskoff=`cat *-ramdiskoff`;
  tagsoff=`cat *-tagsoff`;
  if [ -f *-second ]; then
    second=`ls *-second`;
    second="--second $split_img/$second";
    secondoff=`cat *-secondoff`;
    secondoff="--second_offset $secondoff";
  fi;
  if [ -f /tmp/anykernel/zImage ]; then
    kernel=/tmp/anykernel/zImage;
  else
    kernel=`ls *-zImage`;
    kernel=$split_img/$kernel;
  fi;
  if [ -f /tmp/anykernel/dtb ]; then
    dtb="--dt /tmp/anykernel/dtb";
  elif [ -f *-dtb ]; then
    dtb=`ls *-dtb`;
    dtb="--dt $split_img/$dtb";
  fi;
  cd $ramdisk;
  find . | cpio -H newc -o | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  $bin/mkbootimg --kernel $kernel --ramdisk /tmp/anykernel/ramdisk-new.cpio.gz $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff $dtb --output /tmp/anykernel/boot-new.img;
  if [ $? != 0 -o `wc -c < /tmp/anykernel/boot-new.img` -gt `wc -c < /tmp/anykernel/boot.img` ]; then
    ui_print " "; ui_print "Repacking image failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode; exit;
  fi;
  dd if=/tmp/anykernel/boot-new.img of=$block;
}

# backup_file <file>
backup_file() { cp $1 $1~; }

# replace_string <file> <if search string> <original string> <replacement string>
replace_string() {
  if [ -z "$(grep "$2" $1)" ]; then
      sed -i "s;${3};${4};" $1;
  fi;
}

# insert_line <file> <if search string> <before/after> <line match string> <inserted line>
insert_line() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;${5};" $1;
  fi;
}

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}s;.*;${3};" $1;
  fi;
}

# remove_line <file> <line match string>
remove_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}d" $1;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# append_file <file> <if search string> <patch file>
append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

# replace_file <file> <permissions> <patch file>
replace_file() {
  cp -fp $patch/$3 $1;
  chmod $2 $1;
}

## end methods


## AnyKernel permissions
# set permissions for included files
chmod -R 755 $ramdisk

## AnyKernel install
dump_boot;

# begin ramdisk changes
	
# init.grouper.rc
backup_file init.grouper.rc;
replace_line init.grouper.rc "/sys/module/cpu_tegra3/parameters/no_lp" "	write /sys/devices/system/cpu/cpuquiet/tegra_cpuquiet/no_lp 0";
replace_line init.grouper.rc "/sys/module/cpu_tegra3/parameters/auto_hotplug" "	write /sys/devices/system/cpu/cpuquiet/tegra_cpuquiet/enable 1";
replace_line init.grouper.rc "/sys/module/cpuidle/parameters/lp2_in_idle" "	write /sys/module/cpuidle/parameters/power_down_in_idle 0";
insert_line init.grouper.rc "/sys/module/cpuidle/parameters/power_down_in_idle" after "/sys/module/cpuidle/parameters/power_down_in_idle" "	write /sys/devices/system/cpu/cpufreq/cpuload/enable 1";
replace_line init.grouper.rc "chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/boost_factor" "	chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/io_is_busy"
replace_line init.grouper.rc "chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/core_lock_count" "	chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/go_hispeed_load"
replace_line init.grouper.rc "chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/core_lock_period" "	chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/hispeed_freq"
replace_line init.grouper.rc "chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/go_maxspeed_load" "	chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/input_boost"
replace_line init.grouper.rc "chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/io_is_busy" "	chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/min_sample_time"
replace_line init.grouper.rc "chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/max_boost" "	chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/target_loads"
replace_line init.grouper.rc "chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/sustain_load" "	chmod 0660 /sys/devices/system/cpu/cpufreq/interactive/timer_rate"
replace_line init.grouper.rc "chown system system /sys/devices/system/cpu/cpufreq/interactive/boost_factor" "	chown system system /sys/devices/system/cpu/cpufreq/interactive/io_is_busy"
replace_line init.grouper.rc "chown system system /sys/devices/system/cpu/cpufreq/interactive/core_lock_count" "	chown system system /sys/devices/system/cpu/cpufreq/interactive/go_hispeed_load"
replace_line init.grouper.rc "chown system system /sys/devices/system/cpu/cpufreq/interactive/core_lock_period" "	chown system system /sys/devices/system/cpu/cpufreq/interactive/hispeed_freq"
replace_line init.grouper.rc "chown system system /sys/devices/system/cpu/cpufreq/interactive/go_maxspeed_load" "	chown system system /sys/devices/system/cpu/cpufreq/interactive/input_boost"
replace_line init.grouper.rc "chown system system /sys/devices/system/cpu/cpufreq/interactive/io_is_busy" "	chown system system /sys/devices/system/cpu/cpufreq/interactive/min_sample_time"
replace_line init.grouper.rc "chown system system /sys/devices/system/cpu/cpufreq/interactive/max_boost" "	chown system system /sys/devices/system/cpu/cpufreq/interactive/target_loads"
replace_line init.grouper.rc "chown system system /sys/devices/system/cpu/cpufreq/interactive/sustain_load" "	chown system system /sys/devices/system/cpu/cpufreq/interactive/timer_rate"
# end ramdisk changes

write_boot;

## end install

