#!/usr/bin/env bash

BASE_GIT_DIR=~/.localdev
HELM_BIN=${HELM_BIN:-/usr/local/bin/helm}
#SERVICE_NAME=service-bus
#GIT_REPO_PROJECT_BASE=git@gitlab.gruzer.ru:apps
_REPO_HELM_CHART_DIR=.helm
LOCALDEV_BRANCH=${LOCALDEV_BRANCH:-master}
#REMOTE_CLUSTER=cluster.local

function installChart() {
  CHART_ARGS="--set global.release=${LOCALDEV_BRANCH} \
              --set global.commit=${COMMIT_SHA} \
              --set global.env=${LOCALDEV_BRANCH} \
              --set global.type=local \
              --set global.ci_url=${SERVICE_NAME}"
  REMOTE_DOMAINS=$(echo "$REMOTE_DOMAINS" | awk '{gsub(/^ +| +$/,"")} {print $0}')
  if [ -n "$REMOTE_DOMAINS" ]; then
    CHART_ARGS="$CHART_ARGS --set remoteDomains={$REMOTE_DOMAINS}"
  fi
  $HELM_BIN install --debug --dry-run --name "${SERVICE_NAME}"-"${LOCALDEV_BRANCH}" \
                    --namespace "${LOCALDEV_BRANCH}" ${CHART_ARGS} \
                    "${BASE_GIT_DIR}/${SERVICE_NAME}/${_REPO_HELM_CHART_DIR}" && \
                    return 0;
  exit 1;
}

function chartInstalled() {
  helm get "${SERVICE_NAME}"-"${LOCALDEV_BRANCH}" > /dev/null 2>&1
  rc=$?
  case $rc in
    1|0) return $rc
    ;;
    *) echo "== Could not determine status of helm chart =="; exit $rc
    ;;
  esac
}

function downloadChart() {
  if [ -d "$BASE_GIT_DIR/$SERVICE_NAME" ]; then
    git $LOCALDEV_GIT_CONF status > /dev/null 2>&1 && \
    echo "== Directory with name ${SERVICE_NAME} already exists and is git repository =="
    return 0
  else
    git clone --quiet "$PROJECT_GIT_REPO" "$BASE_GIT_DIR/$SERVICE_NAME" && \
    return 0;
  fi
  echo "ERROR == Could not clone project repository ${SERVICE_NAME} =="
  return 1
}

function getLatestSha() {
  git $LOCALDEV_GIT_CONF fetch --quiet || return 2
  LATEST_BRANCH_SHA="$(git $LOCALDEV_GIT_CONF rev-parse origin/$LOCALDEV_BRANCH)" || \
  echo "WARNING == Failed to get latest SHA in git repo ${LOCALDEV_GIT_CONF} =="
  COMMIT_SHA="${COMMIT_SHA:-$LATEST_BRANCH_SHA}"
  echo "== Commit SHA used for checkout is ${COMMIT_SHA} =="
}

function checkoutGit() {
  git $LOCALDEV_GIT_CONF checkout --force "$COMMIT_SHA" && \
  echo "== Checked out commit with SHA ${COMMIT_SHA} ==" && return 0
  return 1;
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

function createSecret() {
  local secert_name="${LOCALDEV_REGISTRY_SECRET_NAME:-regsecret}"
  kubectl get ns "${LOCALDEV_BRANCH}" || kubectl create ns "${LOCALDEV_BRANCH}"
  if ! kubectl get secret "${secert_name}" --namespace "${LOCALDEV_BRANCH}" > /dev/null 2>&1; then
    kubectl create secret docker-registry "${secert_name}" \
                                          --docker-server="${LOCALDEV_REGISTRY_SERVER}" \
                                          --docker-username="${LOCALDEV_REGISTRY_USERNAME=}" \
                                          --docker-password="${LOCALDEV_REGISTRY_PASSWORD}" \
                                          --docker-email="${GITLAB_EMAIL}" \
                                          --namespace "${LOCALDEV_BRANCH}" && \
      return 0
    return 1
  fi
}

set -e

if [ -z "$SERVICE_NAME" ]; then
  echo "== Service name to be deployed is not defined =="
  exit 3
fi

PROJECT_GIT_REPO="${GIT_REPO_PROJECT_BASE}/${SERVICE_NAME}.git"
REMOTE_DOMAINS=$(echo "$REMOTE_DOMAINS" | awk '{gsub(/^ +| +$/,"")} {print $0}')
LOCALDEV_GIT_CONF="--git-dir=${BASE_GIT_DIR}/${SERVICE_NAME}/.git --work-tree=${BASE_GIT_DIR}/${SERVICE_NAME}"
TRY_CHECKOUT_IF_DIRTY=$(echo "$TRY_CHECKOUT_IF_DIRTY"|tr '[:upper:]' '[:lower:]')
REMOTE_DOMAINS="${LOCALDEV_BRANCH}".svc."${REMOTE_CLUSTER}","${LOCALDEV_FAILOVER_BRANCH}".svc."${REMOTE_CLUSTER}"
mkdir -p $BASE_GIT_DIR
if [ -n "$REMOTE_DOMAINS" ]; then
  CHART_ARGS="$CHART_ARGS --set remoteDomains={$REMOTE_DOMAINS}"
fi

downloadChart
if gitIsClean or $TRY_CHECKOUT_IF_DIRTY; then
  checkoutGit
fi

getLatestSha
createSecret
if chartInstalled; then
  echo "== Chart ${SERVICE_NAME}-${LOCALDEV_BRANCH} already exists, please delete manually if you want it reinstalled =="
else
  installChart
fi

exit 0
