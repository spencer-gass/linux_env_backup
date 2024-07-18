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
            "rtl/axis/axis_connect.sv",
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

    tb = lib.test_bench("mpls_router_tb")

    packet_minlen = 64
    packet_maxlen = 100
    for slow in [False, True]:
        for n_ports in [3, 8]:
            for axis_data_bytes in [1, 4, 8] if slow else [1, 4]:
                for num_mpls_labels in [4, 8, 16] if slow else [1, 4]:
                    for test_case in tb.get_tests():
                        num_packets_to_send = 32 if slow else 8
                        test_case.add_config(
                                "P%d_DB%d_PL%dTO%d_NL%d_NP%d_%s" % (
                                        n_ports,
                                        axis_data_bytes,
                                        packet_minlen,
                                        packet_maxlen,
                                        num_mpls_labels,
                                        num_packets_to_send,
                                        "s" if slow else "f"
                                ),
                                parameters={
                                        'N_PORTS': n_ports,
                                        'AXIS_DATA_BYTES': axis_data_bytes,
                                        'PACKET_MINLEN': packet_minlen,
                                        'PACKET_MAXLEN': packet_maxlen,
                                        'NUM_MPLS_LABELS': num_mpls_labels,
                                        'NUM_PACKETS_TO_SEND': num_packets_to_send,
                                },
                                attributes={'.slow': None} if slow else {}
                        )

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
