`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 26.04.2026 17:28:44
// Design Name: Main Memory Testbench
// Module Name: tb_main_memory
// Project Name: MESI Protocol
// Target Devices: Zybo 20
// Tool Versions: 
// Description: 
// 
// Dependencies: Main Memory Design
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_main_memory
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32,
      parameter DEPTH = 256)(

    );
    
    reg clk;
    reg reset;
    
    reg mem_req_valid;
    wire mem_req_ready;
    reg mem_req_rw;
    reg [(ADDR_WIDTH - 1) : 0] mem_req_addr;
    reg [((DATA_WIDTH * 8) - 1) : 0] mem_req_data;
    wire mem_resp_valid;
    wire [((DATA_WIDTH * 8) - 1) : 0] mem_resp_rdata; 
    
    localparam LINE_WIDTH = DATA_WIDTH * 8;
    
    //--------------------------UUT Module Instantiation----------------------
    main_memory
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .DEPTH (DEPTH)) UUT (
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
    
    //------------------------Clock Generation-------------------------------
    initial begin
        clk = 1'b0;
        forever begin
            #5 clk = ~ clk;
        end
    end
    
    //-------------------------Reset Assertion-------------------------------
    initial begin
        reset = 1'b0;
        @(posedge clk)
            reset = 1'b1;
        @(posedge clk)
            reset = 1'b0;
    end
    
    //---------------------Testbench Signal Initialization------------------
    initial begin
        mem_req_valid = 1'b0;
        mem_req_rw = 1'b0;
        mem_req_addr = {ADDR_WIDTH{1'b0}};
        mem_req_data = {LINE_WIDTH{1'b0}};
    end
            
    //-------------------------Stimulus--------------------------------------
    initial begin
        repeat (5)
            @(posedge clk);
        mem_req_valid = 1'b1;
        mem_req_rw = 1'b0;
        mem_req_addr = 32'h10000040;
        mem_req_data = $random;
        @(posedge clk)
            mem_req_valid = 1'b0;
        
        repeat (15)
            @(posedge clk);
        mem_req_valid = 1'b1;
        mem_req_rw = 1'b1;
        mem_req_addr = 32'h10000050;
        mem_req_data = $random;
        @(posedge clk)
            mem_req_valid = 1'b0;     
        
        repeat (15)
            @(posedge clk);
        mem_req_valid = 1'b1;
        mem_req_rw = 1'b0;
        mem_req_addr = 32'h10000040;
        mem_req_data = $random;
        @(posedge clk)
            mem_req_valid = 1'b0;            
    end
endmodule
