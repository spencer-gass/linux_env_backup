#!/usr/bin/env python3
"""
Testbench ethernet_ip_packet_src_tb.
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
            "rtl/avmm/avmm_interface.sv",
            "rtl/avmm/avmm_kepler_pkg.sv",
            "rtl/avmm/avmm_gpio.sv",
            "rtl/gmii/gmii_interface.sv",
            "rtl/gmii/gmii_interface.sv",
            "rtl/gmii/gmii_connect.sv",
            "rtl/util/util_ints.sv",
            "rtl/xclock/xclock_pulse.sv",
            "rtl/xclock/pulse2toggle.sv",
            "rtl/xclock/xclock_sig.sv",
            "rtl/xclock/toggle2pulse.sv",
            "rtl/axis/axis_interface.sv",
            "rtl/axis/axis_footer_add.sv",
            "sim/axis/axis_test_driver.sv",
            "verilog-ethernet/rtl/eth_mac_1g.v",
            "verilog-ethernet/rtl/lfsr.v",
            "verilog-ethernet/rtl/axis_gmii_rx.v",
            "verilog-ethernet/rtl/axis_gmii_tx.v",
            "verilog-axis/rtl/axis_async_fifo_adapter.v",
            "verilog-axis/rtl/axis_async_fifo.v",
            "verilog-axis/rtl/axis_adapter.v",
            "verilog-axis/rtl/sync_reset.v",
            "verilog-ethernet/rtl/eth_mac_1g_fifo.v",
            "verilog-axis/rtl/axis_adapter.v",
            "rtl/axis/axis_adapter_wrapper.sv",
            "verilog-ethernet/rtl/ip_eth_tx.v",
            "verilog-ethernet/rtl/eth_axis_tx.v",
            "rtl/axis/axis_repeat.sv",
            "sim/util/util_longrand.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "sim/avmm/avmm_test_driver_pkg.sv",
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            "rtl/ethernet/ethernet_packet_src.sv",
            "sim/ethernet/ethernet_packet_src_tb.sv"
    ]
    for f in sources:
        lib.add_source_files(os.path.join(project_path, f))

    tb = lib.test_bench("ethernet_packet_src_tb")

    # pylint: disable=invalid-name
    for PACKET_LENGTH in [5, 120]:
        for DATA_BYTES in [1, 8]:
            tb.add_config("PKT_LEN%d_DATA_BYTES%d" % (PACKET_LENGTH, DATA_BYTES),
                          parameters={
                                  'PACKET_LENGTH': PACKET_LENGTH,
                                  'DATA_BYTES': DATA_BYTES,
                          })

    return tb


def main():
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
