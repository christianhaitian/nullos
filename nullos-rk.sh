#!/bin/bash -e

# This will build a qcow bootdisk for nullos

DISKFILE="nullos-rk-$(date +"%m-%d-%Y").qcow2"
DEVICE_NBD="/dev/nbd0"
DIR_OUT="$( realpath "${PWD}" )"
DIR_SOURCE="$( realpath "$(dirname "${0}" )" )"

GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

# simple echo, in color
function say {
  SAY_TEXT="${1}"
  SAY_COLOR=${2:-$YELLOW}
  printf "${SAY_COLOR}${SAY_TEXT}${ENDCOLOR}\n"
}

# run with "boot" arg, and it will just fix up /boot on an existing disk-image and exit
BOOT_ONLY=0
if [ ! -z "${1}" ] && [ "${1}" == "boot" ];then
  say "You used boot option."
  BOOT_ONLY=1
fi

# setup deps in host
function setup_host {
  say "Setting up dev-environment with tools needed to make nullos image"
  # TODO: check to make sure it's running in linux
  # TODO: check to make sure it's running in deb-based linux
  sudo apt update
  sudo apt install -y build-essential debootstrap unzip git dosfstools qemu-utils
}

# create the inial qcow image
function image_create {
  say "Creating disk image."
  qemu-img create -f qcow2 "${DIR_OUT}/${DISKFILE}" 2G
  sudo modprobe nbd max_part=8
  sudo qemu-nbd --connect="${DEVICE_NBD}" "${DIR_OUT}/${DISKFILE}"
}

# mount root & boot from qcow image
function image_mount {
  say "Mounting disk image."

  say "Mounting root on ${DIR_OUT}/root."
  sudo mkdir -p "${DIR_OUT}/root"
  sudo mount "${DEVICE_NBD}p2" "${DIR_OUT}/root"

  say "Mounting boot on ${DIR_OUT}/root/boot."
  sudo mkdir -p "${DIR_OUT}/root/boot"
  sudo mount "${DEVICE_NBD}p1" "${DIR_OUT}/root/boot"
}

# clean up on exit
function image_unmount {
  say "Unmounting disk image."
  cd "${DIR_OUT}"
  sudo sync
  sudo umount "${DIR_OUT}/root/boot"
  sudo umount "${DIR_OUT}/root"
  sudo qemu-nbd --disconnect "${DEVICE_NBD}"
}
trap image_unmount EXIT

# setup partitions on fresh qcow image
function image_partition {
  say "Paritioning & formatting disk image."
  cat << EOF | sudo sfdisk --wipe always ${DEVICE_NBD}
label: dos
device:${DEVICE_NBD}
unit: sectors
sector-size: 512

${DEVICE_NBD}p1 : start=        2048, size=      204800,  type=c,   name=BOOT, bootable
${DEVICE_NBD}p2 : start=      206848, size=     3987456, type=83, name=NULLOS
EOF
  UUID_ROOT=$(sudo blkid -s UUID -o value "${DEVICE_NBD}p2")
  UUID_BOOT=$(sudo blkid -s UUID -o value "${DEVICE_NBD}p1")

  sudo mkfs -t vfat "${DEVICE_NBD}p1"
  sudo mkfs -t ext2 "${DEVICE_NBD}p2"

  sudo dosfslabel ${DEVICE_NBD}p1 BOOT
  sudo e2label ${DEVICE_NBD}p2 NULLOS
}

# put files on /boot
function setup_boot {
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

  # update UUID in /boot/boot.ini
  say "Updating boot to use {UUID_ROOT}=${UUID_ROOT}."
  cd "${DIR_OUT}"
  sudo sed "s/{UUID_ROOT}/${UUID_ROOT}/g" -i "${DIR_OUT}/root/boot/boot.ini"
}

# put files on /
function setup_root {
  sudo debootstrap --arch arm64 bullseye "${DIR_OUT}/root" https://deb.debian.org/debian

  # download prebuilt mali drivers
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

  # boot-settings manager
  sudo mkdir -p "${DIR_OUT}/root/usr/local/bin/"
  sudo cp "${DIR_SOURCE}/nullos-config.py" "${DIR_OUT}/root/usr/local/bin/nullos-config.py"
  sudo cp "${DIR_SOURCE}/nullos-config.service" "${DIR_OUT}/etc/systemd/system/nullos-config.service"

  say "Setting up things in chroot."
  cat << EOF | sudo chroot "${DIR_OUT}/root"
apt install -y curl
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y openssh-server nodejs connman ofono bluez wpasupplicant
systemctl disable ssh
printf "\nPermitRootLogin yes\n" >> /etc/ssh/sshd_config
printf "null0\nnull0\n" | passwd
apt-get clean
systemctl enable nullos-config

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
}


setup_host

if [ "${BOOT_ONLY}" == 0 ]; then
  image_create
  image_partition
  image_mount
  setup_boot
  setup_root
  say "Disk image created at ${DISKFILE}." $GREEN
else
  image_mount
  setup_boot
  say "Boot modified at ${DISKFILE}." $GREEN
fi
