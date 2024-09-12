#!/bin/sh

EXTENSION='Darwin.yml'


find roles/ -type f -name $EXTENSION | while read -r LINE; do
  FILE="$( basename "$LINE" )"


  case "$LINE" in
    *"$EXTENSION")
      DIRNAME="$( dirname "$LINE" )"
      mv -v "$DIRNAME/$FILE" "$DIRNAME/MacOSX.yml"
    ;;
  esac
done
