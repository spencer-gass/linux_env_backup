# Utility scripts for our working with our SDR projects.

package require kepler::vivado

namespace eval ::kepler::vivado {}
namespace eval ::kepler::vivado::project_add {}
namespace eval ::kepler::vivado::project_add::helpers {}

# Look up full part names given our short form.
variable ::kepler::vivado::PART_SHORT_NAMES [dict create \
    "410t"   "xc7k410tffg676-2" \
    "160t"   "xc7k160tffg676-2" \
    "6cg"    "xczu6cg-ffvb1156-1L-i" \
    "6cglv"  "xczu6cg-ffvb1156-1LV-i" \
    "9cg"    "xczu9cg-ffvb1156-1L-i" \
    "9cglv"  "xczu9cg-ffvb1156-1LV-i" \
    "9eg"    "xczu9eg-ffvb1156-1L-i" \
    "9eglv"  "xczu9eg-ffvb1156-1LV-i" \
    "15eg"   "xczu15eg-ffvb1156-1L-i" \
    "15eglv" "xczu15eg-ffvb1156-1LV-i" \
    "28dr"   "xczu28dr-ffvg1517-2-e" \
    "47dr"   "xczu47dr-ffve1156-1-e" \
    "7ev"    "xczu7ev-ffvc1156-2-e" \
]
# We have dropped support for:
# "325t"  "xc7k325tffg676-2"

# Look up our short names given the full part name.
variable ::kepler::vivado::PART_LONG_NAMES [dict create]
dict for {short_name long_name} $::kepler::vivado::PART_SHORT_NAMES {
    dict set ::kepler::vivado::PART_LONG_NAMES $long_name $short_name
}


# Look up parts supported by each board.
variable ::kepler::vivado::BOARD_PART_SUPPORT [dict create \
    "xk7sdr"              "160t 410t" \
    "pch"                 "6cg 6cglv 9cg 9cglv 9eg 9eglv 15eg 15eglv" \
    "rsmpcu"              "9eglv" \
    "hsd"                 "9eg" \
    "mpcu"                "15eglv" \
    "mpcut1"              "15eglv" \
    "sue"                 "9eglv" \
    "sug"                 "15eglv" \
    "pcuecp"              "15eglv" \
    "pcugse"              "15eglv" \
    "pcuhdr"              "15eglv" \
    "zcu104"              "7ev" \
    "zcu111"              "28dr" \
    "trenz_rfsoc_carrier" "47dr" \
]

variable ::kepler::vivado::BOARD_NAMES [dict keys $::kepler::vivado::BOARD_PART_SUPPORT]


proc ::kepler::vivado::get_part_longname { shortname } {
    # We use short aliases for the FPGA parts we work with, to avoid
    # having to specify the complete part number each time.
    # Look up the part number from its alias.
    #
    # shortname - the short-form to look up
    #
    # Returns: the part name associated with $shortname

    variable ::kepler::vivado::PART_SHORT_NAMES

    if {[catch {set longname [dict get $::kepler::vivado::PART_SHORT_NAMES $shortname]}]} {
        error "ERROR: Unknown part short name $shortname"
    }
    return $longname
}

proc ::kepler::vivado::get_part_shortname { part } {
    # Look up our short-form corresponding to a full part number.
    #
    # part - the part number to look up
    #
    # Returns: the short name associated with $part

    if {[catch {set shortname [dict get $::kepler::vivado::PART_LONG_NAMES $part]}]} {
        error "ERROR: Unknown part $part"
    }
    return $shortname
}


proc ::kepler::vivado::check_board_name { board_name } {
    # Verify that $board_name is a valid/known board name.
    #
    # board_name - the board name to check.
    #
    # Returns: 1 if the board name is known. Raises an error if the board name is unknown.

    variable ::kepler::vivado::BOARD_NAMES

    set idx [lsearch -exact $::kepler::vivado::BOARD_NAMES $board_name]
    if {$idx >= 0} {
        return 1
    }
    error "ERROR: Unknown board $board_name"
}


proc ::kepler::vivado::project_add::helpers::add_constraints {xdcdir filelist} {
    # Add a files in filelist as constraints to the current project.
    # If the files end in _impl.(tcl|xdc) or _synth.(tcl|xdc), then only add them to
    # implementation or synthesis, respectively.
    #
    # xdcdir - The top-level directory for xdc files for this project. This directory should \
    #         have sub-directories "common" and the current board name.
    # filelist - A list of constraint files to add to the project.

    add_files -norecurse -fileset [get_filesets constrs_1] $filelist

    foreach filename $filelist {
        # If constraints end in _synth or _impl, then remove them from the other stage.
        # (By default, they're added to both.)
        if {[string match *_synth.tcl $filename] || [string match *_synth.xdc $filename]} {
            set_property USED_IN_IMPLEMENTATION false [get_files $filename]
        } elseif {[string match *_impl.tcl $filename] || [string match *_impl.xdc $filename]} {
            set_property USED_IN_SYNTHESIS false [get_files $filename]
        }

        set processing_order NORMAL

        # Load Tcl scripts after XDCs.
        if {[string match *.tcl $filename]} {
            set processing_order LATE
        }

        set_property PROCESSING_ORDER $processing_order [get_files $filename]
    }
}


proc ::kepler::vivado::project_add::helpers::parse_scoped_constraint_module {filename} {
    # Parse a scoped constraint filename and return just the module name.
    # This assumes the name is of the form "module_name" followed optionally by "_early" or "_late",
    # followed optionally by "_synth" or "_impl", and finally ending with ".xdc" or ".tcl".
    #
    # filename - Name (can be with full path) of the file to extract module name from.

    set replaced [string map {_impl "" _synth "" _early "" _late "" .tcl ""} $filename]
    regsub -all {_order\d+} $replaced "" replaced
    return $replaced
}


proc ::kepler::vivado::project_add::helpers::get_constraint_ordinal_number {filename} {
    # Gets file ordinal number.
    # Any file without `_order#` in the filename is assigned the value 500.
    #
    # filename - Name (can be with full path) of the file to extract ordinal number from.

    set result [regexp -all {_order(\d+)} $filename all_matches number]
    if {$result == 0} {
        set number 500
    }
    return $number
}


proc ::kepler::vivado::project_add::helpers::reorder_constraint_groups {} {
    # Change compilation order of constraints by _orderXXX_ suffix/infix in the file name
    set constraint_files [get_files -of [get_filesets {constrs_1}] -regexp {.*?\.tcl} -nocase]
    set order_map {}
    foreach f $constraint_files {
        set constr_order [kepler::vivado::project_add::helpers::get_constraint_ordinal_number  [file tail $f]]
        set map_entry {}
        lappend map_entry $constr_order
        lappend map_entry $f
        lappend order_map $map_entry
    }

    set sorted_order_map [lsort -integer -index 0 $order_map]

    for {set i 1} {$i < [llength $sorted_order_map]} {incr i} {
        reorder_files -fileset constrs_1 -after [lindex [lindex $sorted_order_map $i-1] 1] [lindex [lindex $sorted_order_map $i] 1]
    }
}


proc ::kepler::vivado::project_add::sources {} {
    # Add Kepler-created Verilog files from "rtl" and constraints from "vivado/xdc"
    # to the current prooject.  This only adds files found one directory below rtl, and files
    # in rtl/board for the current project.
    #
    # If a constraint ends in _impl.{xdc,tcl} or _synth.{xdc,tcl}, then it will only
    # be added to the appropriate stage.
    #
    # Scoped constraints are in "scoped" sub-directories. The name of the constraint file must be
    # the name of the module to be applied using SCOPED_TO_REF. The filename extension and a suffix
    # of either _impl or _synth will be removed.
    #
    # It does not deal with 3rd-party IP cores, etc. See ::kepler::vivado::ips() for that.

    set rtldir "[get_property DIRECTORY [current_project]]/../../../rtl"
    set project_name [get_property NAME [current_project]]
    set xdcdir "[get_property DIRECTORY [current_project]]/../../xdc"

    # Get all Verilog files in subdirectories of RTL (only 1 level deep).
    set filelist {}
    foreach dirname [glob -nocomplain -directory $rtldir -type d {*}] {
        foreach filename [glob -nocomplain -directory $dirname -type f {*.{v,sv,svh}}] {
            lappend filelist [file normalize $filename]
        }
    }

    # Get all Verilog files specific to the board.
    foreach filename [glob -nocomplain -directory "${rtldir}/board/${project_name}" -type f "board_${project_name}_*.{v,sv,svh}"] {
        lappend filelist [file normalize $filename]
    }

    if {[llength $filelist] > 0} {
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
    }

    # Get memory initialization files (*.hex, *.mif) in the same locations as our Verilog files.
    set filelist {}
    foreach dirname [glob -nocomplain -directory $rtldir -type d {*}] {
        foreach filename [glob -nocomplain -directory $dirname -type f {*.{hex,mif}}] {
            lappend filelist [file normalize $filename]
        }
    }
    foreach filename [glob -nocomplain -directory "${rtldir}/board/${project_name}" -type f "board_${project_name}_*.{hex,mif}"] {
        lappend filelist [file normalize $filename]
    }
    if {[llength $filelist] > 0} {
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
        set_property file_type {Memory Initialization Files} [get_files $filelist]
    }

    # Normal constraints: all in xdc/common and xdc/${project_name} but not sub-directories.
    set filelist {}
    foreach filename [glob -nocomplain -directory "${xdcdir}/common" -type f {*.{xdc,tcl}}] {
        lappend filelist [file normalize $filename]
    }
    foreach filename [glob -nocomplain -directory "${xdcdir}/${project_name}" -type f {*.{xdc,tcl}}] {
        lappend filelist [file normalize $filename]
    }
    if {[llength $filelist] > 0} {
        helpers::add_constraints "$xdcdir" "$filelist"
    }

    # Scoped constraints: all in xdc/common/scoped and xdc/${project_name}/scoped but not sub-directories.
    set filelist {}
    foreach filename [glob -nocomplain -directory "${xdcdir}/common/scoped" -type f {*.{xdc,tcl}}] {
        lappend filelist [file normalize $filename]
    }
    foreach filename [glob -nocomplain -directory "${xdcdir}/${project_name}/scoped" -type f {*.{xdc,tcl}}] {
        lappend filelist [file normalize $filename]
    }
    if {[llength $filelist] > 0} {
        helpers::add_constraints "$xdcdir" "$filelist"
        # Apply scoping
        foreach filepath $filelist {
            set filename [file tail $filepath]
            set modulename [kepler::vivado::project_add::helpers::parse_scoped_constraint_module $filename]
            set_property SCOPED_TO_REF $modulename [get_files $filepath]
        }
    }

    helpers::add_constraints "$xdcdir" "$filelist"
    helpers::reorder_constraint_groups
}


proc ::kepler::vivado::project_add::libraries {} {
    # Add third-party RTL source libraries that we use,
    # that won't be found by ::kepler::vivado::project_add::sources because the do not conform
    # to our standard directory layout.

    set proj_dir [get_property DIRECTORY [current_project]]

    if {[catch {
        ########################
        # Comblock DSSS Modulator Library
        cd "${proj_dir}/../../../comblock/dsss_mod_core"
        source src.tcl

        ########################
        # Comblock DSSS Demodulator Library
        cd "${proj_dir}/../../../comblock/dsss_demod_core"
        source src.tcl

        ########################
        # Comblock Turbo Fec Encoder Library
        cd "${proj_dir}/../../../comblock/turbo_code_enc_core"
        source src.tcl

        ########################
        # Comblock Turbo Fec Decoder Library
        cd "${proj_dir}/../../../comblock/turbo_code_dec_core"
        source src.tcl

        ########################
        # Comblock SOF Sync Library
        cd "${proj_dir}/../../../comblock/sof_sync_core"
        source src.tcl

        ########################
        # Comtech DVB-S2 Library
        cd "${proj_dir}/../../../comtech/dvbs2/syn"
        source Srcs/src.tcl
        cd "${proj_dir}/../../../rtl/dvbs2/wrappers"
        source src.tcl
    } err ]} {
        cd $proj_dir
        puts "ERROR adding Comblock librarie"
        error $err
    }
    cd $proj_dir

    ########################
    # Analog Devices Sources
    # Get all Verilog files in subdirectories of ADHDL (only 2 levels deep).
    if {[catch {
        set adhdldir "${proj_dir}/../../../rtl/adhdl/library"
        set filelist {}
        foreach dirname1 [glob -nocomplain -directory $adhdldir -type d {*}] {
            foreach filename [glob -nocomplain -directory $dirname1 -type f {*.{v,sv,svh}}] {
                lappend filelist [file normalize $filename]
            }
            foreach dirname2 [glob -nocomplain -directory $dirname1 -type d {*}] {
                foreach filename [glob -nocomplain -directory $dirname2 -type f {*.{v,sv,svh}}] {
                    lappend filelist [file normalize $filename]
                }
            }
        }
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
    } err]} {
        puts "ERROR adding Analog Devices libraries"
        error $err
    }

    ###########################################
    # Verilog-AXIS and Verilog-Ethernet Sources
    # Get all Verilog files
    if {[catch {
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../verilog-axis/rtl" -type f {*.{v,sv,svh}}] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../verilog-ethernet/rtl" -type f {*.{v,sv,svh}}] {
            lappend filelist [file normalize $filename]
        }
        add_files -norecurse -fileset [get_filesets sources_1] $filelist

        # Get all TCL files
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../verilog-axis/syn" -type f {*.tcl}] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../verilog-ethernet/syn" -type f {*.tcl}] {
            lappend filelist [file normalize $filename]
        }
        if {[llength $filelist] > 0} {
            add_files -norecurse -fileset [get_filesets constrs_1] $filelist
            foreach filename $filelist {
                # Load Tcl scripts after XDCs.
                if {[string match *.tcl $filename]} {
                    set_property PROCESSING_ORDER LATE [get_files $filename]
                }
                # The verilog-axis and verilog-ethernet TCL files are all implementation-specific
                set_property USED_IN_SYNTHESIS false [get_files $filename]
            }
        } else {
            error "ERROR: Could not find verilog-axis and verilog-ethernet libraries. Try running 'git submodule update'."
        }
    } err]} {
        puts "ERROR adding verilog-axis or verilog-ethernet libraries"
        error $err
    }

    ###################
    # Nysa-SATA Sources
    # Get all Verilog files
    if {[catch {
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../nysa_sata" -type f {*.{v,sv,svh}}] {
            lappend filelist [file normalize $filename]
        }
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
    } err ]} {
        puts "ERROR adding Nysa-SATA libraries"
        error $err
    }

    ###################
    # Design Gateway SATA IP core
    if {[catch {
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../design_gateway/sata" -type f {*.{sv,vhd,edn}}] {
            lappend filelist [file normalize $filename]
        }
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
    } err]} {
        puts "ERROR adding Design Gateway libraries"
        error $err
    }

    ###################
    # CBKPAN-HDL Sources
    # Get all VHDL files for xlink
    if {[catch {
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../cbkpan/xlink" -type f "*.vhd"] {
            lappend filelist [file normalize $filename]
        }
        read_vhdl -vhdl2008 -library xil_defaultlib $filelist
    } err]} {
        puts "ERROR adding CBKPAN libraries"
        error $err
    }

    ###################
    # Creonic DVB-S2X Sources
    # Get .edn and Verilog stub files
    if {[catch {
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../../third_party/creonic/dvbs2x_demodulator/netlist" -type f {*.{v,edn}}] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../../third_party/creonic/dvbs2x_decoder/netlist" -type f {*.{v,edn}}] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../../third_party/creonic/dvbs2x_decoder_short_frames/netlist" -type f {*.{v,edn}}] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../../third_party/creonic/dvbs2x_modulator_m800/netlist" -type f {*.{v,edn}}] {
            lappend filelist [file normalize $filename]
        }
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
    } err]} {
        puts "ERROR adding Creonic libraries"
        error $err
    }

    ###################
    # 4links SpaceWire HDL Sources
    # Get all VHDL files for SpaceWire IP
    if {[catch {
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../FourLinks/spacewire/Lib" -type f "*.vhd"] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../FourLinks/spacewire/RTL/IP_Wrappers" -type f "*.vhd"] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../FourLinks/spacewire/RTL/IP_Wrappers/Xilinx" -type f "*.vhd"] {
            lappend filelist [file normalize $filename]
        }
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../FourLinks/spacewire/RTL/IP_Sub_Modules" -type f "*.vhd"] {
            lappend filelist [file normalize $filename]
        }
        add_files -norecurse $filelist
        set_property library work [get_files $filelist]
        set_property file_type {VHDL 2008} [get_files $filelist]
    } err]} {
        puts "ERROR adding 4links libraries"
        error $err
    }

    ########################################
    # Gatehouse IP for the Sateliot project
    if {[catch {
        set filelist {}
        foreach filename [glob -nocomplain -directory "${proj_dir}/../../../gatehouse_template" -type f "*.vhdp"] {
            lappend filelist [file normalize $filename]
        }
        read_vhdl -vhdl2008 -library xil_defaultlib $filelist
    } err]} {
        puts "ERROR adding Gatehouse libraries"
        error $err
    }
}


proc ::kepler::vivado::project_add::ips {} {
    # Add Xilinx IP Cores from "vivado/ipsrcs".
    #
    # We store IPs in two different ways: Tcl-managed vs vivado-managed. See the README.md
    # file in vivado/ipsrcs for more details. This function finds and adds/updates both
    # kinds of IP files.
    #
    # This does not handle other third-party IP libraries,
    # or cores in non-standard locations.

    set proj [current_project]
    set proj_dir [get_property DIRECTORY $proj]
    set part_short [::kepler::vivado::get_part_shortname [get_property part $proj]]


    # ###################
    # In-project IP Cores
    # Add vivado/ipsrc to the ip_repo_paths if it is not already there, so that any custom IP cores
    # (identified by "component.xml" files) get found.
    set ip_repo_paths [get_property ip_repo_paths $proj]
    set proj_ipsrcs [file normalize "[get_property DIRECTORY $proj]/../../ipsrcs"]
    if {[lsearch $ip_repo_paths $proj_ipsrcs] < 0} {
        lappend ip_repo_paths $proj_ipsrcs
        set_property ip_repo_paths $ip_repo_paths $proj
    }
    update_ip_catalog


    # ##################################
    # Xilinx IP Cores and Block Diagrams
    # Note: there should not be many IP cores found here. We've moving away from checking in binary blobs
    # and towards checking in text configurations of IP cores instead. This is handled in the "Tcl-managed"
    # section below.
    set filelist {}
    # Get *.xcix files from the IP core directory,
    # and get *.xci and *.bd files from appropriate subdirectories for this board type and part.
    set proj_ipsrcs "${proj_dir}/../../ipsrcs/vivado-managed"
    foreach board_dir "common $proj" {
        foreach filename [glob -nocomplain -directory [file join $proj_ipsrcs $board_dir $part_short] -type f {*.xcix}] {
            # .xcix files are archives. Vivado treats them as directories.
            # When adding/manipulating IP cores, you need to refer to the
            # .xci file inside the archive.
            set rootname [file rootname $filename]
            set basename [file tail $rootname]
            set xciname [file join $rootname "${basename}.xci"]

            lappend filelist [file normalize $xciname]
        }
        foreach filename [glob -nocomplain -directory [file join $proj_ipsrcs $board_dir $part_short] -type f */{*.{xci,bd}}] {
            lappend filelist [file normalize $filename]
        }
    }
    if { [llength $filelist] > 0 } {
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
    }

    foreach file $filelist {
        set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
        if { [llength $file_obj] > 0} {
            if { ![get_property "is_locked" $file_obj] } {
              set_property -name "generate_synth_checkpoint" -value "1" -objects $file_obj
            }
        }
    }


    #######################
    # Tcl-managed IP cores
    ::kepler::vivado::ips::import_all_ip_infos
    ::kepler::vivado::ips::import_all_bd_tcls

    ###########
    # DCP Files
    set filelist {}
    foreach board_dir "common $proj" {
        foreach filename [glob -nocomplain -directory [file join $proj_ipsrcs $board_dir $part_short]  -type f {*.dcp}] {
            lappend filelist [file normalize $filename]
        }
    }
    if { [llength $filelist] > 0 } {
        add_files -norecurse -fileset [get_filesets sources_1] $filelist
    }

    # ############################
    # Non-standard Xilinx IP Cores
    cd "${proj_dir}/../../ipsrcs"

    # We don't like special cases. Sometimes they're necessary.
    # However, we should review them from time to time to see if they can be
    # handled in a more standard way.

    cd [get_property DIRECTORY $proj]
}

proc ::kepler::vivado::project_add::config {} {
    # Modify Vivado project configuration settings
    #
    # For example, promote some warnings to errors, etc.

    set proj [current_project]
    set proj_dir [get_property DIRECTORY $proj]
    set part_short [::kepler::vivado::get_part_shortname [get_property part $proj]]


    ######################################################
    # Promote some dangerous synthesis warnings to errors

    # Don't allow inferring latches
    set_msg_config -quiet -id {Synth 8-327} -new_severity {ERROR}

    # Don't allow illegal (incorrect direction) port assignments
    set_msg_config -quiet -id {Synth 8-2900} -new_severity {ERROR}

    # Don't allow multi-driven nets
    set_msg_config -quiet -id {Synth 8-3352} -new_severity {ERROR}
}

proc ::kepler::vivado::project_add::all {} {
    ::kepler::vivado::project_add::config
    ::kepler::vivado::project_add::sources
    ::kepler::vivado::project_add::libraries
    ::kepler::vivado::project_add::ips
}

namespace eval ::kepler::vivado::project_add {
    namespace export *
    namespace ensemble create
}

proc ::kepler::vivado::write_hdf_if_sysdef {} {
    # Write an HDF or XSA file, if appropriate for the current project.

    set top_name  [get_property TOP [current_fileset]]
    set impl_run [current_run -implementation]
    set impl_dir [get_property DIRECTORY $impl_run]
    set proj_name [current_project]
    set proj_dir [get_property DIRECTORY $proj_name]
    set sdk_dir [file join $proj_dir "${proj_name}.sdk"]

    # Write an HDF or XSA file, depending on the Vivado version.
    if {[version -short] >= "2019.2"} {
        # Newer: write an XSA. File > Export > Export hardware puts this directly in the project directory.
        # For these versions, there is no sysdef file we can search for. I don't know how to test
        # to see whether or not there is a CPU in the design, so the best we can do is try it
        # and ignore errors.
        puts "Cannot auto-detect whether or not to export an XSA. Trying unconditionally and ignoring errors."
        if {[catch {write_hw_platform -fixed -force -file "${proj_dir}/${top_name}.xsa"}]} {
            puts [concat "There was en error generating the XSA. If this design does not have a CPU platform," \
             "then the error can be safely ignored. If you were expceting an XSA to be generated," \
             "then check the error log for details."]
        }
    } else {
        # Older: write an HDF in the SDK sub-directory to match what File > Export > Export Hardware would do.
        # For these versions, we can search for the existence of a sysdef file. If one doesn't exist,
        # then there is no platform to export.
        set sysdef_files [glob -nocomplain -directory "$impl_dir" -tails -type f {*.sysdef}]
        set num_sysdefs [llength $sysdef_files]
        if {$num_sysdefs == 0} {
            puts "No sysdef file found in $impl_dir. Not writing a hdf file."
        } else {
            puts "Found a sysdef file. Writing an hdf."
            file mkdir $sdk_dir
            write_hwdef -force "${sdk_dir}/${top_name}.hdf"
        }
    }
}


proc ::kepler::vivado::create_sdr_ooc {} {
    # Create OOC compiles for the DVB-S2 mod and demod in our SDR projects.
    # This supports xk7sdr, pch and hsd projects.

    # The commands below to create these OOC units were captured from the TCL console
    # after setting OOC using the GUI.

    set projpath [get_property DIRECTORY [current_project]]
    set project_name [get_property NAME [current_project]]

    set ooc_data {# (c) Copyright 2014 Xilinx, Inc. All rights reserved.

    # Add in a clock definition for each input clock to the out-of-context module.
    # The module will be synthesized as top so reference the clock origin using get_ports.
    # You will need to define a clock on each input clock port, no top level clock information
    # is provided to the module when set as out-of-context.
    # Here is an example:
    # create_clock -name clk_200 -period 5 [get_ports clk]
    }

    if {[lsearch "xk7sdr pch hsd dvbs2_dcps" $project_name] >= 0} {
        # OOC for board_xk7sdr_top.rxsdr_inst_0.rxsdr_dspinst.rxsdr_dvbs2_inst.DUT_demodulator:
        create_fileset -blockset -define_from demod_2_sa_s2_wrapper demod_2_sa_s2_wrapper
        file mkdir "$projpath/${project_name}.srcs/demod_2_sa_s2_wrapper/new"
        close [ open "$projpath/${project_name}.srcs/demod_2_sa_s2_wrapper/new/demod_2_sa_s2_wrapper_ooc.xdc" w ]
        add_files -fileset demod_2_sa_s2_wrapper "$projpath/${project_name}.srcs/demod_2_sa_s2_wrapper/new/demod_2_sa_s2_wrapper_ooc.xdc"
        set filename "$projpath/${project_name}.srcs/demod_2_sa_s2_wrapper/new/demod_2_sa_s2_wrapper_ooc.xdc"
        set fileId [open $filename "w"]
        puts -nonewline $fileId $ooc_data
        close $fileId
        set_property USED_IN {out_of_context synthesis implementation}  [get_files  "$projpath/${project_name}.srcs/demod_2_sa_s2_wrapper/new/demod_2_sa_s2_wrapper_ooc.xdc"]


        # OOC for board_xk7sdr_top.txsdr_inst.txsdr_dvbs2_inst.txdsp_modulator:
        create_fileset -blockset -define_from sa_2_mod_s2_wrapper sa_2_mod_s2_wrapper
        file mkdir "$projpath/${project_name}.srcs/sa_2_mod_s2_wrapper/new"
        close [ open "$projpath/${project_name}.srcs/sa_2_mod_s2_wrapper/new/sa_2_mod_s2_wrapper_ooc.xdc" w ]
        add_files -fileset sa_2_mod_s2_wrapper "$projpath/${project_name}.srcs/sa_2_mod_s2_wrapper/new/sa_2_mod_s2_wrapper_ooc.xdc"
        set filename "$projpath/${project_name}.srcs/sa_2_mod_s2_wrapper/new/sa_2_mod_s2_wrapper_ooc.xdc"
        set fileId [open $filename "w"]
        puts -nonewline $fileId $ooc_data
        close $fileId
        set_property USED_IN {out_of_context synthesis implementation}  [get_files  "$projpath/${project_name}.srcs/sa_2_mod_s2_wrapper/new/sa_2_mod_s2_wrapper_ooc.xdc"]
    } else {
        puts "Don't know how to create DVB-S2 OOC compiles for ${project_name}."
    }
}



proc ::kepler::vivado::generate_all_ip_targets {} {
    # Generate output products for all IP cores and block diagrams.
    #
    # TODO: The only step that Vivado normally does that this function omits is running
    # export_simulation on each IP block. (Some work needs to be done to figure out the
    # correct arguments for that command. Also, we generally don't try to simulate IP cores with
    # external simulators.)

    set obj_list [concat [::get_ips -exclude_bd_ips] [::kepler::vivado::ips::get_bd_files]]
    ::generate_target all $obj_list
    foreach ip [::get_ips -all] {
        # When you generate targets for a BD, Vivado does this step for all IPs, including IPs in BDs.
        catch { ::config_ip_cache -export $ip }
    }
    ::export_ip_user_files -of_objects $obj_list -no_script -sync -force -quiet
    foreach ip $obj_list {
        ::create_ip_run $ip
    }
}


proc ::kepler::vivado::launch_all_ip_runs {{max_jobs 0} {all_except synth_1}} {
    # Launch synthesis runs for all IP cores and block diagrams.
    #
    # max_jobs - Number of jobs to run concurrently. If you set this to 0, then the value
    #   of [get_param synth.maxThreads] will be used.
    # all_except - Run all synthesis runs except this one.
    #
    # We don't know how to identify which runs are for OOC objects and which are for the main project,
    # but Kepler typically leaves the default runs named synth_1 and impl_1. So, we run all synthesis
    # runs except $all_except (which defaults to synth_1).
    #
    # This function automatically calls generate_all_targets first. Targets must be generated in order
    # for the runs to exist.

    if {$max_jobs <= 0} {
        set max_jobs [::get_param synth.maxThreads]
    }

    generate_all_ip_targets

    set run_list ""
    foreach run [::get_runs] {
        if {$run == $all_except } {
            continue
        }
        # Only include synthesis runs
        if {![::get_property IS_SYNTHESIS $run]} {
            continue
        }
        # Exclude completd runs
        if {[::get_property PROGRESS $run] != "100%"} {
            if {[::get_property PROGRESS $run] != "0%"} {
                # Partially complete. Reset it.
                ::reset_run $run
            }
            lappend run_list $run
        }
    }
    if {[llength $run_list] > 0} {
        ::launch_runs -jobs $max_jobs $run_list
    } else {
        puts "All IP runs are up to date."
    }
}


proc ::kepler::vivado::check_design_linking_ips {} {
    # Check to make sure no IPs used in synthesis use a DesignLinking license.
    # If any of them do, it probably indicates you are having problems accessing our
    # license server. Check you VPN connection.
    #
    # If any IPs use DesignLinking, this will log a CRITICAL WARNING, log a WARNING for each
    # such IP core, and return 0. If no IPs use DesignLinking, this will return 1.
    #
    # We normally run this check as part of a post-synthesis hook script.
    # This check is usually quick, but some people have seen it take 5 minutes or more.
    # We don't know what causes the slow-down. If you want to bypass this check, you can
    # add `set skip_design_linking_check 1` to `~/.Xilinx/Vivado/Vivado_init.tcl`.

    global skip_design_linking_check

    if {[info exists skip_design_linking_check] && ($skip_design_linking_check == 1)} {
        puts "Skipping checks for DesignLinking licenses because skip_design_linking_check == 1."
        return 1
    }

    set current_ip_status [report_ip_status -license_status -return_string]

    set ok 1
    if {[expr [regexp -line  -all {\s+((Synthesis)|(Any))\s+.*?Design_Linking} $current_ip_status ] != 0]} {
        set ok 0
        send_msg_id {Kepler 3-1} {CRITICAL WARNING} "Design_Linking license used. Bitstream generation will be impossible. Please regenerate your IPs."
        foreach line [split $current_ip_status \n] {
            set res [regexp {^\|\s+(\w+).*?Design_Linking} $line all_matches ip_instance]
            if {$res==1} {
                send_msg_id {Kepler 3-2} {WARNING} "Design_Linking license is potentially used in $ip_instance"
            }
        }
    }
    return $ok
}


proc ::kepler::vivado::generate_ip_sim_target { ip_type } {

    # if {![current_project]} {
    #     puts "opening pcuecp.xpr"
    #     open_project pcuecp.xpr
    # }

    open_project .xpr

    foreach ip [get_ips] {
        set ipdef [get_property IPDEF $ip]
        if {[lrange [split $ipdef :] 0 2] == [list xilinx.com ip $ip_type]} {
            set ip_name [get_property NAME $ip]
            puts "Generating simulation output products for $ip_name"
            generate_target simulation [get_ips $ip_name] -force
        }
    }
}
