#!/bin/bash

#set -e
export TZ='Asia/Kolkata' && date
export KERNELDIR=`readlink -f .`
echo "kerneldir = $KERNELDIR"
#export CCACHE_DIR=$PWD/../ccberyllium

TG=$HOME/telegram.sh/telegram
TGSTKR="curl https://api.telegram.org/bot${BOT_API_KEY}/sendSticker -d "chat_id=${CHAT_ID}" -d sticker="
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
	time git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 -b lineage-18.1 --depth 1 arm32-gcc
fi
if [ -d "arm64-gcc" ]; then
	echo "arm64-gcc already exists"
else
	time git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 -b lineage-18.1 --depth 1 arm64-gcc
fi
if [ -d "clang" ]; then
	echo "clang already exists"
else
	time git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 -b android11-release --depth 1 clang
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
rm -rf beryllium*.zip

# Start the build
SECONDS=0
time make ARCH=arm64 beryllium_defconfig
PATH="$KERNELDIR/clang/clang-r383902b/bin:$KERNELDIR/arm64-gcc/bin:$KERNELDIR/arm32-gcc/bin:${PATH}" \
	time make -j$(nproc --all) ARCH=arm64 \
	CC=clang \
	CLANG_TRIPLE=aarch64-linux-gnu- \
	CROSS_COMPILE=aarch64-linux-android- \
	CROSS_COMPILE_ARM32=arm-linux-androideabi- \
	2>&1 | tee bl-$(date +'%Y%m%d-%H%M').txt

if [ "$(grep Image.gz $LOG | cut -d / -f 4)" == "" ] ; then
	duration=$SECONDS
	echo "Build failed. ($(($duration / 60)) minute(s) and $(($duration % 60)) seconds)"
	$TG -f $LOG "Build failed. ($(($duration / 60)) minute(s) and $(($duration % 60)) seconds)"
	$TGSTKR"CAACAgIAAx0CZHWblQACGmxk7EsPW2fdT4kE9c80hf7rCjeo7AACLQADtEzqKNU0XYBPAmKKMAQ"
	exit 1
fi

#duration=$SECONDS
#echo "Build successful. ($(($duration / 60)) minute(s) and $(($duration % 60)) seconds)"
#$TG -f $LOG "Build successful. ($(($duration / 60)) minute(s) and $(($duration % 60)) seconds)"
#$TGSTKR"CAACAgIAAx0CZHWblQACGmtk7EsOE7CE28UD_n4bcQQXr_pKTwACPgADtEzqKETA00xcaOSEMAQ"

pack() {
VERSION="g$(git rev-parse --verify --short=8 HEAD 2>/dev/null)-$(date +'%Y%m%d-%H%M')"

rm beryllium-$VERSION.zip 2>/dev/null

# Pack AnyKernel3
rm -rf kernelzip
mkdir -p kernelzip/
cp out/arch/arm64/boot/Image.gz-dtb kernelzip/
cp -rp $KERNELDIR/anykernel3/* kernelzip/
cd kernelzip/
zip -r9 beryllium-$VERSION.zip *
cp beryllium-$VERSION.zip ../beryllium-$VERSION.zip
cd ..
}

up() {
# Upload package
duration=$SECONDS
echo "Build successful. ($(($duration / 60)) minute(s) and $(($duration % 60)) seconds)"
$TG -f beryllium-$VERSION.zip "Build successful. ($(($duration / 60)) minute(s) and $(($duration % 60)) seconds)"$'\n'$'\n'"$(ls bery*)"$'\n'$'\n'"$(cat $KERNELDIR/out/include/generated/uts* | cut -d '"' -f 2)"$'\n'$'\n'"$(cat $KERNELDIR/out/include/generated/comp*h | grep LINUX_COMPILER | cut -d '"' -f 2)"$'\n'$'\n'"$(cat $KERNELDIR/out/include/generated/comp*h | grep UTS_VERSION | cut -d '"' -f 2)"
mv $LOG bl-$(ls bery*zip | rev | cut -d / -f 1 | rev | cut -d . -f 1 | cut -d - -f 2-).txt
$TG -f $LOG
# Grep warnings if any
grep warning* $LOG > w$(ls $LOG | rev | cut -d / -f 1 | rev)
if [ "$(cat $LOG2)" == "" ]; then
	echo no warning
else
	$TG -f $LOG2
fi
$TGSTKR"CAACAgIAAx0CZHWblQACGmtk7EsOE7CE28UD_n4bcQQXr_pKTwACPgADtEzqKETA00xcaOSEMAQ"
}

pack && up
