# soc_build: Vivado build script

open_project "hdl/vivado/workspace/15eglv_pcuecp/pcuecp.xpr"

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

set soc_build_ip_cores [get_ips]
if {[llength $soc_build_ip_cores] > 0} {
    upgrade_ip -quiet $soc_build_ip_cores
}

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
if {![file exists "${soc_build_proj_dir}/soc_build_include_scripts.txt"]} {
    set soc_build_fp [open "${soc_build_proj_dir}/soc_build_include_scripts.txt" w]
    puts $soc_build_fp "SYNTH_POST \"[dict get $soc_build_synth_hooks STEPS.SYNTH_DESIGN.TCL.POST]\""
    if [get_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED $soc_build_impl_1] {
        puts $soc_build_fp "IMPL_POST \"[dict get $soc_build_impl_hooks STEPS.POST_ROUTE_PHYS_OPT_DESIGN.TCL.POST]\""
    } else {
        puts $soc_build_fp "IMPL_POST \"[dict get $soc_build_impl_hooks STEPS.ROUTE_DESIGN.TCL.POST]\""
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

# ##########
# Synthesis
reset_run synth_1

launch_runs synth_1 -jobs 1

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

# #####
# Done
# Record some key statistics from implementation.
report_property $soc_build_impl_1 -file "${soc_build_proj_dir}/soc_build_impl_status.rpt" -append -regex {.*STATS.ELAPSED.*|.*PROGRESS.*|.*STATUS.*}

# Note: We don't check PROGRESS to tell whether or not implementation failed.
# This doesn't seem to work reliably when using "-to_step write_bitstream".
# Instead, we just end. We'll know if we succeeded, because there will be a bitfile, etc.
close_project
