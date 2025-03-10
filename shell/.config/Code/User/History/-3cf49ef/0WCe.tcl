set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# VNP4 runtime drivers aren't generated automatically
# generating simulation targets for the IP generates the drivers
::kepler::vivado::generate_ip_sim_target vitis_net_p4
