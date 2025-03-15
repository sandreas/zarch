#!/bin/sh

ENV_FILE=".env"

# function to load .env variable by name, example:
# load_env_variable DISK
function load_env_variable {
  echo "$(grep "$1" "$ENV_FILE" | cut -d '=' -f 2 | sed "s/^[\"']\(.*\)[\"'].*$/\1/")"
  return $?
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

echo -ne "
DISK=$DISK
POOL=$POOL
HOSTNAME=$HOSTNAME
TIMEZONE=$TIMEZONE
LOCALE=$LOCALE
CONSOLE_FONT=$CONSOLE_FONT
USERNAME=$USERNAME
USERPASSWD=$USERPASSWD
"