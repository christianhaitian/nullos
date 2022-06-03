# nullos

Fast-booting OS that is barely tuned from debian bullseye. There are 2 flavors: pi (for 32bit pi devices) and rk (for RK handheld devices, like the RG351V.)

In order to use it, you will need docker & qemu.

# rk

This is basically a minimal version of [jelos](https://github.com/JustEnoughLinuxOS/distribution) or [arkos](https://github.com/christianhaitian/arkos) with debian system installed on top.

Here is what I did on Mac M1:

```sh
brew install lima
limactl start template://debian

# edit config, make sure ~ is writable

limactl shell debian ./nullos-rk.sh
```

On a linux system, you should be able to just run `./nullos-rk.sh`

You can use the outputted image, like this:

```sh
D=$(date +"%m-%d-%Y")

# put directly on SD card like this:
qemu-img dd -f qcow2 -O raw bs=4M if="nullos-rk-${D}.qcow2" of=/dev/sdd

# convert qcow to raw image
qemu-img convert "nullos-rk-${D}.qcow2" "nullos-rk-${D}.raw"
gzip "nullos-rk-${D}.raw" --stdout > "nullos-rk-${D}.img.gz"
```


## pi

> **WARNING** This was the original target, but dev has slowed, since I have a RG351V, now. The current main of this repo no longer builds for this, but I will probably come back to it.

You should be able to grab the `img.gz` file from the [latest release](https://github.com/notnullgames/nullos/releases) and extract it to your >10G SD card with `dd` or hwatever you like to use to turn pi image-files into SD cards.


## thanks

I could not have made this, or a lot of projects I work on without the amazing work & help by these awesome developers:

- Christian Haitian (ArkOS)
- fewt (JELOS)
- Johnny on Flame (JELOS)
