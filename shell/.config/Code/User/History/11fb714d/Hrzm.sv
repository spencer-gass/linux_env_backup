// CONFIDENTIAL
// Copyright (c) 2021 Kepler Communications Inc.

`include "vunit_defines.svh"
`include "../../rtl/util/util_check_elab.svh"
`default_nettype none
`timescale 1ns/1ps

/**
 * Test bench for axis_dpi_pkt.
 */
module p4_router_top_tb ();
    import AXIS_DPI_PKT_PKG::*;

    parameter   int         MAX_LATENCY;

    parameter   bit         PARALLEL_HEADER;
    localparam  int         PARALLEL_HEADER_SIZE = PARALLEL_HEADER ? 14 : 0;

    // Set this to 1 for the C++ side to echo axis_in to axis_out.
    parameter   bit         LOOPBACK;
    // Set this to 1 for the C++ side to read/write axis_out/in from/to a PCAP file
    parameter   bit         PCAP;
    // Set this to 1 for the C++ side to connect axis_in/out to sockets.
    parameter   bit         SOCKET;

    localparam  int         MODE = PCAP ? DPI_PKT_PCAP : (SOCKET ? DPI_PKT_SOCKET : DPI_PKT_ECHO);

    // Set by VUnit to be the VUnit output directory (hdl/sim/workspace/vunit_out/test_output/<test_case_name>/
    parameter string        output_path = "./";
    // Set by p4_router_top_tb.py
    parameter string        input_path = "./";
    localparam string       input_filename = "mpls_ipv4_1_pkts.pcap";
    localparam string       output_filename = "mpls_ipv4_1_pkts.pcap";

    parameter int NUM_8B_ING_PHYS_PORTS  = 2;
    parameter int NUM_16B_ING_PHYS_PORTS = 0;
    parameter int NUM_32B_ING_PHYS_PORTS = 2;
    parameter int NUM_64B_ING_PHYS_PORTS = 0;
    parameter int NUM_8B_EGR_PHYS_PORTS  = 2;
    parameter int NUM_16B_EGR_PHYS_PORTS = 0;
    parameter int NUM_32B_EGR_PHYS_PORTS = 2;
    parameter int NUM_64B_EGR_PHYS_PORTS = 0;

    parameter int AVMM_DATALEN = 32;
    parameter int AVMM_ADDRLEN = 16;

    localparam  int         MAX_PKT_SIZE = 100;
    localparam  int         HEADER_SIZE = 14;
    localparam  int         MAX_PAYLOAD_SIZE = MAX_PKT_SIZE - HEADER_SIZE;
    localparam  int         MIN_PAYLOAD_SIZE = 46;
    localparam  int         NUM_PKTS = 1;
    localparam  int         DPI_DATA_BYTES = 1; // DPI C requires AXIS data bytes = 1

    localparam  bit[47:0]   LOCAL_MAC   = 48'hAA_BB_CC_DD_EE_FF;
    localparam  bit[47:0]   REMOTE_MAC  = 48'h11_22_33_44_55_66;

    localparam  bit[111:0]  ETH_HEADER_TO_SEND = {REMOTE_MAC, LOCAL_MAC, 16'h0000};

    import p4_router_pkg::*;
    import p4_router_tb_pkg::*;

    /*
     * The file python/kepler/test/rtlsim/axis/axis_dpi_pkt_in.pcap contains 50 captured packets,
     * so we cannot increase NUM_PKTS beyond 50.
     */
    `ELAB_CHECK_LE(NUM_PKTS, 50);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signals and interfaces


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: clocks and resets

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

    AXIS_int #(
        .DATA_BYTES ( DPI_DATA_BYTES    )
    ) axis_in (
        .clk        ( core_clk_ifc.clk       ),
        .sresetn    ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH   )
    );

    AXIS_int #(
        .DATA_BYTES ( DPI_DATA_BYTES    )
    ) axis_out (
        .clk        ( core_clk_ifc.clk       ),
        .sresetn    ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH   )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AVMM interfaces

    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 4            ),
        .BURST_CAPABLE ( 1'b1         )
    ) p4_router_avmm ();

    AvalonMM_int #(
        .DATALEN       ( AVMM_DATALEN ),
        .ADDRLEN       ( AVMM_ADDRLEN ),
        .BURSTLEN      ( 1            ),
        .BURST_CAPABLE ( 1'b0         )
    ) vnp4_avmm ();


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SUB-SECTION: AXIS sink/driver modules/interfaces


    // AXIS_sink #(
    //     .DATA_BYTES ( axis_out.DATA_BYTES   )
    // ) axis_out_sink (
    //     .clk        ( core_clk_ifc.clk       ),
    //     .sresetn    ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH   )
    // );

    // AXIS_sink_module axis_sink_inst (
    //     .i          ( axis_out.Slave    ),
    //     .control    ( axis_out_sink     )
    // );

    // AXIS_driver #(
    //     .DATA_BYTES ( axis_in.DATA_BYTES    )
    // ) axis_in_sink (
    //     .clk        ( core_clk_ifc.clk       ),
    //     .sresetn    ( core_sreset_ifc.reset != core_sreset_ifc.ACTIVE_HIGH   )
    // );

    // AXIS_driver_module axis_driver_inst (
    //     .o          ( axis_in.Master    ),
    //     .control    ( axis_in_sink         )
    // );


    int pkt_size, capped_pkt_size, expected_pkt_size;
    logic [8*DPI_DATA_BYTES-1:0] i_pkt_data_queue [$];
    // Store a copy of previously-sent packets for checking
    logic [8*DPI_DATA_BYTES-1:0] i_pkt_data_prev [NUM_PKTS-1:0][MAX_PKT_SIZE-1:0];
    int                      i_pkt_size_prev [NUM_PKTS-1:0];
    logic [8*DPI_DATA_BYTES-1:0] o_pkt_data_queue [$];


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: DPI packet gen/ana

    axis_dpi_pkt #(
        .MODE               ( MODE                  ),
        .MAX_PKT_SIZE       ( MAX_PKT_SIZE          ),
        .MAX_LATENCY        ( MAX_LATENCY           ),
        .WRITE_HEADER_BYTES ( PARALLEL_HEADER_SIZE  ),
        .WRITE_HEADER_DATA  ( ETH_HEADER_TO_SEND    )
    ) pkt_src_sink (
        // .axis_in    ( axis_in.Slave     ),
        // .axis_out   ( axis_out.Master   )
        .axis_in    ( egr_8b_phys_ports[0]  ),
        .axis_out   ( ing_8b_phys_ports[0]  )
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: DUT

    p4_router #(
        .MODULE_ID                      ( 0 ),
        .NUM_8B_ING_PHYS_PORTS          ( NUM_8B_ING_PHYS_PORTS  ),
        .NUM_16B_ING_PHYS_PORTS         ( NUM_16B_ING_PHYS_PORTS ),
        .NUM_32B_ING_PHYS_PORTS         ( NUM_32B_ING_PHYS_PORTS ),
        .NUM_64B_ING_PHYS_PORTS         ( NUM_64B_ING_PHYS_PORTS ),
        .NUM_8B_EGR_PHYS_PORTS          ( NUM_8B_EGR_PHYS_PORTS  ),
        .NUM_16B_EGR_PHYS_PORTS         ( NUM_16B_EGR_PHYS_PORTS ),
        .NUM_32B_EGR_PHYS_PORTS         ( NUM_32B_EGR_PHYS_PORTS ),
        .NUM_64B_EGR_PHYS_PORTS         ( NUM_64B_EGR_PHYS_PORTS ),
        .VNP4_DATA_BYTES                ( 64 ),
        .USER_METADATA_WIDTH            ( 19 ),
        .ING_PHYS_PORT_METADATA_WIDTH   ( 10 ),
        .VNP4_AXI4LITE_DATALEN          ( 32 ),
        .VNP4_AXI4LITE_ADDRLEN          ( 15 ),
        .MTU_BYTES                      ( 5000 )
    ) dut (
        .core_clk_ifc             ( core_clk_ifc            ),
        .core_sreset_ifc          ( core_sreset_ifc         ),
        .cam_clk_ifc              ( core_clk_ifc            ),
        .cam_sreset_ifc           ( core_sreset_ifc         ),
        .avmm_clk_ifc             ( avmm_clk_ifc            ),
        .interconnect_sreset_ifc  ( interconnect_sreset_ifc ),
        .peripheral_sreset_ifc    ( peripheral_sreset_ifc   ),
        .vnp4_avmm                ( vnp4_avmm               ),
        .p4_router_avmm           ( p4_router_avmm          ),
        .ing_8b_phys_ports        ( ing_8b_phys_ports ),
        .ing_16b_phys_ports       ( ing_16b_phys_ports ),
        .ing_32b_phys_ports       ( ing_32b_phys_ports ),
        .ing_64b_phys_ports       ( ing_64b_phys_ports ),
        .egr_8b_phys_ports        ( egr_8b_phys_ports ),
        .egr_16b_phys_ports       ( egr_16b_phys_ports ),
        .egr_32b_phys_ports       ( egr_32b_phys_ports ),
        .egr_64b_phys_ports       ( egr_64b_phys_ports )
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Tests

    // Set up the simulation clock
    always #10    avmm_clk_ifc.clk <= ~avmm_clk_ifc.clk;
    always #3.333 core_clk_ifc.clk <= ~core_clk_ifc.clk;


    `TEST_SUITE begin
        `TEST_SUITE_SETUP begin
            $timeformat(-9, 3, " ns", 20);
            avmm_clk_ifc.clk     <= 1'b0;
            core_clk_ifc.clk     <= 1'b0;
        end

        `TEST_CASE_SETUP begin
            `CHECK_EQUAL(pkt_src_sink.setup(input_path, input_filename, output_path, output_filename), 0);

            interconnect_sreset_ifc.reset = interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset = peripheral_sreset_ifc.ACTIVE_HIGH;
            core_sreset_ifc.reset = core_sreset_ifc.ACTIVE_HIGH;
            @(posedge avmm_clk_ifc.clk);
            interconnect_sreset_ifc.reset = ~interconnect_sreset_ifc.ACTIVE_HIGH;
            peripheral_sreset_ifc.reset = ~peripheral_sreset_ifc.ACTIVE_HIGH;
            @(posedge core_clk_ifc.clk);
            core_sreset_ifc.reset = ~core_sreset_ifc.ACTIVE_HIGH;

        end


        `TEST_CASE("basic") begin
            // vunit: .dpi
            fork
                pkt_src_sink.c_run();
                // begin
                //     for (int i=0; i<NUM_PKTS; i++) begin
                //         pkt_size = i + MIN_PAYLOAD_SIZE + HEADER_SIZE;
                //         i_pkt_data_queue = {};

                //         // If the header wasn't passed in parallel, serialize it in
                //         if (!PARALLEL_HEADER) begin
                //             for (int j=0; j<HEADER_SIZE; j++) begin
                //                 i_pkt_data_queue.push_back(ETH_HEADER_TO_SEND[8*(HEADER_SIZE-j-1) +: 8]);
                //             end
                //         end

                //         // Ethernet payload: hard-coded values to compare against axis_dpi_pkt_out_golden.pcap
                //         for (int j=0; j<pkt_size-HEADER_SIZE; j++) begin
                //             i_pkt_data_queue.push_back(i*j);
                //         end

                //         /**
                //          * Add enough latency that the timestamps will match regardless of whether
                //          * the header was parallel
                //          */
                //         if (PARALLEL_HEADER) begin
                //             repeat(HEADER_SIZE) @(posedge core_clk_ifc.clk);
                //         end

                //         // axis_in_sink.write_queue(.input_data(i_pkt_data_queue), .max_latency(MAX_LATENCY));

                //         // Record previous packet's data, used to verify output data in loopback mode
                //         capped_pkt_size = UTIL_INTS::U_INT_MIN(pkt_size, MAX_PKT_SIZE) - PARALLEL_HEADER_SIZE;
                //         for (int j=0; j<capped_pkt_size; j++) begin
                //             i_pkt_data_prev[i][j] = i_pkt_data_queue[j];
                //         end
                //         i_pkt_size_prev[i] = capped_pkt_size;
                //     end
                // end

                // begin
                //     for (int i=0; i<NUM_PKTS; i++) begin
                //         o_pkt_data_queue = {};
                //         // axis_out_sink.read_queue(.output_data(o_pkt_data_queue), .max_latency(MAX_LATENCY));

                //         if (LOOPBACK) begin
                //             `CHECK_EQUAL(o_pkt_data_queue.size(), i_pkt_size_prev[i]);
                //             for (int j=0; j<i_pkt_size_prev[i]; j++) begin
                //                 `CHECK_EQUAL(o_pkt_data_queue[j], i_pkt_data_prev[i][j]);
                //             end
                //         end else begin // Output from PCAP file
                //             expected_pkt_size = i + MIN_PAYLOAD_SIZE + HEADER_SIZE;
                //             if (expected_pkt_size > MAX_PKT_SIZE) begin
                //                 expected_pkt_size = MAX_PKT_SIZE;
                //             end
                //             `CHECK_EQUAL(o_pkt_data_queue.size(), expected_pkt_size);
                //             // Check header
                //             for (int j=0; j<6; j++) begin
                //                 `CHECK_EQUAL(o_pkt_data_queue[j], LOCAL_MAC[8*(5-j) +: 8]);
                //             end
                //             for (int j=0; j<6; j++) begin
                //                 `CHECK_EQUAL(o_pkt_data_queue[j+6], REMOTE_MAC[8*(5-j) +: 8]);
                //             end
                //             `CHECK_EQUAL(o_pkt_data_queue[12], 8'h00);
                //             `CHECK_EQUAL(o_pkt_data_queue[13], 8'h00);
                //             // Check payload
                //             for (int j=0; j<expected_pkt_size-HEADER_SIZE; j++) begin
                //                 `CHECK_EQUAL(o_pkt_data_queue[j+HEADER_SIZE], i + j);
                //             end
                //         end
                //     end
                // end
            join
        end


        `TEST_CASE_CLEANUP begin
            // Stall for one cycle to guarantee C has time to finish executing its last write
            @(posedge core_clk_ifc.clk);

            pkt_src_sink.teardown();
        end


        `TEST_SUITE_CLEANUP begin
        end
    end

    `WATCHDOG(1ms);
endmodule
