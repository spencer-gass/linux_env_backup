#!/usr/bin/env python3
"""
Testbench dvbs2x_tx_symb_rate_divider_mmi
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
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            "rtl/mmi/mmi_interface.sv",
            "rtl/dvbs2/dvbs2_bb_frame_counter.sv",
            "rtl/dvbs2/dvbs2_bb_frame_counter_mmi.sv",
            "rtl/util/util_ints.sv",
            "sim/util/util_longrand.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "sim/dvbs2/dvbs2_bb_frame_counter_mmi_tb.sv",
            "sim/mmi/mmi_test_driver.sv",
    ]

    for f in sources:
        lib.add_source_files(os.path.join(project_path, f))

    tb = lib.test_bench("dvbs2_bb_frame_counter_mmi_tb")

    # pylint: disable=invalid-name
    for slow in [False, True]:
        for DVB_STANDARD in [0, 1]:
            tb.add_config(
                    "DVBv%d_%s" % (DVB_STANDARD,
                                   "s" if slow else "f"),
                    parameters={
                            'RAND_RUNS': 1000 if slow else 100,
                            'DVB_STANDARD': DVB_STANDARD
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
