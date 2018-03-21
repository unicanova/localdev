#!/usr/bin/env bash

runAsRoot() {
  local CMD="$*"

  if [[ "$OS" == "windows" ]]; then
    echo "skip sudo for windows"
  elif [ $EUID -ne 0 ]; then
    CMD="sudo $CMD"
  fi

  $CMD
}

initArch() {
  ARCH=$(uname -m)
  case $ARCH in
    armv5*) ARCH="armv5";;
    armv6*) ARCH="armv6";;
    armv7*) ARCH="armv7";;
    aarch64) ARCH="arm64";;
    x86) ARCH="386";;
    x86_64) ARCH="amd64";;
    i686) ARCH="386";;
    i386) ARCH="386";;
  esac
}

initOS() {
  OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')
  case "$OS" in
    # Minimalist GNU for Windows
    mingw*) OS='windows';;
  esac
}
