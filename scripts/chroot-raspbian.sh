#!/usr/bin/bash

# chroot into upstream raspbian image

SCRIPT_DIR=$(cd "${0%[/\\]*}" > /dev/null && pwd)
WORK_DIR=$(realpath work)
source "${SCRIPT_DIR}/lib.sh"

ensure_raspbian
chroot_image "${WORK_DIR}/raspbian-lite.img" $*