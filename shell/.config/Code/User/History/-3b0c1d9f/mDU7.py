#!/usr/bin/env python3
"""
Testbench p4_router_egress
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
            "rtl/util/util_ints.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "verilog-axis/rtl/axis_async_fifo.v",
            "rtl/avmm/avmm_interface.sv",
            "rtl/avmm/avmm_kepler_pkg.sv",
            "sim/avmm/avmm_test_driver_pkg.sv",
            "sim/avmm/avmm_protocol_check.sv",
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            "rtl/xclock/xclock_avmm.sv",
            "rtl/xclock/xclock_resetn.sv",
            "rtl/p4_router/p4_router_avmm_regs.sv",
            "sim/p4_router/p4_router_avmm_regs_tb.sv",
    ]
    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))

    tb = lib.test_bench("p4_router_avmm_regs_tb")

    num_ports_configs = [
            {
                    '8B': 3,
                    '16B': 3,
                    '32B': 3,
                    '64B': 3
            },
            {
                    '8B': 2,
                    '16B': 0,
                    '32B': 0,
                    '64B': 0
            },
            {
                    '8B': 5,
                    '16B': 0,
                    '32B': 4,
                    '64B': 0
            },
    ]

    for test_case in tb.get_tests():
        for num_ports_config in num_ports_configs:
                test_case.add_config(
                    "test_8B_%d_16B_%d_32B_%d_64B_%d" % (
                            num_ports_config['8B'],
                            num_ports_config['16B'],
                            num_ports_config['32B'],
                            num_ports_config['64B']
                    ),
                    parameters={
                            'NUM_8B_ING_PHYS_PORTS': num_ports_config['8B'],
                            'NUM_16B_ING_PHYS_PORTS': num_ports_config['16B'],
                            'NUM_32B_ING_PHYS_PORTS': num_ports_config['32B'],
                            'NUM_64B_ING_PHYS_PORTS': num_ports_config['64B'],
                            'NUM_8B_EGR_PHYS_PORTS': num_ports_config['8B'],
                            'NUM_16B_EGR_PHYS_PORTS': num_ports_config['16B'],
                            'NUM_32B_EGR_PHYS_PORTS': num_ports_config['32B'],
                            'NUM_64B_EGR_PHYS_PORTS': num_ports_config['64B']
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