#!/usr/bin/env bash

: ${MINIKUBE_VM_DRIVER:="virtualbox"}
: ${MINIKUBE_DNS_DOMAIN:="dev.local"}

: ${OPENVPN_DAEMONSET_YAML:="daemonsets/OpenVPN-daemonset.yaml"}
: ${COREDNS_CONFIG_YAML:="addons/coreDNS-configmap.yaml"}
: ${KUBECTL:="/usr/local/bin/kubectl"}

KUBECTL_OPTS=${KUBECTL_OPTS:-}
MINIKUBE_CLUSTER_STATUS=$(minikube status | awk '/cluster/ {print $2}')

set -e

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
    local dns_pod="$(kubectl get pod -l k8s-app=kube-dns -n kube-system -o=jsonpath='{.items[0].metadata.name}')" && \
      kubectl -n kube-system exec $dns_pod -- kill -SIGUSR1 1 && \
        return 0
  fi
  exit 1
}

function install_minikube() {
  if [ "$MINIKUBE_CLUSTER_STATUS" == "Running" ]; then
    echo == Kubernetes minikube is already running, not installing it ==
    return 0
  else
    echo Installing Kubernetes with minikube vm-driver "${MINIKUBE_VM_DRIVER}"
    minikube start --vm-driver "${MINIKUBE_VM_DRIVER}" \
                   --feature-gates=CustomPodDNS=true \
                   --dns-domain "${MINIKUBE_DNS_DOMAIN}" && \
      echo "== Successfully started Minikube ==" && return 0
  fi
  exit 1
}

function create_openvpn_tunnel() {
  echo "== Configure daemonset with OpenVPN client =="
  if ! kubectl --namespace=kube-system get secret openvpn-conf -o=jsonpath='{.metadata.name}'; then
    kubectl create --namespace "kube-system" secret generic openvpn-conf --from-file ${OPENVPN_CONFIG_FILE:-"secrets/config.conf"} || \
      echo "ERROR == Failed to create secert from openvpn config file at ${OPENVPN_CONFIG_FILE} =="
  fi
  create_resource_from_string "$(cat ${OPENVPN_DAEMONSET_YAML})" "2" "20" "OpenVPN-Daemonset" "kube-system" && \
    return 0
  exit 1
}

### Install and configure kubernetes ###
install_minikube
sleep 15
echo Enabling coredns addon
minikube addons enable coredns
create_openvpn_tunnel
update_core_dns_plugin
