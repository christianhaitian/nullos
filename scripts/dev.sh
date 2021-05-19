#!/usr/bin/bash

# this will build a raspbian dev disk

WORK_DIR=$(realpath work)

function cleanup {
  # unmount & remove loop
  sudo umount -f "${WORK_DIR}/root"
  sudo losetup -d $LOOP
}
trap cleanup EXIT

# setup host requirements
sudo apt install -y binfmt-support qemu-user-static git
mkdir -p "${WORK_DIR}/root"
cp ${WORK_DIR}/raspbian-lite.img "${WORK_DIR}/raspbian-dev.img"

# resize the root partition to fill the disk
qemu-img resize "${WORK_DIR}/raspbian-dev.img" -f raw 10G
LOOP=$(sudo losetup -fP --show "${WORK_DIR}/raspbian-dev.img")
echo "- +" | sudo sfdisk -N 2 $LOOP
sudo e2fsck -f "${LOOP}p2"
sudo resize2fs "${LOOP}p2"

# mount the partition
sudo mount "${LOOP}p2" "${WORK_DIR}/root"

sudo chroot "${WORK_DIR}/root" apt-get update

sed 's/deb /deb-src /g'  "${WORK}/etc/apt/sources.list" | sudo tee -a "${WORK}/etc/apt/sources.list"

cp "${WORK_DIR}/libsdl2.deb" "${WORK_DIR}/libsdl2-dev.deb" "${WORK_DIR}/root/tmp/"

cat << CHROOT | sudo chroot "${WORK_DIR}/root" bash
apt-get update && apt-get upgrade -y
apt-get install -y build-essential git debhelper dh-autoreconf pkg-config libtool g++ libfreetype6-dev luajit libluajit-5.1-dev libmodplug-dev libmpg123-dev libopenal-dev libphysfs-dev libogg-dev libvorbis-dev libtheora-dev zlib1g-dev
apt-get install -y /tmp/*.deb
rm /tmp/*.deb
CHROOT

