`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 27.04.2026 19:47:07
// Design Name: L1 Cache Testbench
// Module Name: tb_l1_cache
// Project Name: MESI Protocol
// Target Devices: Zybo 20
// Tool Versions: 
// Description: 
// 
// Dependencies: L1 Cache Design
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_l1_cache
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32,
      parameter WAYS = 2,
      parameter SETS = 32,
      parameter LINE_BYTES = 32,
      parameter CMD_WIDTH = 2,
      parameter ID_WIDTH = 1,
      parameter CACHE_ID = 0)(

    );
    
    //----------------------------------Global Signals-------------------------------
    reg clk;
    reg reset;
    
    //----------------------------------Core Interface------------------------------
    reg req_valid;
    wire req_ready;
    reg req_rw;
    reg [(ADDR_WIDTH - 1) : 0] req_addr;
    reg [(DATA_WIDTH - 1) : 0] req_data;
    reg [(DATA_WIDTH/ 8) : 0] req_strb;
    reg resp_ready;
    wire resp_valid;
    wire [(DATA_WIDTH - 1) : 0] resp_rdata;
    
    //--------------------------------Bus Interface-----------------------------
    reg bus_req_ready;
    wire bus_req_valid;                
    wire [(CMD_WIDTH - 1) : 0] bus_req_cmd;                
    wire [(ADDR_WIDTH - 1) : 0] bus_req_addr;                
    wire [((LINE_BYTES * 8) - 1) : 0] bus_req_data;
    reg bus_resp_valid;
    reg bus_resp_shared;
    reg [((LINE_BYTES * 8) - 1) : 0] bus_resp_rdata;
    
    //--------------------------------Snoop Interface-----------------------------  
    reg snoop_valid;              
    reg [(CMD_WIDTH - 1) : 0] snoop_cmd;
    reg [(ADDR_WIDTH - 1) : 0] snoop_addr;
    reg [(ID_WIDTH - 1) : 0] snoop_src_id;
    wire snoop_hit;
    wire snoop_dirty;
    wire snoop_data_valid;
    wire [((LINE_BYTES * 8) - 1) : 0] snoop_data;
    
    //----------------------------Module Instantiation---------------------------
    l1_cache
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .WAYS (WAYS),
      .SETS (SETS),
      .LINE_BYTES (LINE_BYTES),
      .CMD_WIDTH (CMD_WIDTH),
      .ID_WIDTH (ID_WIDTH),
      .CACHE_ID (CACHE_ID)) UUT (
        
        //----------------------------------Global Signals-------------------------------
        .clk (clk),
        .reset (reset),
        
        //----------------------------------Core Interface------------------------------
        .req_valid (req_valid),
        .req_ready (req_ready),
        .req_rw (req_rw),
        .req_addr (req_addr),
        .req_data (req_data),
        .req_strb (req_strb),
        .resp_ready (resp_ready),
        .resp_valid (resp_valid),
        .resp_rdata (resp_rdata),
        
        //--------------------------------Bus Interface-----------------------------
        .bus_req_ready (bus_req_ready),
        .bus_req_valid (bus_req_valid),                
        .bus_req_cmd (bus_req_cmd),                
        .bus_req_addr (bus_req_ad),                
        .bus_req_data (bus_req_data),
        .bus_resp_valid (bus_resp_valid),
        .bus_resp_shared (bus_resp_shared),
        .bus_resp_rdata (bus_resp_rdata),
        
        //--------------------------------Snoop Interface-----------------------------  
        .snoop_valid (snoop_valid),              
        .snoop_cmd (snoop_cmd),
        .snoop_addr (snoop_addr),
        .snoop_src_id (snoop_src_id),
        .snoop_hit (snoop_hit),
        .snoop_dirty (snoop_dirty),
        .snoop_data_valid (snoop_data_valid),
        .snoop_data (snoop_data)
    );
    
        //---------------------------------Clock Generation--------------------------
        initial begin
            clk = 1'b0;
            forever begin
                #5 clk = ~ clk;
            end
        end
        
        //--------------------------------Reset Asssertion---------------------------
        initial begin
            reset = 1'b0;
            @(posedge clk)
                reset = 1'b1;
            @(posedge clk)
                reset = 1'b0;
        end
        
        //---------------------------Initialize Testbench Signals---------------------
        initial begin
            
        end
endmodule
