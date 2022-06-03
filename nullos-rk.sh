#!/bin/bash -e

DISKFILE="nullos-rk-$(date +"%m-%d-%Y").qcow2"

DIR=$PWD

function finish {
  sync
  umount "${DIR}/root/boot"
  umount "${DIR}/root"
  qemu-nbd --disconnect /dev/nbd0
}
trap finish EXIT

sudo apt install -y build-essential debootstrap unzip git dosfstools qemu-utils

if [ "$(uname -m)" == "aarch64" ]; then
  BOOTSTRAP="debootstrap"
else
  sudo apt install -y binfmt-support qemu-user-static 
  BOOTSTRAP="qemu-debootstrap --arch arm64"
fi

qemu-img create -f qcow2 "${DISKFILE}" 2G

sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 "${DISKFILE}"

cat << EOF | sudo sfdisk /dev/nbd0
/dev/nbd0p1 : start=        2048, size=      204800, type=6
/dev/nbd0p2 : start=      206848, size=     3987456, type=83
EOF

sudo mkfs -j /dev/nbd0p2
sudo mkfs -t fat /dev/nbd0p1
sudo mkdir -p root
sudo mount /dev/nbd0p2 root
sudo mkdir -p root/boot
sudo mount /dev/nbd0p1 root/boot

sudo ${BOOTSTRAP} bullseye root https://deb.debian.org/debian

wget https://dn.odroid.com/RK3326/ODROID-GO-Advance/rk3326_r13p0_gbm_with_vulkan_and_cl.zip
unzip rk3326_r13p0_gbm_with_vulkan_and_cl.zip
sudo mkdir -p root/usr/local/lib/aarch64-linux-gnu/ root/usr/local/lib/arm-linux-gnueabihf/
sudo mv libmali.so_rk3326_gbm_arm64_r13p0_with_vulkan_and_cl root/usr/local/lib/aarch64-linux-gnu/libmali-bifrost-g31-rxp0-gbm.so
sudo mv libmali.so_rk3326_gbm_arm32_r13p0_with_vulkan_and_cl root/usr/local/lib/arm-linux-gnueabihf/libmali-bifrost-g31-rxp0-gbm.so
rm rk3326_r13p0_gbm_with_vulkan_and_cl.zip

cd root/boot
unzip ../../ark-boot-RG351V_v2.0_09262021.zip
cd ../..