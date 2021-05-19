#!/usr/bin/make -f

# TODO: make is supposed to skip files that it already built

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


.PHONY: emu
emu: work/raspbian-lite.img work/qemu-rpi-kernel ## run raspbian-lite (for exploring)
	qemu-system-arm \
		-M versatilepb \
		-cpu arm1176 \
		-m 256 \
		-drive "file=work/raspbian-lite.img,if=none,index=0,media=disk,format=raw,id=disk0" \
		-device "virtio-blk-pci,drive=disk0,disable-modern=on,disable-legacy=off" \
		-net "user,hostfwd=tcp::5022-:22" \
		-dtb "work/qemu-rpi-kernel/versatile-pb-buster-5.4.51.dtb" \
		-kernel "work/qemu-rpi-kernel/kernel-qemu-5.4.51-buster" \
		-append 'root=/dev/vda2 panic=1' \
		-no-reboot


.PHONY: debs
debs: work/libsdl2.deb work/libsdl2-dev.deb work/love.deb ## grab debs for SDL


.PHONY: nullos
nullos: work/nullos.img ## generate a custom nullos disk


.PHONY: chroot
chroot: work/nullos.img ## Run in chroot of notnull disk
	./scripts/chroot_image.sh work/nullos.img


.PHONY: chroot-dev
chroot-dev: work/raspbian-dev.img ## Run in chroot of dev disk
	./scripts/chroot_image.sh work/raspbian-dev.img


.PHONY: clean
clean: ## clean up built files
	sudo rm -rf work


### These support the above targets

work:
	mkdir -p work/


# build nullos image
work/nullos.img: work/raspbian-lite.img work/libsdl2.deb work/love.deb
	./scripts/nullos.sh

# build love using dev-image
work/love.deb: work/raspbian-dev.img
	./scripts/love.sh

# collect libsddl from retropie
work/libsdl2.deb: work
	wget https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-2.0-0_2.0.10+5rpi_armhf.deb -O work/libsdl2.deb

# collect libsdl-dev from retropie
work/libsdl2-dev.deb: work
	wget https://files.retropie.org.uk/binaries/buster/rpi1/libsdl2-dev_2.0.10+5rpi_armhf.deb -O work/libsdl2-dev.deb


# collect qemu kernel
work/qemu-rpi-kernel: work
	git clone --depth=1 https://github.com/dhruvvyas90/qemu-rpi-kernel.git work/qemu-rpi-kernel


# collect zip of raspbian-lite image
work/raspbian-lite.zip: work
	wget https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip -O  work/raspbian-lite.zip

# make a dev-image
work/raspbian-dev.img: work/raspbian-lite.img work/libsdl2.deb work/libsdl2-dev.deb
	./scripts/dev.sh

# extract raspberrypi-lite image
work/raspbian-lite.img: work/raspbian-lite.zip
	cd work && \
	unzip raspbian-lite.zip && \
	mv *armhf-lite.img raspbian-lite.img

