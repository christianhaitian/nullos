#!/usr/bin/bash

# this will build a love deb

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

LOOP=$(sudo losetup -fP --show "${WORK_DIR}/raspbian-dev.img")
sudo mount "${LOOP}p2" "${WORK_DIR}/root"

cat << CHROOT | sudo chroot "${WORK_DIR}/root" bash
git clone --depth=1 https://github.com/love2d/love /usr/src/love
cd /usr/src/love
./platform/unix/automagic
./configure
cp -R platform/unix/debian/ .
dpkg-buildpackage -us -uc -j12
CHROOT

cp "${WORK_DIR}/usr/src"/*.deb "${WORK_DIR}"
