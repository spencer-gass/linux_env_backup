#!/usr/bin/env python3
"""
Testbench ipv4_checksum_update
"""

import os.path

from kepler.fpga.sim import vunit_util


def create_testbench(vu, lib, project_path, **kwargs):  # pylint: disable=unused-argument
    """
    Create and configure this test bench.

    vu:     the VUnit instance under which this is being run
    lib:    the VUnit library "lib". Your test bench must be added here.
    project_path:   Absolute path to the KeplerFPGA project.
                    (Source code is in project_path/rtl and project_path/sim.)
    kwargs: Swallow any additional keyword args. (More parameters
            may be added in the future.)
    """

    sources = [
            "rtl/axis/axis_interface.sv",
            "rtl/ipv4/ipv4_checksum_gen.sv",
            "rtl/ipv4/ipv4_checksum_verify.sv",
            "sim/ipv4/ipv4_checksum_tb_pkg.sv",
            "sim/ipv4/ipv4_checksum_verify_tb.sv",
    ]
    for f in sources:
        lib.add_source_files(os.path.join(project_path, f))

    tb = lib.test_bench("ipv4_checksum_verify_tb")

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
