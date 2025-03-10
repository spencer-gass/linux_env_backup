#!/bin/sh
set -eu

if [ $# -ne 2 ]; then
    echo "Two arguments are required:"
    "    1: the path to the directory in which the hdf resides."
    "    2: ECP version number"
    exit 1
fi

HERE=$(dirname $0)
HDF_DIR="$1"

# If we're within a git checkout, see if someone forgot to run "git secret reveal" here or in "layers".
../../soc_build/git-secret-check.sh && (cd ../layers; ../../soc_build/git-secret-check.sh)

# Update the HDF.
petalinux-config --get-hw-description "$HDF_DIR" --silentconfig -v

echo "ECP_VERSION=$2" > project-spec/meta-user/recipes-bsp/device-tree/device-tree.cfg
petalinux-config -c device-tree