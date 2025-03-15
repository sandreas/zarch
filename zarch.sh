#!/bin/sh

ENV_FILE=".env"
PKG_FILE="pkglist.txt"
PKG_AUR_FILE="pkglist_aur.txt"


# pkglist.txt can be overridden with pkglist.txt.local
if [ -f "$PKG_FILE.local" ]; then
  PKG_FILE="$PKG_FILE.local"
fi

# pkglist_aur.txt can be overridden with pkglist_aur.txt.local
if [ -f "$PKG_AUR_FILE.local" ]; then
  PKG_AUR_FILE="$PKG_AUR_FILE.local"
fi

PKG_LIST="$(grep -v "^\s*#" $PKG_FILE)"
PKG_AUR_LIST="$(grep -v "^\s*#" $PKG_AUR_FILE)"


# function to load .env variable by name, example:
# load_env_variable DISK
function load_env_variable {
  echo "$(grep "$1" "$ENV_FILE" | cut -d '=' -f 2 | sed "s/^[\"']\(.*\)[\"'].*$/\1/")"
  return $?
}

function yes_or_no {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;
            [Nn]*) return 1 ;;
        esac
    done
}

function countdown {
  for i in $(seq $1 -1 1); do
    echo $i
    sleep 1
  done;
}

# .env file must exist, otherwise exit
if ! [ -f "$ENV_FILE" ]; then
  echo "please create a file called '$ENV_FILE' in the current directory"
  exit 1
fi

export DISK="$(load_env_variable DISK)"
export POOL="$(load_env_variable POOL)"
export HOSTNAME="$(load_env_variable HOSTNAME)"
export TIMEZONE="$(load_env_variable TIMEZONE)"
export LOCALE="$(load_env_variable LOCALE)"
export KEYMAP="$(load_env_variable KEYMAP)"
export CONSOLE_FONT="$(load_env_variable CONSOLE_FONT)"
export USERNAME="$(load_env_variable USERNAME)"
export USERPASSWD="$(load_env_variable USERPASSWD)" # change after boot



# Logo generated by https://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=ZARCH
# Font Name: ANSI Shadow
echo -ne "
----------------------------------------
███████╗ █████╗ ██████╗  ██████╗██╗  ██╗
╚══███╔╝██╔══██╗██╔══██╗██╔════╝██║  ██║
  ███╔╝ ███████║██████╔╝██║     ███████║
 ███╔╝  ██╔══██║██╔══██╗██║     ██╔══██║
███████╗██║  ██║██║  ██║╚██████╗██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
----------------------------------------

The following config has been loaded:

DISK=$DISK
POOL=$POOL
HOSTNAME=$HOSTNAME
TIMEZONE=$TIMEZONE
LOCALE=$LOCALE
CONSOLE_FONT=$CONSOLE_FONT
USERNAME=$USERNAME
USERPASSWD=$USERPASSWD

WARNING: If you proceed, your disk $DISK
will be COMPLETELY wiped and reformatted.
"
yes_or_no "Are you sure?" || exit 0

echo "ok, let's go in"
countdown 5


# start script

# generate host id (required by zfs)
zgenhostid

# clear all PARTITIONS and create required ones
sgdisk --zap-all $DISK
sgdisk -n1:1M:+512M -t1:EF00 $DISK
sgdisk -n2:0:0 -t2:BF00 $DISK
sleep 1 # required, otherwise the pool creation fails

# create ZFS pool and datasets
zpool create -f -o ashift=12 \
 -O compression=lz4 \
 -O acltype=posixacl \
 -O xattr=sa \
 -O relatime=off \
 -O atime=off \
 -O encryption=aes-256-gcm \
 -O keylocation=prompt \
 -O keyformat=passphrase \
 -o autotrim=on \
 -m none $POOL ${DISK}-part2

zfs create -o mountpoint=none $POOL/ROOT
zfs create -o mountpoint=/ -o canmount=noauto $POOL/ROOT/arch
zfs create -o mountpoint=/home $POOL/home

zpool export $POOL
zpool import -N -R /mnt $POOL
zfs load-key -L prompt $POOL
zfs mount $POOL/ROOT/arch
zfs mount $POOL/home

# create and mount EFI filesystem
mkfs.vfat -F 32 -n EFI $DISK-part1
mkdir /mnt/efi
mount $DISK-part1 /mnt/efi

# select fastest download mirror (significant improvements!)
iso=$(curl -4 ifconfig.co/country-iso)
pacman -Sy --noconfirm --needed reflector \
    && cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak \
    && reflector -a 48 -c "$iso" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

# enable parallel downloads
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# bootstrap base system into zfs filesystem under /mnt
pacstrap /mnt base linux-lts linux-firmware linux-lts-headers efibootmgr zfs-dkms

# bootstrap useful utilities
pacstrap /mnt "$PKG_LIST"

cp /etc/hostid /mnt/etc
cp /etc/resolv.conf /mnt/etc
cp /etc/pacman.conf /mnt/etc/pacman.conf

genfstab /mnt | grep 'LABEL=EFI' -A 1 > /mnt/etc/fstab

# locale settings
echo "LANG=$LOCALE" > /mnt/etc/locale.conf     # no need to define more than LANG - defaults the others
sed -i "s/^#$LOCALE/$LOCALE/g" "/mnt/etc/locale.gen"
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf

if ! [ "$CONSOLE_FONT" = "" ]; then
  echo "FONT=$CONSOLE_FONT" >> /mnt/etc/vconsole.conf
fi

echo "$HOSTNAME" > /mnt/etc/hostname

echo "# Static table lookup for hostnames." > /mnt/etc/hosts
echo "# See hosts(5) for details." >> /mnt/etc/hosts
echo "127.0.0.1   localhost" > /mnt/etc/hosts
echo "::1   localhost" >> /mnt/etc/hosts
echo "127.0.1.1   $HOSTNAME" >> /mnt/etc/hosts

sed -i '/^HOOKS=/s/block filesystems/block zfs filesystems/g' "/mnt/etc/mkinitcpio.conf"

arch-chroot /mnt hwclock --systohc
arch-chroot /mnt timedatectl set-local-rtc 0
arch-chroot /mnt locale-gen
arch-chroot /mnt mkinitcpio -P
arch-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache $POOL
arch-chroot /mnt zpool set bootfs=$POOL/ROOT/arch $POOL
arch-chroot /mnt systemctl enable zfs-import-cache zfs-import.target zfs-mount zfs-zed zfs.target
arch-chroot /mnt mkdir -p /efi/EFI/zbm
arch-chroot /mnt wget -c https://get.zfsbootmenu.org/latest.EFI -O /efi/EFI/zbm/zfsbootmenu.EFI
arch-chroot /mnt efibootmgr --disk $DISK --part 1 --create --label "ZFSBootMenu" --loader '\EFI\zbm\zfsbootmenu.EFI' --unicode "spl_hostid=0x$(hostid) zbm.timeout=1 zbm.prefer=$POOL zbm.import_policy=hostid rd.vconsole.keymap=$KEYMAP rd.vconsole.font=$CONSOLE_FONT quiet" --verbose
arch-chroot /mnt zfs set org.zfsbootmenu:commandline="noresume init_on_alloc=0 rw spl.spl hostid=$(hostid)" $POOL/ROOT


# enable services based on selected install packages
# exact word match is required, so no * is used in case
for pkg in $PKG_LIST; do
  s=""

  case "$pkg" in
    networkmanager)
      s="NetworkManager"
      ;;
    gnome)
      s="gdm"
      ;;
  esac

  [ "$s" = "" ] || arch-chroot /mnt systemctl enable "$s"
done;


# add normal user
arch-chroot /mnt useradd -m -G wheel,sudo -s /usr/bin/zsh "$USERNAME"
arch-chroot /mnt echo "$USERNAME:$USERPASSWD" | chpasswd

# install yay as normal user
arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- cd /tmp/ \
  && git clone https://aur.archlinux.org/yay-bin.git \
  && cd yay-bin \
  && makepkg -si \
  && yay -Y --gendb

# install aur packages via yay
arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- yay -S --noconfirm --needed $PKG_AUR_LIST

umount /mnt/efi
zpool export $POOL
