# nullos

Fast-booting OS that is barely tuned from debian bullseye. There are 2 flavors: pi (for 32bit pi devices) and rk (for RK handheld devices, like the RG351V.) I have stopped working on pi for now, but will probly come back to it.

## rk

This is basically a minimal version of [jelos](https://github.com/JustEnoughLinuxOS/distribution) or [arkos](https://github.com/christianhaitian/arkos) with regular debian system installed on top.

You can get a pre-compiled [release image](https://github.com/notnullgames/nullos/releases) and install the img.gz file with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

You can edit /boot/nullos.ini to setup wifi & ssh and other things.

### configuration

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

### development

Read [here](https://github.com/notnullgames/nullos/wiki/Development) for notes on making the image.


## art

- bootscreen from "Another World" / "Out Of This World" on Amiga


## todo

- qcow overlays for multiple device disks faster (base disk could be reused to cut down debootstrap, too)

## thanks

I could not have made this without the amazing work & help by these awesome developers:

- Christian Haitian (ArkOS) had some [great notes](https://github.com/christianhaitian/arkos/wiki/Building) on getting things working
- fewt (JELOS) made [JELOS](https://github.com/JustEnoughLinuxOS/distribution) and was extremely supportive and helped with some of the ideas
- Johnny on Flame (JELOS) was extremely supportive and helped with some of the ideas
