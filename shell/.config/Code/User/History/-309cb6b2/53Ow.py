"""
This module provides TaskVivado, which builds FPGA bitstreams using Xilinx Vivado.
"""

# pylint: disable=too-many-lines

import datetime
import logging
from pathlib import Path
import subprocess
import time
from typing import Any, Dict, Iterable, List, Optional, Tuple

import colorama
import sqlalchemy

from . import db_def
from . import parse_vivado
from .build_artifact_util import BuildArtifact, apply_renames, get_user_artifacts
from .build_id_util import BuildId
from .build_base import BuildBase
from .db_util import table_insert_or_update_statement, filter_table_columns
from .logging_util import get_build_type_logger, show_log_path, tail_log
from .tool_utils import soc_build_env, get_xilinx_tool_builder, source_and_subprocess_call

######################
# VIVADO BUILD SCRIPT

# The VIVADO_BUILD_* strings are concatenated together to form a Tcl build script.
# Optional steps may be inserted between them.

# Part 1 of the Vivado build script. Assumes the project is already open.
VIVADO_BUILD_1_PREPARE = """
# ######
# Setup
set soc_build_proj_dir [get_property directory [current_project]]
set soc_build_top_name [get_property "top" [get_filesets sources_1]]

cd $soc_build_proj_dir

# Raise the default message limits
if {[get_param messaging.defaultLimit] < 1000} { set_param messaging.defaultLimit 1000 }

# Record initial build information
set soc_build_fp [open "${soc_build_proj_dir}/soc_build_synth_status.rpt" w]
puts $soc_build_fp "PROJ_NAME [get_property name [current_project]]"
puts $soc_build_fp "TOP $soc_build_top_name"
puts $soc_build_fp "BUILD_START [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
close $soc_build_fp
"""

# If requested, upgrade all IP cores.
VIVADO_BUILD_2_UPGRADE_UPGRADE_IPS = """
set soc_build_ip_cores [get_ips]
if {[llength $soc_build_ip_cores] > 0} {
    upgrade_ip -quiet $soc_build_ip_cores
}
"""

# Set hook scripts.
# Overriding synthesis or implementation strategies happens after this.
VIVADO_BUILD_3_SAVE_HOOKS = """
set soc_build_sources_1 [get_filesets sources_1]
set soc_build_synth_1 [get_runs synth_1]
set soc_build_impl_1 [get_runs impl_1]

update_compile_order -fileset $soc_build_sources_1


# ############################
# Strategies and Hook Scripts

# Changing strategies can wipe out hooks. We'll copy them here, so we can re-set them later.
set soc_build_synth_hooks [dict create]
foreach key [list_property $soc_build_synth_1 STEPS.*.TCL.*] {
    dict set soc_build_synth_hooks $key [get_property $key $soc_build_synth_1]
}
set soc_build_impl_hooks [dict create]
foreach key [list_property $soc_build_impl_1 STEPS.*.TCL.*] {
    dict set soc_build_impl_hooks $key [get_property $key $soc_build_impl_1]
}
"""

# Restore hook scripts.
# We also set our own post-synthesis and post-implementation hooks for reporting.
# If they are called, then they will call the appropriate user-set hook script.
VIVADO_BUILD_4_RESTORE_HOOKS = """
# After possibly overriding strategies, restore the hook scripts.
dict for {hook script} $soc_build_synth_hooks {
    set_property $hook $script $soc_build_synth_1
}
dict for {hook script} $soc_build_impl_hooks {
    set_property $hook $script $soc_build_impl_1
}

# We need to set our own post-synthesis and post-implementation hooks for reporting.
# If hook scripts have already been set, then our scripts needs to call those.
# The [current_project] is inaccessible from within a run, so we need to retrieve and store
# the hook scripts now, so we know what to run later. End of implementation is either
# ROUTE_DESIGN or POST_ROUTE_PHYS_OPT_DESIGN, depending on whether or not physical optimization
# is enabled.
if [![file exists "${soc_build_proj_dir}/soc_build_include_scripts.txt"]] {
    set soc_build_fp [open "${soc_build_proj_dir}/soc_build_include_scripts.txt" w]
    puts $soc_build_fp "SYNTH_POST \\"[dict get $soc_build_synth_hooks STEPS.SYNTH_DESIGN.TCL.POST]\\""
    if [get_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED $soc_build_impl_1] {
        puts $soc_build_fp "IMPL_POST \\"[dict get $soc_build_impl_hooks STEPS.POST_ROUTE_PHYS_OPT_DESIGN.TCL.POST]\\""
    } else {
        puts $soc_build_fp "IMPL_POST \\"[dict get $soc_build_impl_hooks STEPS.ROUTE_DESIGN.TCL.POST]\\""
    }
    close $soc_build_fp
}

# Set our own post-synthesis and post-implementation hooks for reporting.
if {[string equal [get_filesets -quiet utils_1] ""]} {
    create_fileset -constrset utils_1
}
add_files -fileset [get_filesets utils_1] [file join $soc_build_proj_dir soc_build_post_synth.tcl] [file join $soc_build_proj_dir soc_build_post_impl.tcl]

set_property STEPS.SYNTH_DESIGN.TCL.POST [file join $soc_build_proj_dir soc_build_post_synth.tcl] $soc_build_synth_1
if [get_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED $soc_build_impl_1] {
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.TCL.POST [file join $soc_build_proj_dir soc_build_post_route_phys_opt.tcl] $soc_build_impl_1
} else {
    set_property STEPS.ROUTE_DESIGN.TCL.POST [file join $soc_build_proj_dir soc_build_post_impl.tcl] $soc_build_impl_1
}
"""

# Run synthesis and implementation.
VIVADO_BUILD_5_RUN_PART1 = """
# ##########
# Synthesis
reset_run synth_1
"""
# Next call "launch_runs synth_1", optionally specifying a "-jobs" value, then part 2.

VIVADO_BUILD_5_RUN_PART2 = """
wait_on_run synth_1

# Record some key statistics from synthesis
report_property [get_runs synth_1] -file "${soc_build_proj_dir}/soc_build_synth_status.rpt" -append -regex {.*STATS.ELAPSED.*|.*PROGRESS.*|.*STATUS.*}

# Exit if synthesis failed
set soc_build_synth_progress [get_property PROGRESS [get_runs synth_1]]
set soc_build_synth_status [get_property STATUS [get_runs synth_1]]
if {$soc_build_synth_progress != "100%"} {
    error "ERROR: Synthesis failed. PROGRESS=${soc_build_synth_progress}, STATUS=${soc_build_synth_status}"
}


# ###############
# Implementation
launch_runs -to_step write_bitstream impl_1
wait_on_run impl_1
"""

# If requested, export the hardware handoff file.
VIVADO_BUILD_6_WRITE_HARDWARE = """
# ################
# Export Hardware

set soc_build_synth_1 [get_runs synth_1]
set soc_build_impl_1 [get_runs impl_1]

# Write an HDF or XSA file, depending on the Vivado version.
if {[version -short] >= "2019.2"} {
    # Newer: write an XSA.
    write_hw_platform -fixed -force -file "$soc_build_proj_dir/$soc_build_top_name.xsa"
} else {
    # Older: write a HDF a sub-directory to match what File > Export > Export Hardware would do.
    set soc_build_sdk_dir [file join $soc_build_proj_dir [current_project].sdk]
    file mkdir $soc_build_sdk_dir
    write_hwdef -force "$soc_build_sdk_dir/$soc_build_top_name.hdf"
}
"""

# Record final stats and close the project.
VIVADO_BUILD_7_FINISH = """
# #####
# Done
# Record some key statistics from implementation.
report_property $soc_build_impl_1 -file "${soc_build_proj_dir}/soc_build_impl_status.rpt" -append -regex {.*STATS.ELAPSED.*|.*PROGRESS.*|.*STATUS.*}

# Note: We don't check PROGRESS to tell whether or not implementation failed.
# This doesn't seem to work reliably when using "-to_step write_bitstream".
# Instead, we just end. We'll know if we succeeded, because there will be a bitfile, etc.
close_project
"""

#########################
# BUILD SCRIPT FRAGMENTS

# '%s' will be replaced with the path to the project file, relative to work_dir.
VIVADO_OPEN_PROJECT_SCRIPT = """
open_project "%s"
"""

# '%s' will be replaced with the new strategy
VIVADO_CHANGE_SYNTH_STRATEGY_SCRIPT = """
set_property -name "strategy" -value "%s" -objects $soc_build_synth_1
"""

# '%s' will be replaced with the new strategy
VIVADO_CHANGE_IMPL_STRATEGY_SCRIPT = """
set_property -name "strategy" -value "%s" -objects $soc_build_impl_1

# Changing the strategy resets properties to default. We always want a .bin file written.
set_property -name "STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE" -value "1" -objects $soc_build_impl_1
"""

# '%d' will be replaced with the number of synthesis jobs to run
VIVADO_LAUNCH_SYNTH_SCRIPT = """
launch_runs synth_1 -jobs %d
"""

###############
# HOOK SCRIPTS
# These scripts assume that the current working directory is the run directory (i.e. runs/synth_1),
# so the project root is two levels above. Note that [current_project] doesn't work from within
# a run.
VIVADO_POST_SYNTH_SCRIPT = """# soc_build: Vivado post-synthesis reporting script
# If the build had a post-synthesis script set before we installed ours, run it.
set soc_build_proj_dir [file normalize "../.."]
set soc_build_fp [open "${soc_build_proj_dir}/soc_build_include_scripts.txt" r]
while { [gets $soc_build_fp soc_build_line] >= 0 } {
    if {[lindex $soc_build_line 0] == "SYNTH_POST"} {
        set soc_build_post_script [lindex $soc_build_line 1]
        if {$soc_build_post_script != ""} {
            if {"[file normalize $soc_build_post_script]" != "[file normalize [info script]]"} {
                puts "Sourcing post-synthesis script '$soc_build_post_script'."
                source $soc_build_post_script
            }
        }
    }
}
close $soc_build_fp

# Run post-synthesis reports.
report_utilization -file "${soc_build_proj_dir}/soc_build_synth_util.rpt"
report_utilization -hierarchical -append -file "${soc_build_proj_dir}/soc_build_synth_util.rpt"
report_methodology -file "${soc_build_proj_dir}/soc_build_synth_methodology.rpt"
"""

VIVADO_POST_IMPL_SCRIPT = """# soc_build: Vivado post-implementation reporting script
# If the build had a post-implementation script set before we installed ours, run it.
set soc_build_proj_dir [file normalize "../.."]
set soc_build_fp [open "${soc_build_proj_dir}/soc_build_include_scripts.txt" r]
while { [gets $soc_build_fp soc_build_line] >= 0 } {
    if {[lindex $soc_build_line 0] == "IMPL_POST"} {
        set soc_build_post_script [lindex $soc_build_line 1]
        if {$soc_build_post_script != ""} {
            if {"[file normalize $soc_build_post_script]" != "[file normalize [info script]]"} {
                puts "Sourcing post-synthesis script '$soc_build_post_script'."
                source $soc_build_post_script
            }
        }
    }
}
close $soc_build_fp

# Run post-implementation reports.
report_utilization -file "${soc_build_proj_dir}/soc_build_impl_util.rpt"
report_utilization -hierarchical -append -file "${soc_build_proj_dir}/soc_build_impl_util.rpt"
report_methodology -file "${soc_build_proj_dir}/soc_build_impl_methodology.rpt"

# Record timing results.
set soc_build_fp [open "${soc_build_proj_dir}/soc_build_impl_status.rpt" w]
puts $soc_build_fp "WNS [get_property slack [get_timing_paths -setup]]"
puts $soc_build_fp "WHS [get_property slack [get_timing_paths -hold]]"
close $soc_build_fp

report_timing -file "${soc_build_proj_dir}/soc_build_impl_timing.rpt"
check_timing -append -file "${soc_build_proj_dir}/soc_build_impl_timing.rpt"
report_pulse_width -all_violators -file "${soc_build_proj_dir}/soc_build_impl_timing_wpws.rpt"

report_cdc -summary -file "${soc_build_proj_dir}/soc_build_impl_cdc_summary.rpt"
report_cdc -details -file "${soc_build_proj_dir}/soc_build_impl_cdc_details.rpt"

# (Complexity and congestion - disabled because they're slow, and SoC Build doesn't currently parse them.
# If the user wants this report, they can run it via a post-implementation hook script.)
#report_design_analysis -hierarchical_depth 10 -complexity -congestion -max_paths 10 -setup -hold -file "${soc_build_proj_dir}/soc_build_impl_design_analysis.rpt"
"""


class VivadoTask(BuildBase):
    """
    Build FPGA bitstreams with Xilinx Vivado.
    """

    @classmethod
    def name(cls) -> str:
        return "vivado"

    @classmethod
    def db_table(cls) -> sqlalchemy.Table:
        return db_def.vivado_table

    def _make_args(self, build_id: BuildId, project_config: dict) -> Dict[str, str]:
        """
        Create the dictionary we use for script argument substitution.

        Args:
            build_id: This must be a complete BuildId.
                must already have been exported and configured here by the "source" task.
            project_config: the project configuration file loaded and parsed from the
                source directory by the source task.

        Raises:
            OSError: if the project creation script does not exist, or Vivado could not
                be launched.
            KeyError: if create-script-args contains an invalid variable substitution.
            ValueError: if create-script-args contains an argument that is missing quotation
                marks, and therefore is getting read as something other than a string type.
            RuntimeError: if project creation fails, either because Vivado exits with a non-zero
                exit code, or if Vivado exits cleanly but the expected project file is not created.

        Returns:
            the argument substitution dictionary.
        """
        vivado_build_info = self._check_vivado_build_info(build_id, project_config)
        proj_file = Path(vivado_build_info["created-project"])

        tclargs = {
                'build_id': str(build_id),
                'build_type': build_id.build_type,
                'proj_file': str(proj_file),  # relative to work_dir
                'proj_dir': str(proj_file.parent),
        }

        return tclargs

    def get_artifacts(self,
                      build_id: BuildId,
                      work_dir: Path,
                      project_config: dict,
                      **kwargs) -> Iterable[BuildArtifact]:
        """
        Returns artifacts from this task.

        This function should try very hard not to raise exceptions. It is used in copying
        build artifacts, which collects build logs in the case of other errors.

        Args:
            build_id: This must be a complete BuildId.
            work_dir: The working directory in which the completed build resides.
                self.build() must have completed.
            project_config: the project configuration file loaded and parsed from the
                source directory by the source task.
            kwargs: Ignored.

        Returns:
            a list of build artifacts.
        """
        artifacts = []  # type: List[BuildArtifact]
        logger = get_build_type_logger(__name__, build_id.build_type)

        vivado_build_info = self._check_vivado_build_info(build_id, project_config)
        proj_file = Path(vivado_build_info["created-project"])
        proj_fullpath = work_dir / proj_file
        proj_dir = proj_fullpath.parent

        artifact_config = project_config.get("projects",
                                             {}).get(build_id.build_type,
                                                     {}).get("vivado-build",
                                                             {}).get("artifact-config",
                                                                     {})
        top_exts = artifact_config.get("toplevel-extensions", {})
        renames = artifact_config.get("renames", [])

        # In order to pick up outputs, we need to parts the build summary report.
        results = parse_vivado.parse_synth_status_rpt(
                logger,
                proj_dir / "soc_build_synth_status.rpt"
        )
        proj = results['proj']
        top = results['top']

        # Pick up log files.
        logs_dir = self._cfg.get_logs_dir(work_dir)
        for logpath in logs_dir.glob("soc_build_vivado*.log"):
            artifacts.append(BuildArtifact(logpath.relative_to(work_dir), ".log", True, False))
        for logpath in proj_dir.glob("soc_build*.rpt"):
            artifacts.append(BuildArtifact(logpath.relative_to(work_dir), ".rpt", True, False))

        if top and proj:
            impl_dir = proj_dir / (proj + ".runs") / "impl_1"
            sdk_dir = proj_dir / (proj + ".sdk")
            bit_file_src = impl_dir / (top + ".bit")
            bin_file_src = impl_dir / (top + ".bin")
            hdf_file_src = sdk_dir / (top + ".hdf")
            xsa_file_src = proj_dir / (top + ".xsa")
            dcp_file_src = impl_dir / (top + "_routed.dcp")

            if bit_file_src.is_file():
                artifacts.append(
                        BuildArtifact(
                                bit_file_src.relative_to(work_dir),
                                bit_file_src.suffix,
                                False,
                                bit_file_src.suffix in top_exts
                        )
                )
            if bin_file_src.is_file():
                artifacts.append(
                        BuildArtifact(
                                bin_file_src.relative_to(work_dir),
                                bin_file_src.suffix,
                                False,
                                bin_file_src.suffix in top_exts
                        )
                )
            if hdf_file_src.is_file():
                artifacts.append(
                        BuildArtifact(
                                hdf_file_src.relative_to(work_dir),
                                hdf_file_src.suffix,
                                False,
                                hdf_file_src.suffix in top_exts
                        )
                )
            if xsa_file_src.is_file():
                artifacts.append(
                        BuildArtifact(
                                xsa_file_src.relative_to(work_dir),
                                xsa_file_src.suffix,
                                False,
                                xsa_file_src.suffix in top_exts
                        )
                )
            if dcp_file_src.is_file():
                artifacts.append(
                        BuildArtifact(
                                dcp_file_src.relative_to(work_dir),
                                dcp_file_src.suffix,
                                False,
                                dcp_file_src.suffix in top_exts,
                                True,  # optional
                        )
                )
        else:
            logger.warning(
                    "Unable to retrieve project name and top module from output report,"
                    " therefore unable to collect some output files."
            )

        # Get user-requested artifacts.
        subst_vars = {
                'build_id': str(build_id),
                'build_type': str(build_id.build_type),
                'proj_dir': str(proj_file.parent),
                'proj_file': str(proj_file),
        }
        artifacts += get_user_artifacts(build_id.build_type, work_dir, artifact_config, subst_vars)

        apply_renames(artifacts, renames)
        return artifacts

    @staticmethod
    def _check_vivado_build_info(build_id: BuildId, project_config: dict) -> dict:
        """
        Check that the necessary entries under vivado-build exist for a particular build type.

        project_config may be modified: if create-script-args is absent, a sentinel value will be
        created for it.

        Args:
            build_id: the key build_id.build_type will be looked up in the project configuration.
            project_config: the project configuration file loaded and parsed from the
                source directory by the source task.

        Returns:
            dict: For convenience, returns the value from
                project_config['projects'][build_id.build_type].

        Raises:
            KeyError: if any of the necessary keys is missing.
            ValueError: if any of the paths are absolute. (They should all be relative: implicitly
                relative to the workspace directory.)
        """
        if "vivado-build" not in project_config.get("projects", {}).get(build_id.build_type, {}):
            raise KeyError(
                    "Build type '%s' has no 'vivado-build' definition in the project config."
                    % build_id.build_type
            )

        vivado_build_info = project_config["projects"][build_id.build_type]["vivado-build"
                                                                            ]  # type: dict
        if "create-script" not in vivado_build_info:
            raise KeyError(
                    "Build type '%s' is missing vivado-build/create-script." % build_id.build_type
            )
        if "created-project" not in vivado_build_info:
            raise KeyError(
                    "Build type '%s' is missing vivado-build/created-project." % build_id.build_type
            )
        if "create-script-args" not in vivado_build_info:
            vivado_build_info["create-script-args"] = []
        if "post-build-script" not in vivado_build_info:
            vivado_build_info["post-build-script"] = ""
        if "post-build-script-args" not in vivado_build_info:
            vivado_build_info["post-build-script-args"] = []

        create_script = Path(vivado_build_info["create-script"])
        proj_file = Path(vivado_build_info["created-project"])

        if create_script.is_absolute():
            raise ValueError(
                    "The vivado-build/create-script path ('%s') for build type '%s' must be"
                    " a relative path." % (create_script,
                                           build_id.build_type)
            )
        if proj_file.is_absolute():
            raise ValueError(
                    "The vivado-build/created-project path ('%s') for build type '%s' must be"
                    " a relative path." % (proj_file,
                                           build_id.build_type)
            )

        return vivado_build_info

    def create(self, build_id: BuildId, work_dir: Path, project_config: dict, **kwargs):
        """
        Run Vivado to create the project.

        Args:
            build_id: This must be a complete BuildId.
            work_dir: The working directory in which the build will take place. Source code
                must already have been exported and configured here by the "source" task.
            project_config: the project configuration file loaded and parsed from the
                source directory by the source task.
            kwargs: Ignored. This task takes no extra arguments.

        Raises:
            OSError: if the project creation script does not exist, or Vivado could not
                be launched.
            KeyError: if create-script-args contains an invalid variable substitution.
            ValueError: if create-script-args contains an argument that is missing quotation
                marks, and therefore is getting read as something other than a string type.
            RuntimeError: if project creation fails, either because Vivado exits with a non-zero
                exit code, or if Vivado exits cleanly but the expected project file is not created.
        """
        logger = get_build_type_logger(__name__, build_id.build_type)

        builder_version, vivado_settings = get_xilinx_tool_builder(
                self._cfg, build_id, project_config, "vivado")
        vivado_build_info = self._check_vivado_build_info(build_id, project_config)
        create_script = Path(vivado_build_info["create-script"])
        create_script_args = vivado_build_info["create-script-args"]
        proj_file = Path(vivado_build_info["created-project"])
        shebang = self._cfg.get(["tools", "vivado", builder_version, "shebang"])

        if not (work_dir / create_script).is_file():
            raise OSError(
                    "While building '%s', the project creation script '%s' does not exist." %
                    (str(build_id),
                     work_dir / create_script)
            )

        # We provide the ability to pass arguments to the project creation script.
        # We allow Python format strings. Create a dictionary with values to substitute.
        tclargs = self._make_args(build_id, project_config)

        logger.info(
                "Creating Vivado project for '%s' with vivado-%s.",
                build_id.build_type,
                builder_version
        )
        cmdline = ["vivado", '-mode', 'batch', '-source', str(create_script)]
        if create_script_args:
            cmdline += ['-tclargs']
            for arg in create_script_args:
                if not isinstance(arg, str):
                    raise ValueError(
                            "In projects/%s/vivado-build/create-script-args, argument '%s' is not"
                            " a string. You must surround it with quotes." %
                            (build_id.build_type,
                             str(arg))
                    )
                    # We cannot do easily that automatically: str(arg) would work for something
                    # like ints, but if they write {work_dir} intending it to become a variable
                    # substitution, Yaml will interpret it as a dictionary, and Python's str(arg)
                    # will not be in the correct form for a string formatting field.
                try:
                    cmdline += [arg.format(**tclargs)]
                except KeyError as err:
                    raise KeyError(
                            "In projects/%s/vivado-build/create-script-args, argument '%s' is not"
                            " a valid substitution." % (build_id.build_type,
                                                        str(arg))
                    ) from err

        # Run Vivado to create the project.
        if not (work_dir / create_script).is_file():
            raise RuntimeError(
                    "Project creation script '%s' for '%s' does not exist." %
                    (create_script,
                     build_id.build_type)
            )
        logs_dir = self._cfg.get_logs_dir(work_dir)
        bash_script = logs_dir / "soc_build_vivado_create.sh"
        vivado_out_filename = logs_dir / "soc_build_vivado_create.log"
        logger.debug(
                "Executing source %s && %s > %s",
                vivado_settings,
                str(cmdline),
                str(vivado_out_filename)
        )
        show_log_path(logger, vivado_out_filename.resolve(), **self._cfg.log_path_settings)
        t_start = time.monotonic()
        with vivado_out_filename.open(self._cfg.log_open_mode) as f_out:
            result = source_and_subprocess_call(
                    cmdline,
                    source_sh=vivado_settings,
                    dest_sh=work_dir / bash_script,
                    shebang=shebang,
                    cwd=work_dir,
                    stdout=f_out,
                    stderr=subprocess.STDOUT,
                    env=soc_build_env(".",
                                      build_id=build_id,
                                      tool_stage=f"{self.name()}-create"),
                    logger=logger
            )
        t_end = time.monotonic()
        logger.debug("Result = %d", result)

        # Record the build time in seconds.
        with (logs_dir / "soc_build_vivado_create_time.log").open("wt") as f:
            f.writelines(str(t_end - t_start))

        if result != 0:
            tail_log(vivado_out_filename, lines=self._cfg.get(["logging", "tail"]), logger=logger)

        if result < 0:
            raise OSError("Error executing Vivado: subprocess.call returned %d." % result)
        if result > 0:
            raise RuntimeError("Project creation failed: Vivado exited with code %d." % result)

        proj_fullpath = work_dir / proj_file
        if not proj_fullpath.is_file():
            raise RuntimeError(
                    "Vivado exited successfully, but the expected project file '%s'"
                    " does not exist under '%s'." % (proj_file,
                                                     work_dir)
            )

        logger.info("Created project at '%s'.", proj_file)

    def _get_strategies(  # pylint: disable=no-self-use
            self,
            build_type: str,
            project_config: dict,
            override_synth_strategy: str = "",
            override_impl_strategy: str = ""
    ) -> Tuple[str,
               str]:
        """
        Get the synthesis and implementation strategies to use. Look them up in
        project_config['build_type'], but allow overrides.

        Args:
            build_type: The build type to look up in project_config.
            project_config: The project configuration file loaded and parsed from the
                source directory by the source task.
            override_synth_strategy: If non-blank, then override the synthesis strategy with this.
            override_impl_strategy: If non-blank, then override the implementation strategy.

        Returns:
            A tuple with (synth_strategy, impl_strategy). Either may be the empty string
            if nothing is provided in the config file or an override.
        """
        # Get synth and impl strategies from the project config if not overridden.
        strategy_info = project_config["projects"][build_type].get("vivado-config",
                                                                   {}).get("strategy",
                                                                           {})
        synth_strategy = override_synth_strategy
        impl_strategy = override_impl_strategy
        if not synth_strategy:
            synth_strategy = strategy_info.get("synth", "")
        if not impl_strategy:
            impl_strategy = strategy_info.get("impl", "")
        return (synth_strategy, impl_strategy)

    def _write_build_scripts(
            self,
            build_id: BuildId,
            work_dir: Path,
            project_config: dict,
            override_synth_strategy: str = "",
            override_impl_strategy: str = "",
            override_run_jobs: Optional[int] = None
    ) -> Path:
        """
        Write out the tcl scripts that will run the Vivado build.

        Args:
            build_id: This must be a complete BuildId.
            work_dir: The working directory in which the build will take place. Source code
                must already have been exported and configured here by the "source" task.
            project_config: The project configuration file loaded and parsed from the
                source directory by the source task.
            override_synth_strategy: If non-blank, then override the synthesis strategy with this.
            override_impl_strategy: If non-blank, then override the implementation strategy.
            override_run_jobs: If not None, then override the number of jobs to use
                when launching synthesis runs. Currently this only applies to synthesis
                to help with OOC of IP cores. When we launch implementation, there is only
                one job that needs to be run.

        Returns:
            Path: a relative path to the build script, relative to work_dir.
        """
        logger = get_build_type_logger(__name__, build_id.build_type)

        vivado_build_info = self._check_vivado_build_info(build_id, project_config)
        proj_file = Path(vivado_build_info["created-project"])
        proj_fullpath = work_dir / proj_file

        # Get synth and impl strategies from the project config if not overridden.
        synth_strategy, impl_strategy = self._get_strategies(
                build_id.build_type,
                project_config,
                override_synth_strategy,
                override_impl_strategy)

        if override_run_jobs is not None:
            run_jobs = override_run_jobs
        else:
            run_jobs = self._cfg.get(["tool-config", "vivado", "run_jobs"], 1)
        run_jobs = max(1, run_jobs)  # sanitize

        workspace_dir = proj_fullpath.parent
        build_script_filepath = workspace_dir / "soc_build_build.tcl"
        logger.debug("Writing %s.", build_script_filepath)
        with build_script_filepath.open("wt") as f:
            f.writelines("# soc_build: Vivado build script\n")
            f.writelines(VIVADO_OPEN_PROJECT_SCRIPT % str(proj_file))
            f.writelines(VIVADO_BUILD_1_PREPARE)
            if vivado_build_info.get("upgrade-ips", True):
                f.writelines(VIVADO_BUILD_2_UPGRADE_UPGRADE_IPS)
            f.writelines(VIVADO_BUILD_3_SAVE_HOOKS)
            if synth_strategy:
                f.writelines(VIVADO_CHANGE_SYNTH_STRATEGY_SCRIPT % synth_strategy)
            if impl_strategy:
                f.writelines(VIVADO_CHANGE_IMPL_STRATEGY_SCRIPT % impl_strategy)
            f.writelines(VIVADO_BUILD_4_RESTORE_HOOKS)
            f.writelines(VIVADO_BUILD_5_RUN_PART1)
            f.writelines(VIVADO_LAUNCH_SYNTH_SCRIPT % run_jobs)
            f.writelines(VIVADO_BUILD_5_RUN_PART2)
            if vivado_build_info.get("export-hardware", False):
                f.writelines(VIVADO_BUILD_6_WRITE_HARDWARE)
            f.writelines(VIVADO_BUILD_7_FINISH)

        post_synth_filepath = workspace_dir / "soc_build_post_synth.tcl"
        logger.debug("Writing %s.", post_synth_filepath)
        with post_synth_filepath.open("wt") as f:
            f.writelines(VIVADO_POST_SYNTH_SCRIPT)

        post_impl_filepath = workspace_dir / "soc_build_post_impl.tcl"
        logger.debug("Writing %s.", post_impl_filepath)
        with post_impl_filepath.open("wt") as f:
            f.writelines(VIVADO_POST_IMPL_SCRIPT)

        return build_script_filepath.relative_to(work_dir)

    def build(self, build_id: BuildId, work_dir: Path, project_config: dict, **kwargs):
        """
        Run Vivado to build the project.

        Args:
            build_id: This must be a complete BuildId.
            work_dir: The working directory in which the build will take place. Source code
                must already have been exported and configured here by the "source" task.
            project_config: The project configuration file loaded and parsed from the
                source directory by the source task.
            kwargs: This task understands the following arguments:
                override_synth_strategy (str) - if not blank, then the synthesis strategy
                    will be overridden with this value.
                override_impl_strategy (str) - if not blank, then the implementation strategy
                    will be overridden with this value.
                override_run_jobs (int) - If not None, then override the number of jobs to use
                    when launching synthesis runs. Currently this only applies to synthesis
                    to help with OOC of IP cores. When we launch implementation, there is only
                    one job that needs to be run.
                override_tfibf (bool) - If not None, then override the config file setting
                    tool-config/vivado/timing_failure_is_build_failure.

        Raises:
            OSError: if Vivado could not be launched.
            RuntimeError: if the project file does not exist. You should call create() first.
        """
        logger = get_build_type_logger(__name__, build_id.build_type)

        override_synth_strategy = kwargs.get('override_synth_strategy', "")
        override_impl_strategy = kwargs.get('override_impl_strategy', "")
        override_run_jobs = kwargs.get('override_run_jobs', None)  # type: Optional[int]

        builder_version, vivado_settings = get_xilinx_tool_builder(
                self._cfg, build_id, project_config, "vivado")
        vivado_build_info = self._check_vivado_build_info(build_id, project_config)
        proj_file = Path(vivado_build_info["created-project"])
        proj_fullpath = work_dir / proj_file
        shebang = self._cfg.get(["tools", "vivado", builder_version, "shebang"])

        if not proj_fullpath.is_file():
            raise RuntimeError(
                    "The project file '%s' does not exist under '%s'. The project must"
                    " be created before it can be built." % (proj_file,
                                                             work_dir)
            )

        build_script = self._write_build_scripts(
                build_id,
                work_dir,
                project_config,
                override_synth_strategy,
                override_impl_strategy,
                override_run_jobs
        )

        if not (work_dir / build_script).is_file():
            raise RuntimeError(
                    "BUG: The build script should have been generated at '%s', but it does"
                    " not exist." % (work_dir / build_script)
            )

        logger.info(
                "Compiling bitstream for '%s' with vivado-%s.",
                build_id.build_type,
                builder_version
        )
        cmdline = ["vivado", '-mode', 'batch', '-source', str(build_script)]
        logs_dir = self._cfg.get_logs_dir(work_dir)
        bash_script = logs_dir / "soc_build_vivado_build.sh"
        vivado_out_filename = logs_dir / "soc_build_vivado_build.log"
        logger.debug(
                "Executing source %s && %s > %s",
                vivado_settings,
                str(cmdline),
                str(vivado_out_filename)
        )
        show_log_path(logger, vivado_out_filename.resolve(), **self._cfg.log_path_settings)
        t_start = time.monotonic()
        with vivado_out_filename.open(self._cfg.log_open_mode) as f_out:
            result = source_and_subprocess_call(
                    cmdline,
                    source_sh=vivado_settings,
                    dest_sh=work_dir / bash_script,
                    shebang=shebang,
                    cwd=work_dir,
                    stdout=f_out,
                    stderr=subprocess.STDOUT,
                    env=soc_build_env(".",
                                      build_id=build_id,
                                      tool_stage=f"{self.name()}-build"),
                    logger=logger
            )
        t_end = time.monotonic()
        logger.debug("Result = %d", result)

        # Record the build time in seconds.
        with (logs_dir / "soc_build_vivado_build_time.log").open("wt") as f:
            f.writelines(str(t_end - t_start))

        if result != 0:
            tail_log(vivado_out_filename, lines=self._cfg.get(["logging", "tail"]), logger=logger)

        if result < 0:
            raise OSError("Error executing Vivado: subprocess.call returned %d." % result)
        if result > 0:
            raise RuntimeError("Build failed: Vivado exited with code %d." % result)

        logger.info("Vivado build complete.")

    def post_build(self, build_id: BuildId, work_dir: Path, project_config: dict, **kwargs):
        """
        Run post-build script with Vivado. This should be run after build().

        Args:
            build_id: This must be a complete BuildId.
            work_dir: The working directory for the build.
            project_config: the project configuration file loaded and parsed from the
                source directory by the source task.
            kwargs: Ignored.

        Raises:
            OSError: if the post-build script does not exist, or Vivado could not
                be launched.
            KeyError: if post-build-script-args contains an invalid variable substitution.
            ValueError: if post-build-script-args contains an argument that is missing quotation
                marks, and therefore is getting read as something other than a string type.
            RuntimeError: if the post-build script fails because Vivado exits with a non-zero
                exit code.
        """
        logger = get_build_type_logger(__name__, build_id.build_type)

        builder_version, vivado_settings = get_xilinx_tool_builder(
                self._cfg, build_id, project_config, "vivado")
        vivado_build_info = self._check_vivado_build_info(build_id, project_config)
        shebang = self._cfg.get(["tools", "vivado", builder_version, "shebang"])

        logs_dir = self._cfg.get_logs_dir(work_dir)
        bash_script = logs_dir / "soc_build_vivado_post_build.sh"
        if not vivado_build_info["post-build-script"]:
            logger.debug(
                    "No post-build script set for projects/%s/vivado-build",
                    build_id.build_type
            )
            with (logs_dir / "soc_build_vivado_post_build_exit.log").open("wt") as f:
                f.writelines("none")
            return

        post_script = Path(vivado_build_info["post-build-script"])
        post_script_args = vivado_build_info["post-build-script-args"]

        if not (work_dir / post_script).is_file():
            raise OSError(
                    "While building '%s', the post-build script '%s' does not exist." %
                    (str(build_id),
                     work_dir / post_script)
            )

        # We provide the ability to pass arguments to the post-build script.
        # We allow Python format strings. Create a dictionary with values to substitute.
        tclargs = self._make_args(build_id, project_config)

        logger.info(
                "Running post-build script for '%s' with vivado-%s.",
                build_id.build_type,
                builder_version
        )
        cmdline = ["vivado", '-mode', 'batch', '-source', str(post_script)]
        if post_script_args:
            cmdline += ['-tclargs']
            for arg in post_script_args:
                if not isinstance(arg, str):
                    raise ValueError(
                            "In projects/%s/vivado-build/post-build-script-args, argument '%s'"
                            " is not a string. You must surround it with quotes." %
                            (build_id.build_type,
                             str(arg))
                    )
                    # We cannot do easily that automatically: str(arg) would work for something
                    # like ints, but if they write {work_dir} intending it to become a variable
                    # substitution, Yaml will interpret it as a dictionary, and Python's str(arg)
                    # will not be in the correct form for a string formatting field.
                try:
                    cmdline += [arg.format(**tclargs)]
                except KeyError as err:
                    raise KeyError(
                            "In projects/%s/vivado-build/post-build-script-args, argument '%s'"
                            " is not a valid substitution." % (build_id.build_type,
                                                               str(arg))
                    ) from err

        # Run the script through Vivado.
        if not (work_dir / post_script).is_file():
            raise RuntimeError(
                    "Post-build script '%s' for '%s' does not exist." %
                    (post_script,
                     build_id.build_type)
            )
        vivado_out_filename = logs_dir / "soc_build_vivado_post_build.log"
        logger.debug(
                "Executing source %s && %s > %s",
                vivado_settings,
                str(cmdline),
                str(vivado_out_filename)
        )
        show_log_path(logger, vivado_out_filename.resolve(), **self._cfg.log_path_settings)
        t_start = time.monotonic()
        with vivado_out_filename.open(self._cfg.log_open_mode) as f_out:
            result = source_and_subprocess_call(
                    cmdline,
                    source_sh=vivado_settings,
                    dest_sh=work_dir / bash_script,
                    shebang=shebang,
                    cwd=work_dir,
                    stdout=f_out,
                    stderr=subprocess.STDOUT,
                    env=soc_build_env(
                            ".",
                            build_id=build_id,
                            tool_stage=f"{self.name()}-post_build"
                    ),
                    logger=logger
            )
        t_end = time.monotonic()
        logger.debug("Result = %d", result)

        # Record the build time in seconds.
        with (logs_dir / "soc_build_vivado_post_build_time.log").open("wt") as f:
            f.writelines(str(t_end - t_start))
        with (logs_dir / "soc_build_vivado_post_build_exit.log").open("wt") as f:
            f.writelines("exit: %d" % result)

        if result != 0:
            tail_log(vivado_out_filename, lines=self._cfg.get(["logging", "tail"]), logger=logger)

        if result < 0:
            raise OSError("Error executing Vivado: subprocess.call returned %d." % result)
        if result > 0:
            raise RuntimeError("Post-build script failed: Vivado exited with code %d." % result)

        logger.info("Vivado post-build script done.")

    @staticmethod
    def _parse_detailed_info(logger: logging.Logger,
                             logs_dir: Path,
                             proj_dir: Path) -> Dict[str,
                                                     Any]:
        """
        Helper function for parse_results(). Parses Vivado build log and other log files
        our build script wrote to extract status and statistics.

        This function raises no exceptions. Results in the output dict may be None
        if the corresponding information could not be found or parsed.

        Args:
            logger: the logger to use.
            logs_dir: the directory in which soc_build logs are stored
            proj_dir: the project path location

        Returns:
            dict: status and statistics parsed from the build outputs. See the
                procedures in parse_vivado for more details.
        """

        results = {}  # type: Dict[str, Any]

        create_time = parse_vivado.parse_build_time(
                logger,
                logs_dir / "soc_build_vivado_create_time.log"
        )
        build_time = parse_vivado.parse_build_time(
                logger,
                logs_dir / "soc_build_vivado_build_time.log"
        )
        post_time = parse_vivado.parse_build_time(
                logger,
                logs_dir / "soc_build_vivado_post_build_time.log",
                missing_ok=True
        )
        if build_time is not None:
            zero_td = datetime.timedelta(seconds=0)
            build_time = build_time + (create_time or zero_td) + (post_time or zero_td)
        else:
            build_time = None
        results['proj_create_time'] = create_time
        results['build_time'] = build_time
        results['post_build_time'] = post_time
        results['post_build_ok'] = parse_vivado.parse_post_build_ok(
                logger,
                logs_dir / "soc_build_vivado_post_build_exit.log"
        )

        results.update(
                parse_vivado.parse_global_build_stats(
                        logger,
                        logs_dir / "soc_build_vivado_build.log"
                )
        )

        results.update(
                parse_vivado.parse_synth_util_rpt(logger,
                                                  proj_dir / "soc_build_synth_util.rpt")
        )

        results.update(
                parse_vivado.parse_impl_util_rpt(logger,
                                                 proj_dir / "soc_build_impl_util.rpt")
        )

        results.update(
                parse_vivado.parse_impl_cdc_summary_rpt(
                        logger,
                        proj_dir / "soc_build_impl_cdc_summary.rpt"
                )
        )

        #**# TODO: What, if anything, do we want to parse from the congestion report?

        return results

    def parse_results(
            self,
            build_id: BuildId,
            work_dir: Path,
            project_config: dict,
            override_tfibf: Optional[bool] = None
    ) -> dict:
        """
        Extract status and statistics from output files.

        Args:
            build_id: This must be a complete BuildId.
            work_dir: The working directory in which the completed build resides.
                self.build() must have completed.
            project_config: the project configuration file loaded and parsed from the
                source directory by the source task.
            override_tfibf: If not None, then override the config file setting
                    tool-config/vivado/timing_failure_is_build_failure.

        Returns:
            dict: key, value pairs for parsed results
        """
        logger = get_build_type_logger(__name__, build_id.build_type)

        vivado_build_info = self._check_vivado_build_info(build_id, project_config)
        proj_file = Path(vivado_build_info["created-project"])
        proj_fullpath = work_dir / proj_file
        proj_dir = proj_fullpath.parent

        config_tfibf = self._cfg.get(["tool-config",
                                      "vivado",
                                      "timing_failure_is_build_failure"],
                                     True)
        if override_tfibf is not None:
            config_tfibf = override_tfibf

        results = {
                'build_id': str(build_id),
                'proj_dir': proj_dir.relative_to(work_dir),
                'proj_file': proj_fullpath.relative_to(work_dir),
        }  # type: Dict[str, Any]

        logger.info("Parsing reports.")

        ########################
        # Project Creation Stats
        results['proj_created'] = proj_fullpath.is_file()
        top = None
        proj = None
        impl_dir = None

        #################
        # Synthesis Stats

        results.update(
                parse_vivado.parse_synth_status_rpt(
                        logger,
                        proj_dir / "soc_build_synth_status.rpt"
                )
        )
        proj = results['proj']
        top = results['top']

        if top and proj:
            impl_dir = proj_dir / (proj + ".runs") / "impl_1"
            bit_file_src = impl_dir / (top + ".bit")
            if bit_file_src.is_file():
                results['impl_ok'] = True
            else:
                results['impl_ok'] = False
                results['impl_status_message'] = "No .bit file produced"

        ######################
        # Implementation Stats
        results.update(
                parse_vivado.parse_impl_status_rpt(logger,
                                                   proj_dir / "soc_build_impl_status.rpt")
        )
        results.update(
                parse_vivado.parse_impl_timing_wpws_rpt(
                        logger,
                        proj_dir / "soc_build_impl_timing_wpws.rpt"
                )
        )
        parse_vivado.update_passed_timing(logger, results)

        if results['impl_ok'] and not (('wns' in results) and ('whs' in results)):
            # So far we think implementation is ok, but we don't have timing info
            results['passed_timing'] = False
            results['impl_status_message'] = "No WNS, WHS values available"

        ################
        # Detailed Stats
        logs_dir = self._cfg.get_logs_dir(work_dir)
        results.update(self._parse_detailed_info(logger, logs_dir, proj_dir))

        ################
        # Overall Result
        post_build_ok = results["post_build_ok"]
        results["build_ok"] = results["proj_created"] and results["synth_ok"] and results[
                "impl_ok"] and ((post_build_ok is None) or post_build_ok)

        if results['vivado_crash']:
            results['build_result_message'] = "FAILED: Vivado crashed"
            results['build_ok'] = False
        elif results['license_not_found']:
            results['build_result_message'] = results['license_not_found']
            results['build_ok'] = False
        elif not results['proj_created']:
            results['build_result_message'] = "FAILED project creation."
            results['build_ok'] = False
        elif not results['synth_ok']:
            results['build_result_message'
                    ] = "FAILED synthesis. (%s)" % results['synth_status_message']
            results['build_ok'] = False
        elif results['impl_ok']:
            if results['passed_timing']:
                results['build_result_message'] = "OK. Passed timing."
            else:
                results['build_result_message'] = "FAILED timing."
                # If timing_failure_is_build_failure is set, then consider this a build failure.
                results['build_ok'] = not config_tfibf
        # The remaining else's only get checked if implementation failed.
        elif results['multi_driven_nets'] > 0:
            results['build_result_message'
                    ] = "FAILED synthesis: %d multi-driven nets." % results['multi_driven_nets']
            results['synth_ok'] = False
            results['build_ok'] = False
        else:
            results['build_result_message'
                    ] = "FAILED implementation. (%s)" % results['impl_status_message']
            results['build_ok'] = False

        return results

    def _execute_finish(
            self,
            err_msg: str,
            build_id: BuildId,
            work_dir: Path,
            project_config: dict,
            **kwargs
    ):
        """
        This is a helper function for execute(). It is called to perform tasks
        that should happen at the end of execute() regardless of whether or not
        there was an error.

        Args:
            err_msg: If non-empty, should be the contents of a cuaght Exception error message.
                This will cause the build to be recoded as a failure, and if it wasn't
                a failure for some other reason, then this will be the error message.
            build_id: As for execute().
            work_dir: As for execute().
            project_config: As for execute().
            kwargs: As for execute().

        Raises:
            RuntimeError: if parsing log files indicates that the build failed
                for any reason.
        """

        logger = get_build_type_logger(__name__, build_id.build_type)
        build_id_str = str(build_id)

        synth_strategy, impl_strategy = self._get_strategies(
                build_id.build_type,
                project_config,
                kwargs.get('override_synth_strategy', ""),
                kwargs.get('override_impl_strategy', ""))
        override_tfibf = kwargs.get('override_tfibf', None)  # type: Optional[bool]

        # Parse build results.
        results = {
                'build_id': build_id_str,
                'synth_strategy': synth_strategy,
                'impl_strategy': impl_strategy,
        }  # type: Dict[str, Any]

        succeeded = False
        results.update(self.parse_results(build_id, work_dir, project_config, override_tfibf))

        if results.get("impl_ok", False):
            logger.info(
                    "%s%s timing%s: WNS = %s, WHS = %s, WPWS = %s",
                    colorama.Fore.GREEN + colorama.Style.BRIGHT \
                            if results.get("passed_timing") \
                            else colorama.Fore.RED + colorama.Style.BRIGHT,
                    "Passed" if results.get("passed_timing") else "Failed",
                    colorama.Style.RESET_ALL,
                    results.get("wns") or "",
                    results.get("whs") or "",
                    results.get("wpws") or "",
            )

        if results['build_ok'] and err_msg:
            logger.debug(
                    "build_ok is true, but Python error message passed in. Setting build_ok"
                    " to False. Error message: %s",
                    err_msg
            )
            results['build_ok'] = False
            result_msg = results.get('build_result_message') or ""
            if result_msg.startswith("FAILED"):
                result_msg += "\n" + err_msg
            else:
                result_msg = "FAILED: " + err_msg
            results['build_result_message'] = result_msg
        succeeded = results['build_ok']

        # Store build results.
        with self._cfg.db_engine.connect() as conn:
            with conn.begin():
                cmd = table_insert_or_update_statement(
                        conn,
                        db_def.vivado_table,
                        db_def.vivado_table.c.build_id,
                        build_id_str
                ).values(**filter_table_columns(results,
                                                db_def.vivado_table))
                conn.execute(cmd)

        if not succeeded:
            raise RuntimeError(
                    "Vivado build of '%s' failed: %s" %
                    (build_id.build_type,
                     results['build_result_message'])
            )

    def execute(
            self,
            build_id: BuildId,
            work_dir: Path,
            project_config: Optional[dict] = None,
            **kwargs
    ):
        """
        Build an FPGA bitstream with Xilinx Vivado. If the design contains processors (e.g.
        a Zynq system or Microblaze IP), then this will also generate a hardware handoff file.

        Args:
            build_id: This must be a complete BuildId.
            work_dir: The working directory in which the build will take place. Source code
                must already have been exported and configured here by the "source" task.
            project_config: The project configuration file loaded and parsed from the
                source directory by the source task. Required - must not be left as None.
            kwargs: This task understands the following arguments:
                override_synth_strategy (str) - if not blank, then the synthesis strategy
                    will be overridden with this value.
                override_impl_strategy (str) - if not blank, then the implementation strategy
                    will be overridden with this value.
                override_tfibf (Optional[bool]): If not None, then override the config file
                    setting tool-config/vivado/timing_failure_is_build_failure.

        Raises:
            ValueError: if project_config is blank or None.
            RuntimeError: if the Vivado build fails
            Exception: other exceptions from child processes are re-raised
            KeyboardInterrupt: other exceptions from child processes are re-raised
        """
        if not project_config:
            raise ValueError("BUG: VivadoTask.execute() was called with a blank project_config.")

        synth_strategy, impl_strategy = self._get_strategies(
                build_id.build_type,
                project_config,
                kwargs.get('override_synth_strategy', ""),
                kwargs.get('override_impl_strategy', ""))

        err_msg = ""  # If this is not blank, the build is considered to have failed.
        try:
            self._cfg.db_set_build_state(build_id, db_def.BuildStates.STAGE_RUNNING, self.name())
            self.create(build_id, work_dir, project_config)
            self.build(
                    build_id,
                    work_dir,
                    project_config,
                    override_synth_strategy=synth_strategy,
                    override_impl_strategy=impl_strategy
            )
            self.post_build(build_id, work_dir, project_config)

        except (Exception, KeyboardInterrupt) as err:
            err_msg = str(err)
            raise
        finally:
            succeeded = False

            try:
                try:
                    # Parse results and store them in the vivado table.
                    self._execute_finish(err_msg, build_id, work_dir, project_config, **kwargs)
                    succeeded = True
                finally:
                    try:
                        self.copy_artifacts(build_id, work_dir, project_config)
                    except (Exception, KeyboardInterrupt):
                        succeeded = False
                        raise
            finally:
                self._cfg.db_set_build_state(
                        build_id,
                        db_def.BuildStates.STAGE_SUCCEEDED
                        if succeeded else db_def.BuildStates.STAGE_FAILED,
                        self.name()
                )

        # If we get here but !succeeded, raise an exception to the caller
        if not succeeded:
            raise RuntimeError("Vivado build of '%s' failed." % build_id.build_type)
