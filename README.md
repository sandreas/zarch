# zarch

Script for installing ArchLinux with ZFSBootMenu, native encryption and automatic system snapshots.

## Features

- Encrypted ZFS with automated snapshots
- ZFSBootMenu
- Gnome

## Important Notes

- This is my personal script for a linux setup - I will not consider adding or changing things, that I absolutely do not need. If you need something to be changed, fork the repository and maintain your own patches.
- This script is planned as single, non-modular file with some minor configs - I'm not going to maintain a modular beast I don't fully understand
- This script is a work in progress and not ready. As soon as it is usable, this note will be removed.

## Prerequisites: Custom base image

ZFS is not supported by the official images. However, there are efforts to provide downloadable ISO images including ZFS support:

- https://github.com/r-maerz/archlinux-lts-zfs
- https://github.com/stevleibelt/arch-linux-live-cd-iso-with-zfs


## Installation media

I personally recommend to use [Ventoy] and just copy over the custom ISO to start the installation process. However, you may also use other tools to create a [USB flash installation medium]. 


## Boot installation media and enable SSH

Although this script installation does not require it, it sometimes is very helpful to perform or debug the installation via SSH. 

### SSH access
```bash
# optional: load keymap (e.g. german keymap) to prevent mistakes typing the password
loadkeys de

# permit root login
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# change password for root to be able to login via SSH
passwd root

# start SSH daemon
systemctl start sshd
```

If you need wifi access, this may be tricky within live systems, because you only have the command line and limited tooling. Here are some examples of how to connect:

### Wifi connection

```bash
iwctl
[iwd] device list
[iwd] station <device> scan
[iwd] station <device> get-networks
[iwd] station <device> connect <SSID>
```

Example with `device=wlan0` and `SSID=MyWifiNetwork`:
```bash
iwctl
[iwd] device list
[iwd] station wlan0 scan
[iwd] station wlan0 get-networks
[iwd] station wlan0 connect MyWifiNetwork
```

If `iwctl` is not available, you may also use the `NetworkManager` command line interface `nmcli`:

```bash
nmcli device wifi connect <SSID> --ask
```

## Initial script configuration - `.env`

This script needs some basic settings. These can be configured in a file called `.env` by default. There is a commented `.env.sample` in this repository, that you can use as a start:

```
DISK="/dev/disk/by-id/nvme-SAMSUNG_my-id"
# pool - ZFS root pool
POOL="rpool"
# hostname - hostname for installation
HOSTNAME="myhostname"
# timezone - which time base should be used
TIMEZONE="America/Chicago"
# locale - display format for date, time, numbers, etc.
LOCALE="en_US.UTF-8"
# keymap - preferred keyboard layout
KEYMAP="us"
# console font - bootup font (see https://wiki.archlinux.org/title/Linux_console)
CONSOLE_FONT="lat2-16"
# username - creates sudo user besides root
USERNAME="sandreas"
# userpasswd - password for this user, you can either specifiy plaintext or just change it after installation
USERPASSWD="password"
```

## ZFSBootMenu - encryption limitations

### TL;DR

You either need to

- Enter your decryption passphrase twice
- Store your passphrase in a plaintext file

### More details

[ZFSBootMenu] is a bootloader, that can boot from ZFS pools or datasets. To do so, it needs to read out the available datasets to let you choose, which one to boot. If your system is encrypted, you need to provide the passphrase to let [ZFSBootMenu] do its job. Unfortunately, the bootloader cannot pass the passphrase to decrypt the pool to the boot environment, which basically means that you have to enter the passphrase again after choosing the boot option. 

This can be prevented by providing your passphrase in a plaintext file, but I did not consider that, since it felt wrong to me. If you would like to do so, you can follow [this guide](https://web.archive.org/web/20250228214144/https://florianesser.ch/posts/20220714-arch-install-zbm/) or work through the [ZFSBootMenu] documentation.

## Let's go




[Ventoy]: https://www.ventoy.net/en/index.html
[USB flash installation medium]: https://wiki.archlinux.org/title/USB_flash_installation_medium
[ZFSBootMenu]: https://docs.zfsbootmenu.org