#!/usr/bin/bash

# chroot into dev image

SCRIPT_DIR=$(cd "${0%[/\\]*}" > /dev/null && pwd)
WORK_DIR=$(realpath work)
source "${SCRIPT_DIR}/lib.sh"

ensure_dev
chroot_image "${WORK_DIR}/nullos-dev.img" $*