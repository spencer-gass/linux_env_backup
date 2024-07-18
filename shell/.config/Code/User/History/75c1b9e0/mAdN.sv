`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/17/2024 04:02:56 PM
// Design Name:
// Module Name: p4_router_util_2022_top
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module p4_router_util_2022_top(

    );

p4_router #(
    .NUM_8B_ING_PHYS_PORTS  ( 5 ),
    .NUM_16B_ING_PHYS_PORTS ( 2 ),
    .NUM_32B_ING_PHYS_PORTS ( 0 ),
    .NUM_64B_ING_PHYS_PORTS ( 4 ),
    .NUM_8B_EGR_PHYS_PORTS  ( 5 ),
    .NUM_16B_EGR_PHYS_PORTS ( 2 ),
    .NUM_32B_EGR_PHYS_PORTS ( 0 ),
    .NUM_64B_EGR_PHYS_PORTS ( 4 ),

    .VNP4_DATA_BYTES             ( 0    ),
    .USER_METADATA_WIDTH         ( 0    ),
    .EGR_SPEC_METADATA_WIDTH     ( 0    ),
    .VNP4_AXI4LITE_DATALEN       ( 32   ),
    .VNP4_AXI4LITE_ADDRLEN       ( 15   ),

    .MTU_BYTES( 5000 )
) dut (

    Clock_int.Output    core_clk_ifc,
    Reset_int.ResetOut  core_sreset_ifc,

    Clock_int.Output    cam_clk_ifc,
    Reset_int.ResetOut  cam_sreset_ifc,

    Clock_int.Output    avmm_clk_ifc,
    Reset_int.ResetOut  interconnect_sreset_ifc,
    Reset_int.ResetOut  peripheral_sreset_ifc,

    AvalonMM_int.Slave  vnp4_avmm,
    AvalonMM_int.Slave  p4_router_avmm,

    AXIS_int.Slave      ing_8b_phys_ports  [NUM_8B_ING_PHYS_PORTS-1:0],  // Can't group interfaces with different parameters into an array. One array per data width supported.
    AXIS_int.Slave      ing_16b_phys_ports [NUM_16B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_32b_phys_ports [NUM_32B_ING_PHYS_PORTS-1:0],
    AXIS_int.Slave      ing_64b_phys_ports [NUM_64B_ING_PHYS_PORTS-1:0],

    AXIS_int.Master     egr_8b_phys_ports  [NUM_8B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_16b_phys_ports [NUM_16B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_32b_phys_ports [NUM_32B_EGR_PHYS_PORTS-1:0],
    AXIS_int.Master     egr_64b_phys_ports [NUM_64B_EGR_PHYS_PORTS-1:0]

);

endmodule
