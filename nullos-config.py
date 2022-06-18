#!/usr/bin/env python3

# this will make the system config match the config file
# it should be run as root

import configparser
import sys
import os

config = configparser.ConfigParser()
config._interpolation = configparser.ExtendedInterpolation()

try:
  config.read(sys.argv[1])
except IndexError:
  config.read('/boot/nullos.ini')

try:
  root_password = config['system']['password']
  os.system(f'printf "{root_password}\n{root_passwd}\n" | passwd')
except:
  pass

try:
  hostname = config['system']['hostname']
  f = open("/etc/hostname")
  f.write(hostname)
  f.close()
except:
  print("Could not set hotname")
  pass

try:
  ssh = config['network']['ssh']
  if ssh:
    os.system('systemctl start ssh.service')
except:
  pass

try:
  ssid = config['network']['ssid']
  psk = config['network']['psk']
  f = open("/var/lib/connman/nullos.conf")
  f.write(f"""
[service_nullos_wifi]
Type = wifi
Name = {ssid}
Passphrase = {psk}
Security = psk
""")
  f.close()
  os.system('connmanctl enable wifi')
except:
  pass