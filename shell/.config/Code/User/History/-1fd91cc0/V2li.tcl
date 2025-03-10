# Utility scripts for our working IP cores.

package require Vivado 1.2017

package require fileutil
package require huddle
package require sha256
package require yaml

package require kepler::util
package require kepler::vivado

namespace eval ::kepler::vivado {}
namespace eval ::kepler::vivado::ips {}
namespace eval ::kepler::vivado::ips::helpers {}



proc ::kepler::vivado::ips::get_ips_no_bds {args} {
    # Equivalent to "get_ips -exclude_bd_ips {*}$args". Vivado 2017 doesn't have the
    # -exclue_bd_ips options, so we need to fake it.
    #
    # Arguments:
    # args - passed to get_ips

    set all_ips {}
    set vivado_ver_maj [lindex [split [::version -short] .] 0]
    foreach ip [::get_ips {*}$args] {
        if {[::get_property SCOPE $ip] == ""} {
            lappend all_ips $ip
        }
    }
    return $all_ips
}


proc ::kepler::vivado::ips::detect_existing_ip_info_file {ip_name {default_location common} {default_version generic} {file_type ip_info}} {
    # If the IP core or block design 'ip_name' has already been exported to a file,
    # then return the type of .ip_info or .bd.tcl file it has been exported to.
    #
    # ip_name - the name of the IP core or block design to look up.
    # default_location - must be "common" or "board". If "board", return "-board-specific" for new files
    #   that don't already exist.
    # default_version - must be "generic" or "specific". If "specific", return "-version-specific" for new
    #   files that don't already exist.
    # file_type - must be "ip_info" or "bd.tcl".
    #
    # Returns: a list of at least three values. The first entry is "1" if the file is found (even if
    #   only for a different Vivado version), "0" if not.
    #   The second is the path to the ip_file if it exists, else what the name of the file would be if
    #   we generated it.
    #   The values in the list from the third entry to the end are arguments that could be passed to
    #   export_ip_info: $ip_name followed optionally by "-board-specific" and/or "-version-specific".

    # Validate arguments
    if {[lsearch "common board" $default_location] < 0} {
        error "'default_location' must be 'common' or 'board', not '$default_location'."
    }
    if {[lsearch "generic specific" $default_version] < 0} {
        error "'default_version' must be 'generic' or 'specific', not '$default_version'."
    }
    if {[lsearch "ip_info bd.tcl" $file_type] < 0} {
        error "'file_type' must be 'bd.tcl' or 'ip_info', not '$file_type'."
    }

    # Board name
    set proj [::current_project]
    # IP path
    set ipsrcs_dir [file normalize "[::get_property DIRECTORY $proj]/../../ipsrcs/tcl-managed"]
    # Vivado major version
    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]

    set filename [glob -nocomplain [file join $ipsrcs_dir common "$ip_name.generic.$file_type"]]
    if {$filename != ""} {
        return "1 $filename $ip_name"
    }

    # Match any version of Vivado, but update the filename to be the current version before returning
    set filenames [glob -nocomplain [file join $ipsrcs_dir common "$ip_name.Vivado.*.$file_type"]]
    if {$filenames != ""} {
        set new_filename [file join $ipsrcs_dir common "$ip_name.Vivado.$vivado_ver.$file_type"]
        return "1 $new_filename $ip_name -version-specific"
    }

    set filename [glob -nocomplain [file join $ipsrcs_dir $proj "$ip_name.generic.$file_type"]]
    if {$filename != ""} {
        return "1 $filename $ip_name -board-specific"
    }

    # Match any version of Vivado, but update the filename to be the current version before returning
    set filenames [glob -nocomplain [file join $ipsrcs_dir $proj "$ip_name.Vivado.*.$file_type"]]
    if {$filenames != ""} {
        set new_filename [file join $ipsrcs_dir $proj "$ip_name.Vivado.$vivado_ver.$file_type"]
        return "1 $new_filename $ip_name -board-specific -version-specific"
    }

    # If we get here, no such file was found.
    if {$default_location == "common"} {
        set filename [file join $ipsrcs_dir "common" $ip_name]
    } else {
        set filename [file join $ipsrcs_dir $proj $ip_name]
    }
    if {$default_version == "generic"} {
        set filename "$filename.generic.$file_type"
    } else {
        set filename "$filename.Vivado.$vivado_ver.$file_type"
    }

    set result "0"
    lappend result $filename $ip_name
    if {$default_location == "board"} {
        lappend result "-board-specific"
    }
    if {$default_version == "specific"} {
        lappend result "-version-specific"
    }
    return $result
}


proc ::kepler::vivado::ips::helpers::get_ip_hash_location {ip_info_filepath} {
    # Write a sha256 hash file for the given .ip_info or .bd.tcl file, for the part number of the current project.
    # This function is not intended to be called directly. It is a helper function for write_ip_hash_for.
    #
    # ip_info_filepath - the .ip_info or .bd.tcl file for which we are creating a hash.
    #
    # Returns: the location of the hash file for the specified .ip_info or .bd.tcl file and current part number.
    #
    # This function assumes ip_info_filepath is a path that adheres to our expected directory structure.
    # It uses parts of the filename and path structure to determine where to write the hash file

    set ext [file extension $ip_info_filepath]
    if {$ext == ".ip_info"} {
        # ok
    } elseif {$ext == ".tcl"} {
        set tmp [file rootname $ip_info_filepath]
        set extext "[file extension $tmp]$ext"
        if {$extext != ".bd.tcl"} {
            error "The filename must end in '.ip_info' or '.bd.tcl', not '$ext'."
        }
    } else {
        error "The filename must end in '.ip_info' or '.bd.tcl', not '$ext'."
    }

    # Board name
    set proj [::current_project]
    # IP path
    set ipsrcs_dir [file normalize "[::get_property DIRECTORY $proj]/../../ipsrcs/tcl-managed"]
    # Vivado major version (e.g. 2021.2)
    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]
    # Current part
    set current_part [::get_property PART $proj]
    set part_short [::kepler::vivado::get_part_shortname $current_part]

    set dir_parts [file split [file normalize $ip_info_filepath]]
    set filename [lindex $dir_parts end]
    set filename_parts [split $filename .]
    set ip_name [lindex $filename_parts 0]
    if {$ext == ".ip_info"} {
        set offset 1
    } else {
        # .bd.tcl has an extra "."
        set offset 2
    }
    set want_common [expr {[lindex $dir_parts end-$offset] == "common"}]
    set want_generic [expr {[lindex $filename_parts end-$offset] == "generic"}]

    if {$want_common} {
        set hash_filepath [file join $ipsrcs_dir common $part_short]
    } else {
        set hash_filepath [file join $ipsrcs_dir $proj $part_short]
    }
    if {$want_generic} {
        set hash_filepath [file join $hash_filepath "$ip_name.generic$ext.sha256"]
    } else {
        set hash_filepath [file join $hash_filepath "$ip_name.Vivado.$vivado_ver$ext.sha256"]
    }

    return $hash_filepath
}


proc ::kepler::vivado::ips::helpers::write_ip_hash_for {ip_info_filepath} {
    # Write a sha256 hash file for the given .ip_info or .bd.tcl file, for the part number of the current project.
    # This function is not intended to be called directly. It is a helper function for export_ip_info
    # and import_ip_info.
    #
    # ip_info_filepath - the .ip_info or .bd.tcl file for which we are creating a hash.
    #
    # Returns: the path to the hash file that is written.
    #
    # This function assumes ip_info_filepath is a path that adheres to our expected directory structure.
    # It uses parts of the filename and path structure to determine where to write the hash file

    set hash_filepath [get_ip_hash_location $ip_info_filepath]
    set hash_dir [file dirname $hash_filepath]
    file mkdir $hash_dir

    puts "Writing hash file to $hash_filepath"
    set f [open $hash_filepath w]
    puts $f "[::sha2::sha256 -hex -filename $ip_info_filepath]  [fileutil::relative $hash_dir $ip_info_filepath]"
    close $f
    return $hash_filepath
}


proc ::kepler::vivado::ips::helpers::check_ip_hash_for {ip_info_filepath} {
    # Check to see whether or not the sha256 has file for the given .ip_info or .bd.tcl is up to date for the
    # part number of the current project.  This function is not intended to be called directly. It is a helper
    # function for import_ip_info.
    #
    # ip_info_filepath - the .ip_info or .bd.tcl file for which we are creating a hash.
    #
    # Returns: 1 if the hash file exists and is up to date; 0 otherwise.
    #
    # This function assumes ip_info_filepath is a path that adheres to our expected directory structure.
    # It uses parts of the filename and path structure to determine where to write the hash file

    set hash_filepath [get_ip_hash_location $ip_info_filepath]
    if {[file exists $hash_filepath]} {
        # A hash file exists. Is it up to date?
        set f [open $hash_filepath r]
        set expected_hash [lindex [gets $f] 0]
        set actual_hash [::sha2::sha256 -hex -filename $ip_info_filepath]
        if {$expected_hash == $actual_hash} {
            return 1
        }
    }

    # If we get here, either the file didn't exist or the hash didn't match.
    return 0
}


proc ::kepler::vivado::ips::export_ip_info {ip_name args} {
    # Export an IP core to a .ip_info file. This can be read back in with import_ip_info.
    #
    # ip_name - the name of the IP core to export. Must already be in the project.
    # args - documented below
    # -board-specific - instead of writing to "ipsrcs/tcl-managed/common", write to
    #       "ipsrcs/tcl-managed/[::current_project]".
    # -version-specific - export this IP core to a file specific to this Vivado version.
    #       The default is to write a version-less file. If there are major
    #       IP core upgrades between Vivado versions, the core settings from one version
    #       may not work with a newer/older one.
    #
    # Note: you should not have multiple different kinds of ip_info file saved. For example,
    # if you create a version in "common", then you should not also have board-specific versions.
    # If you create a vivado-specific version, then you should not also have a generic version.
    # You can call detect_existing_ip_info_file to determine if an existing file exists,
    # and if so, what kind.

    set proj [::current_project]
    set proj_dir "[::get_property DIRECTORY $proj]"

    # Parse arguments.
    set want_common 1
    set want_generic 1
    while {[llength $args] > 0} {
        set arg [::kepler::util::lpop args]
        switch -- $arg {
            -board-specific {
                set want_common 0
            }
            -version-specific {
                set want_generic 0
            }
            default {
                error "Unknown argument '$arg' to ::kepler::vivado::ips::export_ip_info."
            }
        }
    }


    # Determine the correct filename, and also figure out if this IP core has already been written
    # to an .ip_info file. It is an error if the user is trying to switch between common/board-specifc
    # or generic/version-specific.
    set detect_args "$ip_name"
    if {$want_common} {
        lappend detect_args "common"
    } else {
        lappend detect_args "board"
    }
    if {$want_generic} {
        lappend detect_args "generic"
    } else {
        lappend detect_args "specific"
    }
    set existing_ip_info [detect_existing_ip_info_file {*}$detect_args]
    set already_exists [lindex $existing_ip_info 0]
    set filepath [lindex $existing_ip_info 1]
    set existing_args [lrange $existing_ip_info 2 end]
    if {$already_exists} {
        set existing_common 1
        set existing_generic 1
        if {[lsearch $existing_args "-board-specific"] >= 0} {
            set existing_common 0
        }
        if {[lsearch $existing_args "-version-specific"] >= 0} {
            set existing_generic 0
        }

        # If the file already exists, options must be the same.
        if {($want_common != $existing_common) || ($want_generic != $existing_generic)} {
            error "You are attempting to save IP core '$ip_name' to a .ip_info file of a different type\
                than an already existing .ip_info file for the same IP core. You cannot save both\
                'common' and board-specific, or 'generic' and version-specific versions of the same\
                IP core. Specify parameters -board-specific and/or -version-specific as appropriate."
        }
    }


    # Retrieve the IP info.
    set ip [get_ips_no_bds $ip_name]
    set ip_info [::huddle create]
    set ipdef [::get_property IPDEF $ip]
    if {$want_generic} {
        # Strip the version info
        set ipdef [join [lrange [split $ipdef :] 0 2] :]
    }
    ::huddle set ip_info ipdef $ipdef

    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]
    if {!$want_generic} {
        # Store the Vivado version.
        ::huddle set ip_info vivado $vivado_ver
    }

    ::huddle set ip_info config [::huddle create]
    foreach key [::list_property $ip CONFIG.*] {
        # huddle2yaml doesn't write empty strings correctly, causing problems on input.
        set value [string trim [::get_property $key $ip]]
        if {$value == ""} {
            ::huddle set ip_info config $key {""}
        } else {
            ::huddle set ip_info config $key "$value"
        }
    }

    # Verify that the path to a p4 file is relative if it exists
    set p4_path_property "CONFIG.P4_FILE"
    if {([lrange [split $ipdef :] 0 2] == {xilinx.com ip vitis_net_p4}) && [::list_property $ip $p4_path_property] == $p4_path_property} {
        set p4_path [string trim [::get_property $p4_path_property $ip]]
        if {[file pathtype $p4_path] != "relative"} {
            puts "Warning: p4 file path is absolute but needs to be relative."
            if {[lsearch [file split $p4_path] "p4"] == -1} {
                error "p4 file path does not include kepler/p4 directory"
            }
            set new_path [fileutil::relative $wsDir $p4_path]
            puts "Warning: Changing p4 path from $p4_path to $new_path"
            ::set_property $p4_path_property "$new_path" $ip
            ::huddle set ip_info config $p4_path_property "$new_path"
        }
    }

    # Note: This stores all properties, even read-only ones. This causes warnings when we
    # re-import the IP core using this information. Ideally, we should exclude read-only
    # properties. But I don't know how to tel whether or not a property is read-only except for
    # parsing the table output of `report_property`.

    # Memory generators have additional files we need to store.
    if {[::list_property -quiet $ip CONFIG.XML_INPUT_FILE] != ""} {
        set xml_input_file [::get_property CONFIG.XML_INPUT_FILE $ip]
        set xml_input_path [file join [::get_property IP_DIR $ip] $xml_input_file]
        set f [open $xml_input_path r]
        set xml_input_data "[read $f]"
        close $f
        ::huddle set ip_info xml_input_data [::huddle create]
        ::huddle set ip_info xml_input_data $xml_input_file $xml_input_data
    }

    # Update the Vivado version number in the filename if necessary
    # Vivado major version (e.g. 2021.2)
    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]
    set dir [file dirname $filepath]
    set filepath_updated [file join $dir "$ip_name.Vivado.$vivado_ver.ip_info"]
    if {$filepath_updated != $filepath} {
        puts "Filepath was '$filepath', updated to '$filepath_updated'"
    }

    # Save the file.
    set f [open $filepath_updated w]
    puts $f [::yaml::huddle2yaml $ip_info]
    close $f
    puts "Wrote '$filepath_updated'."

    helpers::write_ip_hash_for $filepath_updated
    return ""
}


proc ::kepler::vivado::ips::import_ip_info {ip_info_filepath args} {
    # Import an IP core from a .ip_info file. If the core already exists in the project,
    # it will be deleted and re-created. If the IP core is not compatible with the
    # chip used for the current project, then the core will not be loaded.
    #
    # ip_info_filepath - the .ip_info file to import.
    # args - documented below
    # -force - re-import even if the hash file is already current.

    set ip_info_filepath [file normalize $ip_info_filepath]
    set proj [::current_project]
    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]
    set ip_name [lindex [split [file tail $ip_info_filepath] .] 0]
    set current_part [::get_property PART $proj]
    set current_family [::get_property FAMILY $current_part]

    set import_needed 0
    while {[llength $args] > 0} {
        set arg [::kepler::util::lpop args]
        switch -- $arg {
            -force {
                set import_needed 1
            }
            "" {
                # Ignore blank arguments. (This simplifies import_all_ip_infos.)
            }
            default {
                error "Unknown argument '$arg' to ::kepler::vivado::ips::import_ip_info."
            }
        }
    }

    if {[get_ips_no_bds -quiet $ip_name] == ""} {
        set import_needed 1
    }
    if {!$import_needed} {
        # If we're not forcing an import, check the file hash.
        set import_needed [expr {![helpers::check_ip_hash_for $ip_info_filepath]}]
    }

    if {!$import_needed} {
        puts "Skipping IP core '$ip_name' because it is already up to date."
        return
    }


    set f [open $ip_info_filepath r]
    set ip_info [::yaml::yaml2huddle -types {} [read $f]]
    close $f

    # Check to see if this IP core is compatible with the current chip.
    set ipdef_name [::huddle strip [::huddle get $ip_info ipdef]]
    # We want to look up the name in the catalog. Note that some IP names are prefixes
    # of others. Therefore, we can't just add "*" after the IP name. We can do that
    # if a version is also provided. If no version is provided, we should instead add ":*".
    set ipdef_name_pieces [split $ipdef_name :]
    if {[llength $ipdef_name_pieces] <= 3} {
        set ipdef_name_search "${ipdef_name}:*"
    } else {
        set ipdef_name_search "${ipdef_name}*"
    }
    set ipdefs [get_ipdef $ipdef_name_search]
    if {[llength $ipdefs] == 0} {
        error "IP core '$ipdef_name' is not in the current IP catalog."
    }
    set compatible 0

    foreach ipdef $ipdefs {
        foreach family [::get_property SUPPORTED_FAMILIES $ipdef] {
            # Example of family: zynquplus:ALL:Production
            if {$current_family == [lindex [split $family :] 0]} {
                set compatible 1
            }
        }
    }

    # RFSoC
    # Hard-code for RFSoC parts because Xilinx places RFSoC IP compatibility under the zynquplus family
    # Example:
    # [::get_property SUPPORTED_FAMILIES $ipdef] returns a list similar to either
    # zynquplus:xczu39dr-ffvf1760-2-i:Production:xczu39dr-ffvf1760-2LVI-i:Production:xczu39dr-fsvf1760-2-i...
    # or zynquplus:ALL:Production
    # Pattern follows colon-separated list of family, and then pairs of part number, and production status.
    # zynquplusRFSOC is a superset of zynquplus, so the family name match check done in the code above won't work
    # but the part number e.g. xczu39dr-ffvf1760-2-i is still under the parent family, i.e. zynquplus.
    # So we search for either a part number match or if "ALL" parts are supported.
    if {!$compatible && $current_family == "zynquplusRFSOC"} {
        foreach ipdef $ipdefs {
            foreach family [::get_property SUPPORTED_FAMILIES $ipdef] {
                if {[lindex [split $family :] 0] == "zynquplus"} {
                    if {[lindex [split $family :] 1] == "ALL" || [lsearch -exact [split $family :] $current_part] >= 0} {
                        set compatible 1
                    }
                }
            }
        }
    }

    if {!$compatible} {
        puts "Skipping IP core '$ip_name' because it is not compatible with part $current_part."
        return
    }

    if {[lsearch [::huddle keys $ip_info] vivado] >= 0} {
        set expected_vivado_ver [::huddle strip [::huddle get $ip_info vivado]]
        if { ($expected_vivado_ver != "") && ($expected_vivado_ver != $vivado_ver) } {
            error "$filename was created with Vivado $expected_vivado_ver but you are using Vivado $vivado_ver."
        }
    }

    puts "Importing '$ip_name'."


    # If the IP core already exists in the project, remove it.
    set existing_ip [get_ips_no_bds -quiet $ip_name]
    if {$existing_ip != ""} {
        puts "Deleting existing core '$ip_name' and its files on disk."
        # This may or may not be a container IP.
        set ip_container [::get_property IP_CORE_CONTAINER $existing_ip]
        set ip_dir [::get_property IP_DIR $existing_ip]
        set ip_file [::get_property IP_FILE $existing_ip]

        # Remove the IP core from the project.
        ::remove_files [::get_property IP_FILE $existing_ip]

        # Delete the IP core files from disk.
        if {[file exists $ip_container]} {
            file delete -force $ip_container
        }
        if {[file exists $ip_dir]} {
            file delete -force $ip_dir
        }
        if {[file exists $ip_file]} {
            file delete -force $ip_file
        }
    }

    set part_ip_dir [file dirname [helpers::get_ip_hash_location $ip_info_filepath]]
    file mkdir $part_ip_dir

    # ipdef example: xilinx.com:ip:ila:6.2
    set pieces [split $ipdef_name :]
    if {[llength $pieces] < 3} {
        error "Error parsing ipdef from $filename."
    }
    set cmdstring "::create_ip -vendor [lindex $pieces 0] -library [lindex $pieces 1] -name [lindex $pieces 2]"
    if {[llength $pieces] >= 4} {
        set cmdstring "$cmdstring -version [lindex $pieces 3]"
    }
    set cmdstring "$cmdstring -module_name $ip_name -dir $part_ip_dir"
    # Note: without a -dir argument, this will create the IP core in the project workspace directory,
    # usually under "./[::current_project].ip_user_files/ip/".
    eval $cmdstring
    set ip [get_ips_no_bds $ip_name]

    # Before configuring the core, write out any xml input files.
    if {[lsearch [::huddle keys $ip_info] xml_input_data ] >= 0} {
        set ip_dir [::get_property IP_DIR $ip]
        file mkdir $ip_dir
        foreach xml_input_file [::huddle keys [::huddle get $ip_info xml_input_data]] {
            set f [open [file join $ip_dir $xml_input_file] w]
            puts $f [::huddle strip [::huddle get $ip_info xml_input_data $xml_input_file]]
            close $f
        }
    }

    # Configure the core.
    # Retrieve the config key from the huddle and convert it to a normal dict.
    # Pass that to set_property.

    # We should just be able to do:
    #   ::set_property -dict[::huddle strip [::huddle get $ip_info config]] $ip
    # but that fails.
    # The process of going through yaml and huddle seems to add whitespace to some values,
    # which causes failures for some IP core imports. For example, the GTH transceiver IP
    # complains that the value of RX_CC_VAL does not consist solely of 0's and 1's because it ends up
    # with a space at the end.
    set config_dict [dict create]
    foreach key [::huddle keys [::huddle get $ip_info config]] {
        dict set config_dict $key [string trim [::huddle strip [::huddle get $ip_info config $key]]]
    }
    ::set_property -dict $config_dict $ip
    # Note: You'll get a warning, because export_ip_info includes read-only properties which we can't set.
    # See export_ip_info, above.

    # We just imported the IP core, so update the hash.
    helpers::write_ip_hash_for $ip_info_filepath
    return ""
}


proc ::kepler::vivado::ips::export_all_ip_infos {{new_location board} {new_version generic}} {
    # Save all IP cores as .ip_info files.
    # For any core that has already been saved, the same file type will be used.
    # If new cores exist that have not yet been saved, the file location (common/board-specific)
    # and type (generic/version-specific) will be based on the arguments.
    #
    # new_location - must be either "common" or "board". Will be applied to new IP cores
    #   that have not yet been saved.
    # new_version - must be either "generic" or "specific". Will be applied to new IP cores
    #   that have not yet been saved.

    # Validate arguments
    if {[lsearch "common board" $new_location] < 0} {
        error "'new_location' must be 'common' or 'board', not '$new_location'."
    }
    if {[lsearch "generic specific" $new_version] < 0} {
        error "'new_version' must be 'generic' or 'specific', not '$new_version'."
    }


    foreach ip [get_ips_no_bds] {
        set existing_info [detect_existing_ip_info_file $ip $new_location $new_version]
        set export_args [lrange $existing_info 2 end]
        export_ip_info {*}$export_args
    }
}


proc ::kepler::vivado::ips::import_all_ip_infos {args} {
    # Import IP all .ip_info files.
    #
    # args - documented below.
    # -force - re-import IP cores even if they already seem to be up to date

    set force_arg ""
    while {[llength $args] > 0} {
        set arg [::kepler::util::lpop args]
        switch -- $arg {
            -force {
                set force_arg "-force"
            }
            default {
                error "Unknown argument '$arg' to ::kepler::vivado::ips::import_all_ip_infos."
            }
        }
    }

    set proj [::current_project]
    # IP path
    set ipsrcs_dir [file normalize "[::get_property DIRECTORY $proj]/../../ipsrcs/tcl-managed"]
    # Vivado major version
    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]

    set ip_files [glob -nocomplain [file join $ipsrcs_dir common "*.generic.ip_info"]]
    set ip_files [concat $ip_files [glob -nocomplain [file join $ipsrcs_dir common "*.Vivado.$vivado_ver.ip_info"]]]
    set ip_files [concat $ip_files [glob -nocomplain [file join $ipsrcs_dir $proj "*.generic.ip_info"]]]
    set ip_files [concat $ip_files [glob -nocomplain [file join $ipsrcs_dir $proj "*.Vivado.$vivado_ver.ip_info"]]]
    foreach ip_file $ip_files {
        import_ip_info $ip_file $force_arg
    }
}


proc ::kepler::vivado::ips::reset_all_output_products {} {
    # Reset the output products of all IP cores in the current project.

    foreach ip [get_ips_no_bds] {
        ::reset_target all [::get_files [::get_property IP_FILE $ip]]
    }
}


proc ::kepler::vivado::ips::get_bd_files {} {
    # Return a list of the paths to all user-created block design files (*.bd) in the current project.

    set bd_files ""
    foreach bd_file [::get_files -quiet {*.bd}] {
        if {[::get_property IS_GENERATED $bd_file]} {
            continue
        }

        lappend bd_files $bd_file
    }
    return $bd_files
}


proc ::kepler::vivado::ips::get_bds {} {
    # Return a list of the names of all user-created block designs in the current project.
    #
    # Note: there does not seem to be a way to get the name of a block design without first
    # opening the *.bd file (after which you can run [current_bd_design]). This proc assumes
    # that design names match their filenames.

    set bds ""
    foreach bd_file [get_bd_files] {
        set bd_name [file rootname [file tail $bd_file]]
        lappend bds $bd_name
    }

    return $bds
}


proc ::kepler::vivado::ips::export_bd_tcl {bd_name args} {
    # Export a block design to a .bd.tcl file. This can be read back in with import_bd.tcl.
    #
    # bd_name - the name of the IP core to export. Must already be in the project.
    # args - documented below
    # -board-specific - instead of writing to "ipsrcs/tcl-managed/common", write to
    #       "ipsrcs/tcl-managed/[::current_project]".
    # -version-specific - export this IP core to a file specific to this Vivado version.
    #       The default is to write a version-less file. If there are major
    #       IP core upgrades between Vivado versions, the core settings from one version
    #       may not work with a newer/older one.
    #
    # Note: you should not have multiple different kinds of bd.tcl file saved. For example,
    # if you create a version in "common", then you should not also have board-specific versions.
    # If you create a vivado-specific version, then you should not also have a generic version.
    # You can call detect_existing_ip_info_file to determine if an existing file exists,
    # and if so, what kind.

    # Parse arguments.
    set want_common 1
    set want_generic 1
    while {[llength $args] > 0} {
        set arg [::kepler::util::lpop args]
        switch -- $arg {
            -board-specific {
                set want_common 0
            }
            -version-specific {
                set want_generic 0
            }
            default {
                error "Unknown argument '$arg' to ::kepler::vivado::ips::export_bd_tcl."
            }
        }
    }

    # Determine the correct filename, and also figure out if this BD has already been written
    # to a .bd_info file. It is an error if the user is trying to switch between common/board-specifc
    # or generic/version-specific.
    set detect_args "$bd_name"
    if {$want_common} {
        lappend detect_args "common"
    } else {
        lappend detect_args "board"
    }
    if {$want_generic} {
        lappend detect_args "generic"
    } else {
        lappend detect_args "specific"
    }
    lappend detect_args "bd.tcl"
    set existing_bd_info [detect_existing_ip_info_file {*}$detect_args]
    set already_exists [lindex $existing_bd_info 0]
    set filepath [lindex $existing_bd_info 1]
    set existing_args [lrange $existing_bd_info 2 end]
    if {$already_exists} {
        set existing_common 1
        set existing_generic 1
        if {[lsearch $existing_args "-board-specific"] >= 0} {
            set existing_common 0
        }
        if {[lsearch $existing_args "-version-specific"] >= 0} {
            set existing_generic 0
        }

        # If the file already exists, options must be the same.
        if {($want_common != $existing_common) || ($want_generic != $existing_generic)} {
            error "You are attempting to save block design '$bd_name' to a .bd.tcl file of a different type\
                than an already existing .bd.tcl file for the same IP core. You cannot save both\
                'common' and board-specific, or 'generic' and version-specific versions of the same\
                IP core. Specify parameters -board-specific and/or -version-specific as appropriate."
        }
    }

    set proj [::current_project]
    set ipsrcs_dir [file normalize "[::get_property DIRECTORY $proj]/../../ipsrcs/tcl-managed"]

    # Get the path to the .bd file.
    set bd_filepath ""
    foreach bd_file [get_bd_files] {
        if {[regexp "/$bd_name.bd$" $bd_file]} {
            set bd_filepath $bd_file
            break
        }
    }
    if {$bd_filepath == ""} {
        error "Could not find a block design file matching '$bd_name.bd'."
    }

    # The write_bd_tcl command can only export the currently-opened block design. If it's already open,
    # close it first, to ensure that any changes on-disk are reflected in the open design. One example
    # where this applies is that different versions of Vivado may rename the block diagram address segments,
    # which we access using ::get_bd_addr_segs in fixup_bd_tcl below.
    ::close_bd_design -quiet $bd_name
    ::open_bd_design $bd_filepath

    # There doesn't seem to be a way to determine the name of the block design without opening it.
    # Now that we have, verify that the name matches what we expect.
    set actual_bd_name [::current_bd_design]
    if {$actual_bd_name != $bd_name} {
        error "Opened '$bd_filepath', but the design is named '$actual_bd_name' instead of '$bd_name'."
    }

    # We set bd_folder to "." so that we can create this anywhere we want later.
    set write_args "-force -bd_folder ."
    if {$want_generic} {
        lappend write_args -no_ip_version
    } else {
        lappend write_args -ignore_minor_versions
    }

    # Update the Vivado version number in the filename if necessary
    # Vivado major version (e.g. 2021.2)
    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]
    set dir [file dirname $filepath]
    set filepath_updated [file join $dir "$bd_name.Vivado.$vivado_ver.bd"]
    if {"$filepath_updated.tcl" != $filepath} {
        puts "Filepath was '$filepath', updated to '$filepath_updated.tcl'"
    }

    # The ::write_bd_tcl script fails to export USAGE properties of address segments.
    # We need to patch that into the script.
    ::write_bd_tcl {*}$write_args $filepath_updated.tmp.tcl
    helpers::fixup_bd_tcl $filepath_updated
    puts "Wrote '$filepath_updated'."
    ::close_bd_design [::current_bd_design]

    helpers::write_ip_hash_for $filepath_updated.tcl
    return ""
}

proc ::kepler::vivado::ips::helpers::fixup_bd_tcl {filepath} {
    # The ::write_bd_tcl fails to export USAGE properties of address segments.
    # This proc opens $filepath.tmp.tcl and copies it line by line to $filepath,
    # inserting set_property commands to set USAGE properties for address segments
    # based on the currently-open BD design.
    #
    # filepath - the full path to the final Tcl script. An existing file called $filepath.tmp.tcl
    #   must already exist, there must be a currently-open block design, and $filepath.tmp.tcl
    #   must match that currently-open design.
    #
    # $filepath.tmp.tcl will be deleted when this proc is complete.
    # We use .tmp.tcl instead of just .tmp, because ::write_bd_tcl automatically appends ".tcl"
    # if the filename does not already end in that.

    puts "Patching exported block diagram script $filepath.tmp.tcl."
    set fin [open $filepath.tmp.tcl r]
    set fout [open $filepath.tcl w]
    set found_insert_location 0
    set done_insertions 0
    while {[gets $fin line] >= 0} {
        if {! $found_insert_location} {
            if {[string trim $line] == "# Restore current instance"} {
                # Insert here
                set found_insert_location 1

                puts $fout "  # Set usages for address segments"
                foreach seg [::get_bd_addr_segs] {
                    set seg_usage [::get_property USAGE $seg]
                    puts $fout "  if \{\[catch \{set_property USAGE memory \[get_bd_addr_segs $seg\]\}\]\} \{"
                    puts $fout "    puts \"WARNING: error setting USAGE for $seg\""
                    puts $fout "  \}"
                }
                puts $fout "\n\n"
            }

            puts $fout "$line"
        } else {
            # Insertion is complete. Just copy the lines.
            puts $fout "$line"
        }
    }

    close $fout
    close $fin

    file delete $filepath.tmp.tcl
}


proc ::kepler::vivado::ips::export_all_bd_tcls {{new_location board} {new_version generic}} {
    # Save all block designs as .bd.tcl files.
    # For any core that has already been saved, the same file type will be used.
    # If new cores exist that have not yet been saved, the file location (common/board-specific)
    # and type (generic/version-specific) will be based on the arguments.
    #
    # new_location - must be either "common" or "board". Will be applied to new IP cores
    #   that have not yet been saved.
    # new_version - must be either "generic" or "specific". Will be applied to new IP cores
    #   that have not yet been saved.

    # Validate arguments
    if {[lsearch "common board" $new_location] < 0} {
        error "'new_location' must be 'common' or 'board', not '$new_location'."
    }
    if {[lsearch "generic specific" $new_version] < 0} {
        error "'new_version' must be 'generic' or 'specific', not '$new_version'."
    }


    foreach bd [get_bds] {
        set existing_info [detect_existing_ip_info_file $bd $new_location $new_version bd.tcl]
        set export_args [lrange $existing_info 2 end]
        export_bd_tcl {*}$export_args
    }
}


proc ::kepler::vivado::ips::import_bd_tcl {bd_tcl_filepath args} {
    # Import a block diagram from a .bd.tcl file. If the BD already exists in the project,
    # it will be deleted and re-created
    #
    # bd_tcl_filepath - the .bd.tcl file to import.
    # args - documented below
    # -force - re-import even if the hash file is already current.

    set bd_tcl_filepath [file normalize $bd_tcl_filepath]
    set proj [::current_project]
    set ipsrcs_dir [file normalize "[::get_property DIRECTORY $proj]/../../ipsrcs/tcl-managed"]
    # Assume the block design name is the start of the filename
    set bd_name [lindex [split [file tail $bd_tcl_filepath] .] 0]

    set import_needed 0
    while {[llength $args] > 0} {
        set arg [::kepler::util::lpop args]
        switch -- $arg {
            -force {
                set import_needed 1
            }
            "" {
                # Ignore blank arguments. (This simplifies import_all_bd_tcls.)
            }
            default {
                error "Unknown argument '$arg' to ::kepler::vivado::ips::import_bd_tcl."
            }
        }
    }

    set all_bds [get_bds]
    set already_exists 1
    if {[lsearch $all_bds $bd_name] < 0} {
        set already_exists 0
        set import_needed 1
    }
    if {!$import_needed} {
        # If we're not forcing an import, check the file hash.
        set import_needed [expr {![helpers::check_ip_hash_for $bd_tcl_filepath]}]
    }

    if {!$import_needed} {
        puts "Skipping block design '$bd_name' because it is already up to date."
        return
    }

    # If the block design already exists in the project, remove it.
    if {$already_exists} {
        puts "Deleting existing block design '$bd_name' and its files on disk."

        set all_bd_files [get_bd_files]
        set bd_filepath ""
        foreach bd_file [get_bd_files] {
            set this_bd_name [file rootname [file tail $bd_file]]
            if {$this_bd_name == $bd_name} {
                set bd_filepath [file normalize $bd_file]
                break
            }
        }
        if {$bd_filepath == ""} {
            error "Could not find .bd file for '$bd_name'."
        }

        # We expect the .bd file to reside inside a directory with the same name.
        set bd_parent_dir [file dirname $bd_filepath]
        set bd_parent_dir_name [file tail $bd_parent_dir]
        if {$bd_parent_dir_name != $bd_name} {
            error "Expected '$bd_filepath' to reside in a directory named '$bd_name', but its parent is '$bd_parent_dir_name'."
        }

        # Close any open block design, and remove this design from the project.
        ::close_bd_design -quiet [::current_bd_design -quiet]
        ::remove_files $bd_filepath

        # Now delete that whole directory, first closing any open design.
        file delete -force $bd_parent_dir
    }

    puts "Importing '$bd_name'."
    set cur_dir [pwd]

    set part_bd_dir [file dirname [helpers::get_ip_hash_location $bd_tcl_filepath]]
    file mkdir $part_bd_dir
    cd $part_bd_dir
    source $bd_tcl_filepath
    ::regenerate_bd_layout

    # Work around a Vivado bug: when the design is created from a Tcl file, modules that size their inputs
    # automatically based on the width of connected signals sometimes default to 0:0 and fail to update
    # their length automatically even when validate_bd_design is run, which is when they would normally
    # get updated. The fix for this is to re-set the signal lengths, then re-validate.
    # So far, we've only observed this happening with top-level ports.
    foreach port [get_bd_ports] {
        # Not all ports have defined widths. For the ones that do, get the signal range LEFT:RIGHT
        # and re-apply it.
        set signal_left [::get_property LEFT $port]
        set signal_right [::get_property RIGHT $port]
        if {$signal_left != ""} {
            ::set_property LEFT $signal_left $port
        }
        if {$signal_right != ""} {
            ::set_property RIGHT $signal_right $port
        }
    }
    # Now re-validate the design so that widths get propagated.
    # Ignore errors. (Load the design as is, even if it's invalid; let the user handle fixing it.)
    ::validate_bd_design -quiet

    ::save_bd_design
    ::close_bd_design [::current_bd_design]

    cd $cur_dir


    # We just imported the IP core, so update the hash.
    helpers::write_ip_hash_for $bd_tcl_filepath
    return ""
}


proc ::kepler::vivado::ips::import_all_bd_tcls {args} {
    # Import IP all .bd_tcl files.
    #
    # args - documented below.
    # -force - re-import IP cores even if they already seem to be up to date

    set force_arg ""
    while {[llength $args] > 0} {
        set arg [::kepler::util::lpop args]
        switch -- $arg {
            -force {
                set force_arg "-force"
            }
            default {
                error "Unknown argument '$arg' to ::kepler::vivado::ips::import_all_bd_tcls."
            }
        }
    }

    set proj [::current_project]
    # IP path
    set ipsrcs_dir [file normalize "[::get_property DIRECTORY $proj]/../../ipsrcs/tcl-managed"]
    # Vivado major version
    set vivado_ver [join [lrange [split [::version -short] .] 0 1] .]

    set bd_tcl_files [glob -nocomplain [file join $ipsrcs_dir common "*.generic.bd.tcl"]]
    set bd_tcl_files [concat $bd_tcl_files [glob -nocomplain [file join $ipsrcs_dir common "*.Vivado.$vivado_ver.bd.tcl"]]]
    set bd_tcl_files [concat $bd_tcl_files [glob -nocomplain [file join $ipsrcs_dir $proj "*.generic.bd.tcl"]]]
    set bd_tcl_files [concat $bd_tcl_files [glob -nocomplain [file join $ipsrcs_dir $proj "*.Vivado.$vivado_ver.bd.tcl"]]]
    foreach ip_file $bd_tcl_files {
        import_bd_tcl $ip_file $force_arg
    }
}
