#!/usr/bin/env bash

BASE_GIT_DIR=~/.localdev
HELM_BIN=${HELM_BIN:-/usr/local/bin/helm}
SERVICE_NAME=service-bus
GIT_REPO_PROJECT_BASE=git@gitlab.gruzer.ru:apps
PROJECT_GIT_REPO="${GIT_REPO_PROJECT_BASE}/${SERVICE_NAME}.git"
COMMIT_SHA=93eae82fdbaf2cb5995fa94b083f0b6bfd745d5d
_REPO_HELM_CHART_DIR=.helm
BRANCH=master
FAILOVER_BRANCH=master
REMOTE_CLUSTER=cluster.local
#REMOTE_DOMAINS="${BRANCH}".svc."${REMOTE_CLUSTER}","${FAILOVER_BRANCH}".svc."${REMOTE_CLUSTER}"
HELM_VERSION=latest
KUBECTL_VERSION=latest
LOCALDEV_GIT_CONF="--git-dir=${BASE_GIT_DIR}/${SERVICE_NAME}/.git --work-tree=${BASE_GIT_DIR}/${SERVICE_NAME}"
TRY_CHECKOUT_IF_DIRTY=$(echo "$TRY_CHECKOUT_IF_DIRTY"|tr '[:upper:]' '[:lower:]')
#kubectl create ns localdev
#kubectl create secret docker-registry "${BRANCH}" --docker-server=registry.gruzer.ru --docker-username=kkalinovskiy --docker-password=my_pass --docker-email=kkalinovskiy@gmail.com -n localdev
#helm init
#helm install --namespace localdev --set global.release=master --set global.commit=93eae82fdbaf2cb5995fa94b083f0b6bfd745d5d --set global.env=localdev --set global.ci_url=service-bus --set global.dns_domain=local.dev .helm/ 
#DNS_POD=$(kubectl get pod -l k8s-app=kube-dns  -n kube-system -o=jsonpath='{.items[0].metadata.name}')
#kubectl -n kube-system exec DNS_POD -- kill -SIGUSR1 1
#helm install --debug --dry-run --namespace stage --set global.release=stage --set global.commit=93eae82fdbaf2cb5995fa94b083f0b6bfd745d5d --set global.env=localdev --set global.type=local --set global.ci_url=service-bus --set remoteDomains={$REMOTE_DOMAINS} .helm/

CHART_ARGS="--set global.release=${BRANCH} --set global.commit=${COMMIT_SHA} --set global.env=${BRANCH} --set global.type=local --set global.ci_url=${SERVICE_NAME}"

REMOTE_DOMAINS=$(echo "$REMOTE_DOMAINS" | awk '{gsub(/^ +| +$/,"")} {print $0}')
echo $REMOTE_DOMAINS
if [ -n "$REMOTE_DOMAINS" ]; then
  CHART_ARGS="$CHART_ARGS --set remoteDomains={$REMOTE_DOMAINS}"
fi

#$HELM_BIN install --debug --dry-run --namespace "${BRANCH}" ${CHART_ARGS} "${HELM_CHART_DIR}"


function installChart() {
  CHART_ARGS="--set global.release=${BRANCH} \
              --set global.commit=${COMMIT_SHA} \
              --set global.env=${BRANCH} \
              --set global.type=local \
              --set global.ci_url=${SERVICE_NAME}"
  REMOTE_DOMAINS=$(echo "$REMOTE_DOMAINS" | awk '{gsub(/^ +| +$/,"")} {print $0}')
  if [ -n "$REMOTE_DOMAINS" ]; then
    CHART_ARGS="$CHART_ARGS --set remoteDomains=${REMOTE_DOMAINS}"
  fi
  echo $CHART_ARGS
  $HELM_BIN install --debug --dry-run --name "${SERVICE_NAME}"-"${BRANCH}"\
                    --namespace "${BRANCH}" ${CHART_ARGS} \
                    "${BASE_GIT_DIR}/${SERVICE_NAME}/${_REPO_HELM_CHART_DIR}" && \
                    return 0;
  exit 1;
}

function chartInstalled() {
  helm get "${SERVICE_NAME}"-"${BRANCH}" > /dev/null 2>&1
  rc=$?
  case $rc in
    1|0) return $rc
    ;;
    *)  echo "== Could not determine status of helm chart =="; exit $rc
    ;;
  esac
}

function downloadChart() {
  if [ -d "$BASE_GIT_DIR/$SERVICE_NAME" ]; then
    git $LOCALDEV_GIT_CONF status > /dev/null && \
    echo "== Directory with name ${SERVICE_NAME} already exists and is git repository =="
    return 0
  else
    echo "$PROJECT_GIT_REPO"
    git clone --quiet "$PROJECT_GIT_REPO" "$BASE_GIT_DIR/$SERVICE_NAME" && \
    return 0;
  fi
  echo "ERROR == Could not clone project repository ${SERVICE_NAME} =="
  exit 1;
}

function getLatestSha() {
  git $LOCALDEV_GIT_CONF fetch --quiet || exit 2
  LATEST_BRANCH_SHA="$(git $LOCALDEV_GIT_CONF rev-parse origin/$BRANCH)" || \
  echo "WARNING == Failed to get latest SHA in git repo ${LOCALDEV_GIT_CONF} =="
  COMMIT_SHA="${COMMIT_SHA:-$LATEST_BRANCH_SHA}"
  echo "== Commit SHA used for checkout is ${COMMIT_SHA} =="
}

function checkoutGit() {
  git $LOCALDEV_GIT_CONF checkout --force "$COMMIT_SHA" && \
  echo "== Checked out commit with SHA ${COMMIT_SHA} ==" && return 0
  exit 1;
}

function gitIsClean() {
  # Update the index
  git $LOCALDEV_GIT_CONF update-index -q --ignore-submodules --refresh
  local rc=0
  # Disallow unstaged changes in the working tree
  if ! git $LOCALDEV_GIT_CONF diff-files --quiet --ignore-submodules --; then
    echo >&2 "you have unstaged changes."
    git $LOCALDEV_GIT_CONF diff-files --name-status -r --ignore-submodules -- >&2
    rc=1
  fi
  # Disallow uncommitted changes in the index
  if ! git $LOCALDEV_GIT_CONF diff-index --cached --quiet HEAD --ignore-submodules --; then
    echo >&2 "your index contains uncommitted changes."
    git $LOCALDEV_GIT_CONF diff-index --cached --name-status -r --ignore-submodules HEAD -- >&2
    rc=1
  fi
  return $rc
}

mkdir -p $BASE_GIT_DIR
downloadChart
if gitIsClean or $TRY_CHECKOUT_IF_DIRTY; then
  checkoutGit
fi
getLatestSha
if chartInstalled; then
  installChart
fi
