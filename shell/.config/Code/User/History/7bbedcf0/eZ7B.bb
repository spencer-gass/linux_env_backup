SUMMARY = "Recipe for  build an external xvc-driver Linux kernel module"
SECTION = "PETALINUX/modules"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263"

inherit module

SRC_URI = "git://github.com/Xilinx/XilinxVirtualCable.git;protocol=https \
	file://0001-adapted-to-petalinux.patch"
SRCREV = "ca897be4188edef3a052396b2d30c99de0cd6331"

S = "${WORKDIR}/git/jtag/zynqMP/src/driver"

# The inherit of module.bbclass will automatically name module packages with
# "kernel-module-" prefix as required by the oe-core build environment.

FILES_${PN} += "/etc/modules/xvc-driver"

# do_install() {
#     mkdir -p ${D}/etc/modules
#     touch ${D}/etc/modules/xvc-driver
# }
