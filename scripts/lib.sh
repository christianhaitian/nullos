#!/usr/bin/bash

# Shared lib for other nullos scripts

# chroot script used to build dev
read -r -d '' SCRIPT_DEV <<'SCRIPT_DEV'
apt-get update
apt-get install -y git build-essential git debhelper dh-autoreconf pkg-config libtool g++ libfreetype6-dev luajit libluajit-5.1-dev libmodplug-dev libmpg123-dev libopenal-dev libphysfs-dev libogg-dev libvorbis-dev libtheora-dev zlib1g-dev
apt-get install -y /tmp/libsdl2.deb /tmp/libsdl2-dev.deb
SCRIPT_DEV

# chroot script used to build nullos
read -r -d '' SCRIPT_NULLOS <<'SCRIPT_NULLOS'
apt update && apt upgrade -y
apt install -y plymouth plymouth-label plymouth-themes
ln -s /usr/lib/arm-linux-gnueabihf/plymouth/script.so /usr/lib/arm-linux-gnueabihf/plymouth/notnull.so
plymouth-set-default-theme notnull
chmod 755 /etc/init.d/pakemon
update-rc.d pakemon defaults
apt-get install -y /tmp/liblove.deb /tmp/love.deb /tmp/libsdl2.deb
apt-get clean
SCRIPT_NULLOS

# chroot script used to build love debs
read -r -d '' SCRIPT_LOVE <<'SCRIPT_LOVE'
git clone --depth=1 https://github.com/love2d/love /usr/src/love
cd /usr/src/love
./platform/unix/automagic
./configure
cp -R platform/unix/debian/ .
dpkg-buildpackage -us -uc -j12 
SCRIPT_LOVE

# use on null os to start pakemon
read -r -d '' PAKEMON_INIT <<'PAKEMON_INIT'
#!/usr/bin/bash
### BEGIN INIT INFO
# Provides:          pakemon
# Required-Start:    \$local_fs
# Required-Stop:     \$local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Pakemon
# Description:       Pakemon Graphical Frontend
### END INIT INFO
export SDL_RENDER_DRIVER=opengles2
case "\$1" in
  start)
    love /home/pi/pakemon/src &
    ;;
  stop)
    killall -9 love
    ;;
  *)
    exit 1
    ;;
esac
exit 0
PAKEMON_INIT



# output red text
# Usage: red <TEXT>
red() {
    printf "\033[0;31m$@\033[0m\n"
}

# output green text
# Usage: green <TEXT>
green() {
    printf "\033[0;32m$@\033[0m\n"
}

# output yellow text
# Usage: yellow <TEXT>
yellow() {
    printf "\033[0;33m$@\033[0m\n"
}

# ensure OS deps are installed
yellow "Checking depedencies..."
sudo apt-get -qq install -y binfmt-support qemu-user-static git qemu-utils
export WORK_DIR=$(realpath work)
mkdir -p "${WORK_DIR}/root"

# mount a pi image
# Usage: mount_image <IMAGE_FILE>
mount_image() {
  if $(mount | grep -q "${WORK_DIR}/root"); then
    yellow "work/root is already mounted. Skipping."
  else
    export IMAGE="${1}"
    SHORT=$(basename "${IMAGE}")
    yellow "Mounting ${SHORT} on work/root."
    export LOOP=$(sudo losetup -fP --show "${IMAGE}")
    sudo mount "${LOOP}p2" "${WORK_DIR}/root"
    sudo mount "${LOOP}p1" "${WORK_DIR}/root/boot"
  fi
}

# unmount currently mounted pi-image
# Usage: umount_image
umount_image() {
  if $(mount | grep -q "${WORK_DIR}/root"); then
    yellow "Unmounting work/root."
    sudo rm -rf "${WORK_DIR}/root/tmp"/*
    sudo umount -f "${WORK_DIR}/root/boot"
    sudo umount -f "${WORK_DIR}/root"
    sudo losetup -d $LOOP
  else
    yellow "work/root not mounted, skipping."
  fi
}

# called on parent script-exit to make sure everything is cleaned up
trap umount_image EXIT

# chroot to a pi image
# Usage: chroot_image <IMAGE_FILE>
chroot_image() {
  mount_image "${1}"
  shift
  sudo chroot "${WORK_DIR}/root" $*
}

# make sure you have raspbian-lite base-image
# Usage: ensure_raspbian
ensure_raspbian() {
  if [ ! -f "${WORK_DIR}/raspbian-lite.img" ]; then
    if [ ! -f "${WORK_DIR}/raspbian-lite.zip" ]; then
      green "Downloading raspbian-lite."
      wget https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip -O  "${WORK_DIR}/raspbian-lite.zip"
    fi
    cd "${WORK_DIR}"
    unzip raspbian-lite.zip
    mv *.img raspbian-lite.img
  else
    yellow "Found raspbian-lite disk image."
  fi
}

# make sure you have dev image to build stuff in
# Usage: ensure_dev
ensure_dev() {
  if [ ! -f "${WORK_DIR}/nullos-dev.img" ]; then
    ensure_raspbian
    ensure_sdl
    green "Building dev disk image."
    cp "${WORK_DIR}/raspbian-lite.img" "${WORK_DIR}/nullos-dev.img"
    resize_image "${WORK_DIR}/nullos-dev.img" 10G
    mount_image "${WORK_DIR}/nullos-dev.img"
    cp "${WORK_DIR}/libsdl2.deb" "${WORK_DIR}/libsdl2-dev.deb" "${WORK_DIR}/root/tmp"
    echo "${SCRIPT_DEV}" | chroot_image "${WORK_DIR}/nullos-dev.img"
    umount_image
  else
    yellow "Found dev disk image."
  fi
}

# make sure you have the basic nullos image setup
# Usage: ensure_nullos
ensure_nullos() {
  if [ ! -f "${WORK_DIR}/nullos.img" ]; then
    ensure_raspbian
    ensure_sdl
    ensure_love
    green "Building nullos disk image."
    cp "${WORK_DIR}/raspbian-lite.img" "${WORK_DIR}/nullos.img"
    resize_image "${WORK_DIR}/nullos-dev.img" 10G
    cp "${WORK_DIR}/love.deb" "${WORK_DIR}/liblove.deb" "${WORK_DIR}/libsdl2.deb" "${WORK_DIR}/root/tmp"
    
    echo "${PAKEMON_INIT}" | sudo tee "${WORK_DIR}/root/etc/init.d/pakemon"
    sudo git clone --depth=1 https://github.com/notnullgames/pakemon.git "${WORK_DIR}/root/home/pi/pakemon"
    sudo git clone --depth=1 https://github.com/notnullgames/plymouth-theme.git "${WORK_DIR}/root/usr/share/plymouth/themes/notnull"
    
    echo "nullbox" | sudo tee "${WORK_DIR}/root/etc/hostname"
    cat << HOSTS | sudo tee "${WORK_DIR}/root/etc/hosts"
127.0.0.1 localhost
::1   localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
127.0.1.1 nullbox
HOSTS
    
    cat << CONFIG | sudo tee "${WORK_DIR}/root/boot/config.txt"
# For more options and information see
# http://rpf.io/configtxt
# Some settings may impact device functionality. See link above for details
# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1
# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
disable_overscan=1
# turn off rainbow-screen
disable_splash=1
# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16
# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720
# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1
# uncomment to force a specific HDMI mode (this will force VGA)
hdmi_group=1
hdmi_mode=1
# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
hdmi_drive=2
# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4
# uncomment for composite PAL
#sdtv_mode=2
#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800
# Uncomment some or all of these to enable the optional hardware interfaces
dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on
# Uncomment this to enable infrared communication.
#dtoverlay=gpio-ir,gpio_pin=17
#dtoverlay=gpio-ir-tx,gpio_pin=18
# Additional overlays and parameters are documented /boot/overlays/README
# Enable audio (loads snd_bcm2835)
dtparam=audio=on
[pi4]
# Enable DRM VC4 V3D driver on top of the dispmanx display stack
dtoverlay=vc4-fkms-v3d
max_framebuffers=2
[all]
dtoverlay=vc4-fkms-v3d,cma-128
gpu_mem=128
CONFIG

    
    echo "${SCRIPT_NULLOS}" | chroot_image "${WORK_DIR}/nullos.img"
    umount_image
  else
    yellow "Found nullos disk image."
  fi
}

# make sure you have qemu kernel stuff
# Usage: ensure_qemu_kernel
ensure_qemu_kernel() {
  if [ ! -d "${WORK_DIR}/qemu-rpi-kernel" ]; then
    green "Downloading qemu kernel."
    git clone --depth=1 https://github.com/dhruvvyas90/qemu-rpi-kernel.git "${WORK_DIR}/qemu-rpi-kernel"
  else
    yellow "Found qemu kernel."
  fi
}

# make sure you have retropie's SDL debs
# Usage: ensure_sdl
ensure_sdl() {
  if [ ! -f "${WORK_DIR}/libsdl2.deb" ] || [ ! -f "${WORK_DIR}/libsdl2-dev.deb" ]; then
    green "Downloading Retropie SDL debs."
    wget https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-2.0-0_2.0.10+5rpi_armhf.deb -O "${WORK_DIR}/libsdl2.deb"
    wget https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-dev_2.0.10+5rpi_armhf.deb -O "${WORK_DIR}/libsdl2-dev.deb"
  else
    yellow "Found Retropie SDL debs."
  fi
}

# make sure you have the built love deb
# Usage: ensure_love
ensure_love() {
  if [ ! -f "${WORK_DIR}/liblove.deb" ] || [ ! -f "${WORK_DIR}/love.deb" ]; then
    ensure_dev
    green "Building Love debs."
    echo "${SCRIPT_LOVE}" | chroot_image "${WORK_DIR}/nullos-dev.img"
    cp "${WORK_DIR}/root/usr/src"/liblove0*.deb "${WORK_DIR}/liblove.deb"
    cp "${WORK_DIR}/root/usr/src"/love_*.deb "${WORK_DIR}/love.deb"
    umount_image
  else
    yellow "Found Love debs."
  fi
}

# resize the image, and root partition to fill the disk
# Usage: resize_image <IMAGE_FILE> <SIZE>
resize_image() {
  IMAGE_FILE="${1}"
  SIZE="${2}"
  qemu-img resize "${IMAGE_FILE}" -f raw $SIZE
  echo "- +" | sfdisk -N2 "${IMAGE_FILE}"
  LOOP=$(sudo losetup -fP --show "${IMAGE_FILE}")
  sudo e2fsck -f "${LOOP}p2"
  sudo resize2fs "${LOOP}p2"
  sudo losetup -d $LOOP
}
