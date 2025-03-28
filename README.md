# zarch

<!-- pacman -Qqme > installs.txt -->

Script for installing ArchLinux with ZFSBootMenu, native encryption and automatic system snapshots.

**IMPORTANT: This script is designed to work on modern EFI systems and DOES NOT SUPPORT traditional BIOS ones.**

## Features

- ZFSBootMenu on UEFI
- ArchLinux on Encrypted ZFS with automated snapshots via `zrepl`
- Configurable profiles for arch packages (`archpkg.txt`), aur packages (`aurpkg.txt`) and enabled system services (`services.txt`)
- `default` profile with
  - Gnome Desktop Environment
  - `zrepl` auto snapshots
  - Small footprint, helpful utilities

### Todo
- [ ] Auto-`scrub` via cronjob
- [ ] More specific predefined profiles (Notebook, Desktop, etc.)
- [ ] Integrate Ansible (?)
- [ ] Use `systemd-run` / `systemd-nspawn` instead of `set-locale-once` service
- [ ] Add BIOS support (if possible)

## Important Notes

- This is my personal script for a linux setup - I will not consider adding or changing things, that I do not need. If you need something to be changed or a custom profile, please fork the repository and maintain your own code.
- This script is planned as single, non-modular file with some minor config profiles - I'm not going to maintain a modular multi-script beast I don't fully understand

## Prerequisites: Custom base image

ZFS is not supported by the official images. However, there are efforts to provide downloadable ISO images including ZFS support:

- What I use:
  - https://github.com/r-maerz/archlinux-lts-zfs (~1.22GB)
- An alternative I did not test:
  - https://github.com/stevleibelt/arch-linux-live-cd-iso-with-zfs (~1.36GB)


## Installation media

I personally recommend to use [Ventoy] and just copy over the custom ISO to start the installation process. However, you may also use other tools to create a [USB flash installation medium]. 

## Boot installation media and enable SSH

Although this script installation does not require SSH per se, it is sometimes very helpful to perform or debug the installation over a remote connection to do some research or bridge waiting times. 

### Configure SSH access

These commands must be executed on the local system, after this you should have remote access via SSH:
```bash
# optional: load keymap (e.g. german keymap), to prevent mistakes typing the password
# loadkeys de

# permit root login
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# change password for root to be able to login via SSH
passwd root

# start SSH daemon
systemctl start sshd
```

If you need Wi-Fi access, this may be tricky within live systems, because you only have the command line and limited tooling. Here is an example of how to connect with Intel Wifi:

### Wifi connection

**Template**
```bash
iwctl
[iwd] device list
[iwd] station <device> scan
[iwd] station <device> get-networks
[iwd] station <device> connect <SSID>
```

**Example** with `device=wlan0` and `SSID=MyWifiNetwork`:
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

## Default profile

This script needs some basic settings. These can be configured in a profile directory, which must have the following structure:

- `archpkg.txt` - the packages that are installed by default
- `aurpkg.txt` - AUR (non-official user maintained) packages you'd like to install
- `services.txt` - Services you'd like to have enabled by default
- `zarch.conf` - Config file with `DISK`, `HOSTNAME`, `LOCALE` etc.

To create a custom profile, it is recommended to copy an existing profile directory and customize it by editing the files.

## Let's go

<span style="color:red;font-size:2em;">**⚠️WARNING: This script will wipe your disk. Only proceed if you know what you're doing.**</span>

Before starting to wipe the disk, `zarch.sh` will check some preconditions and if the passwords are empty, it will ask you to provide them. I did my best to prevent destroying your data, but I'm not responsible for possible data loss or script malfunctions. Be sure to have a backup.

**Starting `zarch.sh`**

```bash
# install required recommended tools
pacman -Sy --noconfirm --needed git screen vim

git clone https://github.com/sandreas/zarch

cd zarch

# ./zarch.sh <profile-directory>
./zarch.sh default
```

## ZFSBootMenu - encryption limitations

### TL;DR

You either need to

- Enter your decryption passphrase twice
- Store your passphrase in a plaintext file

### More details

[ZFSBootMenu] is a bootloader, that can boot from ZFS pools or datasets. To do so, it needs to read out the available datasets to let you choose, which one to boot. If your system is encrypted, you need to provide the passphrase to let [ZFSBootMenu] do its job. Unfortunately, the bootloader cannot pass the passphrase to decrypt the pool to the boot environment, which basically means that you have to enter the passphrase again after choosing the boot option.

This can be prevented by providing your passphrase in a plaintext file, but I did not consider that, since it felt wrong to me. If you would like to do so, you can follow [this guide](https://web.archive.org/web/20250228214144/https://florianesser.ch/posts/20220714-arch-install-zbm/) or work through the [ZFSBootMenu] documentation.



## References

I would like to thank the creators of the following projects / articles making this possible:

- Florian Esser - [Install Arch Linux on an encrypted zpool with ZFSBootMenu]
- Maurizio Oliveri - [arch_on_zfs]
- Chris Titus - [ArchTitus]

Further, I can recommend the excellent [ZFSBootMenu documentation]. I also plan to extend this repository in the future to support traditional BIOS systems, which should be supported, but for now you need UEFI.


[Ventoy]: https://www.ventoy.net/en/index.html
[USB flash installation medium]: https://wiki.archlinux.org/title/USB_flash_installation_medium
[ZFSBootMenu]: https://docs.zfsbootmenu.org

[ArchTitus]: https://github.com/ChrisTitusTech/ArchTitus/
[Install Arch Linux on an encrypted zpool with ZFSBootMenu]: https://web.archive.org/web/20250228214144/https://florianesser.ch/posts/20220714-arch-install-zbm/
[arch_on_zfs]: https://gist.github.com/Soulsuke/6a7d1f09f7fef968a2f32e0ff32a5c4c

[ZFSBootMenu documentation]: https://docs.zfsbootmenu.org/
[rEFInd integration]: https://docs.zfsbootmenu.org/en/v3.0.x/general/uefi-booting.html#id2