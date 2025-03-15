#!/bin/sh
function RUN() {
  cmd="$@"
  output="$(sh -c "$cmd" 2>&1)"
  returnCode="$?"

  LOG "$cmd"
  [ "$output" = "" ] || LOG "$output"
  LOG "return code: $returnCode"
  LOG ""

  if ! [ "$returnCode" = "0" ]; then
    echo "COMMAND FAILED (Code $returnCode):"
    echo "==================================="
    echo "  $cmd"
    echo "  $output"
    echo "==================================="
  fi
}

function LOG() {
  if [ "$LOG_FILE" = "" ]; then
    export LOG_FILE="$(basename $0).log"
  fi
  echo "$1" >> "$LOG_FILE"
}

RUN [ -f /etc/hostid ] || zgenhostid




