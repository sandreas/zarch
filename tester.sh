#!/bin/sh
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

USER_NAME="$(READ_USER_INPUT "
username:
" "
confirm username:
")"
PASSWORD="$(READ_USER_INPUT "
new password:
" "
confirm new password:
" "-s")"
echo "<$USER_NAME>:<$PASSWORD>"