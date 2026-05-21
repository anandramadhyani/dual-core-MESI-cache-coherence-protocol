`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 25.04.2026 19:37:38
// Design Name: Core Generator Testbench
// Module Name: tb_core_gen
// Project Name: MESI Protocol
// Target Devices: Zybo 20
// Tool Versions: 
// Description: 
// 
// Dependencies: COre Generator Design
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_core_gen
     #(parameter ADDR_WIDTH = 32,
       parameter DATA_WIDTH = 32,
       parameter MAX_DELAY_WIDTH = 10)(

    );
    
        reg clk;
        reg reset;
        reg start;
        wire done;
        
        wire req_valid;
        reg req_ready;
        wire req_rw;
        wire [(ADDR_WIDTH - 1) : 0] req_addr;
        wire [(DATA_WIDTH - 1) : 0] req_data;
        wire [((DATA_WIDTH/ 8) - 1) : 0] req_strb;
        
        reg resp_valid;
        wire resp_ready;
        reg [(DATA_WIDTH - 1) : 0] resp_rdata;
        
        //------------------------------UUT Module Instantiation----------------------------
        core_gen
            #(.ADDR_WIDTH (ADDR_WIDTH),
              .DATA_WIDTH (DATA_WIDTH),
              .MAX_DELAY_WIDTH (MAX_DELAY_WIDTH)) UUT (
            
            .clk (clk),
            .reset (reset),
            .start (start),
            .done (done),
            
            .req_valid (req_valid),
            .req_ready (req_ready),
            .req_rw (req_rw),
            .req_addr (req_addr),
            .req_data (req_data),
            .req_strb (req_strb),
            
            .resp_valid (resp_valid),
            .resp_ready (resp_ready),
            .resp_rdata (resp_rdata)
        );
        
        //-------------------------------Clock Generation------------------------------------
        initial begin
            clk = 1'b0;
            forever begin
                #5 clk = ~ clk;
            end
        end
        
        //-------------------------------Reset Assertion-------------------------------------
        initial begin
            reset = 1'b0;
            @(posedge clk)
                reset = 1'b1;
            @(posedge clk)
                reset = 1'b0;                
        end
        
        //-------------------------------Initialize Testbench Signals--------------------------
        initial begin
            start = 1'b0;
            req_ready = 1'b0;
            resp_valid = 1'b0;
            resp_rdata = {DATA_WIDTH{1'b0}};
        end
        
        //-------------------------------Provide Stimulus------------------------------------
        initial begin
            repeat (5)
                @(posedge clk);
            start = 1'b1;
            @(posedge clk)
                start = 1'b0; 
            repeat (10) begin    
                wait (req_valid);
                @(posedge clk)
                    req_ready = 1'b1;
                @(posedge clk)
                    req_ready = 1'b0; 
                repeat (13)
                    @(posedge clk);
                resp_valid = 1'b1;
                resp_rdata = $random;
                @(posedge clk)
                    resp_valid = 1'b0;
                    resp_rdata = {DATA_WIDTH{1'b0}}; 
            end     
        end
endmodule
