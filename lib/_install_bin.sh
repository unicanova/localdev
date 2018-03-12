#!/usr/bin/env bash

installFile() {
  echo hash type is $HASH_TYPE
  if [ $HASH_TYPE == "md5" ]; then
    local sum=$(md5sum ${TMP_FILE} | awk '{print $1}')
  else [ $HASH_TYPE == "sha256" ]
    local sum=$(sha256sum ${TMP_FILE} | awk '{print $1}')
  fi

  local expected_sum=$(cat ${SUM_FILE})
  if [ "$sum" != "$expected_sum" ]; then
    exit 1
  fi

  chmod +x "$TMP_FILE" && runAsRoot cp "$TMP_FILE" "$INSTALL_DIR"
}
