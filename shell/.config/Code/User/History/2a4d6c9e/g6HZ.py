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
            "rtl/axis/axis_adapter_wrapper.sv",
            "rtl/axis/axis_arb_mux_wrapper.sv",
            "rtl/axis/axis_async_fifo_wrapper.sv",
            "rtl/axis/axis_fifo_wrapper.sv",
            "rtl/axis/axis_interface.sv",
            "rtl/mpls/mpls_ingress.sv",
            "sim/axis/axis_test_driver.sv",
            "sim/mpls/mpls_ingress_tb.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "verilog-axis/rtl/arbiter.v",
            "verilog-axis/rtl/axis_adapter.v",
            "verilog-axis/rtl/axis_async_fifo.v",
            "verilog-axis/rtl/axis_arb_mux.v",
            "verilog-axis/rtl/priority_encoder.v",
    ]
    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))

    tb = lib.test_bench("mpls_ingress_tb")

    for test_case in tb.get_tests():
        test_case.add_config(
            "test_%d" % (0),
            parameters={
                    # 'NUM_PHYS_PORTS': 2,
                    # 'AXIS_DATA_BYTES': 16,
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
