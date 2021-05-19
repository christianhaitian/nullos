#!/usr/bin/make -f

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


.PHONY: emu
emu: emu-files/raspbian-lite.img emu-files/qemu-rpi-kernel ## run raspbian-lite (for exploring)
	qemu-system-arm \
		-M versatilepb \
		-cpu arm1176 \
		-m 256 \
		-drive "file=emu-files/raspbian-lite.img,if=none,index=0,media=disk,format=raw,id=disk0" \
		-device "virtio-blk-pci,drive=disk0,disable-modern=on,disable-legacy=off" \
		-net "user,hostfwd=tcp::5022-:22" \
		-dtb "emu-files/qemu-rpi-kernel/versatile-pb-buster-5.4.51.dtb" \
		-kernel "emu-files/qemu-rpi-kernel/kernel-qemu-5.4.51-buster" \
		-append 'root=/dev/vda2 panic=1' \
		-no-reboot


.PHONY: debs
debs: emu-files/libsdl2.deb emu-files/libsdl2-dev.deb ## grab debs for SDL

.PHONY: nullos
nullos: emu-files/nullos.img ## generate a custom nullos disk


.PHONY: clean
clean: ## clean up built files
	sudo rm -rf work emu-files


### These support the above targets

emu-files:
	mkdir -p emu-files/


# build nullos image
emu-files/nullos.img: emu-files/raspbian-lite.img emu-files/libsdl2.deb emu-files/libsdl2-dev.deb
	./build_nullos.sh

# collect libsddl from retropie
emu-files/libsdl2.deb: emu-files
	wget https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-2.0-0_2.0.10+5rpi_armhf.deb -O emu-files/libsdl2.deb

# collect libsdl-dev from retropie
emu-files/libsdl2-dev.deb: emu-files
	wget https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-dev_2.0.10+5rpi_armhf.deb -O emu-files/libsdl2-dev.deb


# collect qemu kernel
emu-files/qemu-rpi-kernel: emu-files
	git clone --depth=1 https://github.com/dhruvvyas90/qemu-rpi-kernel.git emu-files/qemu-rpi-kernel


# collect zip of raspbian-lite image
emu-files/raspbian-lite.zip: emu-files
	wget https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip -O  emu-files/raspbian-lite.zip

# extract raspberrypi-lite image
emu-files/raspbian-lite.img: emu-files/raspbian-lite.zip
	cd emu-files && \
	unzip raspbian-lite.zip && \
	mv *armhf-lite.img raspbian-lite.img

