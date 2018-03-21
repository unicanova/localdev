#!/usr/bin/env bash

DOWNLOAD_BINARY=minikube
: ${INSTALL_DIR:="/usr/local/bin"}

downloadFile() {
  HASH_TYPE=sha256
  MINIKUBE_STABLE_VERSION=latest
  BINARY_VERSION=${MINIKUBE_VERSION:-$MINIKUBE_STABLE_VERSION}
  DOWNLOAD_URL="https://storage.googleapis.com/minikube/releases/${BINARY_VERSION}/${DOWNLOAD_BINARY}-${OS}-${ARCH}"
  CHECKSUM_URL="$DOWNLOAD_URL.$HASH_TYPE"
  TMP_ROOT="$(mktemp -dt ${DOWNLOAD_BINARY}-XXXXXX)"
  TMP_FILE="$TMP_ROOT/$DOWNLOAD_BINARY"
  SUM_FILE="$TMP_ROOT/$DOWNLOAD_BINARY.$HASH_TYPE"
  echo "Downloading $DOWNLOAD_URL"
  if type "curl" > /dev/null; then
    curl -SsL "$CHECKSUM_URL" -o "$SUM_FILE"
  elif type "wget" > /dev/null; then
    wget -q -O "$SUM_FILE" "$CHECKSUM_URL"
  fi
  if type "curl" > /dev/null; then
    curl -SsL "$DOWNLOAD_URL" -o "$TMP_FILE"
  elif type "wget" > /dev/null; then
    wget -q -O "$TMP_FILE" "$DOWNLOAD_URL"
  fi
}

source lib/_facts.sh
source lib/_install_bin.sh

initArch
initOS
downloadFile
checkInstalledVersion
installFile

