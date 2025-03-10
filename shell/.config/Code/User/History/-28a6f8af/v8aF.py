#!/usr/bin/env python3
"""
Testbench p4_router_top
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
            "sim/util/util_protocol_check_helpers.sv",
            "rtl/util/util_ints.sv",
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            #     "rtl/xclock/xclock_avmm.sv",
            #     "rtl/xclock/xclock_resetn.sv",
            "rtl/axis/axis_interface.sv",
            "sim/axis/axis_test_driver.sv",
            #     "rtl/axis/axis_arb_mux_wrapper.sv",
            #     "rtl/axis/axis_adapter_wrapper.sv",
            #     "rtl/axis/axis_demux_wrapper.sv",
            #     "rtl/axis/axis_async_fifo_wrapper.sv",
            #     "rtl/axis/axis_fifo_wrapper.sv",
            #     "rtl/axis/axis_dist_ram_fifo.sv",
            #     "rtl/axis/axis_interface.sv",
            #     "rtl/axis/axis_sof.sv",
            #     "rtl/axis/axis_profile.sv",
            #     "rtl/axis/axis_mute.sv",
            "rtl/axis/axis_connect.sv",
            #     "verilog-axis/rtl/arbiter.v",
            #     "verilog-axis/rtl/axis_arb_mux.v",
            #     "verilog-axis/rtl/priority_encoder.v",
            #     "verilog-axis/rtl/axis_adapter.v",
            #     "verilog-axis/rtl/axis_async_fifo.v",
            #     "verilog-axis/rtl/axis_demux.v",
            "sim/axis/axis_packet_generator.sv",
            "sim/axis/axis_packet_checker.sv",
            "rtl/axi4/axi4_interface.sv",
            "rtl/avmm/avmm_interface.sv",
            "rtl/avmm/avmm_kepler_pkg.sv",
            "sim/avmm/avmm_test_driver_pkg.sv",
            "sim/avmm/avmm_protocol_check.sv",
            "sim/p4_router/p4_router_tb_pkg.sv",
            "rtl/p4_router/p4_router_pkg.sv",
            "rtl/p4_router/p4_router_congestion_manager.sv",
            "sim/p4_router/p4_router_congestion_manager_tb.sv",
    ]

    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))

    vunit_util.add_xilinx_libs(vu)

    tb = lib.test_bench("p4_router_congestion_manager_tb")

    #     num_ports_configs = [
    #             {
    #                     '8B': 1,
    #                     '16B': 1,
    #                     '32B': 1,
    #                     '64B': 1
    #             },
    #             {
    #                     '8B': 3,
    #                     '16B': 3,
    #                     '32B': 3,
    #                     '64B': 3
    #             },
    #             {
    #                     '8B': 2,
    #                     '16B': 0,
    #                     '32B': 0,
    #                     '64B': 0
    #             },
    #             {
    #                     '8B': 0,
    #                     '16B': 2,
    #                     '32B': 0,
    #                     '64B': 0
    #             },
    #             {
    #                     '8B': 0,
    #                     '16B': 0,
    #                     '32B': 2,
    #                     '64B': 0
    #             },
    #             {
    #                     '8B': 0,
    #                     '16B': 0,
    #                     '32B': 0,
    #                     '64B': 2
    #             },
    #     ]

    #     for test_case in tb.get_tests():
    #         for num_ports_config in num_ports_configs:

    #             # skip cases where ingress capacity is greater than output bus capacity
    #             test_case.add_config(
    #                     "test_8B_%d_16B_%d_32B_%d_64B_%d" % (
    #                             num_ports_config['8B'],
    #                             num_ports_config['16B'],
    #                             num_ports_config['32B'],
    #                             num_ports_config['64B']
    #                     ),
    #                     parameters={
    #                             'NUM_8B_ING_PHYS_PORTS': num_ports_config['8B'],
    #                             'NUM_16B_ING_PHYS_PORTS': num_ports_config['16B'],
    #                             'NUM_32B_ING_PHYS_PORTS': num_ports_config['32B'],
    #                             'NUM_64B_ING_PHYS_PORTS': num_ports_config['64B'],
    #                             'NUM_8B_EGR_PHYS_PORTS': num_ports_config['8B'],
    #                             'NUM_16B_EGR_PHYS_PORTS': num_ports_config['16B'],
    #                             'NUM_32B_EGR_PHYS_PORTS': num_ports_config['32B'],
    #                             'NUM_64B_EGR_PHYS_PORTS': num_ports_config['64B'],
    #                     },
    #             )

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
