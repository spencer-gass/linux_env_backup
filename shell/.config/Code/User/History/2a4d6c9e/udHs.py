#!/usr/bin/env python3
"""
Testbench mpls_ingress
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
            "rtl/axis/axis_adapter_wrapper.sv",
            "rtl/axis/axis_arb_mux_wrapper.sv",
            "rtl/axis/axis_async_fifo_wrapper.sv",
            "rtl/axis/axis_fifo_wrapper.sv",
            "rtl/axis/axis_interface.sv",
            "sim/mpls/mpls_ingress_tb_pkg.sv",
            "rtl/mpls/mpls_ingress_port_array_adapt.sv",
            "rtl/mpls/mpls_ingress.sv",
            "sim/mpls/mpls_ingress_tb.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "sim/axis/axis_test_driver.sv",
            "rtl/util/util_ints.sv",
            "verilog-axis/rtl/arbiter.v",
            "verilog-axis/rtl/axis_adapter.v",
            "verilog-axis/rtl/axis_async_fifo.v",
            "verilog-axis/rtl/axis_arb_mux.v",
            "verilog-axis/rtl/priority_encoder.v",
    ]
    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))

    tb = lib.test_bench("mpls_ingress_tb")

    num_ports_configs = [
        {'8B':1, '16B':1, '32B':1, '64B':1},
        {'8B':3, '16B':3, '32B':3, '64B':3},
        {'8B':2, '16B':0, '32B':0, '64B':0},
        {'8B':0, '16B':2, '32B':0, '64B':0},
        {'8B':0, '16B':0, '32B':2, '64B':0},
        {'8B':0, '16B':0, '32B':0, '64B':2},
        {'8B':5, '16B':4, '32B':4, '64B':0},
    ]

    for test_case in tb.get_tests():
        for num_ports_config in num_ports_configs:
            for converged_data_width in [8, 64]:

                port_width_sum = 1 * num_ports_config['8B'] + \
                                 2 * num_ports_config['16B'] + \
                                 4 * num_ports_config['32B'] + \
                                 8 * num_ports_config['64B']

                if port_width_sum > converged_data_width: # skip cases where ingress capacity is greater than output bus capacity
                    continue

                test_case.add_config(
                        "test_8B_%d_16B_%d_32B_%d_64B_%d_out_width_%s" % (
                            num_ports_config['8B'],
                            num_ports_config['16B'],
                            num_ports_config['32B'],
                            num_ports_config['64B'],
                            converged_data_width
                        ),
                        parameters={
                            'NUM_8B_PORTS':  num_ports_config['8B'],
                            'NUM_16B_PORTS': num_ports_config['16B'],
                            'NUM_32B_PORTS': num_ports_config['32B'],
                            'NUM_64B_PORTS': num_ports_config['64B'],
                            'CONVERGED_AXIS_DATA_BYTES': converged_data_width
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
