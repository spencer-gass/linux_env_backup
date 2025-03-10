#!/usr/bin/env python3
"""
Testbench axis array generator and checker
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
            "rtl/xclock/xclock_resetn.sv",
            "rtl/axis/axis_interface.sv",
            "sim/axis/axis_packet_checker.sv",
            "sim/axis/axis_packet_generator.sv",
            "sim/axis/axis_array_packet_checker.sv",
            "sim/axis/axis_array_packet_generator.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "sim/axis/axis_test_driver.sv",
            "rtl/util/util_ints.sv",
    ]
    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))

    tb = lib.test_bench("axis_array_generator_and_checker_tb")

#     for test_case in tb.get_tests():
#                 test_case.add_config(
#                         "test_8B_%d_16B_%d_32B_%d_64B_%d_out_width_%s" % (
#                                 num_ports_config['8B'],
#                                 num_ports_config['16B'],
#                                 num_ports_config['32B'],
#                                 num_ports_config['64B'],
#                                 converged_data_width
#                         ),
#                         parameters={
#                                 'NUM_8B_PORTS': num_ports_config['8B'],
#                                 'NUM_16B_PORTS': num_ports_config['16B'],
#                                 'NUM_32B_PORTS': num_ports_config['32B'],
#                                 'NUM_64B_PORTS': num_ports_config['64B'],
#                                 'CONVERGED_AXIS_DATA_BYTES': converged_data_width
#                         },
#                 )

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
