#!/usr/bin/env python3
"""
Testbench network_packet_generator
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
            "rtl/xclock/xclock_sig.sv",
            "rtl/axis/axis_interface.sv",
            "rtl/axis/axis_sop.sv",
            "rtl/axi4/axi4_interface.sv",
            "rtl/avmm/avmm_interface.sv",
            "rtl/avmm/avmm_kepler_pkg.sv",
            "rtl/avmm/avmm_gpio.sv",
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            "rtl/network_packet_generator/network_packet_generator.sv",
            "rtl/util/util_ints.sv",
            "sim/avmm/avmm_test_driver_pkg.sv",
            "sim/avmm/avmm_protocol_check.sv",
            "sim/network_packet_generator/vitis_net_p4_network_packet_utils_parser_pkg.sv",
            "sim/network_packet_generator/vitis_net_p4_network_packet_utils_parser_sim_netlist.v",
            "sim/network_packet_generator/network_packet_generator_tb.sv",
            #"sim/util/util_protocol_check_helpers.sv",
    ]
    for f in sources:
        lib.add_source_files(os.path.join(project_path, f))

    vunit_util.add_xilinx_libs(vu)

    tb = lib.test_bench("network_packet_generator_tb")

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
