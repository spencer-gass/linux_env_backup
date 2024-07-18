// CONFIDENTIAL
// Copyright (c) 2023 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Uses avmm_to_axi4lite module as an entry point for VNP4 table config controller.
 */
 s
module avmm_to_axi4lite
    import UTIL_INTS::U_INT_CEIL_DIV;
(
    Clock_int.Input         clk_ifc,
    Reset_int.ResetIn       interconnect_sreset_ifc,
    Reset_int.ResetIn       peripheral_sreset_ifc,

    AvalonMM_int.Slave      avmm,
    AXI4Lite_int.Master     axi4lite
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    `ELAB_CHECK_EQUAL ( axi4lite.DATALEN,   avmm.DATALEN );
    `ELAB_CHECK_EQUAL ( avmm.BURSTLEN,      1            );
    `ELAB_CHECK_EQUAL ( avmm.BURST_CAPABLE, 0            );


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Signal Declarations


    var logic [1:0] avmm_writeresponse_latched; // register translated axi4lite.bresp to delay response to avmm as protocol requires
    var logic [1:0] avmm_readresponse_latched;  // register translated axi4lite.rresp to delay response to avmm as protocol requires
    var logic       peripheral_sreset;
    var logic       wa_complete;
    var logic       wd_complete;
    var logic       ra_complete;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Function Declarations


    // Function converts from AXI4-Lite response code to AVMM response code
    function automatic logic [1:0] axi4lite_to_avmm_resp(input logic [1:0] resp);
        case (resp)
            axi4lite.OKAY:   axi4lite_to_avmm_resp = avmm.RESPONSE_OKAY;
            axi4lite.EXOKAY: axi4lite_to_avmm_resp = avmm.RESPONSE_OKAY;
            axi4lite.SLVERR: axi4lite_to_avmm_resp = avmm.RESPONSE_SLAVE_ERROR;
            axi4lite.DECERR: axi4lite_to_avmm_resp = avmm.RESPONSE_DECODE_ERROR;
        endcase
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    // AVMM read command will activate AXI4-Lite Read-Address Channel
    assign axi4lite.araddr  = avmm.address;
    assign axi4lite.arvalid = avmm.read & ~ra_complete;
    assign axi4lite.arprot  = 3'b000;

    // AXI4-Lite Slave sends Read-Data to AVMM Master when it is valid
    assign axi4lite.rready  = 1'b1; // No backpressure on reads

    // AVMM write command will activate AXI4-Lite Write-Address Channel first
    assign axi4lite.awaddr  = avmm.address;
    assign axi4lite.awvalid = avmm.write & ~wa_complete;
    assign axi4lite.awprot  = 3'b000;

    // AVMM write command will activate AXI4-Lite Write-Data Channel when the address has been succesfully transmitted
    assign axi4lite.wdata  = avmm.writedata;
    assign axi4lite.wvalid = avmm.write & ~wd_complete;
    assign axi4lite.wstrb  = avmm.byteenable;

    // AVMM write command will turn on write response ready signal
    assign axi4lite.bready = 1'b1; // No backpressure on write responses

    /**
    * Avalon MM Response Combinational Logic
    *
    * Determines avmm.response based on current operation / data ,
    * validity of axi4lite responses i.e. read, write or don't care
    */
    always_comb begin
        // If slave is in reset, always return zero
        if (avmm.readdatavalid) begin
            avmm.response = avmm_readresponse_latched;
        end else if(avmm.writeresponsevalid) begin
            avmm.response = avmm_writeresponse_latched;
        end else begin
            avmm.response = 'X;
        end
    end

    // Avalon MM waitrequest
    assign avmm.waitrequest = ((avmm.read | avmm.write) & (!(axi4lite.rvalid | axi4lite.bvalid))) & ~peripheral_sreset;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Logic Implementation


    assign peripheral_sreset = peripheral_sreset_ifc.reset == peripheral_sreset_ifc.ACTIVE_HIGH;

    /**
    * Avalon MM Write Response Register
    *
    * Naturally, the avmm.waitrequest depends on when the axi4-lite slave finishes it's execution,
    * indicated by bvalid or rvalid, however once waitrequest goes low, the Avalon MM expects the
    * write response in exactly one clock cycle, hence the need for a register
    */
    always_ff @(posedge clk_ifc.clk) begin
        if (interconnect_sreset_ifc.reset == interconnect_sreset_ifc.ACTIVE_HIGH) begin
            avmm.writeresponsevalid <= 1'b0;
            avmm.readdata           <= 'X;
            avmm.readdatavalid      <= 1'b0;

            avmm_writeresponse_latched  <= 'X;
            avmm_readresponse_latched  <= 'X;

            wa_complete             <= 1'b0;
            wd_complete             <= 1'b0;
            ra_complete             <= 1'b0;
        end else begin
            if (peripheral_sreset) begin
                avmm.writeresponsevalid <= avmm.write;
                avmm.readdatavalid      <= avmm.read;
                avmm.readdata           <= '0;

                avmm_writeresponse_latched <= '0;
                avmm_readresponse_latched  <= '0;

            end else begin
                avmm.writeresponsevalid <= axi4lite.bvalid;
                avmm.readdatavalid      <= axi4lite.rvalid;
                avmm.readdata           <= axi4lite.rdata;

                avmm_writeresponse_latched <= axi4lite_to_avmm_resp(axi4lite.bresp);
                avmm_readresponse_latched  <= axi4lite_to_avmm_resp(axi4lite.rresp);
            end

            if (~wa_complete) begin
                wa_complete <= axi4lite.awvalid & axi4lite.awready;
            end
            if (~wd_complete) begin
                wd_complete <= axi4lite.wvalid & axi4lite.wready;
            end
            if (~ra_complete) begin
                ra_complete <= axi4lite.arvalid & axi4lite.arready;
            end

            // Waitrequest deasserted indicates a completed AVMM transaction
            if (~avmm.waitrequest) begin
                wa_complete <= 1'b0;
                wd_complete <= 1'b0;
                ra_complete <= 1'b0;
            end
        end
    end
endmodule

`default_nettype wire
