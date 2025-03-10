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
update_compile_order -force
set ip_list [get_ips]
puts "IPs found: $ip_list"
puts "DBG-SRG: generating vnp4 drivers"
::kepler::vivado::generate_ip_sim_target vitis_net_p4
