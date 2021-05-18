#!/usr/bin/bash

# this can be run in context of chroot or ssh to setup nullos

sudo apt update

# setup bootsplash & nologo/quiet boot
sudo apt install -y plymouth plymouth-label plymouth-themes git
sudo git clone --depth=1 https://github.com/konsumer/plymouth-theme.git /usr/share/plymouth/themes/notnull
sudo ln -s /usr/lib/arm-linux-gnueabihf/plymouth/script.so /usr/lib/arm-linux-gnueabihf/plymouth/notnull.so
sudo plymouth-set-default-theme notnull
cat /boot/cmdline.txt | sed 's/console=tty1/console=tty3/g' | sed 's/rootwait/rootwait logo.nologo quiet splash plymouth.enable=1 plymouth.ignore-serial-consoles/g' | sudo tee /boot/cmdline.txt

# TODO: figure out what raspi-config installs when you enable GL driver - I think it's "dtoverlay=vc4-fkms-v3d,cma-128"
# TODO: figure out what legacy/full/fake KMS options modify & see what works (in testing only disabled worked with regular love/sdl)
# TODO: love without X probly needs SDL recompile: https://discourse.libsdl.org/t/problems-using-sdl2-on-raspberry-pi-without-x11-running/22621/8
# TODO: look into "SDL_RENDER_DRIVER=opengles2" - https://github.com/libsdl-org/SDL/blob/22c221f3b0b19b8c6ccb70c866ee7eced099fdda/docs/README-raspberrypi.md
# TODO: Mesa recompiled with vc4 support will make SDL work by default

# setup host
echo "nullbox" | sudo tee /etc/hostname

cat << HOSTS | sudo tee /etc/hosts
127.0.0.1 localhost
::1   localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
127.0.1.1 nullbox
HOSTS

# add pi to input group
sudo usermod -aG input pi

# get a copy of pakemon & run early in boot-process
git clone --depth=1 https://github.com/notnullgames/pakemon.git /home/pi/pakemon
sudo apt install -y love
cat << PAKEMON | sudo tee /etc/init.d/pakemon
#!/usr/bin/bash

### BEGIN INIT INFO
# Provides:          pakemon
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Pakemon
# Description:       Pakemon Graphical Frontend
### END INIT INFO

export SDL_RENDER_DRIVER=opengles2

case "$1" in
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
PAKEMON
sudo chmod 755 /etc/init.d/pakemon
sudo update-rc.d pakemon defaults

# setup pi boot config
cat << CONFIG | sudo tee /boot/config.txt
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
