`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CSUN
// Engineer: Ananda Thirtha
// 
// Create Date: 27.04.2026 19:46:45
// Design Name: Private L1 Cache
// Module Name: l1_cache
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


module l1_cache
    #(parameter ADDR_WIDTH = 32,
      parameter DATA_WIDTH = 32,
      parameter WAYS = 2,
      parameter SETS = 32,
      parameter LINE_BYTES = 32,
      parameter CMD_WIDTH = 2,
      parameter ID_WIDTH = 1,
      parameter CACHE_ID = 0)(
        
        //----------------------------------Global Signals-------------------------------
        input wire clk,
        input wire reset,
        
        //----------------------------------Core Interface------------------------------
        input wire req_valid,
        output reg req_ready,
        input wire req_rw,
        input wire [(ADDR_WIDTH - 1) : 0] req_addr,
        input wire [(DATA_WIDTH - 1) : 0] req_data,
        input wire [((DATA_WIDTH/ 8) - 1) : 0] req_strb,
        input wire resp_ready,
        output reg resp_valid,
        output reg [(DATA_WIDTH - 1) : 0] resp_rdata,
        
        //--------------------------------Bus Interface-----------------------------
        input wire bus_req_ready,
        output reg bus_req_valid,                
        output reg [(CMD_WIDTH - 1) : 0] bus_req_cmd,                
        output reg [(ADDR_WIDTH - 1) : 0] bus_req_addr,                
        output reg [((LINE_BYTES * 8) - 1) : 0] bus_req_data,
        input wire bus_resp_valid,
        input wire bus_resp_shared,
        input wire [((LINE_BYTES * 8) - 1) : 0] bus_resp_rdata,
        
        //--------------------------------Snoop Interface-----------------------------  
        input wire snoop_valid,              
        input wire [(CMD_WIDTH - 1) : 0] snoop_cmd,
        input wire [(ADDR_WIDTH - 1) : 0] snoop_addr,
        input wire [(ID_WIDTH - 1) : 0] snoop_src_id,
        output reg snoop_hit,
        output reg snoop_dirty,
        output reg snoop_data_valid,
        output reg [((LINE_BYTES * 8) - 1) : 0] snoop_data
    );
    
    //-------------------------------WIDTH Declaration-----------------------------------------
    localparam LINE_WIDTH_IN_BITS = LINE_BYTES * 8;
    localparam INDEX_WIDTH = $clog2(SETS);
    localparam OFFSET_WIDTH = $clog2(LINE_BYTES);
    localparam TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;
    localparam WORD_OFFSET_WIDTH = OFFSET_WIDTH - 2;
    
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
    
    //------------------------------------Cache Array-----------------------------------
    reg [(TAG_WIDTH - 1) : 0] tag_array [0 : (SETS - 1)][0 : (WAYS - 1)];
    reg valid_array [0 : (SETS - 1)][0 : (WAYS - 1)];
    reg dirty_array [0 : (SETS - 1)][0 : (WAYS - 1)];
    reg [(LINE_WIDTH_IN_BITS - 1) : 0] data_line_array [0 : (SETS - 1)][0 : (WAYS - 1)];
    reg lru_array [0 : (SETS - 1)];
    reg [1 : 0] mesi_array [0 : (SETS - 1)][0 : (WAYS - 1)];
    
    //-----------------------------Request Latch Registers-------------------------------
    reg latched_req_rw;
    reg [(ADDR_WIDTH - 1) : 0] latched_req_addr;
    reg [(DATA_WIDTH - 1) : 0] latched_req_data;
    
    //---------------------------------Data Registers-----------------------------------
    reg [(DATA_WIDTH - 1) : 0] req_data_reg;
    reg [(LINE_WIDTH_IN_BITS - 1) : 0] bus_resp_data_reg;    
    reg bus_resp_shared_reg;
    
    //---------------------------------Snoop Latch Registers----------------------------
    reg [(CMD_WIDTH - 1) : 0] snoop_cmd_reg;
    reg [(ADDR_WIDTH - 1) : 0] snoop_addr_reg;
    reg snoop_way_reg;
    reg snoop_index_reg;
    
    //--------------------------------Address Breakdown---------------------------------
    wire [(TAG_WIDTH - 1) : 0] req_tag = latched_req_addr[(ADDR_WIDTH - 1) : (INDEX_WIDTH + OFFSET_WIDTH)];
    wire [(INDEX_WIDTH - 1) : 0] req_index = latched_req_addr [((INDEX_WIDTH + OFFSET_WIDTH) - 1) : (OFFSET_WIDTH)];
    wire [(OFFSET_WIDTH - 1) : 0] req_offset = latched_req_addr [(OFFSET_WIDTH - 1) : 0];
    wire [(WORD_OFFSET_WIDTH - 1) : 0] req_word_sel = latched_req_addr [(OFFSET_WIDTH - 1) : 2];
    wire [(ADDR_WIDTH - 1) : 0] req_line_addr = {latched_req_addr [(ADDR_WIDTH - 1) : (OFFSET_WIDTH)], {OFFSET_WIDTH{1'b0}}};
    
    //-------------------------------Combinational Look-Up-------------------------------
    wire valid_way0 = (valid_array[req_index][0]) && (mesi_array[req_index][0] != INVALID);
    wire valid_way1 = (valid_array[req_index][1]) && (mesi_array[req_index][1] != INVALID);
    wire hit_way0 = valid_way0 && ((tag_array[req_index][0]) == req_tag);
    wire hit_way1 = valid_way1 && ((tag_array[req_index][1]) == req_tag);
    wire hit_way = hit_way1;
    wire hit = hit_way0 || hit_way1;
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] hit_line = (hit_way) ?
                                        data_line_array[req_index][1] : data_line_array[req_index][0];
    wire [1 : 0] hit_mesi = hit_way ? mesi_array[req_index][1] : mesi_array[req_index][0];                                     
                                        
    //-----------------------------Victim Selection---------------------------------------
    reg victim_way;
    always @(*) begin
        if (!valid_way0) begin
            victim_way = 1'b0;
        end
        else if (!valid_way1) begin
            victim_way = 1'b1;
        end
        else begin
            victim_way = lru_array [req_index];
        end
    end  
    
    wire [(LINE_WIDTH_IN_BITS - 1) : 0] victim_line = (victim_way) ? 
                                                data_line_array[req_index][1] : data_line_array[req_index][0];
    wire [(TAG_WIDTH - 1) : 0] victim_tag = (victim_way) ? tag_array[req_index][1] : tag_array[req_index][0];
    wire victim_valid = (victim_way) ? valid_array[req_index][1] : valid_array[req_index][0];
    wire victim_dirty = (victim_way) ? dirty_array[req_index][1] : dirty_array[req_index][0];
    wire [1:0] victim_mesi  = victim_way ? mesi_array[req_index][1] : mesi_array[req_index][0];
    wire [(ADDR_WIDTH - 1) : 0] victim_addr = {victim_tag, req_index, {OFFSET_WIDTH{1'b0}}}; 
       
    //---------------------------------Snoop Look-Up--------------------------------------------
    wire [(INDEX_WIDTH - 1) : 0] snoop_index = snoop_addr [((INDEX_WIDTH + OFFSET_WIDTH) - 1) : (OFFSET_WIDTH)];
    wire [(TAG_WIDTH - 1) : 0] snoop_tag = snoop_addr [(ADDR_WIDTH - 1) : (INDEX_WIDTH + OFFSET_WIDTH)];
    
    wire snoop_match0 = valid_array[snoop_index][0] && 
                        (mesi_array[snoop_index][0] !== INVALID) && 
                        (tag_array[snoop_index][0] == snoop_tag);
    wire snoop_match1 = valid_array[snoop_index][1] && 
                        (mesi_array[snoop_index][1] !== INVALID) && 
                        (tag_array[snoop_index][1] == snoop_tag);
    wire snoop_match = snoop_match0 || snoop_match1;
    wire snoop_way = snoop_match1;
    wire [(LINE_WIDTH_IN_BITS) : 0] snoop_line =   snoop_way ? 
                                                   data_line_array[snoop_index][1] : data_line_array[snoop_index][0];  
    wire [1 : 0] snoop_state = snoop_way ? 
                               mesi_array[snoop_index][1] : mesi_array[snoop_index][0];                    
    
    //---------------------------Read 32-bit word from Cache Line-------------------------------
    function [(LINE_WIDTH_IN_BITS - 1) : 0] get_word_from_line;
        input [(LINE_WIDTH_IN_BITS - 1) : 0] line;
        input [(WORD_OFFSET_WIDTH - 1) : 0] wsel;
        integer bit_position;
        begin
            bit_position = wsel * DATA_WIDTH;
            get_word_from_line = line[bit_position +: DATA_WIDTH];
        end 
    endfunction
    
    //------------------------Write a 32-bit word into the Cache Line-----------------------------
    function [(LINE_WIDTH_IN_BITS - 1) : 0] put_word_in_line;
        input [(LINE_WIDTH_IN_BITS - 1) : 0] line;
        input [(WORD_OFFSET_WIDTH - 1) : 0] wsel;
        input [(DATA_WIDTH - 1) : 0] w_data;
        integer bit_position;
        reg [(LINE_WIDTH_IN_BITS - 1) : 0] temp_line;
        begin
            temp_line = line; 
            bit_position = wsel * DATA_WIDTH;
            temp_line[bit_position +: DATA_WIDTH] = w_data;
            put_word_in_line = temp_line;
        end
    endfunction
    
    //------------------------------------FSM States--------------------------------------------
    localparam IDLE = 4'd0;
    localparam LATCH_REQ = 4'd1;
    localparam LOOK_UP = 4'd2;
    localparam HIT_READ = 4'd3;
    localparam HIT_WRITE = 4'd4;
    localparam MISS_SELECT = 4'd5;
    localparam WB_REQ = 4'd6;
    localparam WB_WAIT = 4'd7;
    localparam BUS_UPGR_REQ = 4'd8;
    localparam BUS_RDX_REQ = 4'd9;
    localparam BUS_RD_REQ = 4'd10;
    localparam BUS_WAIT = 4'd11;
    localparam REFILL = 4'd12;
    localparam RESPOND = 4'd13;
            
    //--------------------------------State Registers-------------------------------------------
    reg [3 : 0] state, next_state;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    //-------------------------------Request Latch Logic------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            latched_req_rw <= 1'b0;
            latched_req_addr <= {ADDR_WIDTH{1'b0}};
            latched_req_data <= {DATA_WIDTH{1'b0}};
        end
        else begin
            case (state)
                IDLE: begin
                    latched_req_rw <= 1'b0;
                    latched_req_addr <= {ADDR_WIDTH{1'b0}};
                    latched_req_data <= {DATA_WIDTH{1'b0}};
                end
                
                LATCH_REQ: begin
                    latched_req_rw <= req_rw;
                    latched_req_addr <= req_addr;
                    latched_req_data <= req_data;
                end
                
                default: begin
                    latched_req_rw <= latched_req_rw;
                    latched_req_addr <= latched_req_addr;
                    latched_req_data <= latched_req_data;
                end
            endcase
        end
    end
    
    //--------------------------------------Data Latch Logic-----------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            req_data_reg <= {DATA_WIDTH{1'b0}};
            bus_resp_data_reg <= {LINE_WIDTH_IN_BITS{1'b0}};
            bus_resp_shared_reg <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    req_data_reg <= {DATA_WIDTH{1'b0}};
                    bus_resp_data_reg <= {LINE_WIDTH_IN_BITS{1'b0}};
                    bus_resp_shared_reg <= 1'b0;
                end
                
                HIT_READ: begin
                    req_data_reg <= get_word_from_line(hit_line, req_word_sel);
                end
                
                BUS_WAIT: begin
                    if (bus_resp_valid) begin
                        bus_resp_data_reg <= bus_resp_rdata;
                        bus_resp_shared_reg <= bus_resp_shared;
                    end
                end
                
                REFILL: begin
                    if (!latched_req_rw) begin
                        req_data_reg <= get_word_from_line(bus_resp_data_reg, req_word_sel);
                    end
                end
                
                default: begin
                    req_data_reg <= req_data_reg;
                    bus_resp_data_reg <= bus_resp_data_reg;
                    bus_resp_shared_reg <= bus_resp_shared_reg;
                end
            endcase
        end
    end
    
    //---------------------------------------Snoop Latch Logic--------------------------------
//    always @(posedge clk or posedge reset) begin
//        if (reset) begin
//            snoop_cmd_reg <= {CMD_WIDTH{1'b0}};
//            snoop_addr_reg <= {ADDR_WIDTH{1'b0}};
//            snoop_way_reg <= 1'b0;
//            snoop_index_reg <= {INDEX_WIDTH{1'b0}};
//        end
//        else begin
//            case (state) 
//                IDLE: begin
//                    snoop_cmd_reg <= {CMD_WIDTH{1'b0}};
//                    snoop_addr_reg <= {ADDR_WIDTH{1'b0}};
//                    snoop_way_reg <= 1'b0;
//                    snoop_index_reg <= {INDEX_WIDTH{1'b0}};
//                end
//            endcase
//        end
//    end
    
    //-------------------------------------Cache Array Logic-----------------------------------
    integer s, w;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (s = 0; s < SETS; s = s + 1) begin
                lru_array[s] <= 1'b0;
                for (w = 0; w < WAYS; w = w + 1) begin
                    valid_array[s][w] <= 1'b0;
                    dirty_array[s][w] <= 1'b0;
                    tag_array[s][w] <= {TAG_WIDTH{1'b0}};
                    mesi_array[s][w] <= INVALID;
                    data_line_array[s][w] <= {LINE_WIDTH_IN_BITS{1'b0}};
                end
            end
        end
        else begin
            if (snoop_valid && (snoop_src_id != CACHE_ID) && snoop_match) begin
                case (snoop_cmd)
                    CMD_READ: begin
                        if (mesi_array[snoop_index][snoop_way] == MODIFIED) begin
                            mesi_array[snoop_index][snoop_way]  <= SHARED;
                            dirty_array[snoop_index][snoop_way] <= 1'b0;
                        end
                        else if (mesi_array[snoop_index][snoop_way] == EXCLUSIVE) begin
                            mesi_array[snoop_index][snoop_way] <= SHARED;
                        end
                    end

                    CMD_READX,
                    CMD_UPGRADE: begin
                        mesi_array[snoop_index][snoop_way]  <= INVALID;
                        valid_array[snoop_index][snoop_way] <= 1'b0;
                        dirty_array[snoop_index][snoop_way] <= 1'b0;
                    end
                    
                    default: begin
                    
                    end 
                endcase
            end
            case (state) 
                IDLE: begin
                    
                end
                
                HIT_READ: begin
                    if (hit_way0) begin
                        lru_array[req_index] <= 1'b1;
                    end
                    else begin
                        lru_array[req_index] <= 1'b0;
                    end
                end
                
                HIT_WRITE: begin
                    if (hit_way0) begin
                        valid_array[req_index][0] <= 1'b1;
                        dirty_array[req_index][0] <= 1'b1;
                        mesi_array[req_index][0] <= MODIFIED;
                        lru_array[req_index] <= 1'b1;
                        data_line_array[req_index][0] <= put_word_in_line(hit_line, req_word_sel, latched_req_data);
                    end
                    else begin
                        valid_array[req_index][1] <= 1'b1;
                        dirty_array[req_index][1] <= 1'b1;
                        mesi_array[req_index][1] <= MODIFIED;
                        lru_array[req_index] <= 1'b0;
                        data_line_array[req_index][1] <= put_word_in_line(hit_line, req_word_sel, latched_req_data);
                    end
                end 
                
                REFILL: begin
                    if (victim_way) begin
                        tag_array[req_index][1] <= req_tag;
                        valid_array[req_index][1] <= 1'b1;
                        dirty_array[req_index][1] <= 1'b0;
                        lru_array[req_index] <= 1'b0;
                        if (latched_req_rw) begin
                            data_line_array[req_index][1] <= put_word_in_line
                                                            (bus_resp_data_reg, req_word_sel, latched_req_data);
                            dirty_array[req_index][1] <= 1'b1;
                            mesi_array[req_index][1] <= MODIFIED;
                        end else begin
                            data_line_array[req_index][1] <= bus_resp_data_reg;
                            mesi_array[req_index][1] <= bus_resp_shared_reg ? SHARED : EXCLUSIVE;
                        end
                    end
                    else begin
                        tag_array[req_index][0] <= req_tag;
                        valid_array[req_index][0] <= 1'b1;
                        dirty_array[req_index][0] <= 1'b0;
                        lru_array[req_index] <= 1'b1;
                        if (latched_req_rw) begin
                            data_line_array[req_index][0] <= put_word_in_line
                                                            (bus_resp_data_reg, req_word_sel, latched_req_data);
                            dirty_array[req_index][0] <= 1'b1;
                            mesi_array[req_index][0] <= MODIFIED;
                        end else begin
                            data_line_array[req_index][0] <= bus_resp_data_reg;
                            mesi_array[req_index][0] <= bus_resp_shared_reg ? SHARED : EXCLUSIVE;
                        end
                    end
                end
                
                
            endcase
        end
    end
    
    //---------------------------------Next State Logic----------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (req_valid) begin
                    next_state = LATCH_REQ;
                end                
            end
            
            LATCH_REQ: begin
                next_state = LOOK_UP;
            end
            
            LOOK_UP: begin
                case (hit)
                    1'b0: begin
                        next_state = MISS_SELECT;
                    end
                    
                    1'b1: begin
                        case (latched_req_rw)
                            1'b0: begin
                                next_state = HIT_READ;
                            end
                            
                            1'b1: begin
                                case (hit_mesi)
                                    MODIFIED,
                                    EXCLUSIVE: begin
                                        next_state = HIT_WRITE;
                                    end
                                    
                                    SHARED: begin
                                        next_state = BUS_UPGR_REQ;
                                    end
                                    
                                    default: begin
                                        next_state = IDLE;
                                    end
                                endcase 
                            end
                            
                            default: begin
                                next_state = IDLE;
                            end
                        endcase                        
                    end
                    
                    default: begin
                        next_state = IDLE;
                    end
                endcase
            end
            
            HIT_WRITE: begin
                next_state = RESPOND;
            end
            
            HIT_READ: begin
                next_state = RESPOND;
            end
            
            MISS_SELECT: begin
                case (victim_valid)
                    1'b0: begin
                        case (latched_req_rw)
                            1'b0: begin
                                next_state = BUS_RD_REQ;
                            end
                            
                            1'b1: begin
                                next_state = BUS_RDX_REQ;
                            end
                            
                            default: begin
                                next_state = IDLE;
                            end
                        endcase
                    end
                    
                    1'b1: begin
                        if (victim_dirty || victim_mesi == MODIFIED) begin
                            next_state = WB_REQ;
                        end
                    end
                    
                    default: begin
                        next_state = IDLE;
                    end
                endcase
            end
            
            WB_REQ: begin
                if (bus_req_ready) begin
                    next_state = WB_WAIT;
                end    
            end
            
            WB_WAIT: begin
                case (latched_req_rw)
                    1'b0: begin
                        next_state = BUS_RD_REQ;
                    end
                    
                    1'b1: begin
                        next_state = BUS_RDX_REQ;
                    end
                    
                    default: begin
                        next_state = IDLE;
                    end
                endcase
            end
            
            BUS_RD_REQ: begin
                if (bus_req_ready) begin
                    next_state = BUS_WAIT;
                end
            end
            
            BUS_RDX_REQ: begin
                if (bus_req_ready) begin
                    next_state = BUS_WAIT;
                end
            end
            
            BUS_UPGR_REQ: begin
                if (bus_req_ready) begin
                    next_state = BUS_WAIT;
                end
            end
            
            BUS_WAIT: begin
                if (bus_resp_valid) begin
                    if (bus_req_cmd == CMD_UPGRADE) begin
                        next_state = HIT_WRITE;
                    end
                    else begin
                        next_state = REFILL;
                    end
                end
            end
            
            REFILL: begin
                next_state = RESPOND;
            end
            
            RESPOND: begin
                if (resp_ready) begin
                    next_state = IDLE;
                end
            end
                                    
            default:  begin
                next_state = IDLE;
            end
        endcase
    end
    
    //----------------------------------Snoop Output Logic---------------------------------
    always @(*) begin
        snoop_hit = 1'b0;
        snoop_dirty = 1'b0;
        snoop_data_valid = 1'b0;
        snoop_data = {LINE_WIDTH_IN_BITS{1'b0}};
        if (snoop_valid && (snoop_src_id != CACHE_ID)) begin
            if (snoop_match) begin
                snoop_hit = 1'b1;
                if (snoop_state == MODIFIED) begin
                    snoop_dirty = 1'b1;
                    snoop_data_valid = 1'b1;
                    snoop_data = snoop_line;
                end
            end
        end
    end
    
    //----------------------------------Output Logic----------------------------------------
    always @(*) begin
        req_ready = 1'b0;
        resp_valid = 1'b0;
        resp_rdata = {DATA_WIDTH{1'b0}};
        bus_req_valid = 1'b0;
        bus_req_cmd = {CMD_WIDTH{1'b0}};
        bus_req_addr = {ADDR_WIDTH{1'b0}};
        bus_req_data = {LINE_WIDTH_IN_BITS{1'b0}};
    
        case (state)
            IDLE: begin
                
            end
            
            LATCH_REQ: begin
                req_ready = 1'b1;
            end
            
            LOOK_UP: begin
            
            end
            
            HIT_READ: begin
            
            end
            
            HIT_WRITE: begin
            
            end
            
            MISS_SELECT: begin
            
            end
            
            WB_REQ: begin
                bus_req_valid = 1'b1;
                bus_req_cmd = CMD_WRITE_BACK;
                bus_req_addr = victim_addr;
                bus_req_data = victim_line;
            end
            
            WB_WAIT: begin
            
            end
            
            REFILL: begin
                
            end
            
            RESPOND: begin
                resp_valid = 1'b1;
                if (latched_req_rw == 1'b0) begin
                    resp_rdata = req_data_reg;
                end
            end
            
            BUS_RD_REQ: begin
                bus_req_valid = 1'b1;
                bus_req_cmd   = CMD_READ;
                bus_req_addr  = req_line_addr;
            end
            
            BUS_RDX_REQ: begin
                bus_req_valid = 1'b1;
                bus_req_cmd   = CMD_READX;
                bus_req_addr  = req_line_addr;
            end
            
            BUS_UPGR_REQ: begin
                bus_req_valid = 1'b1;
                bus_req_cmd   = CMD_UPGRADE;
                bus_req_addr  = req_line_addr;
            end
            
            BUS_WAIT: begin
                
            end
            
            default: begin
                req_ready = 1'b0;
                resp_valid = 1'b0;
                resp_rdata = {DATA_WIDTH{1'b0}};
                bus_req_valid = 1'b0;
                bus_req_cmd = {CMD_WIDTH{1'b0}};
                bus_req_addr = {ADDR_WIDTH{1'b0}};
                bus_req_data = {LINE_WIDTH_IN_BITS{1'b0}};
            end
        endcase
    end
endmodule
