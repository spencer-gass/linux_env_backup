# Set git constants in git_info.sv.
# If the "git" executable is not in the path, a message will be printed.
source "[file dirname [info script]]/kepler.tcl"

package require kepler::util 1

::kepler::util::git_util set_consts
set vivado_version [version -short]
set vivado_version [string range $vivado_version 0 5]
set_property generic VIVADO_VERSION="$vivado_version" [current_fileset]

# VNP4 runtime drivers aren't generated automatically
# generating simulation targets for the IP generates the drivers
::kepler::vivado::generate_ip_sim_target vitis_net_p4
