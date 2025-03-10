#!/usr/bin/env python3
"""
Testbench VNP4 with IPv4 checksum user extern
"""

from pathlib import Path

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
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            "rtl/axis/axis_interface.sv",
            "sim/p4_router/p4_router_tb_pkg.sv",
            "rtl/p4_router/p4_router_pkg.sv",
            "sim/axis/axis_packet_generator.sv",
            "sim/axis/axis_packet_checker.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "sim/axis/axis_test_driver.sv",
            "rtl/axis/axis_to_user_extern.sv",
            "rtl/ipv4/ipv4_checksum_update.sv",
            "rtl/ipv4/ipv4_checksum_gen.sv",
            "rtl/ipv4/ipv4_checksum_verify.sv",
            "rtl/util/util_ints.sv",
            "sim/ipv4/ipv4_checksum_tb_pkg.sv",
            "sim/p4_router/vitis_net_p4_passthrough_with_ipv4_user_extern_pkg.sv",
            "sim/p4_router/vitis_net_p4_passthrough_with_ipv4_user_extern_sim_netlist.v",
            "sim/p4_router/vnp4_ipv4_user_extern_tb.sv",
    ]
    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))
    tb = lib.test_bench("vnp4_ipv4_user_extern_tb")

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.add_xilinx_libs(vu)
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
