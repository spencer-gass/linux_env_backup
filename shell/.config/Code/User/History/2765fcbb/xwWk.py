#!/usr/bin/env python3
"""
Testbench dac_ad5601_ctrl_mmi
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
            "rtl/mmi/mmi_interface.sv",
            "rtl/common/clock_interface.sv",
            "rtl/common/reset_interface.sv",
            "rtl/spi/spi_interface.sv",
            "rtl/spi/spi_mux.sv",
            "rtl/spi/spi_drv.sv",
            "sim/mmi/mmi_test_driver.sv",
            "sim/util/util_longrand.sv",
            "sim/util/util_protocol_check_helpers.sv",
            "rtl/dac_ad5601/dac_ad5601_ctrl_mmi.sv",
            "sim/dac_ad5601/dac_ad5601_ctrl_mmi_tb.sv",
    ]
    for f in sources:
        lib.add_source_files(os.path.join(project_path, f))

    tb = lib.test_bench("dac_ad5601_ctrl_mmi_tb")

    # pylint: disable=invalid-name
    for SET_DEFAULT_ON_RESET in [0, 1]:
        tb.add_config(
                "DEFAULT_ON_RESET_%d" % (SET_DEFAULT_ON_RESET,
                                         ),
                parameters={
                        'SET_DEFAULT_ON_RESET': SET_DEFAULT_ON_RESET,
                }
        )
    for MMI_DATALEN in [16, 32]:
        tb.add_config(
                "MMI_DATALEN_%d" % (MMI_DATALEN,
                                         ),
                parameters={
                        'DATALEN': MMI_DATALEN,
                }
        )

    return tb


def main():
    "Run just this test bench."
    vu, lib = vunit_util.init_vunit()
    create_testbench(vu=vu, lib=lib, project_path=vunit_util.get_project_path())
    vunit_util.vunit_run(vu)


if __name__ == "__main__":
    main()
