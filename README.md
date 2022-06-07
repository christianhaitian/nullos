# nullos

Fast-booting OS that is barely tuned from debian bullseye. There are 2 flavors: pi (for 32bit pi devices) and rk (for RK handheld devices, like the RG351V.)

In order to use it, you will need docker & qemu.

## rk

This is basically a minimal version of [jelos](https://github.com/JustEnoughLinuxOS/distribution) or [arkos](https://github.com/christianhaitian/arkos) with debian system installed on top.

You can get a pre-compiled [release image](https://github.com/notnullgames/nullos/releases) and install the img.gz file with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

You can edit /boot/nullos.ini to setup wifi & ssh and other things.

```ini
[system]
# root password
password = nullos

# your hostname
hostname = nullos

[network]
# your wifi settings
; ssid = "Your WIFI AP"
; psk = "your password"

# enable wifi
ssh = false
```

### creating image

You should use [releases](https://github.com/notnullgames/nullos/releases), if you aren't working on the image, but here is what I did on a Mac M1:

```sh
brew install lima
limactl start template://debian

# edit config, make sure ~ is writable

limactl shell debian ./nullos-rk.sh
```

You should also be able to use qemu or UTM, too, if you like.

Then you can clean up like this:

```
limactl stop debian
limactl rm debian
```

On a linux system, you should be able to just run `./nullos-rk.sh`

You can use the outputted image, like this:

```sh
# put directly on SD card like this:
sudo qemu-img dd -f qcow2 -O raw bs=100M if="nullos-rk-$(date +"%m-%d-%Y").qcow2" of=/dev/disk4

# convert qcow to raw image
qemu-img convert "nullos-rk-$(date +"%m-%d-%Y").qcow2" "nullos-rk-$(date +"%m-%d-%Y").raw"
gzip "nullos-rk-$(date +"%m-%d-%Y").raw" --stdout > "nullos-rk-$(date +"%m-%d-%Y").img.gz"
```


## pi

> **WARNING** This was the original target, but dev has slowed, since I have a RG351V, now. The current main of this repo no longer builds for this, but I will probably come back to it.


## art

- bootscreen from "Another World" / "Out Of This World" on Amiga


## todo

- qcow overlays for multiple device disks faster
- /boot/settings.ini: [example](https://github.com/JustEnoughLinuxOS/distribution/blob/main/packages/jelos/config/system/configs/system.cfg) [usage](https://github.com/JustEnoughLinuxOS/distribution/blob/main/packages/jelos/sources/scripts/wifictl) [parser](https://github.com/JustEnoughLinuxOS/distribution/blob/main/packages/jelos/profile.d/02-distribution#L17)
- use [network-manager](https://www.npmjs.com/package/node-network-manager) to manage internet
- [cache debootstrap](http://cheesehead-techblog.blogspot.com/2012/01/local-file-cache-to-speed-up.html) in dev environment?

## thanks

I could not have made this without the amazing work & help by these awesome developers:

- Christian Haitian (ArkOS)
- fewt (JELOS)
- Johnny on Flame (JELOS)
