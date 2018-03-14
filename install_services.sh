#!/usr/bin/env bash

_SERVICE_DEFINITION_DIRECTORY=${_SERVICE_DEFINITION_DIRECTORY:-services}
file_objects=$(find services -maxdepth 1 -type f -name "[!.]*")

for f_object in $file_objects; do
  unset LOCALDEV_BRANCH
  unset SERVICE_NAME
  unset GIT_REPO_PROJECT_BASE
  unset COMMIT_SHA
  unset LOCALDEV_FAILOVER_BRANCH
  unset REMOTE_CLUSTER
  source $f_object && ./helm.sh && \
  echo "== chart from $SERVICE_NAME from $f_object installed =="
done

exit 0
