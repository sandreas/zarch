#!/bin/sh
PKG_LIST="a b c gnome gnome-extension-testing networkmanager testing"

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

  [ "$s" = "" ] || echo "$s"
done;
