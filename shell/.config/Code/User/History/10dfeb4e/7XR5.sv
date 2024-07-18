// CONFIDENTIAL
// Copyright (c) 2024 Kepler Communications Inc.

`timescale 1ns/1ps
`default_nettype none


module vnp4_control_sim
import vnp4_sim_pkg::*;
(
   // Clocks & Resets
   input  logic                          axi_aclk,
   input  logic                          axi_aresetn,
   // AXI4-lite interface
   output logic [S_AXI_ADDR_WIDTH-1:0]   m_axi_awaddr,
   output logic                          m_axi_awvalid,
   input  logic                          m_axi_awready,
   output logic [S_AXI_DATA_WIDTH-1:0]   m_axi_wdata,
   output logic [S_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
   output logic                          m_axi_wvalid,
   input  logic                          m_axi_wready,
   input  logic [1:0]                    m_axi_bresp,
   input  logic                          m_axi_bvalid,
   output logic                          m_axi_bready,
   output logic [S_AXI_ADDR_WIDTH-1:0]   m_axi_araddr,
   output logic                          m_axi_arvalid,
   input  logic                          m_axi_arready,
   input  logic [S_AXI_DATA_WIDTH-1:0]   m_axi_rdata,
   input  logic                          m_axi_rvalid,
   output logic                          m_axi_rready,
   input  logic [1:0]                    m_axi_rresp
);

    // --------------------------------------------------------------------------
    // AXI Lite tasks used by DPI

    localparam logic [1:0] OKAY = 2'b00;

    localparam int AXIS_WRITE_TIMEOUT = 20;
    localparam int AXIS_READ_TIMEOUT  = 50;

    logic [1:0] m_axi_bresp_fifo[$];
    logic [1:0] m_axi_rresp_fifo[$];

    export "DPI-C" task axi_lite_wr;
    export "DPI-C" task axi_lite_rd;

    initial begin
         m_axi_awaddr  <= 32'b0;
         m_axi_awvalid <= 1'b0;
         m_axi_wdata   <= 32'b0;
         m_axi_wstrb   <= 4'b0;
         m_axi_wvalid  <= 1'b0;
         m_axi_bready  <= 1'b0;
         m_axi_araddr  <= 32'b0;
         m_axi_arvalid <= 1'b0;
         m_axi_rready  <= 1'b0;
     end

    // AXI lite 32-bit write
    task axi_lite_wr (input int address, input int data);
        logic addr_done;
        logic data_done;

        @(posedge axi_aclk) begin
            m_axi_awaddr  <= address;
            m_axi_awvalid <= 1'b1;
            m_axi_wdata   <= data;
            m_axi_wstrb   <= 4'b1111;
            m_axi_wvalid  <= 1'b1;
            addr_done     <= m_axi_awready;
            data_done     <= m_axi_wready;
            m_axi_bresp_fifo.push_back(OKAY);
        end

        if (AXI_DEBUG)
            $display("** Info: Write address = 0x%h, data = 0x%h   %t ps", address, data, $time);

        for (int i = 0; i < AXIS_WRITE_TIMEOUT; i++) begin
            @(posedge axi_aclk) begin
                if (addr_done || m_axi_awready) begin
                    m_axi_awvalid <= 1'b0;
                    addr_done     <= 1'b1;
                end
                if (data_done || m_axi_wready) begin
                    m_axi_wvalid <= 1'b0;
                    data_done    <= 1'b1;
                end
                if (addr_done && data_done)
                   break;
            end
        end

        if (!(addr_done && data_done))
           $fatal(1, "** Error: Time-out for write data=%x to address=%x   %t ps", address, data, $time);
    endtask

    // AXI lite 32-bit read
    task axi_lite_rd (input int address, inout int data);
        logic addr_done;
        logic data_done;

        @(posedge axi_aclk) begin
            m_axi_araddr  <= address;
            m_axi_arvalid <= 1'b1;
            addr_done     <= m_axi_arready;
            data_done     <= m_axi_rvalid;
            m_axi_rready  <= 1'b1;
            m_axi_rresp_fifo.push_back(OKAY);
        end

        for (int i = 0; i < AXIS_READ_TIMEOUT; i++) begin
            @(posedge axi_aclk) begin
                if (addr_done || m_axi_arready) begin
                    m_axi_arvalid <= 1'b0;
                end
                if (data_done || m_axi_rvalid) begin
                    data <= m_axi_rdata;
                    m_axi_rready <= 1'b0;
                end
                if (addr_done && data_done) begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    break;
                end
                addr_done <= addr_done | m_axi_arready;
                data_done <= data_done | m_axi_rvalid;
            end
        end

        if (!(addr_done && data_done))
            $fatal(1, "Time-out for read at address = 0x%h   %t ps", address, $time);

        if (AXI_DEBUG)
            $display("** Info: Read address  = 0x%h, data = 0x%h   %t ps", address, data, $time);
    endtask

    // AXI4-lite bresp check
    logic [1:0] bresp_expect;
    int   mgmt_wr_err_cnt;
    int   mgmt_wr_ok_cnt;

    always @(posedge axi_aclk) begin : bresp_check
        if (!axi_aresetn) begin
            mgmt_wr_err_cnt <= '0;
            mgmt_wr_ok_cnt  <= '0;
        end
        else begin
            m_axi_bready <= 1'b1;
            if (m_axi_bvalid) begin
                if (m_axi_bready) begin
                    m_axi_bready <= 1'b0;
                    bresp_expect = m_axi_bresp_fifo.pop_front();
                    if (m_axi_bresp != bresp_expect) begin
                        $fatal(1, "Incorrect correct data %2b, expected %2b", m_axi_bresp, bresp_expect);
                        mgmt_wr_err_cnt <= mgmt_wr_err_cnt+1;
                    end
                    else begin
                        mgmt_wr_ok_cnt <= mgmt_wr_ok_cnt+1;
                    end
                end
                else begin
                    m_axi_bready <= 1'b1;
                end
            end
        end
    end

    // AXI4-lite rresp check
    logic [1:0] rresp_expect;
    int   mgmt_rd_err_cnt;
    int   mgmt_rd_ok_cnt;

    always @(posedge axi_aclk) begin : rresp_check
        if (!axi_aresetn) begin
            mgmt_rd_err_cnt <= '0;
            mgmt_rd_ok_cnt  <= '0;
        end
        else begin
            if (m_axi_rvalid && m_axi_rready) begin
                rresp_expect = m_axi_rresp_fifo.pop_front();
                if (m_axi_rresp != rresp_expect) begin
                    $fatal(1, "Incorrect correct data %2b, expected %2b", m_axi_rresp, rresp_expect);
                    mgmt_rd_err_cnt <= mgmt_rd_err_cnt + 1;
                end
                else begin
                    mgmt_rd_ok_cnt <= mgmt_rd_ok_cnt + 1;
                end
            end
        end
    end

    // --------------------------------------------------------------------------
    // Test sequence

    strArray table_entry_handles[string][$];
    strArray empty_strArray_list [$];
    strArray empty_strArray;
    strArray match_fields;
    strArray action_params;
    strArray cmd_line;
    string str_line;
    string command;
    string table_name;
    string action_name;
    int fh, delim_idx;
    int entry_priority;
    int entry_handle;
    bitArray key, mask;
    bitArray response;

    initial begin

        // Wait for reset signal to start
        @ (posedge axi_aresetn);
        for (int d=0; d<20; d++) @ (posedge axi_aclk);

        // instantiate drivers
        vitis_net_p4_forward_pkg::initialize("p4_router.vnp4_avmm_to_axi4lite.table_config");

        // open CLI commands file
        fh = $fopen($sformatf("./cli_commands.txt"), "r");
        if (!fh) begin
            $fatal(1, "** Error: Failed to open file './cli_commands.txt' file");
        end

        // read file lines
        while(!$feof(fh)) begin
            if($fgets(str_line, fh)) begin

                // remove '\n' at the end of line
                while (str_line[str_line.len()-1] == "\n")
                    str_line = str_line.substr(0, str_line.len()-2);

                // ignore comments and empty lines
                if (str_line[0] == "%"  ||
                    str_line[0] == "#"  ||
                    str_line[0] == "\n" ||
                    str_line.len() == 0)
                    continue;

                // split line and parse command
                cmd_line = split(str_line, " ");
                command = cmd_line[0];
                case (command)

                     // table_add <table name> <action name> <match fields> => [action parameters] [priority]
                     "table_add" : begin
                         // parse args
                         for (delim_idx = 1; delim_idx < cmd_line.size(); delim_idx++) begin
                             if (cmd_line[delim_idx] == "=>")
                                 break;
                         end
                         table_name   = cmd_line[1];
                         action_name  = cmd_line[2];
                         match_fields = cmd_line[3:delim_idx-1];
                         parse_match_fields(table_name, match_fields, key, mask);
                         split_action_params_and_prio(table_name, cmd_line[delim_idx+1:cmd_line.size()-1], action_params, entry_priority);
                         parse_action_parameters(table_name, action_name, action_params, response);
                         // execute command
                         if (VERBOSE) begin
                           $display("** Info: Adding entry to table %0s", table_name);
                           $display("  - match key:\t0x%0x", key);
                           $display("  - key mask:\t0x%0x", mask);
                           $display("  - response:\t0x%0x", response);
                           $display("  - priority:\t%0d", entry_priority);
                         end
                         vitis_net_p4_forward_pkg::table_add(table_name, key, mask, response, entry_priority);
                         // create entry handle
                         if (!table_entry_handles.exists(table_name))
                             table_entry_handles[table_name] = empty_strArray_list;
                         for (int i = 0; i <= table_entry_handles[table_name].size(); i++) begin
                             if (i == table_entry_handles[table_name].size())
                                table_entry_handles[table_name][i] = empty_strArray;
                             if (table_entry_handles[table_name][i].size() == 0) begin
                                 table_entry_handles[table_name][i] = match_fields;
                                 entry_handle = i;
                                 break;
                             end
                         end
                         if (VERBOSE)
                           $display("** Info: Entry has been added with handle %0d", entry_handle);
                     end

                     // table_modify <table name> <action name> <entry handle> [action parameters]
                     "table_modify" : begin
                         // parse args
                         table_name    = cmd_line[1];
                         action_name   = cmd_line[2];
                         entry_handle  = cmd_line[3].atoi();
                         action_params = cmd_line[4:cmd_line.size()-1];
                         parse_action_parameters(table_name, action_name, action_params, response);
                         // get entry handle
                         if (!table_entry_handles.exists(table_name)) begin
                             $fatal(1, "** Error: Table entry '%0d' not found for table '%0s'", entry_handle, table_name);
                         end
                         if (table_entry_handles[table_name][entry_handle].size() == 0) begin
                             $fatal(1, "** Error: Table entry '%0d' not found for table '%0s'", entry_handle, table_name);
                         end
                         match_fields = table_entry_handles[table_name][entry_handle];
                         parse_match_fields(table_name, match_fields, key, mask);
                         // execute command
                         if (VERBOSE) begin
                           $display("** Info: Modifying entry from table %0s", table_name);
                           $display("  - response:\t0x%0x", response);
                         end
                         vitis_net_p4_forward_pkg::table_modify(table_name, key, mask, response);
                         if (VERBOSE)
                           $display("** Info: Entry has been modified with handle %0d", entry_handle);
                     end

                     // table_delete <table name> <entry handle>
                     "table_delete" : begin
                         // parse args
                         table_name   = cmd_line[1];
                         entry_handle = cmd_line[2].atoi();
                         // get entry handle
                         if (!table_entry_handles.exists(table_name)) begin
                             $fatal(1, "** Error: Table entry '%0d' not found for table '%0s'", entry_handle, table_name);
                         end
                         if (table_entry_handles[table_name][entry_handle].size() == 0) begin
                             $fatal(1, "** Error: Table entry '%0d' not found for table '%0s'", entry_handle, table_name);
                         end
                         match_fields = table_entry_handles[table_name][entry_handle];
                         parse_match_fields(table_name, match_fields, key, mask);
                         // execute command
                         if (VERBOSE) begin
                           $display("** Info: Deleting entry from table %0s", table_name);
                           $display("  - match key:\t0x%0x", key);
                           $display("  - key mask:\t0x%0x", mask);
                         end
                         vitis_net_p4_forward_pkg::table_delete(table_name, key, mask);
                         if (VERBOSE)
                           $display("** Info: Entry has been deleted with handle %0d", entry_handle);
                         // delete entry handle
                         table_entry_handles[table_name][entry_handle] = empty_strArray;
                     end

                     // table_clear <table name>
                     "table_clear" : begin
                         table_name = cmd_line[1];
                         for (int i = 0; i <= table_entry_handles[table_name].size(); i++) begin
                             if (table_entry_handles[table_name][entry_handle].size() > 0) begin
                                 match_fields = table_entry_handles[table_name][entry_handle];
                                 parse_match_fields(table_name, match_fields, key, mask);
                                 vitis_net_p4_forward_pkg::table_delete(table_name, key, mask);
                             end
                         end
                     end

                     // reset_state
                     "reset_state" : begin
                         $display("** Info: Reseting 'vitis_net_p4_forward' to default state");
                         vitis_net_p4_forward_pkg::reset_state();
                     end

                     // exit
                     "exit" : begin
                         break;
                     end

                     "wait" : begin
                        forever #1;
                     end

                     // ignore invalid commands
                     default : begin
                         $display("** Info: Ignoring invalid command '%0s'", command);
                         continue;
                     end

                endcase
            end
        end

        // destroy instantiated drivers
        vitis_net_p4_forward_pkg::terminate();

    end

endmodule
