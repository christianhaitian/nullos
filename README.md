# nullos

Fast-booting OS that is barely tuned from debian bullseye. There are 2 flavors: pi (for 32bit pi devices) and rk (for RK handheld devices, like the RG351V.)

In order to use it, you will need docker & qemu.

## rk

This is basically a minimal version of [jelos](https://github.com/JustEnoughLinuxOS/distribution) or [arkos](https://github.com/christianhaitian/arkos) with debian system installed on top.

You can get a pre-compiled [release image](https://github.com/notnullgames/nullos/releases) and install the img.gz file with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

### creating image

Here is what I did on Mac M1:

```sh
brew install lima
limactl start template://debian

# edit config, make sure ~ is writable

limactl shell debian ./nullos-rk.sh
```

Then you can clean up like this:

```
limactl stop debian
limactl rm debian
```

On a linux system, you should be able to just run `./nullos-rk.sh`

You can use the outputted image, like this:

```sh
D=$(date +"%m-%d-%Y")

# put directly on SD card like this:
sudo qemu-img dd -f qcow2 -O raw bs=4M if="nullos-rk-${D}.qcow2" of=/dev/disk4

# convert qcow to raw image
qemu-img convert "nullos-rk-${D}.qcow2" "nullos-rk-${D}.raw"
gzip "nullos-rk-${D}.raw" --stdout > "nullos-rk-${D}.img.gz"
```


## pi

> **WARNING** This was the original target, but dev has slowed, since I have a RG351V, now. The current main of this repo no longer builds for this, but I will probably come back to it.


## thanks

I could not have made this without the amazing work & help by these awesome developers:

- Christian Haitian (ArkOS)
- fewt (JELOS)
- Johnny on Flame (JELOS)
