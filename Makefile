#!/usr/bin/make -f

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## clean up built files
	@sudo rm -rf work

.PHONY: chroot
chroot: ## Chroot into target nullos image
	@./scripts/chroot-nullos.sh

.PHONY: chroot-raspbian
chroot-raspbian: ## Chroot into raspbian-lite image to check stuff out
	@./scripts/chroot-raspbian.sh

.PHONY: chroot-dev
chroot-dev: ## Chroot into dev-image to manually build stuff
	@./scripts/chroot-dev.sh

.PHONY: build
build: ## Build nullos image
	@./scripts/chroot-nullos.sh echo "Image built"
