#!/bin/bash -e

# This will build a qcow bootdisk for nullos


# TODO: check to make sure it's running in linux

# deps
# TODO: check to make sure it's running in deb-based linux
sudo apt update
sudo apt install -y build-essential debootstrap unzip git dosfstools qemu-utils

DISKFILE="nullos-rk-$(date +"%m-%d-%Y").qcow2"
DEVICE_NBD="/dev/nbd0"
DIR_OUT="$( realpath "${PWD}" )"
DIR_SOURCE="$( realpath "$(dirname "${0}" )" )"

GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

BOOT_ONLY=0
if [ ! -z "${1}" ] && [ "${1}" == "boot" ];then
  printf "${YELLOW}You used boot option.${ENDCOLOR}\n"
  BOOT_ONLY=1
fi

# clean up on exit
function finish {
  printf "${YELLOW}Unmounting disk image.${ENDCOLOR}\n"
  cd "${DIR_OUT}"
  sudo sync
  sudo umount "${DIR_OUT}/root/boot"
  sudo umount "${DIR_OUT}/root"
  sudo qemu-nbd --disconnect "${DEVICE_NBD}"
}
trap finish EXIT

# build disk image
if [ "${BOOT_ONLY}" == 0 ]; then
  printf "${YELLOW}Creating disk image.${ENDCOLOR}\n"
  qemu-img create -f qcow2 "${DIR_OUT}/${DISKFILE}" 2G
  sudo modprobe nbd max_part=8
  sudo qemu-nbd --connect="${DEVICE_NBD}" "${DIR_OUT}/${DISKFILE}"

  cat << EOF | sudo sfdisk --wipe always ${DEVICE_NBD}
label: dos
device:${DEVICE_NBD}
unit: sectors
sector-size: 512

${DEVICE_NBD}p1 : start=        2048, size=      204800,  type=c,   name=BOOT, bootable
${DEVICE_NBD}p2 : start=      206848, size=     3987456, type=83, name=NULLOS
EOF

  sudo mkfs -t vfat "${DEVICE_NBD}p1"
  sudo mkfs -t ext2 "${DEVICE_NBD}p2"

  sudo dosfslabel ${DEVICE_NBD}p1 BOOT
  sudo e2label ${DEVICE_NBD}p2 NULLOS
fi

printf "${YELLOW}Mounting root on ${DIR_OUT}/root.${ENDCOLOR}\n"
sudo mkdir -p "${DIR_OUT}/root"
sudo mount "${DEVICE_NBD}p2" "${DIR_OUT}/root"

printf "${YELLOW}Mounting boot on ${DIR_OUT}/root/boot.${ENDCOLOR}\n"
sudo mkdir -p "${DIR_OUT}/root/boot"
sudo mount "${DEVICE_NBD}p1" "${DIR_OUT}/root/boot"

# TODO: use qcow overlays to generate all variants (not just RG351V)

# for dev, use boot/ or download zip
if [ -d "${DIR_OUT}/boot" ];then
  printf "${YELLOW}Copying dev boot/.${ENDCOLOR}\n"
  sudo cp -R "${DIR_OUT}/boot"/* "${DIR_OUT}/root/boot/"
else
  # download prebuilt /boot from arkOS (with light modification)
  if [ ! -f "${DIR_OUT}/ark-boot-RG351V_v2.0_09262021.zip" ];then
    printf "${YELLOW}Downloading ArkOS zip boot.${ENDCOLOR}\n"
    wget https://github.com/notnullgames/nullos/releases/download/rk-first/ark-boot-RG351V_v2.0_09262021.zip -O "${DIR_OUT}/ark-boot-RG351V_v2.0_09262021.zip"
  fi
  printf "${YELLOW}Extracting ArkOS zip boot.${ENDCOLOR}\n"
  cd "${DIR_OUT}/root/boot"
  sudo unzip "${DIR_OUT}/ark-boot-RG351V_v2.0_09262021.zip"
fi

if [ ! -z "${0}" ] && [ "${0}" == "boot" ];then
  printf "${YELLOW}Exiting because you used boot option.${ENDCOLOR}\n"
  exit 0
fi

if [ "${BOOT_ONLY}" == 0 ]; then
  sudo debootstrap --arch arm64 bullseye "${DIR_OUT}/root" https://deb.debian.org/debian

  # dowload prebuilt mali drivers
  if [ ! -f "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip" ];then
    printf "${YELLOW}Downloading mali GPU drivers.${ENDCOLOR}\n"
    wget https://dn.odroid.com/RK3326/ODROID-GO-Advance/rk3326_r13p0_gbm_with_vulkan_and_cl.zip -O "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
  fi

  # extract mali drivers
  cd "${DIR_OUT}"
  printf "${YELLOW}Extracting mali GPU drivers.${ENDCOLOR}\n"
  unzip "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
  sudo mkdir -p "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/" "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/"
  sudo mv libmali.so_rk3326_gbm_arm64_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/libmali-bifrost-g31-rxp0-gbm.so"
  sudo mv libmali.so_rk3326_gbm_arm32_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/libmali-bifrost-g31-rxp0-gbm.so"

  # TODO: make gamepad-friendly "welcome" screen to set things up
fi

# update UUID
printf "${YELLOW}Updating boot to use {UUID_ROOT}=${UUID_ROOT}.${ENDCOLOR}\n"
UUID_ROOT=$(sudo blkid -s UUID -o value "${DEVICE_NBD}p2")
cd "${DIR_OUT}"
sudo sed "s/{UUID_ROOT}/${UUID_ROOT}/g" -i "${DIR_OUT}/root/boot/boot.ini"

if [ "${BOOT_ONLY}" == 0 ]; then
  printf "${GREEN}Disk image created at ${DISKFILE}.${ENDCOLOR}\n"
else
  printf "${GREEN}Boot modified at ${DISKFILE}.${ENDCOLOR}\n"
fi
