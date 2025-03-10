# Set git constants in git_info.sv.
# If the "git" executable is not in the path, a message will be printed.
source "[file dirname [info script]]/kepler.tcl"

package require kepler::util 1

# Log a CRITICAL WARNING if any of IPs used in synthesis use the Design_Linking license feature
# (unless $skip_design_linking_check == 1).
::kepler::vivado::check_design_linking_ips



# VNP4 runtime drivers aren't generated automatically
# generating simulation targets for the IP generates the drivers
set synth_dir [pwd]
set project_dir ""

if {[regexp {^(.*?kepler\/hdl\/workspace\/.*?)(\/)} $synth_dir match project_dir]} {
    puts "Project directory: $project_dir"
    cd $project_dir
} else {
    error "Expected working directory to be of the form kepler/hdl/workspace/<proejct_dir> but it is $synth_dir"
}
# cd ../../
::kepler::vivado::generate_ip_sim_target vitis_net_p4
cd $synth_dir
