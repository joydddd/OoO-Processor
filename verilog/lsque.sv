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

    // exe store (from alu)
    input [2:0]                 exe_valid,
    input SQ_ENTRY_PACKET [2:0] exe_store,
    input [2:0][`LSQ-1:0]       exe_idx,

    // LOAD (from Load fu)
    input LOAD_SQ_PACKET [1:0]  load_lookup, 
    output SQ_LOAD_PACKET [1:0] load_forward,
    
    // retire
    input [2:0]                     retire,
    output SQ_ENTRY_PACKET [2:0]    cache_wb

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
    3'b001: begin
        tail_pos[2] = tail;
        tail_pos[1] = tail;
        tail_pos[0] = tail;
    end
    3'b010: begin
        tail_pos[0] = tail;
        tail_pos[1] = tail;
        tail_pos[2] = tail+1;
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

// writeback retire stores
always_comb begin
    cache_wb = 0;
    if (num_retire >= 1) cache_wb[2] = sq_reg[head];
    if (num_retire >= 2) cache_wb[1] = sq_reg[head+1];
    if (num_retire >= 3) cache_wb[0] = sq_reg[head+2];
end


SQ_ENTRY_PACKET [0:2**`LSQ-1] sq_reg_after_retire;
SQ_ENTRY_PACKET [0:2**`LSQ-1] sq_reg_next;


// clear retire entries
always_comb begin
    sq_reg_after_retire = sq_reg;
    if (num_retire >= 1) sq_reg_after_retire[head] = 0;
    if (num_retire >= 2) sq_reg_after_retire[head+1] = 0;
    if (num_retire >= 3) sq_reg_after_retire[head+2] = 0;
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
SQ_ENTRY_PACKET [2**`LSQ-1:0] older_stores; // the younger, the higher idex
logic [2**`LSQ-1:0] older_stores_valid;

/* reorder older stores*/
int older_stores_num;
logic [`LSQ-1:0] load_pos; 
assign load_pos = load_lookup[0].tail_pos;
always_comb begin
    older_stores_num = (head <= load_pos)?
                        load_pos - head:
                        2**`LSQ - head + load_pos;
end
always_comb begin
    older_stores_valid = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (i+older_stores_num >= 2**`LSQ) older_stores_valid[i] = 1;
    end
end
logic [2**`LSQ-1:0][`LSQ-1:0] org_idx;
always_comb begin
    for (int i=0; i<2**`LSQ; i++) begin
        org_idx[i] = i + load_pos;
    end
end
always_comb begin
    for (int i=0; i<2**`LSQ; i++) begin
        older_stores[i] = sq_reg[org_idx[i]];
    end
end

// determin load stall
logic [2**`LSQ-1:0] waiting_store_addr;
always_comb begin
    for(int i=0; i<2**`LSQ; i++) begin
        waiting_store_addr[i] = ~older_stores[i].ready & older_stores_valid[i];
    end
end
assign load_forward[0].stall = |waiting_store_addr;

// determin forwarded data
logic [3:0][2**`LSQ-1:0] byte_forward_valid;
logic [3:0][2**`LSQ-1:0] byte_forward_sel;
always_comb begin
    byte_forward_valid = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (older_stores_valid[i] & older_stores[i].addr == load_lookup[0].addr) begin
            byte_forward_valid[0][i] = older_stores[i].usebytes[0];
            byte_forward_valid[1][i] = older_stores[i].usebytes[1];
            byte_forward_valid[2][i] = older_stores[i].usebytes[2];
            byte_forward_valid[3][i] = older_stores[i].usebytes[3];
        end
    end
end
ps8 byte_sel_0(.req(byte_forward_valid[0]), .en(1'b1), .gnt(byte_forward_sel[0]));
ps8 byte_sel_1(.req(byte_forward_valid[1]), .en(1'b1), .gnt(byte_forward_sel[1]));
ps8 byte_sel_2(.req(byte_forward_valid[2]), .en(1'b1), .gnt(byte_forward_sel[2]));
ps8 byte_sel_3(.req(byte_forward_valid[3]), .en(1'b1), .gnt(byte_forward_sel[3]));

always_comb begin
    load_forward[0].data = 0;
    for(int i=0; i<2**`LSQ; i++) begin
        if (byte_forward_sel[0][i]) 
            load_forward[0].data[7:0] = older_stores[i].data[7:0];
        if (byte_forward_sel[1][i]) 
            load_forward[0].data[15:8] = older_stores[i].data[15:8];
        if (byte_forward_sel[2][i]) 
            load_forward[0].data[23:16] = older_stores[i].data[23:16];
        if (byte_forward_sel[3][i]) 
            load_forward[0].data[31:24] = older_stores[i].data[31:24];
    end
end

always_comb begin
    for(int i=0; i<4; i++) begin
        load_forward[0].usebytes[i] = |byte_forward_valid[i];
    end
end

`ifdef TEST_MODE
assign sq_display = sq_reg;
assign head_dis = head;
assign tail_dis = tail;
assign filled_num_dis = filled_num;
assign older_stores_display = older_stores;
assign older_stores_valid_display = older_stores_valid;
`endif

endmodule


// module LQ(
//     output logic [2:0]          lq_stall
// );

// endmodule

// module LSQ(
//     input                       clock,
//     input                       reset,
//     // DISPATCH
//     input [2:0]                 dis_load, 
//     // hot coding for dispatching load ins. (rule out stall first)
//     input [2:0]                 dis_store,
//     output [2:0][`LSQ:0]        new_lsq_idx,
//     output [2:0]                stall,

//     // Write from store exe
//     intput          

//     // Send data to memory

// );
// assign lsq_stall = lq_stall | sq_stall;


// endmodule


`endif // __LSQUE_V__
