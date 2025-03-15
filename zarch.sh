#!/bin/sh

# define fix config vars
export CONF_FILE="zarch.conf"
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

# read pkglist.txt and pkglist_aur.txt
PKG_LIST="$(grep -v '^\s*$\|^\s*#' $PKG_FILE)"
PKG_AUR_LIST="$(grep -v '^\s*$\|^\s*#' $PKG_AUR_FILE)"

# RUN executes and logs a command (e.g. RUN echo "test")
function RUN() {
  cmd="$@"
  # echo command before executing it (to show progress)
  echo "$cmd"
  output="$(sh -c "$cmd" 2>&1)"
  returnCode="$?"

  # echo output after all variables have been set to prevent setting return code of echo command
  echo $output

  # log command, output and return code
  LOG "$cmd"
  [ "$output" = "" ] || LOG "$output"
  LOG "return code: $returnCode"
  LOG ""


  CHECK_SUCCESS "$returnCode" "$cmd" "$output"
}

# CHECK_SUCCESS checks the success return code of a command (e.g. CHECK_SUCCESS "$?" "echo 'test'")
function CHECK_SUCCESS() {
    returnCode="$1"
    cmd="$2"
    output="$3"
    # if command failed, exit program
    if ! [ "$returnCode" = "0" ]; then
      echo "COMMAND FAILED (Code $returnCode):"
      echo "==================================="
      echo "  $cmd"
      echo "  $output"
      echo "==================================="
      exit $returnCode
    fi
}

function LOG() {
  if [ "$LOG_FILE" = "" ]; then
    export LOG_FILE="$(basename $0).log"
  fi
  echo "$1" >> "$LOG_FILE"
}


# function to load .env variable by name, example:
# load_env_variable DISK
function load_env_variable {
  echo "$(grep "$1" "$CONF_FILE" | cut -d '=' -f 2 | sed "s/^[\"']\(.*\)[\"'].*$/\1/")"
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
if ! [ -f "$CONF_FILE" ]; then
  echo "please create a file called '$CONF_FILE' in the current directory"
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

# generate /etc/hostid (required by zfs)
[ -f /etc/hostid ] || RUN zgenhostid

# clear all PARTITIONS and create required ones
RUN sgdisk --zap-all $DISK
RUN sgdisk -n1:1M:+512M -t1:EF00 $DISK
RUN sgdisk -n2:0:0 -t2:BF00 $DISK
RUN sleep 1 # required, otherwise the pool creation fails

# create ZFS pool and datasets
# RUN not possible due to password prompt
echo "zpool create -f -o ashift=12 ..."
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
CHECK_SUCCESS "$?" "zpool create"

RUN zfs create -o mountpoint=none $POOL/ROOT
RUN zfs create -o mountpoint=/ -o canmount=noauto $POOL/ROOT/arch
RUN zfs create -o mountpoint=/home $POOL/home

RUN zpool export $POOL

RUN zpool import -N -R /mnt $POOL
# RUN not possible due to password prompt
echo "zfs load-key -L prompt $POOL"
zfs load-key -L prompt $POOL
CHECK_SUCCESS "$?" "zfs load-key -L prompt $POOL"
RUN zfs mount $POOL/ROOT/arch
RUN zfs mount $POOL/home

# create and mount EFI filesystem
RUN mkfs.vfat -F 32 -n EFI $DISK-part1
RUN mkdir /mnt/efi
RUN mount $DISK-part1 /mnt/efi

# select fastest download mirror (significant improvements!)
iso=$(curl -4 ifconfig.co/country-iso)
echo "pacman -Sy --noconfirm --needed reflector"
pacman -Sy --noconfirm --needed reflector \
    && cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak \
    && reflector -a 48 -c "$iso" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

CHECK_SUCCESS "$?" "pacman -Sy --noconfirm --needed reflector"

# enable parallel downloads (faster)
RUN sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# bootstrap base system into zfs filesystem under /mnt
echo "pacstrap /mnt base linux-lts linux-firmware linux-lts-headers efibootmgr zfs-dkms"
pacstrap /mnt base linux-lts linux-firmware linux-lts-headers efibootmgr zfs-dkms
CHECK_SUCCESS "$?" "pacstrap /mnt base linux-lts linux-firmware linux-lts-headers efibootmgr zfs-dkms"


# bootstrap useful utilities
echo "pacstrap /mnt "$PKG_LIST""
pacstrap /mnt "$PKG_LIST"
CHECK_SUCCESS "$?" "pacstrap /mnt "$PKG_LIST""


RUN cp /etc/hostid /mnt/etc
RUN cp /etc/resolv.conf /mnt/etc
RUN cp /etc/pacman.conf /mnt/etc/pacman.conf

RUN genfstab /mnt | grep 'LABEL=EFI' -A 1 > /mnt/etc/fstab

# locale settings
RUN echo "LANG=$LOCALE" > /mnt/etc/locale.conf     # no need to define more than LANG - defaults the others
RUN sed -i "s/^#$LOCALE/$LOCALE/g" "/mnt/etc/locale.gen"
RUN echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf

[ "$CONSOLE_FONT" = "" ] || RUN echo "FONT=$CONSOLE_FONT" >> /mnt/etc/vconsole.conf


RUN echo "$HOSTNAME" > /mnt/etc/hostname

RUN echo "# Static table lookup for hostnames." > /mnt/etc/hosts
RUN echo "# See hosts(5) for details." >> /mnt/etc/hosts
RUN echo "127.0.0.1   localhost" > /mnt/etc/hosts
RUN echo "::1   localhost" >> /mnt/etc/hosts
RUN echo "127.0.1.1   $HOSTNAME" >> /mnt/etc/hosts

RUN sed -i '/^HOOKS=/s/block filesystems/block zfs filesystems/g' "/mnt/etc/mkinitcpio.conf"

RUN arch-chroot /mnt hwclock --systohc
RUN arch-chroot /mnt timedatectl set-local-rtc 0
RUN arch-chroot /mnt locale-gen
RUN arch-chroot /mnt mkinitcpio -P
RUN arch-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache $POOL
RUN arch-chroot /mnt zpool set bootfs=$POOL/ROOT/arch $POOL
RUN arch-chroot /mnt systemctl enable zfs-import-cache zfs-import.target zfs-mount zfs-zed zfs.target
RUN arch-chroot /mnt mkdir -p /efi/EFI/zbm
RUN arch-chroot /mnt wget -c https://get.zfsbootmenu.org/latest.EFI -O /efi/EFI/zbm/zfsbootmenu.EFI
RUN arch-chroot /mnt efibootmgr --disk $DISK --part 1 --create --label "ZFSBootMenu" --loader '\EFI\zbm\zfsbootmenu.EFI' --unicode "spl_hostid=0x$(hostid) zbm.timeout=1 zbm.prefer=$POOL zbm.import_policy=hostid rd.vconsole.keymap=$KEYMAP rd.vconsole.font=$CONSOLE_FONT quiet" --verbose
RUN arch-chroot /mnt zfs set org.zfsbootmenu:commandline="noresume init_on_alloc=0 rw spl.spl hostid=$(hostid)" $POOL/ROOT


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

  [ "$s" = "" ] || RUN arch-chroot /mnt systemctl enable "$s"
done;


# add normal user
RUN arch-chroot /mnt useradd -m -G wheel,sudo -s /usr/bin/zsh "$USERNAME"
RUN arch-chroot /mnt echo "$USERNAME:$USERPASSWD" | chpasswd

# install yay as normal user
RUN arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- cd /tmp/ \
  && git clone https://aur.archlinux.org/yay-bin.git \
  && cd yay-bin \
  && makepkg -si \
  && yay -Y --gendb

# install aur packages via yay
RUN arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- yay -S --noconfirm --needed $PKG_AUR_LIST

RUN umount /mnt/efi
RUN zpool export $POOL
