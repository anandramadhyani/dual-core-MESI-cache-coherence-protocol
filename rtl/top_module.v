`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 05.05.2026 22:36:02
// Design Name: Top Module
// Module Name: top_module
// Project Name: MESI Protocol
// Target Devices: Zybo 20
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


module top_module
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32)(
        input wire clk,
        input wire reset,
        
        input wire start,
        output wire done
    );
    
    //----------------------------Local Parameters--------------------------------
    localparam MAX_DELAY_WIDTH = 10;
    localparam STRB_WIDTH = DATA_WIDTH/ 8;
    localparam LINE_BYTES = 32;
    localparam LINE_WIDTH_IN_BITS = LINE_BYTES * 8;
    localparam WAYS = 2;
    localparam SETS = 32;
    localparam CMD_WIDTH = 2;    
    localparam ID_WIDTH = 1;    
    localparam CACHE_0_ID = 0;    
    localparam CACHE_1_ID = 1;    
    localparam DEPTH = 256;    
    
    wire done_core0, done_core1;
    assign done = done_core0 & done_core1;
    
    //-------------------------Core Interface Net Declarations--------------------
    wire core0_req_valid, core1_req_valid;
    wire core0_req_ready, core1_req_ready;
    wire core0_req_rw, core1_req_rw;
    wire [(ADDR_WIDTH - 1) : 0] core0_req_addr, core1_req_addr;
    wire [(DATA_WIDTH - 1) : 0] core0_req_data, core1_req_data;
    wire [(STRB_WIDTH - 1) : 0] core0_req_strb, core1_req_strb;
    wire core0_resp_valid, core1_resp_valid;
    wire core0_resp_ready, core1_resp_ready;
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] core0_resp_rdata, core1_resp_rdata;
    
    //-----------------------Cache-Bus Interface Net Declarations------------------
    wire cache0_bus_req_valid, cache1_bus_req_valid;
    wire cache0_bus_req_ready, cache1_bus_req_ready;
    wire [(CMD_WIDTH - 1) : 0] cache0_bus_req_cmd, cache1_bus_req_cmd;
    wire [(ADDR_WIDTH - 1) : 0] cache0_bus_req_addr, cache1_bus_req_addr;
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] cache0_bus_req_data, cache1_bus_req_data;
    wire cache0_bus_resp_valid, cache1_bus_resp_valid;
    wire cache0_bus_resp_shared, cache1_bus_resp_shared;
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] cache0_bus_resp_rdata, cache1_bus_resp_rdata;
    
    //----------------------Cache-Snoop Interface Net Declarations----------------
    wire cache0_snoop_hit, cache1_snoop_hit;
    wire cache0_snoop_dirty, cache1_snoop_dirty;
    wire cache0_snoop_data_valid, cache1_snoop_data_valid;
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] cache0_snoop_data, cache1_snoop_data;
    
    wire bus_snoop_valid;
    wire [(CMD_WIDTH - 1) : 0] bus_snoop_cmd;
    wire [(ADDR_WIDTH - 1) : 0] bus_snoop_addr;
    wire [(ID_WIDTH - 1) : 0] bus_snoop_src_id;
    
    //------------------------Bus-Memory Interface Net Declarations---------------
    wire mem_req_valid; 
    wire mem_req_ready;
    wire mem_req_rw;
    wire [(ADDR_WIDTH - 1) : 0] mem_req_addr;
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] mem_req_data;
    wire mem_resp_valid;
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] mem_resp_rdata;    
    
    //-----------------------------Core Generator 0--------------------------------
    core_gen
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .MAX_DELAY_WIDTH (MAX_DELAY_WIDTH)) CORE_GEN_0 (
        
        .clk (clk),
        .reset (reset),
        .start (start),
        .done (done_core0),
                
        .req_valid (core0_req_valid),
        .req_ready (core0_req_ready),
        .req_rw (core0_req_rw),
        .req_addr (core0_req_addr),
        .req_data (core0_req_data),
        .req_strb (core0_req_strb),
        
        .resp_valid (core0_resp_valid),
        .resp_ready (core0_resp_ready),
        .resp_rdata (core0_resp_rdata)
    );
    
    //-----------------------------Core Generator 0-------------------------------
    core_gen1
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .MAX_DELAY_WIDTH (MAX_DELAY_WIDTH)) CORE_GEN_1 (
        
        .clk (clk),
        .reset (reset),
        .start (start),
        .done (done_core1),
                
        .req_valid (core1_req_valid),
        .req_ready (core1_req_ready),
        .req_rw (core1_req_rw),
        .req_addr (core1_req_addr),
        .req_data (core1_req_data),
        .req_strb (core1_req_strb),
        
        .resp_valid (core1_resp_valid),
        .resp_ready (core1_resp_ready),
        .resp_rdata (core1_resp_rdata)
    );
    
    //----------------------------Private L1 Cache 0--------------------------------
    l1_cache
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .WAYS (WAYS),
      .SETS (SETS),
      .LINE_BYTES (LINE_BYTES),
      .CMD_WIDTH (CMD_WIDTH),
      .ID_WIDTH (ID_WIDTH),
      .CACHE_ID (CACHE_0_ID)) L1_CACHE_0 (
       
        .clk (clk),
        .reset (reset),
        
        .req_valid (core0_req_valid),
        .req_ready (core0_req_ready),
        .req_rw (core0_req_rw),
        .req_addr (core0_req_addr),
        .req_data (core0_req_data),
        .req_strb (core0_req_strb),
        .resp_ready (core0_resp_ready),
        .resp_valid (core0_resp_valid),
        .resp_rdata (core0_resp_rdata),
        
        .bus_req_ready (cache0_bus_req_ready),
        .bus_req_valid (cache0_bus_req_valid),                
        .bus_req_cmd (cache0_bus_req_cmd),                
        .bus_req_addr (cache0_bus_req_addr),                
        .bus_req_data (cache0_bus_req_data),
        .bus_resp_valid (cache0_bus_resp_valid),
        .bus_resp_shared (cache0_bus_resp_shared),
        .bus_resp_rdata (cache0_bus_resp_rdata),
        
        .snoop_valid (bus_snoop_valid),              
        .snoop_cmd (bus_snoop_cmd),
        .snoop_addr (bus_snoop_addr),
        .snoop_src_id (bus_snoop_src_id),
        .snoop_hit (cache0_snoop_hit),
        .snoop_dirty (cache0_snoop_dirty),
        .snoop_data_valid (cache0_snoop_data_valid),
        .snoop_data (cache0_snoop_data)
    );
    
    //----------------------------Private L1 Cache 1--------------------------------
    l1_cache
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .WAYS (WAYS),
      .SETS (SETS),
      .LINE_BYTES (LINE_BYTES),
      .CMD_WIDTH (CMD_WIDTH),
      .ID_WIDTH (ID_WIDTH),
      .CACHE_ID (CACHE_1_ID)) L1_CACHE_1 (
       
        .clk (clk),
        .reset (reset),
        
        .req_valid (core1_req_valid),
        .req_ready (core1_req_ready),
        .req_rw (core1_req_rw),
        .req_addr (core1_req_addr),
        .req_data (core1_req_data),
        .req_strb (core1_req_strb),
        .resp_ready (core1_resp_ready),
        .resp_valid (core1_resp_valid),
        .resp_rdata (core1_resp_rdata),
        
        .bus_req_ready (cache1_bus_req_ready),
        .bus_req_valid (cache1_bus_req_valid),                
        .bus_req_cmd (cache1_bus_req_cmd),                
        .bus_req_addr (cache1_bus_req_addr),                
        .bus_req_data (cache1_bus_req_data),
        .bus_resp_valid (cache1_bus_resp_valid),
        .bus_resp_shared (cache1_bus_resp_shared),
        .bus_resp_rdata (cache1_bus_resp_rdata),
        
        .snoop_valid (bus_snoop_valid),              
        .snoop_cmd (bus_snoop_cmd),
        .snoop_addr (bus_snoop_addr),
        .snoop_src_id (bus_snoop_src_id),
        .snoop_hit (cache1_snoop_hit),
        .snoop_dirty (cache1_snoop_dirty),
        .snoop_data_valid (cache1_snoop_data_valid),
        .snoop_data (cache1_snoop_data)
    );
    
    //---------------------------------Shared Snoop Bus-----------------------------
    shared_snoop_bus 
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .LINE_BYTES (LINE_BYTES),
      .CMD_WIDTH (CMD_WIDTH),
      .ID_WIDTH (ID_WIDTH)) SNOOP_BUS (
        
        .clk (clk),
        .reset (reset),
        
        //------------------------------Cache 0 Interface-------------------------
        .c0_req_valid (cache0_bus_req_valid),
        .c0_req_ready (cache0_bus_req_ready),
        .c0_req_cmd (cache0_bus_req_cmd),
        .c0_req_addr (cache0_bus_req_addr),
        .c0_req_data (cache0_bus_req_data),
        .c0_resp_valid (cache0_bus_resp_valid),
        .c0_resp_shared (cache0_bus_resp_shared),
        .c0_resp_rdata (cache0_bus_resp_rdata), 
                        
        //------------------------------Cache 1 Interface-------------------------
        .c1_req_valid (cache1_bus_req_valid),
        .c1_req_ready (cache1_bus_req_ready),
        .c1_req_cmd (cache1_bus_req_cmd),
        .c1_req_addr (cache1_bus_req_addr),
        .c1_req_data (cache1_bus_req_data),
        .c1_resp_valid (cache1_bus_resp_valid),
        .c1_resp_shared (cache1_bus_resp_shared),
        .c1_resp_rdata (cache1_bus_resp_rdata),
        
        //------------------------------Snoop Interface---------------------------
        .c0_snoop_hit (cache0_snoop_hit),
        .c0_snoop_dirty (cache0_snoop_dirty),
        .c0_snoop_data_valid (cache0_snoop_data_valid),
        .c0_snoop_data (cache0_snoop_data),
        
        .c1_snoop_hit (cache1_snoop_hit),
        .c1_snoop_dirty (cache1_snoop_dirty),
        .c1_snoop_data_valid (cache1_snoop_data_valid),
        .c1_snoop_data (cache1_snoop_data),
        
        .snoop_valid (bus_snoop_valid),
        .snoop_cmd (bus_snoop_cmd),
        .snoop_addr (bus_snoop_addr),
        .snoop_src_id (bus_snoop_src_id),
        
        //------------------------------Memory Interface--------------------------
        .mem_req_ready (mem_req_ready),
        .mem_req_valid (mem_req_valid),
        .mem_req_rw (mem_req_rw),
        .mem_req_addr (mem_req_addr),
        .mem_req_data (mem_req_data),
        .mem_resp_valid (mem_resp_valid),
        .mem_resp_rdata (mem_resp_rdata)
    );
    
    //-------------------------------Main Memory----------------------------------
    main_memory
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .DEPTH (DEPTH)) RAM (
        .clk (clk),
        .reset (reset),
        
        .mem_req_valid (mem_req_valid),
        .mem_req_ready (mem_req_ready),
        .mem_req_rw (mem_req_rw),
        .mem_req_addr (mem_req_addr),
        .mem_req_data (mem_req_data),
        .mem_resp_valid (mem_resp_valid),
        .mem_resp_rdata (mem_resp_rdata)       
    );        
    
endmodule
