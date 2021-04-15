`ifndef __LSQUE_V__
`define __LSQUE_V__
`define TEST_MODE
`timescale 1ns/100ps
module SQ(
    input                       clock,
    input                       reset,
    // dispatch
    output logic [2:0]          stall,
    input [2:0]                 dispatch, // with stall considered
    output logic [2:0][`LSQ-1:0] tail_pos, 
    // the newly allocated entry idx or the tail position if no allocation

    // rs 
    output logic [2**`LSQ-1:0]  load_tail_ready,

    // exe store (from alu)
    input [2:0]                 exe_valid,
    input SQ_ENTRY_PACKET [2:0] exe_store,
    input [2:0][`LSQ-1:0]       exe_idx,

    // LOAD (from Load fu)
    input LOAD_SQ_PACKET [1:0]  load_lookup, 
    output SQ_LOAD_PACKET [1:0] load_forward,
    
    // retire
    input [2:0]                     retire,
    output SQ_ENTRY_PACKET [2:0]    cache_wb,
    output SQ_ENTRY_PACKET [2:0]    sq_head

    `ifdef TEST_MODE
    , output SQ_ENTRY_PACKET [0:2**`LSQ-1]  sq_display
    , output logic [`LSQ-1:0]               head_dis, tail_dis
    , output logic [`LSQ:0]                 filled_num_dis
    // age logic
    , output SQ_ENTRY_PACKET [2**`LSQ-1:0]  older_stores_display
    , output [2**`LSQ-1:0]                  older_stores_valid_display
    `endif
);
// regs
logic [`LSQ-1:0] head, tail; // tail points the first empty entry, head to the first valid entry
logic [`LSQ-1:0] filled_num; // the reg is not allowed to be full

SQ_ENTRY_PACKET [0:2**`LSQ-1] sq_reg;

// next head and tail
logic [1:0] num_retire, num_dis;
logic [`LSQ:0] next_head, next_tail, next_filled_num; // can be larger than 2**`LSQ
logic [`LSQ-1:0] wrapped_head, wrapped_tail;

assign num_retire = retire[0] + retire[1] + retire[2];
assign num_dis = dispatch[0] + dispatch[1] + dispatch[2];

assign next_head = head + num_retire;
assign next_tail = tail + num_dis;
assign next_filled_num = filled_num + num_dis - num_retire;

assign wrapped_head = next_head[`LSQ-1:0];
assign wrapped_tail = next_tail[`LSQ-1:0];

always_ff @(posedge clock) begin
    if (reset) begin
        head <=`SD 0;
        tail <=`SD 0;
        filled_num <= `SD 0;
    end else begin
        head <= `SD wrapped_head;
        tail <= `SD wrapped_tail;
        filled_num <= `SD next_filled_num;
    end
end


// stall (dependent only on retire)
logic [`LSQ:0] num_empty_entries;
assign num_empty_entries = 2**`LSQ - filled_num + num_retire;
always_comb begin
    if (num_empty_entries < 2) stall = 3'b111;
    else if (num_empty_entries < 3) stall = 3'b011;
    else if (num_empty_entries < 4) stall = 3'b001;
    else stall = 3'b000;
end

// set dispatch index
always_comb begin
    tail_pos = 0;
    case(dispatch)
    3'b000: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail;
        tail_pos[0] = tail;
    end
    3'b001: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail;
        tail_pos[0] = tail;
    end
    3'b010: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail;
        tail_pos[0] = tail+1;
    end
    3'b011: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail;
        tail_pos[0] = tail+1;
    end
    3'b100: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail+1;
        tail_pos[0] = tail+1;
    end
    3'b101: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail+1;
        tail_pos[0] = tail+1;
    end
    3'b110: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail+1;
        tail_pos[0] = tail+2;
    end
    3'b111: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail+1;
        tail_pos[0] = tail+2;
    end
    endcase
end

logic [`LSQ-1:0]  head_inc_1, head_inc_2;
assign head_inc_1 = head+1;
assign head_inc_2 = head+2;

// writeback retire stores
always_comb begin
    cache_wb = 0;
    if (num_retire >= 1) cache_wb[2] = sq_reg[head];
    if (num_retire >= 2) cache_wb[1] = sq_reg[head_inc_1];
    if (num_retire >= 3) cache_wb[0] = sq_reg[head_inc_2];
end

always_comb begin
    sq_head[2] = sq_reg[head];
    sq_head[1] = sq_reg[head_inc_1];
    sq_head[0] = sq_reg[head_inc_2];
end


SQ_ENTRY_PACKET [0:2**`LSQ-1] sq_reg_after_retire;
SQ_ENTRY_PACKET [0:2**`LSQ-1] sq_reg_next;


// clear retire entries
always_comb begin
    sq_reg_after_retire = sq_reg;
    if (num_retire >= 1) sq_reg_after_retire[head] = 0;
    if (num_retire >= 2) sq_reg_after_retire[head_inc_1] = 0;
    if (num_retire >= 3) sq_reg_after_retire[head_inc_2] = 0;
end

always_comb begin
    sq_reg_next = sq_reg_after_retire;
    if (exe_valid[0])sq_reg_next[exe_idx[0]] = exe_store[0];
    if (exe_valid[1])sq_reg_next[exe_idx[1]] = exe_store[1];
    if (exe_valid[2])sq_reg_next[exe_idx[2]] = exe_store[2];
end


always_ff @(posedge clock) begin
    if (reset)
        sq_reg <= `SD 0;
    else sq_reg <= `SD sq_reg_next;
end

///////////////////////////////
////// Age Logic
///////////////////////////////

// reorder older stores
SQ_ENTRY_PACKET [1:0][2**`LSQ-1:0] older_stores; // the younger, the higher idex
logic [1:0][2**`LSQ-1:0] older_stores_valid;
int     older_stores_num0, older_stores_num1;
logic [1:0][`LSQ-1:0] load_pos; 
logic [1:0][2**`LSQ-1:0] waiting_store_addr;
logic [1:0][3:0][2**`LSQ-1:0] byte_forward_valid;
logic [1:0][3:0][2**`LSQ-1:0] byte_forward_sel;
logic [1:0][2**`LSQ-1:0][`LSQ-1:0] org_idx;


/* reorder older stores*/
assign load_pos[0] = load_lookup[0].tail_pos;
always_comb begin
    older_stores_num0 = (head <= load_pos[0])?
                        load_pos[0] - head:
                        2**`LSQ - head + load_pos[0];
end
always_comb begin
    older_stores_valid[0] = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (i+older_stores_num0 >= 2**`LSQ) older_stores_valid[0][i] = 1;
    end
end

always_comb begin
    for (int i=0; i<2**`LSQ; i++) begin
        org_idx[0][i] = i + load_pos[0];
    end
end
always_comb begin
    for (int i=0; i<2**`LSQ; i++) begin
        older_stores[0][i] = sq_reg[org_idx[0][i]];
    end
end

// determin load stall
always_comb begin
    for(int i=0; i<2**`LSQ; i++) begin
        waiting_store_addr[0][i] = ~older_stores[0][i].ready & older_stores_valid[0][i];
    end
end
assign load_forward[0].stall = |waiting_store_addr[0];

// determin forwarded data
always_comb begin
    byte_forward_valid[0] = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (older_stores_valid[0][i] && older_stores[0][i].addr == load_lookup[0].addr) begin
            byte_forward_valid[0][0][i] = older_stores[0][i].usebytes[0];
            byte_forward_valid[0][1][i] = older_stores[0][i].usebytes[1];
            byte_forward_valid[0][2][i] = older_stores[0][i].usebytes[2];
            byte_forward_valid[0][3][i] = older_stores[0][i].usebytes[3];
        end
    end
end
ps8 byte_sel_0(.req(byte_forward_valid[0][0]), .en(1'b1), .gnt(byte_forward_sel[0][0]));
ps8 byte_sel_1(.req(byte_forward_valid[0][1]), .en(1'b1), .gnt(byte_forward_sel[0][1]));
ps8 byte_sel_2(.req(byte_forward_valid[0][2]), .en(1'b1), .gnt(byte_forward_sel[0][2]));
ps8 byte_sel_3(.req(byte_forward_valid[0][3]), .en(1'b1), .gnt(byte_forward_sel[0][3]));

always_comb begin
    load_forward[0].data = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (byte_forward_sel[0][0][i]) 
            load_forward[0].data[7:0] = older_stores[0][i].data[7:0];
        if (byte_forward_sel[0][1][i]) 
            load_forward[0].data[15:8] = older_stores[0][i].data[15:8];
        if (byte_forward_sel[0][2][i]) 
            load_forward[0].data[23:16] = older_stores[0][i].data[23:16];
        if (byte_forward_sel[0][3][i]) 
            load_forward[0].data[31:24] = older_stores[0][i].data[31:24];
    end
end

always_comb begin
    for(int i=0; i<4; i++) begin
        load_forward[0].usebytes[i] = |byte_forward_valid[0][i];
    end
end

`ifdef TEST_MODE
assign sq_display = sq_reg;
assign head_dis = head;
assign tail_dis = tail;
assign filled_num_dis = filled_num;
assign older_stores_display = older_stores[0];
assign older_stores_valid_display = older_stores_valid[0];
`endif


/* reorder older stores*/
assign load_pos[1] = load_lookup[1].tail_pos;
always_comb begin
    older_stores_num1 = (head <= load_pos[1])?
                        load_pos[1] - head:
                        2**`LSQ - head + load_pos[1];
end
always_comb begin
    older_stores_valid[1] = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (i+older_stores_num1 >= 2**`LSQ) older_stores_valid[1][i] = 1;
    end
end
always_comb begin
    for (int i=0; i<2**`LSQ; i++) begin
        org_idx[1][i] = i + load_pos[1];
    end
end
always_comb begin
    for (int i=0; i<2**`LSQ; i++) begin
        older_stores[1][i] = sq_reg[org_idx[1][i]];
    end
end

// determin load stall
always_comb begin
    for(int i=0; i<2**`LSQ; i++) begin
        waiting_store_addr[1][i] = ~older_stores[1][i].ready & older_stores_valid[1][i];
    end
end
assign load_forward[1].stall = |waiting_store_addr[1];

// determin forwarded data
always_comb begin
    byte_forward_valid[1] = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (older_stores_valid[1][i] && older_stores[1][i].addr == load_lookup[1].addr) begin
            byte_forward_valid[1][0][i] = older_stores[1][i].usebytes[0];
            byte_forward_valid[1][1][i] = older_stores[1][i].usebytes[1];
            byte_forward_valid[1][2][i] = older_stores[1][i].usebytes[2];
            byte_forward_valid[1][3][i] = older_stores[1][i].usebytes[3];
        end
    end
end
ps8 byte_sel_4(.req(byte_forward_valid[1][0]), .en(1'b1), .gnt(byte_forward_sel[1][0]));
ps8 byte_sel_5(.req(byte_forward_valid[1][1]), .en(1'b1), .gnt(byte_forward_sel[1][1]));
ps8 byte_sel_6(.req(byte_forward_valid[1][2]), .en(1'b1), .gnt(byte_forward_sel[1][2]));
ps8 byte_sel_7(.req(byte_forward_valid[1][3]), .en(1'b1), .gnt(byte_forward_sel[1][3]));

always_comb begin
    load_forward[1].data = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (byte_forward_sel[1][0][i]) 
            load_forward[1].data[7:0] = older_stores[1][i].data[7:0];
        if (byte_forward_sel[1][1][i]) 
            load_forward[1].data[15:8] = older_stores[1][i].data[15:8];
        if (byte_forward_sel[1][2][i]) 
            load_forward[1].data[23:16] = older_stores[1][i].data[23:16];
        if (byte_forward_sel[1][3][i]) 
            load_forward[1].data[31:24] = older_stores[1][i].data[31:24];
    end
end

always_comb begin
    for(int i=0; i<4; i++) begin
        load_forward[1].usebytes[i] = |byte_forward_valid[1][i];
    end
end

////////////////////////////////////////
////////////   Load Tail Ready
////////////////////////////////////////
always_comb begin 
    for(int i=0; i<2**`LSQ; i++) begin // for each tail position
        load_tail_ready[i] = 1;
        for(int j=0; j<2**`LSQ; j++) begin // for each entry
            if( i >= head && j >= head && j < i) // is older than load tail
                if (sq_reg[j].ready == 0) load_tail_ready[i] = 0;
            if ( i < head && (j < i || j >= head))
                if (sq_reg[j].ready == 0) load_tail_ready[i] = 0;
        end
    end
end

endmodule



`endif // __LSQUE_V__
