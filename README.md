# nullos

This repo is for building custom debs & making a modified (tuned for fast-boot) raspbian-lite disk-image. This is fairly new, so it could probably use a lot of tuning.

You will need qemu and docker to work with it, but should be able to use our stuff without building your own, if you like. You can get help with the build commands that are available with `make`.


## releases

We keep our build-artifacts in [releases](https://github.com/notnullgames/nullos2/releases).

- SDL - compiled to deb for use with the accelerated framebuffer drivers
- love - compiled to deb for pi

## TODO

- retropie SDL debs
- build love using retropie SDL debs

```
https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-dev_2.0.10+5rpi_armhf.deb
https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-2.0-0_2.0.10+5rpi_armhf.deb
```