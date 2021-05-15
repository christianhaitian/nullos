#!/usr/bin/bash

# trim down raspbian system-services
# use systemd-analyze blame & systemd-analyze critical-chain to discover bloat

systemctl disable networking.service
