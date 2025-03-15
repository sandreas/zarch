#!/bin/sh
PKG_FILE="pkglist.txt"
PKG_AUR_FILE="pkglist_aur.txt"

# read pkglist.txt and pkglist_aur.txt
PKG_LIST="$(grep -v '^\s*$\|^\s*#' $PKG_FILE)"
PKG_AUR_LIST="$(grep -v '^\s*$\|^\s*#' $PKG_AUR_FILE)"


echo "$PKG_LIST"


