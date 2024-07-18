// CONFIDENTIAL
// Copyright (c) 2022 Kepler Communications Inc.

/*
 * The intent of the macros in this file are to create copies of interfaces that can be used
 * to provide .Monitor modports from interfaces that may already be some other modport. This is
 * to avoid syntax errors in some tools that are strict about modport types.
 */

/**
 * Make a new AXIS_int called 'monitor_int' that has all signals copied from 'ori_intg'
 * The intent is to provide a new interface from which the .Monitor modport may be used.
 */
`define MAKE_AXIS_MONITOR(monitor_int, orig_int)        \
    AXIS_int #(                                         \
        .DATA_BYTES       ( orig_int.DATA_BYTES ),      \
        .ID_WIDTH         ( orig_int.ID_WIDTH ),        \
        .DEST_WIDTH       ( orig_int.DEST_WIDTH ),      \
        .USER_WIDTH       ( orig_int.USER_WIDTH ),      \
        .SIM_ASSIGN_DELAY ( orig_int.SIM_ASSIGN_DELAY ) \
    ) monitor_int (                                     \
        .clk              ( orig_int.clk ),             \
        .sresetn          ( orig_int.sresetn )          \
    );                                                  \
    assign monitor_int.tvalid = orig_int.tvalid;        \
    assign monitor_int.tready = orig_int.tready;        \
    assign monitor_int.tdata  = orig_int.tdata;         \
    assign monitor_int.tstrb  = orig_int.tstrb;         \
    assign monitor_int.tkeep  = orig_int.tkeep;         \
    assign monitor_int.tlast  = orig_int.tlast;         \
    assign monitor_int.tid    = orig_int.tid;           \
    assign monitor_int.tdest  = orig_int.tdest;         \
    assign monitor_int.tuser  = orig_int.tuser;


/**
 * Make a new AXI_int called 'monitor_int' that has all signals copied from 'orig_int'.
 * The intent is to provide a new interface from which the .Monitor modport may be used.
 */
`define MAKE_AXI4_MONITOR(monitor_int, orig_int)      \
    AXI4_int #(                                       \
        .DATALEN    (orig_int.DATALEN),               \
        .ADDRLEN    (orig_int.ADDRLEN),               \
        .WIDLEN     (orig_int.WIDLEN),                \
        .RIDLEN     (orig_int.RIDLEN)                 \
    ) monitor_int (                                   \
        .clk        (orig_int.clk),                   \
        .sresetn    (orig_int.sresetn)                \
    );                                                \
    assign monitor_int.awid       = orig_int.awid;    \
    assign monitor_int.awaddr     = orig_int.awaddr;  \
    assign monitor_int.awlen      = orig_int.awlen;   \
    assign monitor_int.awsize     = orig_int.awsize;  \
    assign monitor_int.awburst    = orig_int.awburst; \
    assign monitor_int.awlock     = orig_int.awlock;  \
    assign monitor_int.awcache    = orig_int.awcache; \
    assign monitor_int.awprot     = orig_int.awprot;  \
    assign monitor_int.awqos      = orig_int.awqos;   \
    assign monitor_int.awvalid    = orig_int.awvalid; \
    assign monitor_int.awready    = orig_int.awready; \
    assign monitor_int.wdata      = orig_int.wdata;   \
    assign monitor_int.wstrb      = orig_int.wstrb;   \
    assign monitor_int.wlast      = orig_int.wlast;   \
    assign monitor_int.wvalid     = orig_int.wvalid;  \
    assign monitor_int.wready     = orig_int.wready;  \
    assign monitor_int.bid        = orig_int.bid;     \
    assign monitor_int.bresp      = orig_int.bresp;   \
    assign monitor_int.bvalid     = orig_int.bvalid;  \
    assign monitor_int.bready     = orig_int.bready;  \
    assign monitor_int.arid       = orig_int.arid;    \
    assign monitor_int.araddr     = orig_int.araddr;  \
    assign monitor_int.arlen      = orig_int.arlen;   \
    assign monitor_int.arsize     = orig_int.arsize;  \
    assign monitor_int.arburst    = orig_int.arburst; \
    assign monitor_int.arlock     = orig_int.arlock;  \
    assign monitor_int.arcache    = orig_int.arcache; \
    assign monitor_int.arprot     = orig_int.arprot;  \
    assign monitor_int.arqos      = orig_int.arqos;   \
    assign monitor_int.arvalid    = orig_int.arvalid; \
    assign monitor_int.arready    = orig_int.arready; \
    assign monitor_int.rid        = orig_int.rid;     \
    assign monitor_int.rdata      = orig_int.rdata;   \
    assign monitor_int.rresp      = orig_int.rresp;   \
    assign monitor_int.rlast      = orig_int.rlast;   \
    assign monitor_int.rvalid     = orig_int.rvalid;  \
    assign monitor_int.rready     = orig_int.rready;

/**
 * Make a new AXI4Lite_int called 'monitor_int' that has all signals copied from 'orig_int'.
 * The intent is to provide a new interface from which the .Monitor modport may be used.
 */
`define MAKE_AXI4LITE_MONITOR(monitor_int, orig_int)  \
    AXI4Lite_int #(                                   \
        .DATALEN    (orig_int.DATALEN),               \
        .ADDRLEN    (orig_int.ADDRLEN)                \
        ) monitor_int (                               \
        .clk        (orig_int.clk),                   \
        .sresetn    (orig_int.sresetn)                \
    );                                                \
    assign monitor_int.awaddr     = orig_int.awaddr;  \
    assign monitor_int.awprot     = orig_int.awprot;  \
    assign monitor_int.awvalid    = orig_int.awvalid; \
    assign monitor_int.awready    = orig_int.awready; \
    assign monitor_int.wdata      = orig_int.wdata;   \
    assign monitor_int.wstrb      = orig_int.wstrb;   \
    assign monitor_int.wvalid     = orig_int.wvalid;  \
    assign monitor_int.wready     = orig_int.wready;  \
    assign monitor_int.bresp      = orig_int.bresp;   \
    assign monitor_int.bvalid     = orig_int.bvalid;  \
    assign monitor_int.bready     = orig_int.bready;  \
    assign monitor_int.araddr     = orig_int.araddr;  \
    assign monitor_int.arprot     = orig_int.arprot;  \
    assign monitor_int.arvalid    = orig_int.arvalid; \
    assign monitor_int.arready    = orig_int.arready; \
    assign monitor_int.rdata      = orig_int.rdata;   \
    assign monitor_int.rresp      = orig_int.rresp;   \
    assign monitor_int.rvalid     = orig_int.rvalid;  \
    assign monitor_int.rready     = orig_int.rready;

/**
 * Make a new MemoryMap_int called 'monitor_int' that has all signals copied from 'orig_int'.
 * The intent is to provide a new interface from which the .Monitor modport may be used.
 */
`define MAKE_MMI_MONITOR(monitor_int, orig_int)          \
    MemoryMap_int #(                                     \
        .DATALEN            ( orig_int.DATALEN ),        \
        .ADDRLEN            ( orig_int.ADDRLEN ),        \
        .SIM_ASSIGN_DELAY   (orig_int.SIM_ASSIGN_DELAY ) \
    ) monitor_int ();                                    \
    assign monitor_int.wvalid     = orig_int.wvalid;     \
    assign monitor_int.wready     = orig_int.wready;     \
    assign monitor_int.waddr      = orig_int.waddr;      \
    assign monitor_int.wdata      = orig_int.wdata;      \
    assign monitor_int.arvalid    = orig_int.arvalid;    \
    assign monitor_int.arready    = orig_int.arready;    \
    assign monitor_int.raddr      = orig_int.raddr;      \
    assign monitor_int.rvalid     = orig_int.rvalid;     \
    assign monitor_int.rready     = orig_int.rready;     \
    assign monitor_int.rdata      = orig_int.rdata;


/**
 * Make a new AvalonMM_int called 'monitor_int' that has all signals copied from 'orig_int'.
 * The intent is to provide a new interface from which the .Monitor modport may be used.
 */
`define MAKE_AVMM_MONITOR(monitor_int, orig_int)                             \
    AvalonMM_int #(                                                          \
        .DATALEN            ( orig_int.DATALEN          ),                   \
        .ADDRLEN            ( orig_int.ADDRLEN          ),                   \
        .BURSTLEN           ( orig_int.BURSTLEN         ),                   \
        .BURST_CAPABLE      ( orig_int.BURST_CAPABLE    )                    \
    ) monitor_int ();                                                        \
    assign monitor_int.address              =   orig_int.address;            \
    assign monitor_int.burstcount           =   orig_int.burstcount;         \
    assign monitor_int.byteenable           =   orig_int.byteenable;         \
    assign monitor_int.waitrequest          =   orig_int.waitrequest;        \
    assign monitor_int.response             =   orig_int.response;           \
    assign monitor_int.write                =   orig_int.write;              \
    assign monitor_int.writedata            =   orig_int.writedata;          \
    assign monitor_int.writeresponsevalid   =   orig_int.writeresponsevalid; \
    assign monitor_int.read                 =   orig_int.read;               \
    assign monitor_int.readdata             =   orig_int.readdata;           \
    assign monitor_int.readdatavalid        =   orig_int.readdatavalid;
