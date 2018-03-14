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

# checkInstalledVersion checks which version of minikube or kubernetes is installed and
# if it needs to be changed.
checkInstalledVersion() {
  if [[ -f "${INSTALL_DIR}/${DOWNLOAD_BINARY}" ]]; then
    if [[ "${DOWNLOAD_BINARY}" == "minikube" ]]; then
      local version=$(minikube version | awk -F': ' '{print $2}')
    elif [[  "${DOWNLOAD_BINARY}" == "kubectl" ]]; then 
      local version=$(kubectl version --client=true --short=true | awk -F': ' '{print $2}')
    fi
    if [[ "$version" == "$BINARY_VERSION" ]]; then
      echo "${DOWNLOAD_BINARY} ${version} is already ${BINARY_VERSION}"
      return 0
    else
      echo "${DOWNLOAD_BINARY} ${BINARY_VERSION} is available. Changing from version ${version}."
      return 1
    fi
  else
    return 1
  fi
}
