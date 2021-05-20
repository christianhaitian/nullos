#!/usr/bin/bash

# chroot into nullos image

SCRIPT_DIR=$(cd "${0%[/\\]*}" > /dev/null && pwd)
WORK_DIR=$(realpath work)
source "${SCRIPT_DIR}/lib.sh"

ensure_nullos
chroot_image "${WORK_DIR}/nullos.img" $*
