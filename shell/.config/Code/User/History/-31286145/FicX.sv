`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/17/2024 04:02:56 PM
// Design Name:
// Module Name: p4_router_util_top
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

(* DONT_TOUCH = "TRUE" *)
module p4_router_util_top #(
    parameter int NUM_8B_ING_PHYS_PORTS  = 3,
    parameter int NUM_16B_ING_PHYS_PORTS = 0,
    parameter int NUM_32B_ING_PHYS_PORTS = 0,
    parameter int NUM_64B_ING_PHYS_PORTS = 9,
    parameter int NUM_8B_EGR_PHYS_PORTS  = 3,
    parameter int NUM_16B_EGR_PHYS_PORTS = 0,
    parameter int NUM_32B_EGR_PHYS_PORTS = 0,
    parameter int NUM_64B_EGR_PHYS_PORTS = 9
)(

    input var logic clk,
    input var logic sreset

);

    import p4_router_pkg::*;

    localparam BYTES_PER_8BIT_WORD  = 1;
    localparam BYTES_PER_16BIT_WORD = 2;
    localparam BYTES_PER_32BIT_WORD = 4;
    localparam BYTES_PER_64BIT_WORD = 8;



    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) avmm_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )    // Doesn't matter for TB
    ) peripheral_sreset_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )    // Doesn't matter for TB
    ) interconnect_sreset_ifc ();

    Clock_int #(
        .CLOCK_GROUP_ID   ( 0 ), // Doesn't matter for TB
        .SOURCE_FREQUENCY ( 0 )  // Doesn't matter for TB
    ) core_clk_ifc ();

    Reset_int #(
        .CLOCK_GROUP_ID ( 0 )    // Doesn't matter for TB
    ) core_sreset_ifc ();

    assign avmm_clk_ifc.clk = clk;
    assign core_clk_ifc.clk = clk;

    assign peripheral_sreset_ifc.reset = sreset;
    assign interconnect_sreset_ifc.reset = sreset;
    assign core_sreset_ifc.reset = sreset;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS interfaces

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) ing_8b_phys_ports [NUM_8B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) ing_16b_phys_ports [NUM_16B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) ing_32b_phys_ports [NUM_32B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) ing_64b_phys_ports [NUM_64B_ING_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

   AXIS_int #(
        .DATA_BYTES ( BYTES_PER_8BIT_WORD )
    ) egr_8b_phys_ports [NUM_8B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_16BIT_WORD )
    ) egr_16b_phys_ports [NUM_16B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_32BIT_WORD )
    ) egr_32b_phys_ports [NUM_32B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );

    AXIS_int #(
        .DATA_BYTES ( BYTES_PER_64BIT_WORD )
    ) egr_64b_phys_ports [NUM_64B_EGR_PHYS_PORTS-1:0] (
        .clk     (core_clk_ifc.clk       ),
        .sresetn (core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM interfaces

    AvalonMM_int #(
        .DATALEN       ( 32 ),
        .ADDRLEN       ( 15 ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) p4_router_avmm ();

    AvalonMM_int #(
        .DATALEN       ( 32 ),
        .ADDRLEN       ( 15 ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) vnp4_avmm ();

    (* DONT_TOUCH = "TRUE" *)
    p4_router #(
        .NUM_8B_ING_PHYS_PORTS      ( NUM_8B_ING_PHYS_PORTS   ),
        .NUM_16B_ING_PHYS_PORTS     ( NUM_16B_ING_PHYS_PORTS  ),
        .NUM_32B_ING_PHYS_PORTS     ( NUM_32B_ING_PHYS_PORTS  ),
        .NUM_64B_ING_PHYS_PORTS     ( NUM_64B_ING_PHYS_PORTS  ),
        .NUM_8B_EGR_PHYS_PORTS      ( NUM_8B_EGR_PHYS_PORTS   ),
        .NUM_16B_EGR_PHYS_PORTS     ( NUM_16B_EGR_PHYS_PORTS  ),
        .NUM_32B_EGR_PHYS_PORTS     ( NUM_32B_EGR_PHYS_PORTS  ),
        .NUM_64B_EGR_PHYS_PORTS     ( NUM_64B_EGR_PHYS_PORTS  ),
        .VNP4_IP_SEl                ( FRR_T1_MPCU             ),
        .VNP4_DATA_BYTES            ( 64                      ),
        .VNP4_AXI4LITE_DATALEN      ( 32                      ),
        .VNP4_AXI4LITE_ADDRLEN      ( 15                      ),
        .QUEUE_MEM_URAM_DEPTH       ( 8                       ),
        .CLOCK_PERIOD_NS            ( 3.333                   ),
        .MTU_BYTES                  ( 9600                    )
    ) dut (

        .core_clk_ifc               ( core_clk_ifc            ),
        .core_sreset_ifc            ( core_sreset_ifc         ),
        .cam_clk_ifc                ( core_clk_ifc            ),
        .cam_sreset_ifc             ( core_sreset_ifc         ),
        .avmm_clk_ifc               ( avmm_clk_ifc            ),
        .interconnect_sreset_ifc    ( interconnect_sreset_ifc ),
        .peripheral_sreset_ifc      ( peripheral_sreset_ifc   ),
        .vnp4_avmm                  ( vnp4_avmm               ),
        .p4_router_avmm             ( p4_router_avmm          ),
        .ing_8b_phys_ports          ( ing_8b_phys_ports       ),
        .ing_16b_phys_ports         ( ing_16b_phys_ports      ),
        .ing_32b_phys_ports         ( ing_32b_phys_ports      ),
        .ing_64b_phys_ports         ( ing_64b_phys_ports      ),
        .egr_8b_phys_ports          ( egr_8b_phys_ports       ),
        .egr_16b_phys_ports         ( egr_16b_phys_ports      ),
        .egr_32b_phys_ports         ( egr_32b_phys_ports      ),
        .egr_64b_phys_ports         ( egr_64b_phys_ports      )

    );

endmodule
