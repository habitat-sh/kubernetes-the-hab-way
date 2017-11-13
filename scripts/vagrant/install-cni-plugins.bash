#!/bin/bash

set -euo pipefail

readonly tmpdir=$(mktemp -d /tmp/cni-install-XXXX)
mkdir -p "${tmpdir}"

pushd "${tmpdir}" >/dev/null
trap 'popd >/dev/null; rm -rf "${tmpdir}"' EXIT

readonly cni_url="https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz"

curl -fsSL "${cni_url}" -o cni.tar.gz

mkdir -p /opt/cni/bin
tar -xvf cni.tar.gz -C /opt/cni/bin/
