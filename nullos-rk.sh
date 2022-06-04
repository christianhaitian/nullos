#!/bin/bash -e

# TODO: check to make sure it's running in linux

# deps
# TODO: check to make sure it's running in deb-based linux
sudo apt update
sudo apt install -y build-essential debootstrap unzip git dosfstools qemu-utils

DISKFILE="nullos-rk-$(date +"%m-%d-%Y").qcow2"
DEVICE_NBD="/dev/nbd0"
DIR_OUT="${PWD}"

# dowload prebuilt mali drivers
if [ ! -f "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip" ];then
  wget https://dn.odroid.com/RK3326/ODROID-GO-Advance/rk3326_r13p0_gbm_with_vulkan_and_cl.zip -O "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
fi

# download prebuilt /boot from arkOS (with light modification)
if [ ! -f "${DIR_OUT}/ark-boot-RG351V_v2.0_09262021.zip" ];then
  wget https://github.com/notnullgames/nullos/releases/download/rk-first/ark-boot-RG351V_v2.0_09262021.zip -O "${DIR_OUT}/ark-boot-RG351V_v2.0_09262021.zip"
fi

# clean up on exit
function finish {
  cd "${DIR_OUT}"
  sudo sync
  sudo umount "${DIR_OUT}/root/boot"
  sudo umount "${DIR_OUT}/root"
  sudo qemu-nbd --disconnect "${DEVICE_NBD}"
}
trap finish EXIT

# build disk image
qemu-img create -f qcow2 "${DISKFILE}" 2G
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect="${DEVICE_NBD}" "${DISKFILE}"

cat << EOF | sudo sfdisk --wipe always ${DEVICE_NBD}
label: dos
device:${DEVICE_NBD}
unit: sectors
sector-size: 512

${DEVICE_NBD}p1 : start=        2048, size=      204800, type=c
${DEVICE_NBD}p2 : start=      206848, size=     3987456, type=83
EOF

sudo mkfs -t vfat "${DEVICE_NBD}p1"
sudo mkfs -t ext2 "${DEVICE_NBD}p2"

sudo dosfslabel ${DEVICE_NBD}p1 BOOT
sudo e2label ${DEVICE_NBD}p2 NULLOS

sudo mkdir -p "${DIR_OUT}/root"
sudo mount "${DEVICE_NBD}p2" "${DIR_OUT}/root"
sudo mkdir -p "${DIR_OUT}/root/boot"
sudo mount "${DEVICE_NBD}p1" "${DIR_OUT}/root/boot"

sudo debootstrap --arch arm64 bullseye root https://deb.debian.org/debian

# extract mali drivers
cd "${DIR_OUT}"
unzip "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
sudo mkdir -p "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/" "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/"
sudo mv libmali.so_rk3326_gbm_arm64_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/libmali-bifrost-g31-rxp0-gbm.so"
sudo mv libmali.so_rk3326_gbm_arm32_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/libmali-bifrost-g31-rxp0-gbm.so"

# TODO: make gamepad-friendly "welcome" screen to set things up

cd "${DIR_OUT}/root/boot"
sudo unzip "${DIR_OUT}/ark-boot-RG351V_v2.0_09262021.zip"
sed "s/ROOTUUID/${UUID}/g" -i boot.ini
