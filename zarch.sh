#!/bin/sh

# // Install intel-ucode if needed or (amd-ucode):
# pacman -S intel-ucode
# zfs scrubbing: https://gist.github.com/Soulsuke/6a7d1f09f7fef968a2f32e0ff32a5c4c#file-arch_on_zfs-txt-L297

# https://github.com/archlinux/archinstall/issues/107#issuecomment-841701968
# arch-chroot does not support localectl
# maybe with systemd-nspawn as user or root?
# CONTAINER_NAME="setupcontainer"
# systemd-nspawn --boot --machine=$CONTAINER_NAME --hostname=$HOSTNAME --directory /mnt
# interesting options: --user
# machinectl shell $USER_NAME@$CONTAINER_NAME localectl set-keymap ""
# machinectl shell $USER_NAME@$CONTAINER_NAME localectl set-keymap "$KEYMAP"
# machinectl shell $USER_NAME@$CONTAINER_NAME localectl localectl --no-ask-password set-locale LANG="$LOCALE" LC_TIME="$LOCALE"

# pacman -Sy --noconfirm --needed refind
# refind-install --usedefault "$DISK-part1"
# "Boot default"  "zbm.prefer=zroot ro quiet loglevel=0 zbm.skip"
# "Boot to menu"  "zbm.prefer=zroot ro quiet loglevel=0 zbm.show"

# keymap
# systemd-run --machine=$USER_NAME@.host --pty localectl set-keymap ""
# localectl set-keymap de-latin1-nodeadkeys
# gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"


# gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'de')]"
# gsettings set org.gnome.desktop.input-sources current 0

# man systemd-run
#-M, --machine=
#           Execute operation on a local container. Specify a container name to connect to, optionally prefixed by a user name to connect as and a separating "@" character. If the special string ".host"
#           is used in place of the container name, a connection to the local system is made (which is useful to connect to a specific user's user bus: "--user --machine=lennart@.host"). If the "@"
#           syntax is not used, the connection is made as root user. If the "@" syntax is used either the left hand side or the right hand side may be omitted (but not both) in which case the local user
#           name and ".host" are implied.

# todo:



# https://unix.stackexchange.com/questions/75519/how-to-set-default-console-keyboard-layout-in-arch-linux
# loadkeys de - error: https://www.delftstack.com/howto/linux/bash-couldnt-get-a-file-descriptor-referring-to-the-console-error/
# - reset makes `loadkeys de` possible
# sudo machinectl shell --uid=youruser
# DISPLAY=:0 gsettings set org.gnome.desktop.input-sources mru-sources "[('xkb', 'us')]"


# timedatectl --no-ask-password set-ntp 1
# localectl --no-ask-password set-locale LANG="$LOCALE" LC_TIME="$LOCALE"
# ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
# Set keymaps
# localectl --no-ask-password set-keymap ${KEYMAP}


# vconsole.conf
# XKBLAYOUT=de
  #XKBMODEL=pc105
  #XKBVARIANT=nodeadkeys
  #XKBOPTIONS=terminate:ctrl_alt_bksp
# ./X11/xorg.conf.d/00-keyboard.conf:        Option "XkbLayout" "de"
# ./vconsole.conf:KEYMAP=de-latin1-nodeadkeys
# ./vconsole.conf:XKBLAYOUT=de
# - [ ] zrepl default config
# - [ ] Turn off debug packages in your pacman.conf https://bbs.archlinux.org/viewtopic.php?id=293844
# - [x] set root password
# - [ ] use sed -e '/HOOKS=/a HOOKS+=(net)' -i /etc/zfsbootmenu/mkinitcpio.conf
# - [ ] ZFSBootMenu does not boot automatically
#   - Is arch-chroot required for ZFS commands?
# - [ ] Default user cannot log in
#   - Use sudo su chpasswd?
# - [x] Use /etc/sudoers.d/nopasswd and delete it later in favor of passwd
# - [ ] check aura: https://github.com/fosskers/aura?tab=readme-ov-file#what-is-aura
# - [ ] run multiple arch-chroot commands at once (see multi command example below)
# - [ ] create subfolder profiles (./zarch.sh myprofile) with package definitions, e.g. /default/{pkglist_arch.txt,pkglist_aur.txt,services.txt}
#   - pkglist_arch.txt: official packages
#   - pkglist_aur.txt: aur packages
#   - services.txt: services to enable
# - [ ] auto-expect for password prompts?
# - [!] use history | tail -1 instead of next_cmd => not possible, hist is disabled in scripts
# multi command example:
# arch-chroot -u user /mnt bash -s <<-EOF
#  HOME=/home/user
#  cd /some/dir/to/start/on
#  cmd1
#  cmd2
# EOF



PROFILE="$1"
# PROFILE="default"

if [ "$PROFILE" = "" ] || ! [ -d "$PROFILE" ] || ! [ -f "$PROFILE/archpkg.txt" ]; then
  echo "You must specify a profile directory containing archpkg.txt, aurpkg.txt, services.txt and zarch.conf"
  exit 1
fi

PKG_FILE="$PROFILE/archpkg.txt"
PKG_AUR_FILE="$PROFILE/aurpkg.txt"
export CONF_FILE="$PROFILE/zarch.conf"

# RUN executes and logs a command (e.g. RUN echo "test")
RUN() {
  cmd="$@"
  # echo command before executing it (to show progress)
  echo "$cmd"
  output="$(sh -c "$cmd" 2>&1)"
  returnCode="$?"

  # echo output after all variables have been set to prevent setting return code of echo command
  echo "$output"

  # log command, output and return code
  LOG "$cmd"
  [ "$output" = "" ] || LOG "$output"
  LOG "return code: $returnCode"
  LOG ""


  CHECK_SUCCESS "$returnCode" "$cmd" "$output"
}

# CHECK_SUCCESS checks the success return code of a command (e.g. CHECK_SUCCESS "$?" "echo 'test'")
CHECK_SUCCESS() {
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

LOG() {
  if [ "$LOG_FILE" = "" ]; then
    export LOG_FILE
    LOG_FILE="$(basename $0).log"
  fi
  echo "$1" >> "$LOG_FILE"
}

READ_USER_INPUT() {
  message="$1"
  confirm="$2"
  additonal_flags="$3"
  failed_confirm_message=""
  while true; do
    read $additonal_flags -p "$failed_confirm_message $message" var_name

    if [ "$confirm" = "" ]; then
      break
    fi
    read $additonal_flags -p "$confirm" var_name_confirm

    if [ "$var_name" = "$var_name_confirm" ]; then
      break
    fi

    failed_confirm_message="
    passwords did not match, please try again!
    "
  done
  echo "$var_name"
  return 0
}


# function to load .env variable by name, example:
# load_env_variable DISK
LOAD_CONF_VARIABLE() {
  variable="$(grep "$1" "$CONF_FILE" | cut -d '=' -f 2 | sed "s/^[\"']\(.*\)[\"'].*$/\1/")"
  return_value="$?"
  echo "$variable"
  return "$return_value"
}

YES_OR_NO() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;
            [Nn]*) return 1 ;;
        esac
    done
}

COUNTDOWN() {
  for i in $(seq $1 -1 1); do
    echo $i
    sleep 1
  done;
}

APPEND_TEXT_TO_FILE() {
  content="$1"
  file="$2"
  truncate="$3"

  if [ "$truncate" = "truncate" ]; then
      true > "$file"
  fi

  next_cmd="echo $content > $file"
  echo "$next_cmd"
  echo "$content" >> "$file"
  CHECK_SUCCESS "$?" "$next_cmd"
}

# .env file must exist, otherwise exit
if ! [ -f "$CONF_FILE" ]; then
  echo "please create a file called '$CONF_FILE' in the profile directory $PROFILE/"
  exit 1
fi

export DISK
DISK="$(LOAD_CONF_VARIABLE DISK)"
export POOL
POOL="$(LOAD_CONF_VARIABLE POOL)"
export HOSTNAME
HOSTNAME="$(LOAD_CONF_VARIABLE HOSTNAME)"
export TIMEZONE
TIMEZONE="$(LOAD_CONF_VARIABLE TIMEZONE)"
export LOCALE
LOCALE="$(LOAD_CONF_VARIABLE LOCALE)"
export KEYMAP
KEYMAP="$(LOAD_CONF_VARIABLE KEYMAP)"
export CONSOLE_FONT
CONSOLE_FONT="$(LOAD_CONF_VARIABLE CONSOLE_FONT)"
export USER_NAME
USER_NAME="$(LOAD_CONF_VARIABLE USER_NAME)"
# maybe just read -rsp "Password: " USER_PASS
export USER_PASS
USER_PASS="$(LOAD_CONF_VARIABLE USER_PASS)"
export USER_GROUPS
USER_GROUPS="$(LOAD_CONF_VARIABLE USER_GROUPS)"
export ROOT_PASS
ROOT_PASS="$(LOAD_CONF_VARIABLE ROOT_PASS)"
export EXTRA_KERNEL_MODULES
EXTRA_KERNEL_MODULES="$(LOAD_CONF_VARIABLE EXTRA_KERNEL_MODULES)"


if ! [ -d /sys/firmware/efi ]; then
  echo "ERROR:"
  echo "zarch.sh does only work on modern EFI systems, you seem to use traditional BIOS"
  exit 1
fi

if [ "$USER_NAME" = "" ]; then
  USER_NAME="$(READ_USER_INPUT "
  Please provide a default username:
  " "
  Please confirm the default username:
  ")"
fi

if [ "$USER_PASS" = "" ]; then
  USER_PASS="$(READ_USER_INPUT "
  Please provide a password for $USER_NAME:
  " "
  Please confirm the password for $USER_NAME:
  " "-s")"
fi

if [ "$ROOT_PASS" = "" ]; then
  ROOT_PASS="$(READ_USER_INPUT "
  Please provide a password for user root:
  " "
  Please confirm the password for user root:
  " "-s")"
fi

# store short keymap
export KEYMAP_SHORT="$(echo "$KEYMAP" | cut -d '-' -f 1)"



# Logo generated by https://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=ZARCH
# Font Name: ANSI Shadow
printf "
----------------------------------------
███████╗ █████╗ ██████╗  ██████╗██╗  ██╗
╚══███╔╝██╔══██╗██╔══██╗██╔════╝██║  ██║
  ███╔╝ ███████║██████╔╝██║     ███████║
 ███╔╝  ██╔══██║██╔══██╗██║     ██╔══██║
███████╗██║  ██║██║  ██║╚██████╗██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
----------------------------------------
The following config has been loaded:

DISK=%s
POOL=%s
HOSTNAME=%s
TIMEZONE=%s
LOCALE=%s
CONSOLE_FONT=%s
USER_NAME=%s
USER_PASS=*****
ROOT_PASS=*****

WARNING: If you proceed, your disk %s
will be COMPLETELY wiped and reformatted.
" "$DISK" "$POOL" "$HOSTNAME" "$TIMEZONE" "$LOCALE" "$CONSOLE_FONT" "$USER_NAME" "$DISK"
YES_OR_NO "Are you sure?" || exit 0

echo "ok, let's go in"
COUNTDOWN 5


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
next_cmd="zpool create -f -o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O relatime=off -O atime=off -O encryption=aes-256-gcm -O keylocation=prompt -O keyformat=passphrase -o autotrim=on -m none $POOL ${DISK}-part2"
echo "$next_cmd"
zpool create -f -o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -O relatime=off -O atime=off -O encryption=aes-256-gcm -O keylocation=prompt -O keyformat=passphrase -o autotrim=on -m none $POOL ${DISK}-part2
CHECK_SUCCESS "$?" "$next_cmd"

RUN zfs create -o mountpoint=none "$POOL/ROOT"
RUN zfs create -o mountpoint=/ -o canmount=noauto "$POOL/ROOT/arch"
RUN zfs create -o mountpoint=/home "$POOL/home"

RUN zpool export "$POOL"

RUN zpool import -N -R /mnt "$POOL"

# load zfs key - RUN not possible due to password prompt
next_cmd="zfs load-key -L prompt $POOL"
echo "$next_cmd"
# autoexpect: Enter passphrase for 'rpool':
zfs load-key -L prompt "$POOL"
CHECK_SUCCESS "$?" "$next_cmd"

RUN zfs mount "$POOL/ROOT/arch"
RUN zfs mount "$POOL/home"

echo "######################################################"
echo "### OK, you're done, no more interaction required. ###"
echo "######################################################"
COUNTDOWN 3


# create and mount EFI filesystem
RUN mkfs.vfat -F 32 -n EFI "$DISK-part1"
RUN mkdir /mnt/efi
RUN mount "$DISK-part1" /mnt/efi

# select fastest download mirror (significant speed improvements!)
iso=$(curl -4 ifconfig.co/country-iso)
next_cmd="pacman -Sy --noconfirm --needed reflector && reflector -a 48 -c \"$iso\" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist"
echo "$next_cmd"
pacman -Sy --noconfirm --needed reflector \
    && cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak \
    && reflector -a 48 -c "$iso" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
CHECK_SUCCESS "$?" "$next_cmd"

# enable parallel downloads (faster)
RUN sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# bootstrap base system into zfs filesystem under /mnt
next_cmd="pacstrap /mnt base base-devel efibootmgr linux-lts linux-firmware linux-lts-headers sudo wget zfs-dkms"
echo "$next_cmd"
pacstrap /mnt base base-devel efibootmgr linux-lts linux-firmware linux-lts-headers sudo wget zfs-dkms
CHECK_SUCCESS "$?" "$next_cmd"

# configure all members of group wheel to have sudo without password until installation is finished
next_cmd="sed -i '/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL$/s/^# %wheel/%wheel/g' /mnt/etc/sudoers"
echo "$next_cmd"
sed -i '/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL$/s/^# %wheel/%wheel/g' /mnt/etc/sudoers
CHECK_SUCCESS "$?" "$next_cmd"

RUN arch-chroot /mnt timedatectl set-local-rtc 0
RUN arch-chroot /mnt timedatectl set-ntp 1
RUN arch-chroot /mnt hwclock --systohc
RUN arch-chroot /mnt ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
# localectl does not seem to do anything here, just works in a system container
RUN arch-chroot /mnt localectl set-locale LANG="$LOCALE" # LC_TIME="$LOCALE" (LANG DOES OVERRIDE FOR ALL)
RUN arch-chroot /mnt localectl set-keymap '""' # LC_TIME="$LOCALE" (LANG DOES OVERRIDE FOR ALL)
RUN arch-chroot /mnt localectl set-keymap "${KEYMAP}"

LOCALE_SCRIPT="/usr/local/bin/set-locale-once.sh"
APPEND_TEXT_TO_FILE "
[Unit]
Description=Set locale once
After=getty@tty1.service rc-local.service systemd-user-sessions.service

[Service]
ExecStart=$LOCALE_SCRIPT

[Install]
WantedBy=default.target" /mnt/etc/systemd/system/set-locale-once.service "truncate"

# RUN mkdir -p /mnt/usr/local/bin/

cat << EOF > "/mnt${LOCALE_SCRIPT}"
#!/bin/sh
EOF

KEYMAP_SHORT="$(echo "$KEYMAP" | cut -d '-' -f 1)"
GSETTINGS_PART=""
if [ ! "$KEYMAP_SHORT" = "" ]; then
  GSETTINGS_PART="command -V gsettings > /dev/null 2>&1 && (
    gsettings set org.gnome.desktop.input-sources sources \"[('xkb', '${KEYMAP_SHORT}')]\"
    gsettings set org.gnome.desktop.input-sources current 0
  )"
fi

APPEND_TEXT_TO_FILE "
localectl set-locale \"LANG=$LOCALE\"
localectl set-keymap \"\"
localectl set-keymap \"${KEYMAP}\"

$GSETTINGS_PART

systemctl disable set-locale-once
# rm /etc/systemd/system/set-locale-once.service
# rm -- \"\$0\"
" "/mnt/${LOCALE_SCRIPT}"
RUN arch-chroot /mnt chmod +x /usr/local/bin/set-locale-once.sh
RUN arch-chroot /mnt systemctl enable set-locale-once


# add normal user
# non-working options:
# - openssl passwd -6 -stdin
# - mkpasswd -s
# whois contains mkpasswd
# pacman -Sy --needed --noconfirm whois
# CRYPT_PASS="$(echo "$USER_PASS" | mkpasswd -s)"
# RUN arch-chroot /mnt useradd -m -G wheel -s /usr/bin/zsh "$USER_NAME" -p "$CRYPT_PASS"
# RUN arch-chroot /mnt echo "$USER_NAME:$USER_PASS" | chpasswd
RUN arch-chroot /mnt useradd -m -G wheel -s /bin/sh "$USER_NAME"
# the next command is a bit weird.
# - sudo to prevent asking for user password in the first place
# - su -c to execute a command in users context
# - sudo chpasswd because chpasswd needs sudo context
# there might be an easier version to achieve this
next_cmd="arch-chroot /mnt sudo su -c [...] $USER_NAME:***** | sudo chpasswd"
echo "$next_cmd"
arch-chroot /mnt sudo su -c "cat << EOF | sudo chpasswd
$USER_NAME:$USER_PASS
EOF"
CHECK_SUCCESS "$?" "$next_cmd"

next_cmd="arch-chroot /mnt sudo su -c [...] root:***** | sudo chpasswd"
echo "$next_cmd"
arch-chroot /mnt sudo su -c "cat << EOF | sudo chpasswd
root:$ROOT_PASS
EOF"
CHECK_SUCCESS "$?" "$next_cmd"

# bootstrap useful utilities
next_cmd="grep -v '^\s*$\|^\s*#' $PKG_FILE | pacstrap /mnt -"
echo "$next_cmd"
grep -v '^\s*$\|^\s*#' $PKG_FILE | pacstrap /mnt -
CHECK_SUCCESS "$?" "$next_cmd"

RUN cp /etc/hostid /mnt/etc
RUN cp /etc/resolv.conf /mnt/etc
RUN cp /etc/pacman.conf /mnt/etc/pacman.conf

RUN genfstab /mnt | grep 'LABEL=EFI' -A 1 > /mnt/etc/fstab

# locale settings
APPEND_TEXT_TO_FILE "LANG=$LOCALE" /mnt/etc/locale.conf "truncate"    # no need to define more than LANG - defaults the others
RUN sed -i "s/^#$LOCALE/$LOCALE/g" /mnt/etc/locale.gen
APPEND_TEXT_TO_FILE "KEYMAP=$KEYMAP" /mnt/etc/vconsole.conf "truncate"
[ "$CONSOLE_FONT" = "" ] || APPEND_TEXT_TO_FILE "FONT=$CONSOLE_FONT" /mnt/etc/vconsole.conf
APPEND_TEXT_TO_FILE "$HOSTNAME" /mnt/etc/hostname "truncate"

# create /etc/hosts
APPEND_TEXT_TO_FILE "# Static table lookup for hostnames." /mnt/etc/hosts "truncate"
APPEND_TEXT_TO_FILE "# See hosts(5) for details." /mnt/etc/hosts
APPEND_TEXT_TO_FILE "127.0.0.1   localhost" /mnt/etc/hosts
APPEND_TEXT_TO_FILE "::1   localhost" /mnt/etc/hosts
APPEND_TEXT_TO_FILE "127.0.1.1   $HOSTNAME" /mnt/etc/hosts


# configure boot environment (ZFS hooks, fstab, ZFSBootMenu EFI entry, ZFSBootMenu commandline)
# add zfs to mkinitcpio hooks
next_cmd="sed -i '/^HOOKS=/s/block filesystems/block zfs filesystems/g' /mnt/etc/mkinitcpio.conf"
echo "$next_cmd"
sed -i '/^HOOKS=/s/block filesystems/block zfs filesystems/g' /mnt/etc/mkinitcpio.conf
CHECK_SUCCESS "$?" "$next_cmd"



RUN arch-chroot /mnt locale-gen
RUN arch-chroot /mnt mkinitcpio -P
RUN arch-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache "$POOL"
RUN arch-chroot /mnt zpool set bootfs="$POOL/ROOT/arch" "$POOL"
RUN arch-chroot /mnt systemctl enable zfs-import-cache zfs-import.target zfs-mount zfs-zed zfs.target
RUN arch-chroot /mnt mkdir -p /efi/EFI/ZBM
RUN arch-chroot /mnt wget -c https://get.zfsbootmenu.org/latest.EFI -O /efi/EFI/ZBM/ZFSBOOTMENU.EFI
RUN arch-chroot /mnt efibootmgr --disk "$DISK" --part 1 --create --label "ZFSBootMenu" --loader '\EFI\ZBM\ZFSBOOTMENU.EFI' --unicode "spl_hostid=0x$(hostid) zbm.timeout=1 zbm.prefer=$POOL zbm.import_policy=hostid rd.vconsole.keymap=$KEYMAP rd.vconsole.font=$CONSOLE_FONT quiet"

next_cmd="arch-chroot /mnt zfs set org.zfsbootmenu:commandline=\"noresume init_on_alloc=0 rw spl.spl hostid=$(hostid)\" \"$POOL/ROOT\""
echo "$next_cmd"
arch-chroot /mnt zfs set org.zfsbootmenu:commandline="noresume init_on_alloc=0 rw spl.spl hostid=$(hostid)" "$POOL/ROOT"
CHECK_SUCCESS "$?" "$next_cmd"




# build yay package as normal user
RUN pacman -Sy --noconfirm --needed git
RUN git clone https://aur.archlinux.org/yay-bin.git "/mnt/home/$USER_NAME/yay-bin"
RUN arch-chroot /mnt chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME/yay-bin"

# enable sudo without password prompt
# next_cmd="arch-chroot -u \"$USER_NAME\" /mnt sudo -S touch /root/.bash_history <<< \"$USER_PASS\""
# echo "$next_cmd"
# arch-chroot -u "$USER_NAME" /mnt sudo -S touch /root/.bash_history <<< "$USER_PASS"
# CHECK_SUCCESS "$?" "$next_cmd"
# make and install package
RUN arch-chroot -u "$USER_NAME" /mnt makepkg -D "/home/$USER_NAME/yay-bin" -s


yay_pkg_file="$(find "/mnt/home/$USER_NAME/yay-bin/" -name 'yay-bin-*.pkg.tar.*' -not -name '*-debug-*' -exec basename {} \;)"
RUN arch-chroot /mnt pacman -U --noconfirm --needed "/home/$USER_NAME/yay-bin/$yay_pkg_file"

# install aur packages via yay
# RUN echo "$USER_NAME $HOSTNAME = NOPASSWD: /usr/bin/pacman" > /mnt/etc/sudoers.d/yay
# yay_script_file="/home/$USER_NAME/aurinstall.sh"
# cat <<EOF > "/mnt$yay_script_file"
# #!/bin/sh
# echo "$USER_PASS" | sudo -S echo ""
# yay --sudoloop --noconfirm --needed $(echo "$PKG_AUR_LIST" | tr '\n' ' ')
# EOF
# arch-chroot /mnt chmod +x "$yay_script_file"
# arch-chroot /mnt chown "$USER_NAME:$USER_NAME" "$yay_script_file"
# arch-chroot -u "$USER_NAME" /mnt "$yay_script_file"

# enable sudo without password prompt
# next_cmd="arch-chroot -u \"$USER_NAME\" /mnt sudo -S touch /root/.bash_history <<< \"$USER_PASS\""
# echo "$next_cmd"
# arch-chroot -u "$USER_NAME" /mnt sudo -S touch /root/.bash_history <<< "$USER_PASS"
# CHECK_SUCCESS "$?" "$next_cmd"

# CHROOT_PKG_AUR_FILE="/home/$USER_NAME/yay.txt"
# next_cmd="grep -v '^\s*$\|^\s*#' \"$PKG_AUR_FILE\" > \"/mnt$CHROOT_PKG_AUR_FILE\""
# echo "$next_cmd"
# grep -v '^\s*$\|^\s*#' "$PKG_AUR_FILE" > "/mnt$CHROOT_PKG_AUR_FILE"
# CHECK_SUCCESS "$?" "$next_cmd"

# install selected packages via yay
# next_cmd="arch-chroot -u \"$USER_NAME\" /mnt sudo su -c \"yay -Sy --noconfirm --needed $(cat "$CHROOT_PKG_AUR_FILE")\" \"$USER_NAME\""
# echo "$next_cmd"
# arch-chroot -u "$USER_NAME" /mnt sudo su -c "yay -Sy --noconfirm --needed $(cat "$CHROOT_PKG_AUR_FILE")" "$USER_NAME"
# CHECK_SUCCESS "$?" "$next_cmd"

# old way: install selected packages via yay
PKG_AUR_LIST="$(grep -v '^\s*$\|^\s*#' "$PKG_AUR_FILE")"
next_cmd="arch-chroot -u \"$USER_NAME\" /mnt sudo su -c \"yay -Sy --noconfirm --needed $(echo \"$PKG_AUR_LIST\" | tr '\n' ' ')\" \"$USER_NAME\""
echo "$next_cmd"
arch-chroot -u "$USER_NAME" /mnt sudo su -c "yay -Sy --noconfirm --needed $(echo "$PKG_AUR_LIST" | tr '\n' ' ')" "$USER_NAME"
CHECK_SUCCESS "$?" "$next_cmd"


# RUN arch-chroot -u "$USER_NAME" /mnt "echo $USER_PASS | sudo -S echo \"\" && yay --sudoloop --noconfirm --needed $PKG_AUR_LIST"
# arch-chroot -u "$USER_NAME" /mnt echo "$USER_PASS"

# for pkg in $PKG_AUR_LIST; do
#  echo $pkg
# done;

# create basic zrepl.yml for zfs auto snapshotting
RUN mkdir -p /mnt/etc/zrepl/
next_cmd="cat <<EOF > /mnt/etc/zrepl/zrepl.yml"
echo "$next_cmd"
cat <<EOF > /mnt/etc/zrepl/zrepl.yml
global:
  logging:
    - type: syslog
      format: human
      level: warn

jobs:
# this job takes care of snapshot creation + pruning
- name: snapjob
  type: snap
  filesystems: {
      "rpool<": true,
  }
  # create snapshots with prefix zrepl_ every 15 minutes
  snapshotting:
    type: periodic
    interval: 15m
    prefix: zrepl_
    timestamp_format: human
  pruning:
    keep:
    - type: grid
      grid: 1x1h(keep=4) | 24x1h(keep=1) | 7x1d(keep=1) | 4x1w(keep=1) | 12x4w(keep=1) | 1x53w(keep=1)
      regex: "^zrepl_.*"
    # keep all snapshots that don't have the zrepl_ prefix
    - type: regex
      negate: true
      regex: "^zrepl_.*"

EOF
CHECK_SUCCESS "$?" "$next_cmd"

# enable services
SERVICES_FILE="$PROFILE/services.txt"
OLD_IFS="$IFS"
IFS=''
grep -v '^\s*$\|^\s*#' "$SERVICES_FILE" |
while read -r s; do
  next_cmd="arch-chroot /mnt systemctl enable $s"
  echo "$next_cmd"
  arch-chroot /mnt systemctl enable "$s"
  if ! [ "$?" = "0" ]; then
    echo "WARNING! Could not enable service $s"
    echo "Either the service was not found or you have to enable it manually"
  fi
done
IFS="$OLD_IFS"

# CUSTOM_SCRIPT="$PROFILE/custom-chroot.sh"
# if [ -f "$CUSTOM_SCRIPT" ]; then
#   RUN cp "$CUSTOM_SCRIPT" /mnt/custom-chroot.sh
#   RUN chmod +x /mnt/custom-chroot.sh
#   RUN arch-chroot /mnt /custom-chroot.sh
#   RUN rm /mnt/custom-chroot.sh
# fi

# remove sudo access without password
next_cmd="sed -i '/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL$/s/^%wheel/# %wheel/g' /mnt/etc/sudoers"
echo "$next_cmd"
sed -i '/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL$/s/^%wheel/# %wheel/g' /mnt/etc/sudoers
CHECK_SUCCESS "$?" "$next_cmd"

# configure all members of group wheel to have sudo (with password required)
next_cmd="sed -i '/^# %wheel ALL=(ALL:ALL) ALL$/s/^# %wheel/%wheel/g' /mnt/etc/sudoers"
echo "$next_cmd"
sed -i '/^# %wheel ALL=(ALL:ALL) ALL$/s/^# %wheel/%wheel/g' /mnt/etc/sudoers
CHECK_SUCCESS "$?" "$next_cmd"

if ! [ "$USER_GROUPS" = "" ]; then
  RUN arch-chroot /mnt usermod -a -G "$USER_GROUPS" "$USER_NAME"
fi

for module in $EXTRA_KERNEL_MODULES; do
  APPEND_TEXT_TO_FILE "$module" "/mnt/etc/modules-load.d/$module.conf" "truncate"
done


# arch-chroot /mnt systemctl enable "$s"



# CONTAINER_NAME="setupcontainer"
# systemd-run --unit=setupcontainer --scope systemd-nspawn -D /mnt
# systemd-run --machine=setupcontainer /bin/bash -c "touch /test.txt"
# systemd-nspawn --boot --machine=$CONTAINER_NAME --hostname="$HOSTNAME" --directory /mnt &
# interesting options: --user

#systemd-run --machine=setupcontainer --scope systemd-nspawn --pty /bin/bash -c "localectl set-keymap 'de'"
#systemd-nspawn -D /mnt /bin/bash -c "localectl set-keymap ''"
#systemd-nspawn -D /mnt &

# this works
#nohup systemd-nspawn --machine=setupcontainer -D /mnt  0<&- &>/dev/null &
#systemd-run --machine=setupcontainer --pty /bin/bash -c "localectl set-keymap 'de'"
#machinectl poweroff setupcontainer

# this might work
# systemd-nspawn --pty -D /mnt /bin/bash -c "localectl set-keymap ''"

# machinectl shell $USER_NAME@$CONTAINER_NAME localectl set-keymap ""
# machinectl shell $USER_NAME@$CONTAINER_NAME localectl set-keymap "$KEYMAP"
# machinectl shell $USER_NAME@$CONTAINER_NAME localectl localectl --no-ask-password set-locale LANG="$LOCALE" LC_TIME="$LOCALE"


RUN umount /mnt/efi
RUN zpool export "$POOL"
