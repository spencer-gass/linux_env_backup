#!/bin/sh
set -eu

if [ $# -ne 2 ]; then
    echo "Two arguments are required:"
    echo " 1: the path to the directory in which the hdf resides."
    echo " 2: the path to the VNP4.xcix file."
    exit 1
fi

HERE=$(dirname $0)
HDF_DIR="$1"
VNP4_DIR="$2"

# If we're within a git checkout, see if someone forgot to run "git secret reveal" here or in "layers".
../../soc_build/git-secret-check.sh && (cd ../layers; ../../soc_build/git-secret-check.sh)

# Update the HDF.
petalinux-config --get-hw-description "$HDF_DIR" --silentconfig -v

if [ ! -d "project-spec/meta-user/recipes-net" ]; then
    mkdir project-spec/meta-user/recipes-net
fi
if [ ! -d "project-spec/meta-user/recipes-net/frr_dplane" ]; then
    mkdir project-spec/meta-user/recipes-net/frr_dplane
fi
if [ ! -d "project-spec/meta-user/recipes-net/frr_dplane/files" ]; then
    mkdir project-spec/meta-user/recipes-net/frr_dplane/files
fi

cp $VNP4_DIR project-spec/meta-user/recipes-net/frr_dplane/files/vnp4_runtime_driver.zip