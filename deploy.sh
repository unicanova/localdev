#!/usr/bin/env bash

## Get kubernetes binaries
source config
source get_minikube.sh
source get_kubectl.sh

## Install kubernetes using minikube
source install_kubernetes.sh
echo == starting helm installation, this may take couple of minutes ==
source get_helm.sh
helm init
sleep 70
echo "== Installing defined services =="
source install_services.sh
