#!/bin/sh

# This will build the kernel debs & u-boot. You shouldn't need to do this (use releases.)

# I was on a Mac M1 with case-insensitive filesystem, so I made a case-ensitive sparse disk image, mounted it, and ran this from there
# https://support.apple.com/et-ee/guide/disk-utility/dskutl11888/mac

# I figured out settings from here
# https://github.com/JustEnoughLinuxOS/distribution/blob/main/projects/Rockchip/devices/RG351V/options

# TODO: use stuff in rg351x-kernel/arch/arm64/boot for creating boot


# This should work well on windows/linux/mac on arm64 or x86_64 (you need docker, and on x86_64: qemu-user/binfmt)

cat << EOF | docker run --platform linux/arm64 -it --rm -v ${PWD}:/work --workdir /work debian:bullseye

apt update
apt upgrade -y
apt install -y build-essential bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves git python-is-python3 gcc-9 u-boot-tools

update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 9

git clone --depth 1 https://github.com/JustEnoughLinuxOS/rg351x-kernel.git
cd rg351x-kernel
make odroidgoa_defconfig
nice make -j`nproc` bindeb-pkg
mkimage -A arm64 -O linux -T kernel -C none -a 0x1080000 -e 0x1080000 -n 5.x -d arch/arm64/boot/Image ../Image
cp arch/arm64/boot/dts/rockchip/rk3326-rg351v-linux.dtb ..
EOF

# TODO: figure out how to make boot/Image & boot/uInitrd