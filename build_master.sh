#!/bin/bash

#set -e
export TZ='Asia/Kolkata' && date
export KERNELDIR=`readlink -f .`
echo "kerneldir = $KERNELDIR"

TG=$HOME/telegram.sh/telegram
LOG=$KERNELDIR/bl*.txt
LOG2=$KERNELDIR/wbl*.txt

if [[ "${1}" != "skip" ]] ; then
	./build_clean.sh
	./build_kernel.sh stock "$@" || exit 1
fi

VERSION="$(cat version)-$(date +'%Y%m%d-%H%M')"

if [ -e boot.img ] ; then
	rm arter97-beryllium-$VERSION.zip 2>/dev/null

	# Pack AnyKernel2
	rm -rf kernelzip
	mkdir -p kernelzip/dtbs
	cp arch/arm64/boot/Image.gz kernelzip/
	find arch/arm64/boot -name '*.dtb' -exec cp {} kernelzip/dtbs/ \;
	echo "
kernel.string=arter97 kernel $(cat version) @ xda-developers
do.devicecheck=1
do.modules=0
do.cleanup=1
do.cleanuponabort=0
device.name1=beryllium
block=/dev/block/bootdevice/by-name/boot
is_slot_device=auto
ramdisk_compression=auto
" > kernelzip/props
	cp -rp $KERNELDIR/anykernel2/* kernelzip/
	cd kernelzip/
	7z a -mx0 arter97-beryllium-$VERSION-tmp.zip *
	zipalign -v 4 arter97-beryllium-$VERSION-tmp.zip ../arter97-beryllium-$VERSION.zip
	rm arter97-beryllium-$VERSION-tmp.zip
	cd ..
	ls -al arter97-beryllium-$VERSION.zip
	$TG -f arter97-beryllium-$VERSION.zip "$(cat $KERNELDIR/include/generated/uts* | cut -d '"' -f 2)"$'\n'$'\n'"$(cat $KERNELDIR/include/generated/comp*h | grep LINUX_COMPILER | cut -d '"' -f 2)"$'\n'$'\n'"HEAD: $(git log -n 1 --oneline)"
	mv $LOG bl-$(ls arter*zip | rev | cut -d / -f 1 | rev | cut -d . -f 2 | cut -d - -f 2-).txt
	$TG -f $LOG
	# TEMP
	grep warning* $LOG > w$(ls $LOG | rev | cut -d / -f 1 | rev)
	if [ "$(cat $LOG2)" == "" ]; then
		echo no warning
	else
		$TG -f $LOG2
	fi
fi
