#!/usr/bin/bash

# Chroot to an image

WORK_DIR=$(realpath work)

function cleanup {
  # unmount & remove loop
  sudo umount -f "${WORK_DIR}/root/boot"
  sudo umount -f "${WORK_DIR}/root"
  sudo losetup -d $LOOP
}
trap cleanup EXIT

IMAGE="${1}"
shift

# setup host requirements
sudo apt install -y binfmt-support qemu-user-static git

# mount the partition
LOOP=$(sudo losetup -fP --show "${IMAGE}")
sudo mount "${LOOP}p2" "${WORK_DIR}/root"
sudo mount "${LOOP}p1" "${WORK_DIR}/root/boot"

sudo chroot "${WORK_DIR}/root" $*