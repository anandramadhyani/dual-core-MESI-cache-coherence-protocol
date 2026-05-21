`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 04.05.2026 17:03:49
// Design Name: Shared Snoop Bus Design
// Module Name: shared_snoop_bus
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


module shared_snoop_bus 
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32,
      parameter LINE_BYTES = 32,
      parameter CMD_WIDTH = 2,
      parameter ID_WIDTH = 1)(
        
        //-------------------------------Global Signals---------------------------
        input wire clk,
        input wire reset,
        
        //------------------------------Cache 0 Interface-------------------------
        input wire c0_req_valid,
        output reg c0_req_ready,
        input wire [(CMD_WIDTH - 1) : 0] c0_req_cmd,
        input wire [(ADDR_WIDTH - 1) : 0] c0_req_addr,
        input wire [((LINE_BYTES * 8) - 1) : 0] c0_req_data,
        output reg c0_resp_valid,
        output reg c0_resp_shared,
        output reg [((LINE_BYTES * 8) - 1) : 0] c0_resp_rdata, 
                        
        //------------------------------Cache 1 Interface-------------------------
        input wire c1_req_valid,
        output reg c1_req_ready,
        input wire [(CMD_WIDTH - 1) : 0] c1_req_cmd,
        input wire [(ADDR_WIDTH - 1) : 0] c1_req_addr,
        input wire [((LINE_BYTES * 8) - 1) : 0] c1_req_data,
        output reg c1_resp_valid,
        output reg c1_resp_shared,
        output reg [((LINE_BYTES * 8) - 1) : 0] c1_resp_rdata,
        
        //------------------------------Snoop Interface---------------------------
        input wire c0_snoop_hit,
        input wire c0_snoop_dirty,
        input wire c0_snoop_data_valid,
        input wire [((LINE_BYTES * 8) - 1) : 0] c0_snoop_data,
        
        input wire c1_snoop_hit,
        input wire c1_snoop_dirty,
        input wire c1_snoop_data_valid,
        input wire [((LINE_BYTES * 8) - 1) : 0] c1_snoop_data,
        
        output reg snoop_valid,
        output reg [(CMD_WIDTH - 1) : 0] snoop_cmd,
        output reg [(ADDR_WIDTH - 1) : 0] snoop_addr,
        output reg [(ID_WIDTH - 1) : 0] snoop_src_id,
        
        //------------------------------Memory Interface--------------------------
        input wire mem_req_ready,
        output reg mem_req_valid,
        output reg mem_req_rw,
        output reg [(ADDR_WIDTH - 1) : 0] mem_req_addr,
        output reg [((LINE_BYTES * 8) - 1) : 0] mem_req_data,
        input wire mem_resp_valid,
        input wire [((LINE_BYTES * 8) - 1) : 0] mem_resp_rdata
    );
    
    //-------------------------------Local Parameters-----------------------------
    localparam LINE_WIDTH_IN_BITS = LINE_BYTES * 8;
    
    //--------------------------------FSM States----------------------------------
    localparam IDLE = 3'd0;
    localparam GRANT = 3'd1;
    localparam BROADCAST = 3'd2;
    localparam EVALUATE = 3'd3;
    localparam MEM_REQ = 3'd4;
    localparam MEM_WAIT = 3'd5;
    localparam RESPOND = 3'd6;
    
    //---------------------------------MESI States---------------------------------------------
    localparam MODIFIED = 2'd0;
    localparam EXCLUSIVE = 2'd1;
    localparam SHARED = 2'd2;
    localparam INVALID = 2'd3;
    
    //---------------------------------Bus Commands---------------------------------------------
    localparam CMD_READ = 2'd0;
    localparam CMD_READX = 2'd1;
    localparam CMD_UPGRADE = 2'd2;
    localparam CMD_WRITE_BACK = 2'd3;
    
    //---------------------------------Latch Registers------------------------------------------
    reg [(CMD_WIDTH - 1) : 0] latched_cmd;
    reg [(ADDR_WIDTH - 1) : 0] latched_addr;
    reg [(LINE_WIDTH_IN_BITS - 1) : 0] latched_wdata;
    reg [(LINE_WIDTH_IN_BITS - 1) : 0] latch_resp_data;
    reg latch_resp_shared;
    
    //--------------------------------------Owner Registers------------------------------------
    reg [(ID_WIDTH - 1) : 0] req_owner;                         // Cache 0 = 0
                                                                // Cache 1 = 1
    
    //--------------------------------------Peer Snoop Logic------------------------------------
    reg cache_data_used;
    wire peer_snoop_hit = (req_owner) ? c0_snoop_hit : c1_snoop_hit;
    wire peer_snoop_dirty = (req_owner) ? c0_snoop_dirty : c1_snoop_dirty;
    wire peer_snoop_data_valid = (req_owner) ? c0_snoop_data_valid : c1_snoop_data_valid;
    wire [(LINE_WIDTH_IN_BITS) : 0] peer_snoop_data = (req_owner) ? c0_snoop_data : c1_snoop_data;
    
    //--------------------------------------State Register--------------------------------------
    reg [2 : 0] state, next_state;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    //---------------------------------------Next State Logic-----------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (c0_req_valid || c1_req_valid) begin
                    next_state = GRANT;
                end
            end
            
            GRANT: begin
                next_state = BROADCAST;
            end
            
            BROADCAST: begin
                next_state = EVALUATE;
            end
            
            EVALUATE: begin
                case (latched_cmd)
                    CMD_UPGRADE: begin
                        next_state = RESPOND;
                    end
                    
                    CMD_WRITE_BACK: begin
                        next_state = MEM_REQ;
                    end
                    
                    CMD_READ,
                    CMD_READX: begin
                        next_state = MEM_REQ;
                    end
                    
                    default: begin
                        next_state = IDLE;
                    end
                endcase
            end
            
            MEM_REQ: begin
                if (mem_req_ready) begin
                    if (latched_cmd == CMD_WRITE_BACK) begin
                        next_state = RESPOND;
                    end
                    else begin
                        if (cache_data_used) begin
                            next_state = RESPOND;
                        end
                        else begin
                            next_state = MEM_WAIT;
                        end
                    end
                end
            end
            
            MEM_WAIT: begin
                if (mem_resp_valid) begin
                    next_state = RESPOND;
                end
            end
            
            RESPOND: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //------------------------------------Request Latch Logic------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            latched_cmd <= {CMD_WIDTH{1'b0}};
            latched_addr <= {ADDR_WIDTH{1'b0}};
            latched_wdata <= {LINE_WIDTH_IN_BITS{1'b0}};
        end
        else begin
            case (state)
                IDLE: begin
                    latched_cmd <= {CMD_WIDTH{1'b0}};
                    latched_addr <= {ADDR_WIDTH{1'b0}};
                    latched_wdata <= {LINE_WIDTH_IN_BITS{1'b0}};
                end
                
                GRANT: begin
                    if (c0_req_valid) begin
                        latched_cmd <= c0_req_cmd;
                        latched_addr <= c0_req_addr;
                        latched_wdata <= c0_req_data;
                    end
                    else if (c1_req_valid) begin
                        latched_cmd <= c1_req_cmd;
                        latched_addr <= c1_req_addr;
                        latched_wdata <= c1_req_data;
                    end
                end
                
                default: begin
                    latched_cmd <= latched_cmd;
                    latched_addr <= latched_addr;
                    latched_wdata <= latched_wdata;
                end
            endcase
        end
    end
    
    //---------------------------------------Owner Logic------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            req_owner <= {ID_WIDTH{1'b0}};
        end
        else begin
            case (state)
                IDLE: begin
                    req_owner <= {ID_WIDTH{1'b0}};
                end
                
                GRANT: begin
                    if (c0_req_valid) begin
                        req_owner <= 1'b0;
                    end
                    else if (c1_req_valid) begin
                        req_owner <= 1'b1;
                    end
                end
                
                default: begin
                    req_owner <= req_owner;
                end
            endcase
        end
    end
    
    //----------------------------------Cache Data Logic-------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cache_data_used <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    cache_data_used <= 1'b0;
                end
                
                BROADCAST: begin
                    if ((latched_cmd == CMD_READ || latched_cmd == CMD_READX)
                                                    && peer_snoop_data_valid) begin
                        cache_data_used <= 1'b1;
                    end
                end
                
                default: begin
                    cache_data_used <= cache_data_used;
                end
            endcase
        end
    end
    
    //---------------------------------Response Latch Logic--------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            latch_resp_data <= {LINE_WIDTH_IN_BITS{1'b0}};
            latch_resp_shared <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    latch_resp_data <= {LINE_WIDTH_IN_BITS{1'b0}};
                    latch_resp_shared <= 1'b0;
                end
                
                BROADCAST: begin
                    if (latched_cmd == CMD_READ && peer_snoop_hit) begin
                        latch_resp_shared <= 1'b1;
                    end
                    else begin
                        latch_resp_shared <= 1'b0;
                    end
                    if ((latched_cmd == CMD_READ || latched_cmd == CMD_READX)
                                                  && (peer_snoop_data_valid)) begin
                        latch_resp_data <= peer_snoop_data;
                    end
                end
                
                MEM_WAIT: begin
                    if (mem_resp_valid) begin
                        latch_resp_data <= mem_resp_rdata;
                    end
                end
                
                default: begin
                    latch_resp_data <= latch_resp_data;
                    latch_resp_shared <= latch_resp_shared;
                end
            endcase
        end
    end
    
    //--------------------------------------Output Logic------------------------------------------
    always @(*) begin
        c0_req_ready = 1'b0;
        c0_resp_valid = 1'b0;
        c0_resp_shared = 1'b0;
        c0_resp_rdata = {LINE_WIDTH_IN_BITS{1'b0}};
        
        c1_req_ready = 1'b0;
        c1_resp_valid = 1'b0;
        c1_resp_shared = 1'b0;
        c1_resp_rdata = {LINE_WIDTH_IN_BITS{1'b0}};
        
        mem_req_valid = 1'b0;
        mem_req_rw = 1'b0;                
        mem_req_addr = {ADDR_WIDTH{1'b0}};
        mem_req_data = {LINE_WIDTH_IN_BITS{1'b0}};
        
        snoop_valid = 1'b0;
        snoop_cmd = {CMD_WIDTH{1'b0}};
        snoop_addr = {ADDR_WIDTH{1'b0}};
        snoop_src_id = {ID_WIDTH{1'b0}};
        
        case (state)
            IDLE: begin
                
            end
            
            GRANT: begin
                if (c0_req_valid) begin
                    c0_req_ready = 1'b1;
                end
                else if (c1_req_valid) begin
                    c1_req_ready = 1'b1;
                end
            end
            
            BROADCAST: begin
                if (latched_cmd != CMD_WRITE_BACK) begin
                    snoop_valid = 1'b1;
                    snoop_cmd = latched_cmd;
                    snoop_addr = latched_addr;
                    snoop_src_id = req_owner;
                end
            end
            
            EVALUATE: begin
            
            end
            
            MEM_REQ: begin
                mem_req_valid = 1'b1;
                mem_req_addr = latched_addr;
                if (latched_cmd == CMD_WRITE_BACK) begin
                    mem_req_rw = 1'b1;
                    mem_req_data = latched_wdata;
                end
                else begin
                    if (cache_data_used) begin
                        mem_req_rw = 1'b1;
                        mem_req_data = latch_resp_data;
                    end
                    else begin
                        mem_req_rw = 1'b0;
                        mem_req_data = {LINE_WIDTH_IN_BITS{1'b0}};
                    end
                end
            end
            
            MEM_WAIT: begin
            
            end
            
            RESPOND: begin
                if (req_owner == 1'b0) begin
                    c0_resp_valid = 1'b1;
                    c0_resp_shared = latch_resp_shared;
                    c0_resp_rdata = latch_resp_data;
                end
                else if (req_owner == 1'b1) begin
                    c1_resp_valid = 1'b1;
                    c1_resp_shared = latch_resp_shared;
                    c1_resp_rdata = latch_resp_data;
                end
            end
            
            default: begin
                c0_req_ready = 1'b0;
                c0_resp_valid = 1'b0;
                c0_resp_shared = 1'b0;
                c0_resp_rdata = {LINE_WIDTH_IN_BITS{1'b0}};
                
                c1_req_ready = 1'b0;
                c1_resp_valid = 1'b0;
                c1_resp_shared = 1'b0;
                c1_resp_rdata = {LINE_WIDTH_IN_BITS{1'b0}};
                
                mem_req_valid = 1'b0;
                mem_req_rw = 1'b0;                
                mem_req_addr = {ADDR_WIDTH{1'b0}};
                mem_req_data = {LINE_WIDTH_IN_BITS{1'b0}};
                
                snoop_valid = 1'b0;
                snoop_cmd = {CMD_WIDTH{1'b0}};
                snoop_addr = {ADDR_WIDTH{1'b0}};
                snoop_src_id = {ID_WIDTH{1'b0}};
            end
        endcase
    end
    
endmodule
