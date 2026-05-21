`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha 
// 
// Create Date: 06.05.2026 17:54:56
// Design Name: Top Module Testbench
// Module Name: tb_top_module
// Project Name: MESI Protocol
// Target Devices: Zybo 20
// Tool Versions: 
// Description: 
// 
// Dependencies: Top Module Design
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top_module
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32)(

    );
    
    reg clk;
    reg reset;
    reg start;
    wire done;
    
    top_module
    #(.ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH)) UUT (
        .clk (clk),
        .reset (reset),
        
        .start (start),
        .done (done)
    );
    
    //-------------------------------Clock Generation----------------------------
    initial begin
        clk = 1'b0;
        forever begin
            #5 clk = ~ clk;
        end
    end
    
    //------------------------------Reset Assertion------------------------------
    initial begin
        reset = 1'b0;
        @(posedge clk)
            reset = 1'b1;
        @(posedge clk)
            reset = 1'b0;
    end
    
    //-----------------------------Stimulus--------------------------------------
    initial begin
        start = 1'b0;
        repeat (5)
            @(posedge clk);
        start = 1'b1;
        @(posedge clk)
            start = 1'b0;    
    end
    
    //------------------------------Finish Simulation----------------------------
    initial begin
        #2500 $finish;
    end
    
endmodule
