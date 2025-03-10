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
            "rtl/axis/axis_interface.sv",
            "sim/axis/axis_test_driver.sv",
            "rtl/axis/axis_connect.sv",
            "sim/axi4/axi4lite_test_driver.sv",
            "sim/axis/axis_packet_generator.sv",
            "sim/axis/axis_packet_checker.sv",
            "rtl/axi4/axi4_interface.sv",
            "sim/p4_router/p4_router_tb_pkg.sv",
            "rtl/p4_router/p4_router_pkg.sv",
            "rtl/p4_router/p4_router_policer.sv",
            "rtl/p4_router/p4_router_queue_states.sv",
            "sim/p4_router/p4_router_queue_states_tb.sv",
    ]

    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))

    vunit_util.add_xilinx_libs(vu)

    tb = lib.test_bench("p4_router_queue_states_tb")

    for test_case in tb.get_tests():
        for num_queues_to_enqueue in [1, 2 , -1]:

            if (num_queues_to_enqueue == -1):
                # defaults to enqueuing in all queues so not setting the parameter acheives this test case.
                test_case.add_config(
                        "test_all_queues",
                )
            else:
                test_case.add_config(
                        "test_%d_queues" % (
                                num_queues_to_enqueue
                        ),
                        parameters={
                                'NUM_QUEUES_TO_ENQUEUE': num_queues_to_enqueue
                        },
                )

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
