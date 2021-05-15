#!/usr/bin/make -f

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


.PHONY: emu
emu: ## run raspbian-lite in qemu to look at how things are setup
	# TODO: put this all inline, here
	./emu


.PHONY: debs
debs: docker-build ## build custom debs in work/
	docker run --platform armhf -v ${PWD}/work:/work --rm pisdlbuild
	docker run --platform armhf -v ${PWD}/work:/work --rm pilovebuild


.PHONY: clean
clean: ## clean up built files
	sudo rm -rf work


.PHONY: docker-build
docker-build: # setup docker for building debs
	docker build -f docker/sdl.Dockerfile -t pisdlbuild docker/
	docker build -f docker/love.Dockerfile -t pilovebuild docker/
