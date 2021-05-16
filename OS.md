# OS Configuration

This is how I modified a raspbian-lite (by hand) to turn it into nullos. This will all be automated later.

## startup

You can find ways to trim startup time:

```
systemd-analyze blame
systemd-analyze critical-chain
```

On raspbian-lite longest times I found were for really basic stuff & networking (whcih is probly die to wifi/dhcp/ssh)

## raspi-config

These options are wrappers around other config fiels and stuff. Investigate what actually gets edited (cmdline, config, etc.)

- Display Options / Pixel Doubling - off (may already be off need to check)
- Performance/Overlay File System ?
- Interface Options/i2c
- Advanced Options / GL Driver / Full KMS (Fake KMS was needed for my LCD mini-monitor, disabled was needed for stock love to work on FB)
- Advanced Options / Expand Filesystem

## cmdline.txt

I want it to boot withoiut looking "hackery" or showing raspberries.

- `console=serial0,115200 console=tty3 root=PARTUUID=fb2b0f8d-02 rootfstype=ext4 elevator=deadline fsck.repair=yes logo.nologo quiet splash rootwait`

## config.txt

- `disable_splash=1`
- `dtparam=audio=off` and `hdmi_drive=2` since we use HDMI
- `disable_overscan=1`
- `dtparam=i2c_arm=on`


## other

**/etc/hostname**
```
nullbox
```

**/etc/hosts**
```
127.0.0.1 localhost
::1   localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

127.0.1.1 nullbox
```

**/etc/init.d/pakemon**
```bash
#!/usr/bin/bash

### BEGIN INIT INFO
# Provides:          pakemon
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Pakemon
# Description:       Pakemon Graphical Frontend
### END INIT INFO

case "$1" in
  start)
    love /home/pi/pakemon/src &
    ;;
  stop)
    killall -9 love
    ;;
  *)
    exit 1
    ;;
esac

exit 0
```

```
sudo update-rc.d pakemon defaults
```