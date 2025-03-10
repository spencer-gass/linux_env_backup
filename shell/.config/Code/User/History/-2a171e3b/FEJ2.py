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
            "rtl/xclock/xclock_sig.sv",
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            "rtl/util/util_endian_swap.sv ",
            "rtl/avmm/avmm_interface.sv",
            "rtl/avmm/avmm_kepler_pkg.sv",
            "rtl/avmm/avmm_gpio.sv",
            "sim/avmm/avmm_test_driver_pkg.sv",
            "sim/avmm/avmm_protocol_check.sv",
            "rtl/axis/axis_interface.sv",
            "rtl/axis/axis_sof.sv",
            "rtl/axis/axis_sop.sv",
            "rtl/axis/axis_adapter_wrapper.sv",
            "verilog-axis/rtl/axis_adapter.v",
            "rtl/network_packet_generator/network_packet_generator.sv",
            "sim/p4_router/p4_router_tb_pkg.sv",
            "rtl/p4_router/p4_router_pkg.sv",
            "sim/axis/axis_packet_generator.sv",
            "sim/axis/axis_packet_checker.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "sim/axis/axis_test_driver.sv",
            "rtl/axi4/axi4_interface.sv",
            "sim/axi4/axi4lite_test_driver.sv",
            "rtl/util/util_ints.sv",
            "rtl/ipv4/ipv4_checksum_update.sv",
            "rtl/ipv4/ipv4_checksum_gen.sv",
            "rtl/ipv4/ipv4_checksum_verify.sv",
            "rtl/axis/axis_to_user_extern.sv",
            "rtl/p4_router/p4_router_vnp4_wrapper_select.sv",
            "rtl/p4_router/p4_router_vnp4_frr_t1_ecp_tiny_bcam_pkg.sv",
            "rtl/p4_router/p4_router_vnp4_frr_t1_ecp_tiny_bcam_wrapper.sv",
            "sim/p4_router/vitis_net_p4_frr_t1_ecp_tiny_bcam_sim_netlist.v",
            "sim/p4_router/p4_router_vnp4_tiny_bcam_tb.sv",
    ]
    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))
    tb = lib.test_bench("p4_router_vnp4_tiny_bcam_tb")

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.add_xilinx_libs(vu)
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
