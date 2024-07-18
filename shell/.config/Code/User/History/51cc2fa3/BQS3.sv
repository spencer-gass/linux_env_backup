// CONFIDENTIAL
// Copyright (c) 2019 Kepler Communications Inc.

`timescale 1ns/1ps
`include "../util/util_check_elab.svh"
`default_nettype none

/**
 * Controller for a set of TI INA230 current and power monitors.
 * The addressing for 16 current monitors, would be as follows:
 *   0x00 - Address 0 for current monitor 0
 *   0x01 - Address 0 for current monitor 1
 *    .
 *    .
 *    .
 *   0x10 - Address 1 for current monitor 0
 *   0x11 - Address 1 for current monitor 1
 *  And so on. We have a few extra addresses for each current monitor at the end
 *  and then more for the control module after that.
 *
 * Startup:
 * On coming out of reset, this controller writes configuration values to all INA chips, based on the parameters
 * in the 'cpm' interface. In order to avoid false-positive alarms, this controller will not assert any cpm.alarm bits
 * until enough time has elapsed for all CPMs to perform a complete ADC conversion cycle. The time for this delay is calculated
 * based on the value of cpm.VAL_CONF00. The slowest delay across all NUM_MONITOR indices is used. An additional delay can be added
 * to this value, if required. (For example, if the cpm.alert_pins inputs go through circuitry that causes extra delays that must be
 * accounted for.) cpm.alarm bits are also suppressed while the corresponding bits of the cpm.alert_valid inputs are 0.
 */
module cpm_ina23x_ctrl #(
    parameter int                   NUM_MONITORS = 16,
    parameter int unsigned          EXTRA_STARTUP_DELAY_US = 0, // extra time (microseconds) to wait after startup before acting on alarms
    parameter bit                   DEBUG_ILA = 0
) (
    // CPM interface
    CPM_INA23x_int.Ctrl                     cpm,
    // Host side I2C interface
    I2CDriver_int.Master                    i2c,
    // Memory interface
    MemoryMap_int.Slave                     mmi,
    // Output to top level state and ready signals
    SDR_Ctrl_int.Slave                      sdr
);


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Functions


    // Extra time added to the calculated delay time, to provide a bit of a safety margin.
    localparam int unsigned     EXTRA_TIME_MARGIN_US    = 1000;

    /**
     * Convert CT (conversion time) bit values from the CONFIG register to the sample time in us.
     * ct_bits: the value of  V_BUS CT or V_SH VT from the CONFIG register.
     */
    function int unsigned conf_ct_to_conversion_time(input bit [2:0] ct_bits);
        unique case (ct_bits)
        3'b000: return 140;  // this seems to be exponential, but parameters are not given
        3'b001: return 204;
        3'b010: return 332;
        3'b011: return 588;
        3'b100: return 1100;
        3'b101: return 2116;
        3'b110: return 4156;
        3'b111: return 8244;
        endcase
    endfunction

    /**
     * Convert AVG bit values from the CONFIG register to the number of averages.
     */
    function int unsigned conf_avg_to_avg(input bit [2:0] avg_bits);
        unique case (avg_bits)
        3'b000: return 1;   // powers of 4
        3'b001: return 4;
        3'b010: return 16;
        3'b011: return 64;
        3'b100: return 128; // but then powers of 2
        3'b101: return 256;
        3'b110: return 512;
        3'b111: return 1024;
        endcase
    endfunction

    /**
     * Convert the conversion time to the number of clock cycles.
     * ct_vbus: conversion time for V_BUS in us.
     * ct_vsh: conversion time for V_SH in us.
     * num_avg: number of samples being averaged for each reading.
     * clock_freq_hz: clock frequency in Hz.
     * extra_time: extra time to add for safety, in us.
     */
    function int unsigned conv_time_to_clocks(
            input int unsigned ct_vbus_us,
            input int unsigned ct_vsh_us,
            input int unsigned num_avg,
            input int unsigned clock_freq_hz,
            input int unsigned extra_time_us = 1000
        );
        automatic int unsigned t_sample_us = (ct_vbus_us + ct_vsh_us) * num_avg + extra_time_us;
        automatic int unsigned num_clocks = t_sample_us * (clock_freq_hz / 1000000);
        return num_clocks;
    endfunction

    /**
     * Calculate the number of clock cycles we should wait for INA23x conversion to complete given the value
     * of the config register.
     */
    function int unsigned conf_reg_to_conv_clock_delay(input bit [15:0] conf_reg, input int unsigned clock_freq_hz, input int unsigned extra_time_us = 1000);
        automatic int unsigned t_vbus_us = conf_ct_to_conversion_time(conf_reg[8:6]);
        automatic int unsigned t_vsh_us  = conf_ct_to_conversion_time(conf_reg[5:3]);
        automatic int unsigned avgs = conf_avg_to_avg(conf_reg[11:9]);
        automatic int unsigned clocks = conv_time_to_clocks(t_vbus_us, t_vsh_us, avgs, clock_freq_hz, extra_time_us);
        return clocks;
    endfunction

    /**
     * Calculate the maximum number of clock cycles we should wait for INA23x conversion given all config registers.
     */
    function int unsigned max_conv_clock_delay(
            input int unsigned CTRL_CLOCK_FREQ,
            input bit [15:0] VAL_CONF00 [0:NUM_MONITORS-1],
            input int unsigned extra_time_us
    );
        automatic int unsigned max_delay = 0;
        automatic int unsigned this_delay;
        for (int i = 0; i < NUM_MONITORS; i++) begin
            this_delay = conf_reg_to_conv_clock_delay(VAL_CONF00[i], CTRL_CLOCK_FREQ, extra_time_us);
            if (this_delay > max_delay) max_delay = this_delay;
        end
        return max_delay;
    endfunction


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // SECTION: Types and Constant Declarations


    localparam int NUM_MONITORS_WIDTH = $clog2(NUM_MONITORS);
    localparam int NUM_MONITORS_2     = {NUM_MONITORS_WIDTH{1'b1}}+1; //This is NUM_MONITORS rounded off to the nearest power of 2
`ifdef MODEL_TECH
    // Avoid a several-ms initialization delay in simulations.
    $info("%m: Reducing MAX_CONV_DELAY for simulation.");
    localparam int unsigned MAX_CONV_DELAY = 100;
`else
    localparam int unsigned MAX_CONV_DELAY = max_conv_clock_delay(cpm.CTRL_CLOCK_FREQ, cpm.VAL_CONF00, EXTRA_TIME_MARGIN_US + EXTRA_STARTUP_DELAY_US);
`endif
    initial begin
        automatic real tmp_max_conv_delay = MAX_CONV_DELAY;
        automatic real tmp_clock_freq = cpm.CTRL_CLOCK_FREQ;
        automatic real tmp_initdone_wait_time_ms = 1000.0 * tmp_max_conv_delay / tmp_clock_freq;
        $info("%m: Wait time for initial ADC sampling: %f ms.", tmp_initdone_wait_time_ms);
    end

    // INA32x registers
    typedef enum {
        CONFIG,         //0 //0   - 15
        VSHUNT,         //1 //16  - 31
        VBUS,           //2 //32  - 47
        POWER,          //3 //48  - 63
        CURRENT,        //4 //64  - 79
        CAL,            //5 //80  - 95
        MASKEN,         //6 //96  - 111
        ALERTLIMIT,     //7 //112 - 128
        MMI_NUMINAREGS
    } inareg_t;

    // Additional values stored per monitor after the INA registers
    typedef enum {
        POLLREQ,     // First non-INA register (Request a read)
        WRITEREQ,    // Request a write
        RXACKS,      // I2C ack bits. (0 = ACK; 1 = no ACK.)
        MMI_NUMMONREGS
    } monitorreg_t;

    // Control registers for the whole module
    typedef enum {
        CTRL_POLL_PERIOD_MSB,   // MSB of polling period
        CTRL_POLL_PERIOD_LSB,   // LSB of polling period
        CTRL_POLL_MASK,         // mask of monitors to poll
        CTRL_ALERT,             // raw alert pin values from each monitor
        MMI_CTRLWORDS
    } ctrlreg_t;

    // For MMI access, we map all the inareg_t addresses (for each monitor), then
    // the monitorreg_t registers (for each monitor), then the ctrlreg_t registers
    // (only one set for the whole module).
    // This means we have a RAM of MMI_INAWORDS, followed by a register file of
    // MMI_MONWORDS + MMI_CTRLWORDS
    // NOTE: the comments to the right are all assuming 16 monitors, which is
    // not always the case
    localparam int      MMI_WORDSPERMON     = MMI_NUMINAREGS + MMI_NUMMONREGS;      //11
    localparam int      MMI_INAWORDS        = MMI_NUMINAREGS*NUM_MONITORS_2;        //8*16  = 128  //words in all INAs
    localparam int      MMI_CTRLOFFSET      = MMI_WORDSPERMON*NUM_MONITORS_2;       //11*16 = 176 //Control word address offsets
    localparam int      MMI_NWORDS          = MMI_CTRLOFFSET + MMI_CTRLWORDS;       //176+4 = 180 // Number of words
    localparam int      MMI_MONWORDS        = MMI_NUMMONREGS*NUM_MONITORS_2;        //3*16  = 48
    localparam int      MMI_REGFILEWORDS    = MMI_MONWORDS + MMI_CTRLWORDS;         //48+4  = 52 size of the register file
    localparam int      RAMADDR_LEN         = $clog2(MMI_INAWORDS);                 //128
    localparam int      RAM_DEPTH           = MMI_INAWORDS;
    localparam int      RAM_WIDTH           = mmi.DATALEN;
    localparam int      POLL_REQ_END_IDX    = MMI_INAWORDS + NUM_MONITORS_2 ;       //for NUM_MONITORS_2 = 16, POLL_REQ_END_IDX = 128+16 = 144
    localparam int      WRITE_REQ_END_IDX   = POLL_REQ_END_IDX + NUM_MONITORS_2;    //160
    localparam int      RXACKS_END_IDX      = WRITE_REQ_END_IDX + NUM_MONITORS_2;   //176
    localparam int      POLL_PERIOD_MSB_IDX = RXACKS_END_IDX + 1;                   //177
    localparam int      POLL_PERIOD_LSB_IDX = POLL_PERIOD_MSB_IDX + 1;              //178
    localparam int      POLL_MASK_IDX       = POLL_PERIOD_LSB_IDX + 1;              //179
    localparam int      ALERT_IDX           = POLL_MASK_IDX + 1;                    //180

    logic clk, reset_n;

    logic   [(NUM_MONITORS_WIDTH)-1:0]        chip_select, write_chipnum, writereq_chipnum, poll_chipnum, pollreq_chipnum;//chip number
    logic   [$clog2(MMI_NUMINAREGS)-1:0]      reg_select, write_regnum, writereq_regnum, poll_regnum, pollreq_regnum;  //selects register

    logic  new_writereq_available, new_pollreq_available;


    //DPRAM signal declaration
    logic                               a_wen, a_ren;
    logic   [$clog2(RAM_DEPTH)-1:0]     a_addr ;
    logic   [RAM_WIDTH-1:0]             a_wdata;
    logic   [RAM_WIDTH-1:0]             a_rdata;
    logic                               b_wen, b_ren;
    logic   [$clog2(RAM_DEPTH)-1:0]     b_addr ;
    logic   [RAM_WIDTH-1:0]             b_wdata;
    logic   [RAM_WIDTH-1:0]             b_rdata;

    logic                               ram_porta_busy, ram_portb_busy;

    //POLLREQUEST ENCODER signal declaration
    logic                                 poll_request_nxt_stb, poll_request_out_valid, poll_request_start_over;
    logic [NUM_MONITORS_2-1:0]            poll_request, poll_request_out_selected;
    logic [$clog2(NUM_MONITORS_2)-1:0]    poll_request_out_idx;

    //WRITEREQUEST ENCODER signal declaration
    logic                                 write_request_nxt_stb, write_request_out_valid, write_request_start_over;
    logic [NUM_MONITORS_2-1:0]            write_request, write_request_out_selected;
    logic [$clog2(NUM_MONITORS_2)-1:0]    write_request_out_idx;

    //REGISTER NUMBER ENCODER signal declaration
    logic                                 regnum_request_nxt_stb, regnum_request_out_valid, regnum_request_start_over;
    logic [MMI_NUMINAREGS-1:0]            regnum_request, regnum_request_out_selected;
    logic [$clog2(MMI_NUMINAREGS)-1:0]    regnum_request_out_idx;

    logic [31:0]                   poll_counter;

    logic   [NUM_MONITORS_2-1:0]   pollreq_tracker, writereq_tracker;

    logic   [MMI_NUMINAREGS-1:0]   pollreq  [NUM_MONITORS_2-1:0];
    logic   [MMI_NUMINAREGS-1:0]   writereq [NUM_MONITORS_2-1:0];
    logic   [MMI_NUMINAREGS-1:0]   rxack    [NUM_MONITORS_2-1:0];

    // I2C signals
    logic                                 i2c_start_cmd;
    logic  [$clog2(i2c.I2C_MAXBYTES):0]   i2c_n_bytes;
    logic  [6:0]                          i2c_addr;
    logic                                 i2c_rnotw;
    logic  [8*i2c.I2C_MAXBYTES-1:0]       i2c_tx_data;

    // V_bus update external interface
    logic                                 vbus_update_stb;
    logic [$clog2(NUM_MONITORS)-1:0]      vbus_update_num;
    logic [mmi.DATALEN-1:0]               vbus_update_value;

    // V_shunt update external interface
    logic                                 vshunt_update_stb;
    logic [$clog2(NUM_MONITORS)-1:0]      vshunt_update_num;
    logic [mmi.DATALEN-1:0]               vshunt_update_value;

    // Generating outputs to higher levels
    logic   setup_registers_written;
    logic   cpm_initdone;
    integer unsigned initdone_delay_count;  // counts up to MAX_CONV_DELAY

    logic [15:0]    ctrl_poll_period_msb_reg, ctrl_poll_period_lsb_reg;
    logic [7:0]     ctrl_poll_mask_reg;
    logic [15:0]    ctrl_alert_reg;


    assign clk         = sdr.clk;
    assign reset_n     = sdr.sresetn;
    assign ctrl_alert_reg = cpm.alert_pins;

    //MMI read/write operation
    typedef enum {
        INIT,
        WAIT_FOR_READ,
        READ_REG,
        READ_DATA,
        WRITE_DATA
    } mmi_state_t;

    mmi_state_t mmi_state;

    //DPRAM
    /*
    PORT A is used by this module to write/read data that is sent/received to the INA via I2C
    PORT B is used by the MMI bus to read/write data
    Read/write at the same port will not occur simultaneously.
    Read/write at the same address by two different ports will be dealt by the DPRAM module
    (at the moment it states that a read will occur before write (old data will be read first))
    */
    assign ram_porta_busy = (a_ren || a_wen); //if a_ren or a_wen are set then PORT A is busy
    assign ram_portb_busy = (b_ren || b_wen); //if a_ren or a_wen are set then PORT B is busy

    ram_dpram # (
        .RAM_WIDTH(RAM_WIDTH),
        .RAM_DEPTH(RAM_DEPTH),
        .ADDR_WIDTH($clog2(RAM_DEPTH))
    ) ram_dpram_inst (
        .clk     (clk    ),
        .a_wen   (a_wen  ),//PORT A
        .a_ren   (a_ren  ),
        .a_addr  (a_addr ),
        .a_wdata (a_wdata),
        .a_rdata (a_rdata),

        .b_wen   (b_wen  ),//PORT B
        .b_ren   (b_ren  ),
        .b_addr  (b_addr ),
        .b_wdata (b_wdata),
        .b_rdata (b_rdata)
    );

    //Round-robin encoder for handling POLL REQUESTS
    util_round_robin_select #(
        .N      (NUM_MONITORS_2),
        .HIGHEST(0)
    ) poll_request_enc (
        .clk            (clk),
        .rst            (~reset_n),
        .request        (poll_request),
        .next_stb       (poll_request_nxt_stb),
        .out_idx        (poll_request_out_idx),
        .out_selected   (poll_request_out_selected),
        .out_valid      (poll_request_out_valid),
        .start_over     (poll_request_start_over)
    );

    //Round-robin encoder for handling WRITE REQUESTS
    util_round_robin_select #(
        .N      (NUM_MONITORS_2),
        .HIGHEST(0)
    ) write_request_enc (
        .clk            (clk),
        .rst            (~reset_n),
        .request        (write_request),
        .next_stb       (write_request_nxt_stb),
        .out_idx        (write_request_out_idx),
        .out_selected   (write_request_out_selected),
        .out_valid      (write_request_out_valid),
        .start_over     (write_request_start_over)
    );

    //Round-robin encoder for handling REGISTER REQUESTS (after the chip number is selected)
    util_round_robin_select #(
        .N      (MMI_NUMINAREGS),
        .HIGHEST(0)
    ) regnum_request_enc (
        .clk            (clk),
        .rst            (~reset_n),
        .request        (regnum_request),
        .next_stb       (regnum_request_nxt_stb),
        .out_idx        (regnum_request_out_idx),
        .out_selected   (regnum_request_out_selected),
        .out_valid      (regnum_request_out_valid),
        .start_over     (regnum_request_start_over)
    );

    typedef enum {
        LOADDEFAULTS,    //0   // Load defaults from RAM after reset.
        IDLE,            //1   // Waits until a writereq/pollreq is raised
        GET_WRITE_REGNUM,//2   // Get the register number from the writereq encoder
        GET_POLL_REGNUM, //3   // Get the register number from the pollreq encoder
        WRITEPOINTER,    //4   // Send a write pointer request to I2C bus
        READCONFIG,      //5   // Send a read data request, will read from the pointer
        INAWRITE1,       //6   // Get data from RAM to be written on the I2C bus
        INAWRITE2,       //7   // (Wait for data to be read from RAM.)
        WAITI2C1,        //8   // Wait from I2C till i2c.rdy goes down
        WAITI2C2,        //9   // Wait from I2C till i2c.rdy goes high
        STROBE           //10  // Strobe to the next encoder input
    } state_t;

    state_t state, state_after;

    assign i2c.start_cmd   = i2c_start_cmd;
    assign i2c.use_stop    = 1'b0;
    assign i2c.n_bytes     = i2c_n_bytes;
    assign i2c.addr        = i2c_addr;
    assign i2c.rnotw       = i2c_rnotw;
    assign i2c.tx_data     = i2c_tx_data;
    assign i2c.lock_req    = 1'b0; // Unused

    assign sdr.initdone    = cpm_initdone;
    assign sdr.state       = state;

    assign cpm.vbus_update_stb      = vbus_update_stb;
    assign cpm.vbus_update_num      = vbus_update_num;
    assign cpm.vbus_update_value    = vbus_update_value;

    assign cpm.vshunt_update_stb    = vshunt_update_stb;
    assign cpm.vshunt_update_num    = vshunt_update_num;
    assign cpm.vshunt_update_value  = vshunt_update_value;

    always_comb begin
        poll_request = '0;
        write_request = '0;
        for (int i = 0; i < NUM_MONITORS; i++) begin
            poll_request[i]  = |pollreq[i];
            write_request[i] = |writereq[i];
        end
    end

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            cpm.no_vbus_acks <= '0;
        end else begin
            for (int i = 0; i < NUM_MONITORS; i++) begin
                cpm.no_vbus_acks[i] <= (rxack[i] == 8'd0) ? 1'b0 : 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(!reset_n) begin
            a_addr       <= 'X;
            a_ren        <= 1'b0;
            a_wen        <= 1'b0;
            a_wdata      <= 'X;
            reg_select   <= 0;
            chip_select  <= 0;
            poll_counter <= 0;
            pollreq      <= '{NUM_MONITORS_2{cpm.POLL_MASK}};
            writereq     <= '{NUM_MONITORS_2{8'hFF}};
            rxack        <= '{NUM_MONITORS_2{'0}};
            poll_request_nxt_stb   <= 0;
            write_request_nxt_stb  <= 0;
            regnum_request_nxt_stb <= 0;
            pollreq_tracker  <= 0;
            writereq_tracker <= 0;
            i2c_start_cmd    <= 0;
            i2c_n_bytes      <= 0;
            i2c_addr         <= 'X;
            i2c_rnotw        <= 0;
            i2c_tx_data      <= 0;
            setup_registers_written <= 0;
            vbus_update_num     <= 0;
            vbus_update_value   <= 0;
            vbus_update_stb     <= 0;
            vshunt_update_num   <= 0;
            vshunt_update_value <= 0;
            vshunt_update_stb   <= 0;
            state       <= LOADDEFAULTS;
            state_after <= IDLE;
        end else begin
            vbus_update_stb <= 1'b0;
            vshunt_update_stb <= 1'b0;

            case(state)
                LOADDEFAULTS: begin             //0
                    if(reg_select == 0) begin
                        a_addr <= {reg_select, chip_select};
                        a_wdata<= cpm.VAL_CONF00[chip_select];          //CONFIG
                        a_wen  <= 1'b1;
                        if(chip_select == (NUM_MONITORS - 1'b1)) begin
                            reg_select <= 3'd5;
                            chip_select<= 0;
                        end else begin
                            chip_select <= chip_select + 1;
                        end
                    end else if(reg_select == 3'd5) begin
                        a_addr <= {reg_select, chip_select};
                        a_wdata<= cpm.VAL_CAL05[chip_select];           //CAL
                        if(chip_select == (NUM_MONITORS - 1'b1)) begin
                            reg_select <= 3'd6;
                            chip_select<= 0;
                        end else begin
                            chip_select <= chip_select + 1;
                        end
                    end else if(reg_select == 3'd6) begin
                        a_addr <= {reg_select, chip_select};
                        a_wdata<= cpm.VAL_MASKEN06[chip_select];        //MASKEN
                        if(chip_select == (NUM_MONITORS - 1'b1)) begin
                            reg_select <= 3'd7;
                            chip_select<= 0;
                        end else begin
                            chip_select <= chip_select + 1;
                        end
                    end else if(reg_select == 3'd7) begin
                        a_addr <= {reg_select, chip_select};
                        a_wdata<= cpm.VAL_ALIMIT07[chip_select];        //ALERTLIMIT
                        if(chip_select == (NUM_MONITORS - 1'b1)) begin
                            reg_select  <= 0; //Reset
                            chip_select <= 0;
                            state <= IDLE;    //Defaults written now start polling/writing
                            for(int i = 0; i <NUM_MONITORS_2; i++) begin
                                if(i < NUM_MONITORS) begin
                                    writereq[i] <= 8'hE1;
                                    pollreq[i]  <= cpm.POLL_MASK;
                                end else begin
                                    writereq[i] <= 'h0;
                                    pollreq[i]  <= 'h0;
                                end
                            end
                        end else begin
                            chip_select <= chip_select + 1;
                        end
                    end
                end
                //At this point all initialization is complete

                IDLE: begin                 //1
                    a_wen  <= 1'b0;
                    poll_request_nxt_stb <= 1'b0;
                    write_request_nxt_stb <= 1'b0;
                    regnum_request_nxt_stb <= 1'b0;

                    if(!ram_portb_busy) begin //If MMI is idle and read/write not in progress
                        //CHECK for the next WRITE request
                        if(write_request_out_valid) begin
                            regnum_request   <= writereq[write_request_out_idx];
                            writereq_tracker <= writereq[write_request_out_idx];
                            write_chipnum    <= write_request_out_idx;      //The chip making the write request is identified
                            state <= GET_WRITE_REGNUM;
                        // If there is no write index selected, but there are pending requests, issue next_stb
                        end else if(write_request != '0) begin
                            write_request_nxt_stb <= 1'b1;
                        //CHECK for the next POLL request
                        end else if(poll_request_out_valid) begin
                            regnum_request  <= pollreq[poll_request_out_idx];
                            pollreq_tracker <= pollreq[poll_request_out_idx];
                            poll_chipnum    <= poll_request_out_idx;        //The chip making the poll request is identified
                            state <= GET_POLL_REGNUM;
                        // If there is no poll index selected, but there are pending requests, issue next_stb
                        end else if (poll_request != '0) begin
                            poll_request_nxt_stb <= 1'b1;
                        end
                    end
                end

                GET_WRITE_REGNUM: begin     //2
                    regnum_request_nxt_stb <= 1'b0;

                    if(regnum_request_out_valid) begin
                        write_regnum <= regnum_request_out_idx; //This is the register number to 1) read from RAM and then 2) write to INA
                        a_addr       <= {regnum_request_out_idx, write_chipnum}; //{3,4}
                        a_ren        <= 1'b1;
                        state        <= INAWRITE1;
                    end else if (regnum_request != '0) begin
                        regnum_request_nxt_stb <= 1'b1;
                    end else begin
                        state <= IDLE;
                        write_request_nxt_stb <= 1;
                    end
                end

                GET_POLL_REGNUM: begin      //3
                    regnum_request_nxt_stb <= 1'b0;

                    if(regnum_request_out_valid) begin
                        poll_regnum <= regnum_request_out_idx;
                        state       <= WRITEPOINTER;
                    end else if (regnum_request != '0) begin
                        regnum_request_nxt_stb <= 1'b1;
                    end else begin
                        state <= IDLE;
                        poll_request_nxt_stb <= 1;
                    end
                end

                // Start of a read command, write just the pointer we want to read from
                WRITEPOINTER: begin         //4
                    i2c_n_bytes     <= 'h1;
                    i2c_tx_data     <= poll_regnum;                   // Send pointer
                    i2c_addr        <= cpm.I2C_ADDRESS[poll_chipnum]; //current CPM/INA
                    i2c_rnotw       <= 1'b0; //write
                    i2c_start_cmd   <= 1'b1;
                    state           <= WAITI2C1;
                    state_after     <= READCONFIG;
                end

                // Now that the pointer is set correctly, request data from the INA register
                READCONFIG: begin           //5
                    i2c_n_bytes     <= 'h2;
                    i2c_tx_data     <= 'hffff;
                    i2c_addr        <= cpm.I2C_ADDRESS[poll_chipnum]; //current CPM/INA
                    i2c_rnotw       <= 1'b1; //read
                    i2c_start_cmd   <= 1'b1;
                    state           <= WAITI2C1;
                    state_after     <= STROBE;//IDLE;//GET_POLL_REGNUM;//IDLE;
                end

                //issue a read from RAM and then write that to INA via I2C
                INAWRITE1: begin            //6
                    a_ren   <= 1'b0;
                    state   <= INAWRITE2;
                end

                INAWRITE2: begin            //7
                    //data should be available on this clock (at the output of DPRAM)
                    i2c_n_bytes     <= 'h3;
                    i2c_tx_data     <= {write_regnum, a_rdata};        // Send reg num and data
                    i2c_addr        <= cpm.I2C_ADDRESS[write_chipnum]; //current CPM/INA
                    i2c_rnotw       <= 1'b0; //write
                    i2c_start_cmd   <= 1'b1;
                    state <= WAITI2C1;
                    state_after <= STROBE;//IDLE;//GET_WRITE_REGNUM;
                end

                WAITI2C1: begin             //8
                    if(~i2c.rdy) begin      //wait for command to be accepted
                        i2c_start_cmd <= 1'b0;
                        state <= WAITI2C2;
                    end
                end

                //wait for I2C to complete transaction
                WAITI2C2: begin             //9
                    if(i2c.rdy) begin
                        state <= state_after;
                        if(i2c_rnotw) begin
                            //If we just did a READ
                            rxack[poll_chipnum][poll_regnum] <= i2c.rx_ack[0];
                            a_addr  <= {poll_regnum, poll_chipnum};
                            a_wdata <= i2c.rx_data;
                            a_wen   <= 1'b1;
                            pollreq[poll_chipnum][poll_regnum] <= 1'b0;
                            pollreq_tracker[poll_regnum] <= 1'b0;
                            if ((poll_regnum == VBUS) && (i2c.rx_ack[0] == 1'b0)) begin
                                // A new VBUS value is available for this monitor.
                                vbus_update_num         <= poll_chipnum;
                                vbus_update_value       <= i2c.rx_data;
                                vbus_update_stb         <= 1'b1;
                            end

                            if ((poll_regnum == VSHUNT) && (i2c.rx_ack[0] == 1'b0)) begin
                                // A new VSHUNT value is available for this monitor.
                                vshunt_update_num         <= poll_chipnum;
                                vshunt_update_value       <= i2c.rx_data;
                                vshunt_update_stb         <= 1'b1;
                            end
                            regnum_request_nxt_stb <= 1'b1;
                        end else if(state_after == STROBE) begin //if we just did a write (and only a data write - and not a pointer write)
                            rxack[write_chipnum][write_regnum] <= i2c.rx_ack[0];//regnum,chip num //only from address byte
                            writereq[write_chipnum][write_regnum] <= 1'b0;
                            writereq_tracker[write_regnum] <= 1'b0;
                            regnum_request_nxt_stb <= 1'b1;
                        end
                    end
                end

                STROBE: begin               //10
                    a_wen <= 1'b0;
                    regnum_request_nxt_stb <= 1'b0;
                    if(i2c_rnotw) begin
                        if(pollreq_tracker == 0) begin
                            poll_request_nxt_stb <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= GET_POLL_REGNUM;
                        end
                    end else begin
                        if(writereq_tracker == 0) begin
                            write_request_nxt_stb <= 1'b1;
                            regnum_request_nxt_stb <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= GET_WRITE_REGNUM;
                        end
                    end
                end
            endcase

            //To latch the latest writereq registers
            if(new_writereq_available) begin
                writereq[writereq_chipnum][writereq_regnum] <= 1'b1;
            end

            //To latch the latest pollreq registers
            if(new_pollreq_available) begin
                pollreq[pollreq_chipnum][pollreq_regnum] <= 1'b1;
            end else begin
                if(poll_counter < {ctrl_poll_period_msb_reg,ctrl_poll_period_lsb_reg}) begin
                    poll_counter <= poll_counter + 1;
                end else begin
                    poll_counter <= 0;
                    for(int i = 0; i <NUM_MONITORS_2; i++) begin
                        if(i < NUM_MONITORS) begin
                            pollreq[i]  <= ctrl_poll_mask_reg | pollreq[i]; //to accomodate any new pollrequests
                        end else begin
                            pollreq[i]  <= 'h0;
                        end
                    end
                end
            end


            if ((state == STROBE) && (write_request == '0)) begin
                // No more pending values to write.
                setup_registers_written     <= 1'b1;
            end
        end
    end

    //PORT B of DPRAM <--> MMI
    always_ff @(posedge clk) begin
        if(~reset_n) begin
            mmi.rdata   <= 'X;
            mmi.arready <= 1'b0;
            mmi.rvalid  <= 1'b0;
            mmi.wready  <= 1'b0;

            writereq_chipnum <= 0;
            writereq_regnum <= 0;
            pollreq_chipnum <= 0;
            pollreq_regnum  <= 0;
            new_writereq_available <= 0;
            new_pollreq_available  <= 0;

            ctrl_poll_period_msb_reg <= cpm.POLL_PERIOD_MSB;
            ctrl_poll_period_lsb_reg <= cpm.POLL_PERIOD_LSB;
            ctrl_poll_mask_reg       <= cpm.POLL_MASK;

            b_addr      <= 'X;
            b_ren       <= 1'b0;
            b_wen       <= 1'b0;
            b_wdata     <= 'X;
            mmi_state   <= INIT;
        end else begin
            case(mmi_state)

                INIT: begin
                    if(mmi.wvalid) begin            //check if MMI wants to write (higher priority) to INA
                        mmi.wready  <= 1'b1;
                        if(mmi.waddr < MMI_INAWORDS) begin  //RAM_DEPTH
                            b_addr      <= mmi.waddr;
                            b_wdata     <= mmi.wdata;
                            b_wen       <= 1'b1;
                            writereq_chipnum        <= mmi.waddr[NUM_MONITORS_WIDTH-1:0];
                            writereq_regnum         <= mmi.waddr[NUM_MONITORS_WIDTH+2:NUM_MONITORS_WIDTH]; // regnum is from 0 to 7, so [2:0]
                            new_writereq_available  <= 1'b1;
                            mmi_state               <= WRITE_DATA;
                        end else if (mmi.waddr < (MMI_INAWORDS+NUM_MONITORS_2)) begin //Poll request can be set by MMI (otherwise poll_mask)
                            pollreq_chipnum         <= mmi.waddr[NUM_MONITORS_WIDTH-1:0];
                            pollreq_regnum          <= mmi.waddr[NUM_MONITORS_WIDTH+3:NUM_MONITORS_WIDTH];
                            new_pollreq_available   <= mmi.wdata[0]; //1'b1;
                        end else if(mmi.waddr < RXACKS_END_IDX) begin //READ ONLY
                        end else if(mmi.waddr == POLL_PERIOD_MSB_IDX - 1 ) begin // -1 because these values are one-indexed instead of zero-indexed
                            ctrl_poll_period_msb_reg <= mmi.wdata;
                        end else if(mmi.waddr == POLL_PERIOD_LSB_IDX - 1 ) begin
                            ctrl_poll_period_lsb_reg <= mmi.wdata;
                        end else if(mmi.waddr == POLL_MASK_IDX - 1) begin
                            ctrl_poll_mask_reg <= mmi.wdata;
                        end else if(mmi.waddr == ALERT_IDX - 1 ) begin
                            // This register is read-only
                        end else begin
                            //accept but do nothing -- because MMI is trying to write to a nonexistent reg/addr
                            new_writereq_available  <= 1'b0;
                            new_pollreq_available   <= 1'b0;
                        end
                        mmi.rdata   <= 'X;
                        mmi.arready <= 1'b0;
                        mmi.rvalid  <= 1'b0;
                    end else if(mmi.arvalid) begin      //check if MMI wants to read from a specific address
                        mmi.arready     <= 1'b1;
                        //We can read either from RAM or control registers
                        if(mmi.raddr < MMI_INAWORDS) begin
                            b_addr      <= mmi.raddr;
                            b_ren       <= 1'b1;        //Data will be available on the next clk
                            mmi_state   <= WAIT_FOR_READ;
                        end else if (mmi.raddr < POLL_REQ_END_IDX) begin
                            mmi.rdata   <= pollreq[mmi.raddr[3:0]];
                            mmi_state   <= READ_REG;
                        end else if (mmi.raddr < WRITE_REQ_END_IDX) begin
                            mmi.rdata   <= writereq[mmi.raddr[3:0]];
                            mmi_state   <= READ_REG;
                        end else if (mmi.raddr < RXACKS_END_IDX) begin
                            mmi.rdata   <= rxack[mmi.raddr[3:0]];
                            mmi_state   <= READ_REG;
                        end else if (mmi.raddr == POLL_PERIOD_MSB_IDX - 1) begin //176
                            mmi.rdata   <= ctrl_poll_period_msb_reg;
                            mmi_state   <= READ_REG;
                        end else if (mmi.raddr == POLL_PERIOD_LSB_IDX - 1) begin //177
                            mmi.rdata   <= ctrl_poll_period_lsb_reg;
                            mmi_state   <= READ_REG;
                        end else if (mmi.raddr == POLL_MASK_IDX - 1) begin  //178
                            mmi.rdata   <= ctrl_poll_mask_reg;
                            mmi_state   <= READ_REG;
                        end else if (mmi.raddr == ALERT_IDX - 1) begin      //179
                            mmi.rdata   <= ctrl_alert_reg;
                            mmi_state   <= READ_REG;
                        end else begin
                            // Invalid read address.
                            mmi.rdata   <= 'X;
                            mmi_state   <= READ_REG;
                        end
                        mmi.wready  <= 1'b0;
                    end else begin
                        mmi.rdata   <= 'X;
                        mmi.arready <= 1'b0;
                        mmi.rvalid  <= 1'b0;
                        mmi.wready  <= 1'b0;
                        b_addr      <= 'X;
                        b_ren       <= 1'b0;
                        new_writereq_available  <= 1'b0;
                        new_pollreq_available   <= 1'b0;
                    end
                end

                READ_REG: begin //Wait here for mmi to read
                    mmi.arready <= 1'b0;
                    mmi.rvalid  <= 1'b1;
                    if(mmi.rvalid & mmi.rready) begin
                        mmi_state <= INIT;
                        mmi.rvalid <= 1'b0;
                    end
                end

                WAIT_FOR_READ: begin                //Since data becomes available in the next cycle
                    mmi_state <= READ_DATA;
                    mmi.arready <= 1'b0;
                end

                READ_DATA: begin
                    mmi.rdata <= b_rdata;
                    mmi.rvalid <= 1'b1;
                    b_ren <= 1'b0;
                    if(mmi.rready) begin             //Go to the next state only after data is read by MMI
                        mmi_state <= INIT;
                    end
                end

                WRITE_DATA: begin                   //Wait for one clock cycle for write to RAM
                    b_wen       <= 1'b0;
                    mmi.wready  <= 1'b0;
                    mmi_state   <= INIT;
                    new_writereq_available <= 1'b0;
                end
            endcase

            // mmi.wvalid should drop after its handshake.
            // The above logic does this one cycle too late.
            if (mmi.wvalid & mmi.wready) begin
                mmi.wready      <= 1'b0;
            end
        end
    end //always

    // Generate the initdone signal after writing all register values.
    // We write ALIMIT registers last. The data sheet doesn't say how long it takes from the end
    // of an ALIMIT write for the change to be reflected on the INT_N pin. To be safe, we wait until
    // the very next I2C transaction completes.
    always_ff @(posedge clk) begin
        if (~reset_n) begin
            cpm_initdone            <= 1'b0;
            initdone_delay_count    <= 0;
        end else begin

            if (setup_registers_written) begin
                // After all registers are written, wait long enough for the INA chips to do a new
                // pair of V_SHUNT/V_BUS readings and update their alert output pins.
                if (initdone_delay_count < MAX_CONV_DELAY) begin
                    initdone_delay_count <= initdone_delay_count + 1;
                end else begin
                    cpm_initdone <= 1'b1;
                end
            end
        end
    end

    // Set active-high alarm outputs.
    // We register the outputs, which ensures they're glitch-free, but incurs
    // a one-clk cycle latency.
    always_ff @(posedge clk) begin
        if (~reset_n) begin
            cpm.alarm <= '0;

        end else begin
            if (cpm_initdone) begin
                for (int i = 0; i < cpm.NUM_MONITORS; i++) begin
                    // APOL is bit [1] of the MASKEN register.
                    if (cpm.VAL_MASKEN06[i][1]) begin   // active high open-collector
                        cpm.alarm[i] <= cpm.alert_valid[i] & cpm.alert_pins[i];
                    end else begin // active low open-collector
                        cpm.alarm[i] <= cpm.alert_valid[i] & ~cpm.alert_pins[i];
                    end
                end
            end
        end
    end

`ifndef MODEL_TECH
    state_t dbg_prev_state;
    logic dbg_state_changed;
    logic [63:0] dbg_counter;
    logic [NUM_MONITORS-1:0] dbg_prev_alert_pins;
    logic dbg_alert_pins_changed;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            dbg_prev_state <= LOADDEFAULTS;
            dbg_counter <= '0;
            dbg_prev_alert_pins <= '1;

        end else begin
            dbg_prev_state <= state;
            dbg_prev_alert_pins <= cpm.alert_pins;
            dbg_counter <= dbg_counter + 64'd1;
        end
    end

    assign dbg_state_changed = (dbg_prev_state != state) ? reset_n : 1'b0;
    assign dbg_alert_pins_changed = (dbg_prev_alert_pins != cpm.alert_pins) ? reset_n : 1'b0;

    generate
        if (DEBUG_ILA) begin : gen_cpm_ila
            ila_debug cpm_debug (
            .clk    ( clk ),
            .probe0 ( {state, dbg_state_changed, reset_n} ),
            .probe1 ( poll_regnum ),
            .probe2 ( {i2c.start_cmd, dbg_alert_pins_changed, cpm.alert_pins} ),
            .probe3 ( {i2c.n_bytes, i2c.rdy, cpm.alarm} ),
            .probe4 ( {cpm.alert_valid, i2c.addr} ),
            .probe5 ( {i2c.rnotw, cpm.no_vbus_acks} ),
            .probe6 ( i2c.tx_data ),
            .probe7 ( i2c.rx_data ),
            .probe8 ( i2c.rx_ack ),
            .probe9 ( {b_ren, b_wen, new_pollreq_available, new_writereq_available} ),
            .probe10( {i2c.rdy, i2c.start_cmd, a_ren, a_wen, cpm_initdone, setup_registers_written} ),
            // initdone testing:
            .probe11( {initdone_delay_count, write_request_out_valid} ),
            .probe12( write_request_out_idx ),
            .probe13( dbg_counter[63:32] ),
            .probe14( dbg_counter[31:0] ),
            /* // ACK testing:
            .probe11( {rxack[0], rxack[1], rxack[2], rxack[3]} ),
            .probe12( {rxack[4], rxack[5], rxack[6], rxack[7]} ),
            .probe13( {rxack[8], rxack[9], rxack[10], rxack[11]} ),
            .probe14( {rxack[12], rxack[13], rxack[14], rxack[15]} ),
            */
            .probe15( poll_chipnum )
            );

            // Monitor vshunt and vbus value updates
            ila_debug_small cpm_debug_updates (
                .clk    ( clk ),
                .probe0 ( vbus_update_stb ),
                .probe1 ( vbus_update_num ),
                .probe2 ( vbus_update_value ),
                .probe3 ( vshunt_update_stb ),
                .probe4 ( vshunt_update_num ),
                .probe5 ( vshunt_update_value ),
                .probe6 ( dbg_counter[63:32] ),
                .probe7 ( dbg_counter[31:0] )
            );
        end
    endgenerate
`endif
endmodule

`default_nettype wire
