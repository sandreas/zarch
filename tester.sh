#!/bin/sh


if ! [ -d /sys/firmware/efiy ]; then
  echo "ERROR:"
  echo "zarch.sh does only work on modern EFI systems, you seem to use traditional BIOS"
  exit 1
fi


echo "all ok"