#!/usr/bin/env python3
"""
Testbench p4_router_top
"""

from functools import partial
from pathlib import Path

from kepler.fpga.sim import vunit_util
from kepler.fpga.sim.axis_dpi_pkt_helpers import compare_output_pcap_to_golden

# Relative to output_path (arg to compare_output_pcap_to_golden)
OUTPUT_PCAP_FILENAME = "axis_dpi_pkt_out.pcap"
# Relative to vunit_util.get_project_path()
INPUT_PATH = "../python/kepler/tests/rtlsim/p4_router/"
GOLDEN_PCAP_FILENAME = INPUT_PATH + "axis_dpi_pkt_out_golden.pcap"

# If this is set to 1, the C++ side will echo axis_out to axis_in.
LOOPBACK = 0
# If this is set to 1, the C++ side will read/write axis_out/in to/from PCAP files.
PCAP = 1
# Included for manual testing purposes: if SOCKET is set to 1, it will be assumed that there is
# an echo server operating on the same Unix sockets that dpi_pkt_socket.cpp uses. If SOCKET is
# set to 1, LOOPBACK must also be set to 1.
SOCKET = 0


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
            "rtl/xclock/xclock_sig.sv",
            "rtl/xclock/xclock_resetn.sv",
            "sim/axis/axis_dpi_pkt.sv",
            "sim/axis/axis_dpi_pkt_pkg.sv",
            "sim/axis/axis_dpi_pkt_sink.sv",
            "sim/axis/axis_dpi_pkt_src.sv",
            "sim/axis/axis_test_driver.sv",
            "rtl/axis/axis_arb_mux_wrapper.sv",
            "rtl/axis/axis_adapter_wrapper.sv",
            "rtl/axis/axis_demux_wrapper.sv",
            "rtl/axis/axis_async_fifo_wrapper.sv",
            "rtl/axis/axis_fifo_wrapper.sv",
            "rtl/axis/axis_interface.sv",
            "rtl/axis/axis_sof.sv",
            "verilog-axis/rtl/arbiter.v",
            "verilog-axis/rtl/axis_arb_mux.v",
            "verilog-axis/rtl/priority_encoder.v",
            "verilog-axis/rtl/axis_adapter.v",
            "verilog-axis/rtl/axis_async_fifo.v",
            "verilog-axis/rtl/axis_demux.v",
            "rtl/axi4/axi4_interface.sv",
            "rtl/avmm/avmm_to_axi4lite.sv",
            "rtl/avmm/avmm_interface.sv",
            "rtl/avmm/avmm_kepler_pkg.sv",
            "sim/avmm/avmm_test_driver_pkg.sv",
            "sim/avmm/avmm_protocol_check.sv",
            "sim/p4_router/p4_router_tb_pkg.sv",
            "rtl/p4_router/p4_router_pkg.sv",
            "rtl/p4_router/p4_router_avmm_regs.sv",
            "rtl/p4_router/p4_router_ingress_port_array_adapt.sv",
            "rtl/p4_router/p4_router_ingress.sv",
            "rtl/p4_router/p4_router_egress_port_array_adapt.sv",
            "rtl/p4_router/p4_router_egress.sv",
            "rtl/p4_router/p4_router_vnp4_wrapper.sv",
            "rtl/ip/vitis_net_p4_frr_ecp_10G.v",
            "rtl/ip/vnp4_phys_port_echo.v",
            "rtl/p4_router/p4_router.sv",
            "sim/p4_router/p4_router_top_tb.sv",
    ]
    for f in sources:
        lib.add_source_files(str(Path(project_path) / f))

    vunit_util.add_xilinx_libs(vu)

    tb = lib.test_bench("p4_router_top_tb")

    # Library for C sources used with DPI
    dpilib = vu.add_library("dpi", allow_duplicate=True)
    c_files = [
            "sim/dpi/dpi_pkt.cpp",
            "sim/dpi/dpi_pkt_echo.cpp",
            "sim/dpi/dpi_pkt_pcap.cpp",
            "sim/dpi/dpi_pkt_socket.cpp",
            "sim/p4_router/vitisnetp4_drv_dpi.so",
    ]
    assert LOOPBACK or not SOCKET, "SOCKET cannot be set unless in loopback"
    assert LOOPBACK ^ PCAP, "Exactly one DPI option must be selected"

    # VUnit doesn't understand .c files, but ModelSim does.
    # Tell VUnit they're SystemVerilog and not to parse them.
    for f in c_files:
        filename = str(Path(project_path) / f)
        if not dpilib.get_source_files(filename, allow_empty=True):
            sourcefile = dpilib.add_source_file(
                    filename,
                    include_dirs=[project_path],
                    no_parse=True,
                    file_type="systemverilog"
            )
            # Walle runs GCC 4.8.5, which requires a command-line option to enable C++11 features.
            sourcefile.add_compile_option(
                    "modelsim.vlog_flags",
                    ["-ccflags",
                     "-Werror --std=c++11"]
            )

    # pylint: disable=invalid-name
    for MAX_LATENCY in [0]:
        # Can only check the PCAP output file if a) loopback is disabled, so one is written,
        # b) the AXIS input is enabled, and c) random latency is disabled, so the output is
        # deterministic.
        do_post_check = (LOOPBACK == 0) and (MAX_LATENCY == 0)

        tb.add_config(
                "L%d" % (MAX_LATENCY,
                         ),
                parameters={
                        'input_path': str(Path(vunit_util.get_project_path()) / INPUT_PATH) + "/",
                        'MAX_LATENCY': MAX_LATENCY,
                        'LOOPBACK': LOOPBACK,
                        'SOCKET': SOCKET,
                        'PCAP': PCAP,
                },
                post_check=partial(
                        compare_output_pcap_to_golden,
                        OUTPUT_PCAP_FILENAME,
                        GOLDEN_PCAP_FILENAME
                ) if do_post_check else lambda: True,
        )

    tb.set_sim_option("modelsim.vsim_flags", ["-ldflags", "-lpcap"], overwrite=False)

    #     num_ports_configs = [
    #             {
    #                     '8B': 1,
    #                     '16B': 1,
    #                     '32B': 1,
    #                     '64B': 1
    #             },
    #             {
    #                     '8B': 2,
    #                     '16B': 0,
    #                     '32B': 2,
    #                     '64B': 0
    #             },
    #     ]

    #     for test_case in tb.get_tests():
    #         for num_ports_config in num_ports_configs:
    #             for vnp4_data_width in [8, 64]:
    #                 test_case.add_config(
    #                         "test_8B_%d_16B_%d_32B_%d_64B_%d_in_width_%s" % (
    #                                 num_ports_config['8B'],
    #                                 num_ports_config['16B'],
    #                                 num_ports_config['32B'],
    #                                 num_ports_config['64B'],
    #                                 vnp4_data_width
    #                         ),
    #                         parameters={
    #                                 'NUM_8B_PORTS': num_ports_config['8B'],
    #                                 'NUM_16B_PORTS': num_ports_config['16B'],
    #                                 'NUM_32B_PORTS': num_ports_config['32B'],
    #                                 'NUM_64B_PORTS': num_ports_config['64B'],
    #                                 'VNP4_AXIS_DATA_BYTES': egress_data_width
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
