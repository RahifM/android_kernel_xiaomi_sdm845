make O=out ARCH=arm64 beryllium_defconfig

PATH="$HOME/clang/clang-r365631c/bin:$HOME/aarch64/bin:$HOME/arm/bin:${PATH}" \
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-android- \
                      CROSS_COMPILE_ARM32=arm-linux-androideabi-
