`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 26.04.2026 17:28:19
// Design Name: Main Memory Design
// Module Name: main_memory
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


module main_memory
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32,
      parameter DEPTH = 256)(
        input wire clk,
        input wire reset,
        
        input wire mem_req_valid,
        output reg mem_req_ready,
        input wire mem_req_rw,
        input wire [(ADDR_WIDTH - 1) : 0] mem_req_addr,
        input wire [((DATA_WIDTH * 8) - 1) : 0] mem_req_data,
        output reg mem_resp_valid,
        output reg [((DATA_WIDTH * 8) - 1) : 0] mem_resp_rdata       
    );
    
    localparam READ_LATENCY = 10;
    localparam LINE_WIDTH = DATA_WIDTH * 8;
    localparam LINE_INDEX = $clog2(DEPTH);
    
    localparam IDLE = 3'd0;
    localparam LATCH_REQ = 3'd1;
    localparam READ_WAIT = 3'd2;
    localparam READ_RESP = 3'd3;
    localparam WRITE_COMMIT = 3'd4;
    
    reg [2 : 0] state, next_state;
    reg latched_req_rw;
    reg [(ADDR_WIDTH - 1) : 0] latched_req_addr;
    reg [(LINE_WIDTH - 1) : 0] latched_req_data, read_data_reg;
    reg [3 : 0] latency_counter; 
    
    wire [(LINE_INDEX - 1) : 0] line_address = latched_req_addr[12 : 5];
    reg ena_ram, wr_en;
    wire [(LINE_WIDTH - 1) : 0] ram_output;
        
    //----------------------------Main Memory Array--------------------------       
    RAM MAIN_MEMORY (
      .clka(clk),    // input wire clka
      .ena(ena_ram),      // input wire ena
      .wea(wr_en),      // input wire [0 : 0] wea
      .addra(line_address),  // input wire [7 : 0] addra
      .dina(latched_req_data),    // input wire [255 : 0] dina
      .douta(ram_output)  // output wire [255 : 0] douta
    );
    
    //---------------------------State Register-------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    //----------------------------Sequential Logic----------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            latched_req_rw <= 1'b0;
            latched_req_addr <= {ADDR_WIDTH{1'b0}};
            latched_req_data <= {LINE_WIDTH{1'b0}};
            read_data_reg <= {LINE_WIDTH{1'b0}};
            latency_counter <= 4'd0;                        
        end
        else begin
            case (state)
                IDLE: begin
                    latched_req_rw <= 1'b0;
                    latched_req_addr <= {ADDR_WIDTH{1'b0}};
                    latched_req_data <= {LINE_WIDTH{1'b0}};
                    read_data_reg <= {LINE_WIDTH{1'b0}};
                    latency_counter <= 4'd0;
                end
                
                LATCH_REQ: begin
                    latched_req_rw <= mem_req_rw;
                    latched_req_addr <= mem_req_addr;
                    latched_req_data <= mem_req_data;
                    if (mem_req_rw == 1'b0) begin
                        latency_counter <= READ_LATENCY;
                    end
                end
                
                READ_WAIT: begin
                    latency_counter <= latency_counter - 1;
                    read_data_reg <= ram_output;
                end
                
                READ_RESP: begin
                    
                end
                
                WRITE_COMMIT: begin
                    
                end
                
                default: begin
                    latched_req_rw <= 1'b0;
                    latched_req_addr <= {ADDR_WIDTH{1'b0}};
                    latched_req_data <= {LINE_WIDTH{1'b0}};
                    latency_counter <= 4'd0;
                end
            endcase
        end
    end
    
    //-----------------------------Next State Logic---------------------------
    always @(*) begin
        next_state = state;
        ena_ram = 1'b0;
        wr_en = 1'b0;
        case (state)
            IDLE: begin
                if (mem_req_valid) begin
                    next_state = LATCH_REQ;
                end                
            end
            
            LATCH_REQ: begin
                case (mem_req_rw)
                    1'b0: begin
                        next_state = READ_WAIT;                        
                    end
                    
                    1'b1: begin
                        next_state = WRITE_COMMIT;
                    end
                    
                    default: begin
                        next_state = IDLE;
                    end
                endcase
            end
            
            READ_WAIT: begin
                ena_ram = 1'b1;
                wr_en = 1'b0;
                if (latency_counter ==  4'd0) begin
                    next_state = READ_RESP;
                end
            end
            
            READ_RESP: begin
                next_state = IDLE;
            end
            
            WRITE_COMMIT: begin
                ena_ram = 1'b1;
                wr_en = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //---------------------------------Output Logic----------------------------
    always @(*) begin
        mem_req_ready = 1'b0;
        mem_resp_valid = 1'b0;
        mem_resp_rdata = {LINE_WIDTH{1'b0}};
        case (state)
            IDLE: begin
                
            end
            
            LATCH_REQ: begin
                mem_req_ready = 1'b1;
            end
            
            READ_WAIT: begin
            
            end
            
            READ_RESP: begin
                mem_resp_valid = 1'b1;
                mem_resp_rdata = read_data_reg;
            end
            
            WRITE_COMMIT: begin
                
            end
            
            default: begin
                mem_req_ready = 1'b0;
                mem_resp_valid = 1'b0;
                mem_resp_rdata = {LINE_WIDTH{1'b0}};
            end
        endcase
    end
endmodule
