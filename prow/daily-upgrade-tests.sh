#!/bin/bash

# Copyright 2017 Istio Authors

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# Exit immediately for non zero status
set -e
# Check unset variables
set -u
# Print commands
set -x

function cleanup() {
  # log gathering
  cp -a /tmp/istio_upgrade_test/* ${ARTIFACTS_DIR}

  # Mason cleanup
  mason_cleanup
  cat "${FILE_LOG}"
}

function download_untar_istio_release() {
  # Download artifacts
  LINUX_DIST_URL="${1}/istio-${2}-linux.tar.gz"

  wget  -q "${LINUX_DIST_URL}"
  tar -xzf "istio-${2}-linux.tar.gz"
}

echo "Testing Upgrade from ${HUB}/${SOURCE_VERSION} to ${HUB}/${TARGET_VERSION}"

# Check https://github.com/istio/test-infra/blob/master/boskos/configs.yaml
# for existing resources types
RESOURCE_TYPE="${RESOURCE_TYPE:-gke-e2e-test}"
OWNER='upgrade-tests'
INFO_PATH="$(mktemp /tmp/XXXXX.boskos.info)"
FILE_LOG="$(mktemp /tmp/XXXXX.boskos.log)"

# Artifact dir is hardcoded in Prow - boostrap to be in first repo checked out
ARTIFACTS_DIR="${GOPATH}/src/github.com/istio-releases/daily-release/_artifacts"


# Checkout istio at the greenbuild
mkdir -p ${GOPATH}/src/istio.io
pushd    ${GOPATH}/src/istio.io
git clone -n https://github.com/istio/istio.git

pushd istio
#from now on we are in ${GOPATH}/src/istio.io/istio dir

#git checkout $SHA
#Hack to use the latest test script for now.
git checkout master

source "prow/mason_lib.sh"
source "prow/cluster_lib.sh"
trap cleanup EXIT

download_untar_istio_release ${SOURCE_RELEASE_PATH} ${SOURCE_VERSION}
download_untar_istio_release ${TARGET_RELEASE_PATH} ${TARGET_VERSION}

get_resource "${RESOURCE_TYPE}" "${OWNER}" "${INFO_PATH}" "${FILE_LOG}"
setup_cluster

# Install fortio which is needed by the upgrade test.
go get fortio.org/fortio

./tests/upgrade/test_crossgrade.sh --from_hub=${HUB} --from_tag=${SOURCE_VERSION} --from_path=istio-${SOURCE_VERSION} --to_hub=${HUB} --to_tag=${TARGET_VERSION} --to_path=istio-${TARGET_VERSION}

