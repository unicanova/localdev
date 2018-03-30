#!/usr/bin/env bash

: ${MINIKUBE_VM_DRIVER:="virtualbox"}
: ${MINIKUBE_DNS_DOMAIN:="dev.local"}

: ${OPENVPN_DAEMONSET_YAML:="daemonsets/OpenVPN-daemonset.yaml"}
: ${COREDNS_CONFIG_YAML:="addons/coreDNS-configmap.yaml"}
: ${KUBECTL:="kubectl"}

KUBECTL_OPTS=${KUBECTL_OPTS:-}
DOCKERD_FIXED_CIDR=${DOCKERD_FIXED_CIDR:-'172.21.0.0/24'}
DOCKERD_BIP=${DOCKERD_BIP:-'172.21.0.1/24'}
MINIKUBE_CLUSTER_STATUS=$(minikube status | awk '/cluster/ {print $2}')
MINIKUB_START_OPTS=${KUBECTL_START_OPTS:-}

# $1 string with json or yaml.
# $2 count of tries to start the addon.
# $3 delay in seconds between two consecutive tries
# $4 name of this object to use when logging about it.
# $5 namespace for this object
function create_resource_from_string() {
  local -r config_string=$1;
  local tries=$2;
  local -r delay=$3;
  local -r config_name=$4;
  local -r namespace=$5;
  while [ ${tries} -gt 0 ]; do
    echo "${config_string}" | ${KUBECTL} ${KUBECTL_OPTS} --namespace="${namespace}" apply -f - && \
      echo "== Successfully started ${config_name} in namespace ${namespace} at $(date -Is)" && \
      return 0;                                                                                                                                                                                                    
    let tries=tries-1;                                                                                                                                                                                             
    echo "== Failed to start ${config_name} in namespace ${namespace} at $(date -Is). ${tries} tries remaining. =="                                                                                             
    sleep ${delay};                                                                                                                                                                                                
  done                                                                                                                                                                                                             
  return 1;                                                                                                                                                                                                        
}

function update_core_dns_plugin() {
  if create_resource_from_string "$(cat ${COREDNS_CONFIG_YAML})" 2 "20" "core-dns-configmap" "kube-system"; then
    sleep 70
    local tries=20
    local dns_pod="$($KUBECTL get pod -l k8s-app=kube-dns -n kube-system -o=jsonpath='{.items[0].metadata.name}')" && \
    echo "== Restarting coredns service =="
    while [ ${tries} -gt 0 ]; do
      $KUBECTL -n kube-system exec "$dns_pod" -- kill -SIGUSR1 1 && \
        return 0;
      let tries=tries-1;
      sleep 10;
    done

  fi
  return 1
}

function install_minikube() {
  if [ "$MINIKUBE_CLUSTER_STATUS" == "Running" ]; then
    echo == Kubernetes minikube is already running, not installing it ==
    return 0
  else
    local local_mount_dir=$HOME/.localdev/services/
    local remote_mount_dir=/home/services/
    echo Installing Kubernetes with minikube vm-driver "${MINIKUBE_VM_DRIVER}"
    mkdir -p -m 0777 $local_mount_dir
    chmod -R 0755 $local_mount_dir
    minikube start --vm-driver "${MINIKUBE_VM_DRIVER}" \
                   --docker-opt "fixed-cidr=${DOCKERD_FIXED_CIDR}" \
                   --docker-opt "bip=${DOCKERD_BIP}" \
                   "${MINIKUB_START_OPTS}" \
                   --feature-gates=CustomPodDNS=true \
                   --dns-domain "${MINIKUBE_DNS_DOMAIN}" \
                   --mount-string ${local_mount_dir}:${remote_mount_dir} \
                   --mount && \
      echo "== Successfully started Minikube ==" && return 0
  fi
  return 1
}

function create_openvpn_tunnel() {
  echo "== Configure daemonset with OpenVPN client =="
  if ! ${KUBECTL} --namespace=kube-system get secret openvpn-conf -o=jsonpath='{.metadata.name}'; then
    ${KUBECTL} create --namespace "kube-system" secret generic openvpn-conf --from-file ${OPENVPN_CONFIG_FILE:-"secrets/config.conf"} || \
      echo "ERROR == Failed to create secert from openvpn config file at ${OPENVPN_CONFIG_FILE} =="
  fi
  ${KUBECTL} create -f daemonsets/OpenVPN-daemonset.yaml && \
    return 0
  return 1
}

function getKubeIps {
  KUBE_DNS_IP=$(${KUBECTL} get service -l k8s-app=kube-dns -n kube-system | awk 'NR>1 {print $3}')
  MINIKUBE_IP=$(minikube ip)
}

function setRoutes {
  getKubeIps
  echo "INFO == Trying to set routes to minikube container and kubernetes dns =="
  case "$OS" in
    linux*) 
      runAsRoot ip r add $KUBE_DNS_IP via $MINIKUBE_IP
      runAsRoot ip r add $DOCKERD_FIXED_CIDR via $MINIKUBE_IP
      return 0
      ;;
  esac
  return 4 
}

source lib/_facts.sh

initOS
### Install and configure kubernetes ###
install_minikube
sleep 15
echo Enabling coredns addon
minikube addons disable kube-dns
minikube addons enable coredns
minikube addons enable ingress
create_openvpn_tunnel
update_core_dns_plugin
setRoutes
