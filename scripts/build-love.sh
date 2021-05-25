#!/usr/bin/bash

# Just build love debs

SCRIPT_DIR=$(cd "${0%[/\\]*}" > /dev/null && pwd)
WORK_DIR=$(realpath work)
source "${SCRIPT_DIR}/lib.sh"

ensure_love
