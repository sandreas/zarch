#!/bin/sh
# store short keymap
KEYMAP_SHORT="$(echo "$KEYMAP" | cut -d '-' -f 1)"
[ ! "$KEYMAP_SHORT" = "" ] && command -V gsettings > /dev/null 2>&1 && (
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', '${KEYMAP_SHORT}')]"
  gsettings set org.gnome.desktop.input-sources current 0
)
