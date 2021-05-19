#!/usr/bin/bash

# this will build a nullos disk

# setup host requirements
sudo apt install -y binfmt-support qemu-user-static
mkdir -p emu-files/root
cp emu-files/raspbian-lite.img emu-files/nullos.img

# resize the root partition to fill the disk
qemu-img resize emu-files/nullos.img -f raw +10G
LOOP=$(sudo losetup -fP --show emu-files/nullos.img)
echo "- +" | sudo sfdisk -N 2 $LOOP
sudo e2fsck -f "${LOOP}p2"
sudo resize2fs "${LOOP}p2"

# mount the partition
sudo mount "${LOOP}p2" emu-files/root
sudo mount "${LOOP}p1" emu-files/root/boot

chroot emu-files/root

# unmount & remove loop
sudo umount -f emu-files/root/boot
sudo umount -f emu-files/root
sudo losetup -d $LOOP