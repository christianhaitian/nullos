#!/bin/bash -e

# This will build a qcow bootdisk for nullos

# TODO: break the steps into a series of cached qcow2 images, so we can branch into different builds
# TODO: use exfat for /boot ?

TARGET=${TARGET:-RG351V}
DISKFILE="${NAME:-nullos-rk-$(date +"%m-%d-%Y")-${TARGET}.qcow2}"
DEVICE_NBD=/dev/nbd1
DIR_OUT="$( realpath "${PWD}" )"
DIR_SOURCE="$( realpath "$(dirname "${0}" )" )"
DEBIAN_MIRROR=${DEBIAN_MIRROR:-https://deb.debian.org/debian}

GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

# simple echo, in color
function say {
  SAY_TEXT="${1}"
  SAY_COLOR=${2:-$YELLOW}
  printf "${SAY_COLOR}${SAY_TEXT}${ENDCOLOR}\n"
}

CHECK_APT_PROXY=$(curl -I http://127.0.0.1:3142/ftp.us.debian.org 2> /dev/null | awk '/HTTP\// {print $2}')
if [ "${CHECK_APT_PROXY}" == 200 ];then
  say "Found apt-cache. Using it."
  DEBIAN_MIRROR=http://127.0.0.1:3142/ftp.us.debian.org/debian
else
  say "No apt-cache. Speed things up with sudo apt install -y apt-cacher"
fi

# run with "boot" arg, and it will just fix up /boot on an existing disk-image and exit
BOOT_ONLY=0
if [ ! -z "${1}" ] && [ "${1}" == "boot" ];then
  say "You used boot option."
  BOOT_ONLY=1
fi


LIVE=0
if [ ! -z "${1}" ] && [ "${1}" == "live" ];then
  say "You used live option."
  LIVE=1
fi

# setup deps in host
function setup_host {
  say "Setting up dev-environment with tools needed to make nullos image"
  # TODO: check to make sure it's running in linux
  # TODO: check to make sure it's running in deb-based linux
  apt update
  apt install -y build-essential debootstrap unzip git dosfstools qemu-utils
}

# create the inial qcow image
function image_create {
  say "Creating disk image."
  qemu-img create -f qcow2 "${DIR_OUT}/${DISKFILE}" 2G
}

# create a device out of the qcow image
function image_bind {
  say "nbd-mounting image"
  modprobe nbd max_part=8
  qemu-nbd --connect="${DEVICE_NBD}" "${DIR_OUT}/${DISKFILE}"
}

# mount root & boot from qcow image
function image_mount {
  say "Setting up device for disk-image"

  UUID_ROOT=$(blkid -s UUID -o value "${DEVICE_NBD}p2")
  UUID_BOOT=$(blkid -s UUID -o value "${DEVICE_NBD}p1")

  say "Mounting root on ${DIR_OUT}/root."
  mkdir -p "${DIR_OUT}/root"
  mount "${DEVICE_NBD}p2" "${DIR_OUT}/root"

  say "Mounting boot on ${DIR_OUT}/root/boot."
  mkdir -p "${DIR_OUT}/root/boot"
  mount "${DEVICE_NBD}p1" "${DIR_OUT}/root/boot"
}

# clean up on exit
function image_unmount {
  say "Unmounting disk image."
  cd "${DIR_OUT}"
  sync
  umount -f "${DIR_OUT}/root/boot"
  umount -f "${DIR_OUT}/root/dev"
  umount -f "${DIR_OUT}/root"
  qemu-nbd --disconnect "${DEVICE_NBD}"
}

# setup partitions on fresh qcow image
function image_partition {
  say "Paritioning & formatting disk image."
  cat << EOF | sfdisk --wipe always ${DEVICE_NBD}
label: dos
device:${DEVICE_NBD}
unit: sectors
sector-size: 512

${DEVICE_NBD}p1 : start=        2048, size=      204800,  type=c,   name=BOOT, bootable
${DEVICE_NBD}p2 : start=      206848, size=     3987456, type=83, name=NULLOS
EOF
  mkfs -t vfat "${DEVICE_NBD}p1"
  mkfs -t ext2 "${DEVICE_NBD}p2"

  dosfslabel ${DEVICE_NBD}p1 BOOT
  e2label ${DEVICE_NBD}p2 NULLOS
}

# put files on /boot
function setup_ark {
  if [ -d "${DIR_OUT}/ark-${TARGET}" ];then
    say "Found ArkOS boot & kernel files."
  else
    if [ -f "${DIR_OUT}/ark-${TARGET}.zip" ];then
      say "Downloading ArkOS boot & kernel files."
      wget "https://github.com/notnullgames/nullos/releases/download/rk-first/ark-${TARGET}_v2.0_09262021.zip" -O "${DIR_OUT}/ark-${TARGET}.zip"
    fi
    mkdir -p "${DIR_OUT}/ark-${TARGET}"
    cd "${DIR_OUT}/ark-${TARGET}"
    unzip "${DIR_OUT}/ark-${TARGET}.zip"
  fi
  
  say "Copying ArkOS boot files."
  cp -R "${DIR_OUT}/ark-${TARGET}/boot/"* "${DIR_OUT}/root/boot/"
  
  say "Copying ArkOS kernel files."
  cp -R "${DIR_OUT}/ark-${TARGET}/modules/"* "${DIR_OUT}/root/lib/modules"

  # update UUID in /boot/boot.ini
  say "Updating boot to use UUID_ROOT=${UUID_ROOT}."
  cd "${DIR_OUT}"
  sed "s/{UUID_ROOT}/${UUID_ROOT}/g" -i "${DIR_OUT}/root/boot/boot.ini"
}

# put files on /
function setup_root {
  say "Building bullseye root with debootstrap"
  debootstrap --include="curl ssh connman ofono bluez wpasupplicant udev makedev" --arch arm64 bullseye "${DIR_OUT}/root" $DEBIAN_MIRROR

  # download prebuilt mali drivers
  if [ ! -f "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip" ];then
    say "Downloading mali GPU drivers."
    wget https://dn.odroid.com/RK3326/ODROID-GO-Advance/rk3326_r13p0_gbm_with_vulkan_and_cl.zip -O "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
  fi

  # extract mali drivers
  cd "${DIR_OUT}"
  say "Extracting mali GPU drivers."
  unzip "${DIR_OUT}/rk3326_r13p0_gbm_with_vulkan_and_cl.zip"
  mkdir -p "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/" "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/"
  mv libmali.so_rk3326_gbm_arm64_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/aarch64-linux-gnu/libmali-bifrost-g31-rxp0-gbm.so"
  mv libmali.so_rk3326_gbm_arm32_r13p0_with_vulkan_and_cl "${DIR_OUT}/root/usr/local/lib/arm-linux-gnueabihf/libmali-bifrost-g31-rxp0-gbm.so"

  say "Setting up files in root."

  # boot-settings manager
  mkdir -p "${DIR_OUT}/root/usr/local/bin/" "${DIR_OUT}/root/etc/systemd/system/"
  cp "${DIR_SOURCE}/nullos-config.py" "${DIR_OUT}/root/usr/local/bin/nullos-config.py"
  cp "${DIR_SOURCE}/nullos-config.service" "${DIR_OUT}/root/etc/systemd/system/nullos-config.service"

  printf "\nPermitRootLogin yes\n" >> "${DIR_OUT}/root/etc/ssh/sshd_config"
  echo "nullos" > "${DIR_OUT}/root/etc/hostname"

  cat << NET > "${DIR_OUT}/root/etc/network/interfaces"
auto lo
iface lo inet loopback
NET

  cat << FS > "${DIR_OUT}/root/etc/fstab"
UUID=${UUID_ROOT} / ext4 rw,discard,errors=remount-ro,x-systemd.growfs 0 1
UUID=${UUID_BOOT} /boot vfat defaults 0 0
proc             /proc         proc    defaults                 0    0
FS

  say "Setting up things in chroot."
  cat << CHROOT | chroot "${DIR_OUT}/root"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
systemctl disable ssh
printf "null0\nnull0\n" | passwd
apt-get clean
systemctl enable nullos-config
CHROOT
}

setup_host

trap image_unmount EXIT

if [ "${LIVE}" == 1 ]; then
  image_bind
  mount -t bind /dev "${DIR_OUT}/root/dev"
  say "You are in a chroot of the new disk image. Type exit to continue." $GREEN
  chroot "${DIR_OUT}/root"
else
  if [ "${BOOT_ONLY}" == 0 ]; then
    image_create
    image_bind
    image_partition
    image_mount
    setup_ark
    setup_root
    say "Disk image created at ${DISKFILE}." $GREEN
  else
    image_create
    image_bind
    image_partition
    image_mount
    setup_ark
    say "Disk image created at ${DISKFILE} (boot only.)" $GREEN
  fi
fi