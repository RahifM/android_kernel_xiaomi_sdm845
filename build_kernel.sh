#!/bin/bash

#set -e
export TZ='Asia/Kolkata' && date
export KERNELDIR=`readlink -f .`
echo "kerneldir = $KERNELDIR"

TG=$HOME/telegram.sh/telegram
LOG=$KERNELDIR/bl*.txt
LOG2=$KERNELDIR/wbl*.txt

if [ -d "$HOME/telegram.sh" ]; then
	echo "Tgsh already exists"
else
time git clone https://github.com/fabianonline/telegram.sh $HOME/telegram.sh
cp .telegram.sh $HOME/.telegram.sh
sed -i s/demo1/${BOT_API_KEY}/g $HOME/.telegram.sh
sed -i s/demo2/${CHAT_ID}/g $HOME/.telegram.sh
fi

if [ -d "arm32-gcc" ]; then
	echo "arm32-gcc already exists"
else
	time git clone https://github.com/rahifm/arm32-gcc -b gcc-13.1.0 --depth 1
fi
if [ -d "arm64-gcc" ]; then
	echo "arm64-gcc already exists"
else
	time git clone https://github.com/rahifm/arm64-gcc -b gcc-13.1.0 --depth 1
fi

if [ "$(whoami)" == "gitpod" ]; then
        echo "Clean up for gitpod"
	time make clean && make mrproper
fi

echo "Compiling kernel"
$TG "Build started $(date +'%Y%m%d %H%M %Z')"$'\n'$'\n'"Branch: $(git branch --show-current)"$'\n'$'\n'"HEAD: $(git log -n 1 --oneline)"

# Cleanup before start
rm -rf bl-*.txt
rm -rf wbl-*.txt
rm -rf arter97-beryllium*.zip

# Start the build
make arter_beryllium_defconfig
time make -j$(nproc --all) 2>&1 | tee bl-$(date +'%Y%m%d-%H%M').txt

if [ "$(grep Image.gz $LOG | cut -d / -f 4)" == "" ] ; then
	$TG -f $LOG "Kernel compilation failed."
	exit 1
fi

VERSION="$(cat version)-$(date +'%Y%m%d-%H%M')"

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
7z a -mx0 arter97-beryllium-$VERSION.zip *
cp arter97-beryllium-$VERSION.zip ../arter97-beryllium-$VERSION.zip
cd ..

# Upload package
$TG -f arter97-beryllium-$VERSION.zip "$(cat $KERNELDIR/include/generated/uts* | cut -d '"' -f 2)"$'\n'$'\n'"HEAD: $(git log -n 1 --oneline)"$'\n'$'\n'"$(cat $KERNELDIR/include/generated/comp*h | grep LINUX_COMPILER | cut -d '"' -f 2)"$'\n'$'\n'"$(cat $KERNELDIR/include/generated/comp*h | grep UTS_VERSION | cut -d '"' -f 2)"
mv $LOG bl-$(ls arter*zip | rev | cut -d / -f 1 | rev | cut -d . -f 2 | cut -d - -f 2-).txt
$TG -f $LOG
# Grep warnings if any
grep warning* $LOG > w$(ls $LOG | rev | cut -d / -f 1 | rev)
if [ "$(cat $LOG2)" == "" ]; then
	echo no warning
else
	$TG -f $LOG2
fi
