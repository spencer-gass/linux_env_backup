# Set git constants in git_info.sv.
# If the "git" executable is not in the path, a message will be printed.
source "[file dirname [info script]]/kepler.tcl"

package require kepler::util 1

# Log a CRITICAL WARNING if any of IPs used in synthesis use the Design_Linking license feature
# (unless $skip_design_linking_check == 1).
::kepler::vivado::check_design_linking_ips
