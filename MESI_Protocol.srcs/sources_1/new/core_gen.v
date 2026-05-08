`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 25.04.2026 17:17:03
// Design Name: Core Generator Design
// Module Name: core_gen
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


module core_gen
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32,
      parameter MAX_DELAY_WIDTH = 10)(
        
        input wire clk,
        input wire reset,
        input wire start,
        output reg done,
        
        //---------------------------------Cache Side------------------------------
        output reg req_valid,
        input wire req_ready,
        output reg req_rw,
        output reg [(ADDR_WIDTH - 1) : 0] req_addr,
        output reg [(DATA_WIDTH - 1) : 0] req_data,
        output reg [((DATA_WIDTH/ 8) - 1) : 0] req_strb,
        
        input wire resp_valid,
        output reg resp_ready,
        input wire [(DATA_WIDTH - 1) : 0] resp_rdata
    );
    
    localparam STRB_WIDTH = DATA_WIDTH/ 8;
    localparam PC_WIDTH = 6;
    
    localparam IDLE = 4'd0;
    localparam FETCH_ADDR = 4'd1;
    localparam FETCH_DATA = 4'd2;
    localparam DECODE = 4'd3;
    localparam ISSUE_REQ = 4'd4;
    localparam WAIT_RESP = 4'd5;
    localparam DELAY = 4'd6;
    localparam DONE = 4'd7;
    localparam LATCH_ADDR = 4'd8;
    localparam LATCH_DATA = 4'd9;
    localparam DUMMY_ADDR = 4'd10;
    localparam DUMMY_DATA = 4'd11;
    
    localparam OP_READ = 4'b0001;
    localparam OP_WRITE = 4'b0010;
    localparam OP_DELAY = 4'b0011;
    localparam OP_END = 4'b1111;
    
    reg [3 : 0] state, next_state;
    reg prog_rom_ena;
    reg [(PC_WIDTH - 1) : 0] pc;
    reg [(ADDR_WIDTH - 1) : 0] instr;
    reg [(DATA_WIDTH - 1) : 0] wdata_reg, rdata_reg;
    wire [(DATA_WIDTH - 1) : 0] prog_rom_out;
    reg [(MAX_DELAY_WIDTH - 1) : 0] delay_counter_value, prog_delay_value;
    wire [3 : 0] opcode = instr[(ADDR_WIDTH - 1) : ((ADDR_WIDTH - 1) - 3)];
    
    //--------------------------------------Instruction Memory-------------------------------------
    Core_0_Instr_mem INSTR_MEM (
        .clka(clk),    // input wire clka
        .ena(prog_rom_ena),      // input wire ena
        .addra(pc),  // input wire [3 : 0] addra
        .douta(prog_rom_out)  // output wire [31 : 0] douta
    );
        
    //-------------------------------Program Counter------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= {PC_WIDTH{1'b0}};
        end        
        else begin            
            case (state)
                IDLE: begin
                    
                end
                
                DECODE: begin
                    if (opcode == OP_WRITE) begin
                        pc <= pc + 1;
                    end
                    if (opcode == OP_DELAY) begin
                        pc <= pc + 1;
                    end
                end
                                
                WAIT_RESP: begin
                    if (resp_valid) begin
                        pc <= pc + 1;
                    end
                end
                
                default: begin
                    pc <= pc;
                end
            endcase
        end
    end
    
    //---------------------------------Sequential Logic--------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instr <= {ADDR_WIDTH{1'b0}};
            wdata_reg <= {DATA_WIDTH{1'b0}};
            rdata_reg <= {DATA_WIDTH{1'b0}};
            delay_counter_value <= {MAX_DELAY_WIDTH{1'b0}};
        end
        else begin
            case (state)
                IDLE: begin
                    instr <= {ADDR_WIDTH{1'b0}};
                    wdata_reg <= {DATA_WIDTH{1'b0}};
                    rdata_reg <= {DATA_WIDTH{1'b0}};
                    delay_counter_value <= {MAX_DELAY_WIDTH{1'b0}};
                end
                
                LATCH_ADDR: begin
                    instr <= prog_rom_out;
                    delay_counter_value <= {MAX_DELAY_WIDTH{1'b0}};
                end
                
                LATCH_DATA: begin
                    wdata_reg <= prog_rom_out;
                end
                
                DELAY: begin
                    delay_counter_value <= delay_counter_value + 1;
                end
                
                WAIT_RESP: begin
                    if (resp_valid) begin
                        rdata_reg <= resp_rdata;
                    end                    
                end
                
                default: begin
                    
                end
            endcase
        end
    end
    
    //-----------------------------------------State Register---------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    //---------------------------------------Next State--------------------------------------    
    always @(*) begin
        next_state = state;
        prog_rom_ena = 1'b0;
        
        case(state)
            IDLE: begin
                if (start) begin
                    next_state = FETCH_ADDR;
                end
            end
            
            FETCH_ADDR: begin
                prog_rom_ena = 1'b1;
                next_state = DUMMY_ADDR;
            end
            
            DUMMY_ADDR: begin
                prog_rom_ena = 1'b1;
                next_state = LATCH_ADDR;
            end
            
            LATCH_ADDR: begin
                next_state = DECODE;
            end
            
            FETCH_DATA: begin
                prog_rom_ena = 1'b1;
                next_state = DUMMY_DATA;
            end
            
            DUMMY_DATA: begin
                prog_rom_ena = 1'b1;
                next_state = LATCH_DATA;
            end
            
            LATCH_DATA: begin
                next_state = ISSUE_REQ;
            end
            
            DECODE: begin
                case(opcode)
                    OP_READ: begin
                        next_state = ISSUE_REQ;
                    end
                    
                    OP_WRITE: begin
                        next_state = FETCH_DATA;
                    end
                    
                    OP_DELAY: begin
                        prog_delay_value = instr[(MAX_DELAY_WIDTH -1) : 0];
                        next_state = DELAY;
                    end
                    
                    OP_END: begin
                        next_state = DONE;
                    end
                endcase
            end
            
            ISSUE_REQ: begin
                if (req_ready) begin
                    next_state = WAIT_RESP;
                end
            end
            
            WAIT_RESP: begin
                if (resp_valid) begin
                    next_state = FETCH_ADDR;
                end
            end
            
            DELAY: begin
                if (delay_counter_value == prog_delay_value) begin
                    next_state = FETCH_ADDR;
                end
            end
            
            DONE: begin
                
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //-------------------------------------------Output---------------------------------------
    always @(*) begin
        req_valid = 1'b0;
        req_rw = 1'b0;
        req_addr = {ADDR_WIDTH{1'b0}};
        req_data = {DATA_WIDTH{1'b0}};
        req_strb = {STRB_WIDTH{1'b0}};
        resp_ready = 1'b0;
        done = 1'b0;
        
        case (state)
            IDLE: begin
               
            end
            
            FETCH_ADDR: begin
            
            end
            
            DUMMY_ADDR: begin
               
            end
            
            LATCH_ADDR: begin
                
            end
            
            FETCH_DATA: begin
                
            end
            
            DUMMY_DATA: begin
                
            end
            
            LATCH_DATA: begin
                
            end
            
            DECODE: begin
                
            end
            
            ISSUE_REQ: begin
                case (opcode)
                    OP_READ: begin
                        req_valid = 1'b1;
                        req_rw = 1'b0;
                        req_addr = {2'b00, instr[((ADDR_WIDTH - 1) - 4) : 0], 2'b00};
                    end
                    
                    OP_WRITE: begin
                        req_valid = 1'b1;
                        req_rw = 1'b1;
                        req_addr = {2'b00, instr[((ADDR_WIDTH - 1) - 4) : 0], 2'b00};
                        req_data = wdata_reg;
                        req_strb = {STRB_WIDTH{1'b1}};
                    end
                    
                    OP_DELAY: begin
                    
                    end
                    
                    OP_END: begin
                    
                    end                
                endcase
            end
            
            WAIT_RESP: begin
                resp_ready = 1'b1;
            end
            
            DELAY: begin
                
            end
            
            DONE: begin
                done = 1'b1;
            end
            
            default: begin
                
            end 
        endcase
    end
    
endmodule
