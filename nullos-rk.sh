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

function say {
  SAY_TEXT="${1}"
  SAY_COLOR=${2:-$YELLOW}
  printf "${SAY_COLOR}${SAY_TEXT}${ENDCOLOR}\n"
}

BOOT_ONLY=0
if [ ! -z "${1}" ] && [ "${1}" == "boot" ];then
  say "You used boot option."
  BOOT_ONLY=1
fi

# clean up on exit
function finish {
  say "Unmounting disk image."
  cd "${DIR_OUT}"
  sudo sync
  sudo umount "${DIR_OUT}/root/boot"
  sudo umount "${DIR_OUT}/root"
  sudo qemu-nbd --disconnect "${DEVICE_NBD}"
}
trap finish EXIT

# build disk image
if [ "${BOOT_ONLY}" == 0 ]; then
  say "Creating disk image."
  qemu-img create -f qcow2 "${DIR_OUT}/${DISKFILE}" 2G
fi

sudo modprobe nbd max_part=8
sudo qemu-nbd --connect="${DEVICE_NBD}" "${DIR_OUT}/${DISKFILE}"

UUID_ROOT=$(sudo blkid -s UUID -o value "${DEVICE_NBD}p2")
UUID_BOOT=$(sudo blkid -s UUID -o value "${DEVICE_NBD}p1")

if [ "${BOOT_ONLY}" == 0 ]; then
  say "Paritioning & formatting disk image."
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

say "Mounting root on ${DIR_OUT}/root."
sudo mkdir -p "${DIR_OUT}/root"
sudo mount "${DEVICE_NBD}p2" "${DIR_OUT}/root"

say "Mounting boot on ${DIR_OUT}/root/boot."
sudo mkdir -p "${DIR_OUT}/root/boot"
sudo mount "${DEVICE_NBD}p1" "${DIR_OUT}/root/boot"

# TODO: use qcow overlays to generate all variants (not just RG351V)

# for dev, use boot/ or download zip
if [ -d "${DIR_OUT}/boot" ];then
  say "Copying dev boot/."
  sudo cp -R "${DIR_OUT}/boot"/* "${DIR_OUT}/root/boot/"
else
  # download prebuilt /boot from arkOS (with light modification)
  if [ ! -f "${DIR_OUT}/ark-boot.zip" ];then
    say "Downloading ArkOS zip boot."
    wget https://github.com/notnullgames/nullos/releases/download/rk-first/ark-boot-RG351V_v2.0_09262021.zip -O "${DIR_OUT}/ark-boot.zip"
  fi
  say "Extracting ArkOS zip boot."
  cd "${DIR_OUT}/root/boot"
  sudo unzip "${DIR_OUT}/ark-boot.zip"
fi

if [ ! -z "${0}" ] && [ "${0}" == "boot" ];then
  say "Exiting because you used boot option."
  exit 0
fi

if [ "${BOOT_ONLY}" == 0 ]; then
  sudo debootstrap --arch arm64 bullseye "${DIR_OUT}/root" https://deb.debian.org/debian

  # dowload prebuilt mali drivers
  if [ ! -f "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip" ];then
    say "Downloading mali GPU drivers."
    wget https://dn.odroid.com/RK3326/ODROID-GO-Advance/rk3326_r13p0_gbm_with_vulkan_and_cl.zip -O "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
  fi

  # extract mali drivers
  cd "${DIR_OUT}"
  say "Extracting mali GPU drivers."
  unzip "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
  sudo mkdir -p "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/" "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/"
  sudo mv libmali.so_rk3326_gbm_arm64_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/libmali-bifrost-g31-rxp0-gbm.so"
  sudo mv libmali.so_rk3326_gbm_arm32_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/libmali-bifrost-g31-rxp0-gbm.so"

  say "Setting up things in chroot."
  cat << EOF | sudo chroot "${DIR_OUT}/root"
apt install -y curl
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y openssh-server nodejs connman ofono bluez wpasupplicant
systemctl disable ssh
printf "\nPermitRootLogin yes\n" >> /etc/ssh/sshd_config
printf "null0\nnull0\n" | passwd
apt-get clean

echo "nullos" > /etc/hostname

cat << NET > /etc/network/interfaces
auto lo
iface lo inet loopback
NET

cat << FS > /etc/fstab
UUID=${UUID_ROOT} / ext4 rw,discard,errors=remount-ro,x-systemd.growfs 0 1
UUID=${UUID_BOOT} /boot vfat defaults 0 0
FS

EOF
  


  # TODO: install plymouth and themes?: https://github.com/adi1090x/plymouth-themes
fi

# update UUID
say "Updating boot to use {UUID_ROOT}=${UUID_ROOT}."
cd "${DIR_OUT}"
sudo sed "s/{UUID_ROOT}/${UUID_ROOT}/g" -i "${DIR_OUT}/root/boot/boot.ini"

if [ "${BOOT_ONLY}" == 0 ]; then
  say "Disk image created at ${DISKFILE}." $GREEN
else
  say "Boot modified at ${DISKFILE}." $GREEN
fi
