
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


.PHONY: emu
emu: ## run raspbian-lite in qemu to look at how things are setup
	./emu


.PHONY: debs
debs: work/libsdl2_2.0.14_armhf.deb	## build custom debs in work/


.PHONY: clean
clean:	## clean up built files
	sudo rm -rf work


# setup docker for building debs
.PHONY: docker-build
docker-build:
	docker build -t pisdlbuild docker/


# build debs
work/libsdl2_2.0.14_armhf.deb: docker-build
	docker run --platform armhf -v ${PWD}/work:/work --rm pisdlbuild