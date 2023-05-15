#!/bin/bash
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/ramdisk`
export PARTITION_SIZE=67108864
TG=$HOME/telegram.sh/telegram
LOG=$KERNELDIR/bl*.txt
export OS="9.0.0"
export SPL="2019-02"

echo "kerneldir = $KERNELDIR"
echo "ramfs_source = $RAMFS_SOURCE"

RAMFS_TMP="/tmp/arter97-dipper-ramdisk"

echo "ramfs_tmp = $RAMFS_TMP"
cd $KERNELDIR

if [ -d "$HOME/telegram.sh" ]; then
	echo "Tgsh already exists"
else
git clone https://github.com/fabianonline/telegram.sh $HOME/telegram.sh
mv .telegram.sh $HOME/.telegram.sh
sed -i s/demo1/${BOT_API_KEY}/g $HOME/.telegram.sh
sed -i s/demo2/${CHAT_ID}/g $HOME/.telegram.sh
fi

if [ -d "arm32-gcc" ]; then
	echo "arm32-gcc already exists"
else
	git clone https://github.com/rahifm/arm32-gcc -b 9 --depth 1
fi
if [ -d "arm64-gcc" ]; then
	echo "arm64-gcc already exists"
else
	git clone https://github.com/rahifm/arm64-gcc -b 9 --depth 1
fi

stock=0
if [[ "${1}" == "stock" ]] ; then
	stock=1
	shift
fi

if [[ "${1}" == "skip" ]] ; then
	echo "Skipping Compilation"
else
	echo "Compiling kernel"
	$TG "Build started $(date +'%Y%m%d %H%M %Z')"$'\n'$'\n'"Branch: $(git branch --show-current)"$'\n'$'\n'"HEAD: $(git log -n 1 --oneline)"
	#cp defconfig .config
	make arter_beryllium_defconfig
	make -j$(nproc --all) 2>&1 | tee bl-$(date +'%Y%m%d-%H%M').txt "$@" || exit 1
fi

if [ "$(grep Image.gz $LOG | cut -d / -f 4)" == "" ] ; then
	$TG -f $LOG "Kernel compilation failed."
	exit 1
fi

echo "Building new ramdisk"
#remove previous ramfs files
rm -rf '$RAMFS_TMP'*
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
#copy ramfs files to tmp directory
cp -axpP $RAMFS_SOURCE $RAMFS_TMP
cd $RAMFS_TMP

#clear git repositories in ramfs
find . -name .git -exec rm -rf {} \;
find . -name EMPTY_DIRECTORY -exec rm -rf {} \;

sed -i -e s@ro.build.version.release.*@ro.build.version.release=${OS}@g \
       -e s@ro.build.version.security_patch.*@ro.build.version.security_patch=${SPL}-01@g prop.default

if [[ "$stock" == "1" ]] ; then
	# Don't use Magisk
	mv .backup/init init
	rm -rf .backup
fi

$KERNELDIR/ramdisk_fix_permissions.sh 2>/dev/null

cd $KERNELDIR
rm -rf $RAMFS_TMP/tmp/*

cd $RAMFS_TMP
find . | fakeroot cpio -H newc -o | gzip -9 > $RAMFS_TMP.cpio.gz
ls -lh $RAMFS_TMP.cpio.gz
cd $KERNELDIR

echo "Making new boot image"
mkbootimg \
    --kernel $KERNELDIR/arch/arm64/boot/Image.gz-dtb \
    --ramdisk $RAMFS_TMP.cpio.gz \
    --cmdline 'console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xA84000 androidboot.hardware=qcom androidboot.console=ttyMSM0 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 service_locator.enable=1 swiotlb=2048 androidboot.configfs=true firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 buildvariant=user printk.devkmsg=on' \
    --base           0x00000000 \
    --pagesize       4096 \
    --kernel_offset  0x00008000 \
    --ramdisk_offset 0x01000000 \
    --second_offset  0x00f00000 \
    --tags_offset    0x00000100 \
    --os_version     $OS \
    --os_patch_level $SPL \
    --header_version 1 \
    -o $KERNELDIR/boot.img

GENERATED_SIZE=$(stat -c %s boot.img)
if [[ $GENERATED_SIZE -gt $PARTITION_SIZE ]]; then
	echo "boot.img size larger than partition size!" 1>&2
	exit 1
fi

echo "done"
ls -al boot.img
echo ""
