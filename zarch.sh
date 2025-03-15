#!/bin/sh

ENV_FILE=".env"

if ! [ -f "$ENV_FILE" ]; then
  echo "please create a file called '$ENV_FILE' in the current directory"
fi


# FTP_HOST="$(grep 'host' .env | cut -d '=' -f 2)"
# FTP_USERNAME="$(grep 'username' .credentials | cut -d '=' -f 2)"
# FTP_OBSCURED_PASSWORD="$(grep 'password' .credentials | cut -d '=' -f 2)"