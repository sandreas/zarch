#!/bin/sh


# build yay package as normal user
pacstrap -Sy git
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
export zarch_failed_service_enables=""
grep -v '^\s*$\|^\s*#' "$SERVICES_FILE" |
while read -r s; do
  next_cmd="arch-chroot /mnt systemctl enable $s"
  echo "$next_cmd"
  arch-chroot /mnt systemctl enable "$s"
  # CHECK_SUCCESS "$?" "$next_cmd"
  echo "WARNING! Could not enable service $s"
  echo "Either the service was not found or you have to enable it manually"
done
IFS="$OLD_IFS"

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

RUN umount /mnt/efi
RUN zpool export "$POOL"
