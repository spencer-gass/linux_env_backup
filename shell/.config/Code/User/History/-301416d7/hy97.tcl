# soc_build: Vivado post-synthesis reporting script
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

# VNP4 runtime drivers aren't generated automatically
# generating simulation targets for the IP generates the drivers
::kepler::vivado::generate_ip_sim_target vitis_net_p4
