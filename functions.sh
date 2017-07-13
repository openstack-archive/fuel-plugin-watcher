#!/bin/bash
# Copyright 2016 Mirantis, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eux

ROOT="$(dirname "$(readlink -f "$0")")"
MODULES_DIR="${ROOT}"/deployment_scripts/modules
RPM_REPO="${ROOT}"/repositories/centos/
DEB_REPO="${ROOT}"/repositories/ubuntu/

# Download RPM or DEB packages and store them in the local repository directory
function download_package {
    local package_type=$1
    local url=$2
    local wget_lvl=${3:-4}
    if [[ "$package_type" == 'deb' ]]; then
      REPO=$DEB_REPO
    elif [[ "$package_type" == 'rpm' ]]; then
      REPO=$RPM_REPO
    else
      echo "Invalid package type: $1"
    fi

    wget -P "$REPO" -A "$package_type" -nd -r -l ${wget_lvl} "$url"
}

# Download official Puppet module and store it in the local directory
function download_puppet_module {
    local m_dir=$1
    local git_repo=$2
    local git_branch=$3

    rm -rvf "${MODULES_DIR:?}"/"$m_dir"
    git clone "${git_repo}" --single-branch -b "${git_branch}" "${MODULES_DIR}/${m_dir}"
}

# Generate version file in format:
# Build: $build_date
# FUEL_PLUGIN_COMMIT=$sha
# $pkg_name=$pkg_version
function generate_deb_version_file {
    local version_file="${1:-build_version}"
    local tmp_file=$(mktemp)
    echo "# Build: $(date +%Y-%m-%d-%H-%M-%S)"  >> "${version_file}"
    echo "FUEL_PLUGIN_REF=$(git rev-parse --abbrev-ref HEAD)" >> "${version_file}"
    echo "FUEL_PLUGIN_COMMIT=$(git rev-parse HEAD)" >> "${version_file}"
    while read -d '' -r pkg; do
        dpkg-deb -I "${pkg}"| awk '/Package:/{name=$2}/Version:/{ver=$2;print name"="ver}' >> "${tmp_file}"
    done < <(find "repositories/ubuntu" -name '*.deb' -print0)
    cat "${tmp_file}" | sort >> "${version_file}"
    rm -vf "${tmp_file}"
}
