// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Converts Xilinx Vitis Networking P4 user_extern interface to AXIS master.
 */

module axis_to_user_extern #(
    parameter int UE_IN_DATA_BITS = 0;
    parameter int UE_OUT_DATA_BITS = 0;
) (
    // Input from VNP4
    input var logic [UE_IN_DATA_BITS-1:0]   user_extern_data_in,
    input var logic                         user_extern_valid_in,
    // Output to VNP4
    input var logic [UE_OUT_DATA_BITS-1:0]  user_extern_data_out,
    input var logic                         user_extern_valid_out,
    // Output to user logic
    AXIS_int.Master                         axis_out,
    // Input from user logic
    AXIS_int.Slave                          axis_in
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int NB               = ssi_out.NB;
    localparam int NBYTES           =(ssi_out.NB-1)/8 + 1;
    localparam int N_CHANNELS       = ssi_out.N_CHANNELS;
    localparam int N_PARALLEL       = ssi_out.N_PARALLEL;
    localparam int SSI_N_SAMPLES    = ssi_out.N_CHANNELS * ssi_out.N_PARALLEL;

    // The expected size of the AXIS interface required to pack all of the SSI samples
    localparam int EXPECTED_AXIS_BYTES = ALIGNED ? NBYTES*SSI_N_SAMPLES
                                                 : (NB*SSI_N_SAMPLES-1)/8 + 1;


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Parameter Validation


    // The streams must be exactly compatible sizes
    `ELAB_CHECK_GE(8*axis_out.DATA_BYTES, UE_IN_DATA_BITS);
    `ELAB_CHECK_GE(8*axis_in.DATA_BYTES,  UE_OUT_DATA_BITS);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Output Assignments


    // SSI cannot backpressure
    assign axis_in.tready = 1'b1;

    assign ssi_out.valid        = axis_in.tvalid;
    assign ssi_out.center_ref   = axis_in.tvalid;

    always_comb begin
        for (int i=0; i<N_PARALLEL; i++) begin
            for (int j=0; j<N_CHANNELS; j++) begin
                if (ALIGNED) begin
                    ssi_out.data[j][i] = axis_in.tdata[8*NBYTES*(N_CHANNELS*i + j) +: NB];
                end else begin
                    ssi_out.data[j][i] = axis_in.tdata[NB*(N_CHANNELS*i + j)       +: NB];
                end
            end
        end
    end

endmodule

`default_nettype wire
