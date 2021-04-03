`ifndef __LSQUE_V__
`define __LSQUE_V__
`define TEST_MODE
`timescale 1ns/100ps
module SQ(
    input                       clock,
    input                       reset,
    // dispatch
    output logic [2:0]          struct_stall,
    input [2:0]                 dispatch, // with struct_stall considered
    output logic [2:0][`LSQ-1:0] new_entry_idx,
    // write addr and value
    input [1:0]                 exe_valid,
    input SQ_ENTRY_PACKET [1:0] exe_store,
    input [1:0][`LSQ-1:0]       exe_idx,
    
    // retire
    input [2:0]                 retire,
    output SQ_ENTRY_PACKET [2:0]    cache_wb  
    `ifdef TEST_MODE
    , output SQ_ENTRY_PACKET [2**`LSQ-1:0] sq_display
    , output logic [`LSQ-1:0]       head_dis, tail_dis, filled_num_dis
    `endif
);
// regs
logic [`LSQ-1:0] head,tail, filled_num;
// tail points at the last valid entry. head points the next empty entry
SQ_ENTRY_PACKET [2**`LSQ-1:0] sq_reg;
`ifdef TEST_MODE
assign sq_display = sq_reg;
assign head_dis = head;
assign tail_dis = tail;
assign filled_num_dis = filled_num;
`endif

// next head and tail
logic [1:0] num_retire, num_dis;
logic [`LSQ:0] next_head, next_tail, next_filled_num; // can be larger than 2**`LSQ
logic [`LSQ-1:0] wraped_head, wraped_tail, wrapped_filled_num;

assign num_retire = retire[0] + retire[1] + retire[2];
assign num_dis = dispatch[0] + dispatch[1] + dispatch[2];

assign next_head = head + num_dis;
assign next_tail = tail + num_retire;
assign next_filled_num = filled_num + num_dis - num_retire;

assign wrapped_head = next_head[`LSQ-1:0];
assign wrapped_tail = next_tail[`LSQ-1:0];
assign wrapped_filled_num = next_filled_num[`LSQ-1:0];

always_ff @(posedge clock) begin
    if (reset) begin
        head <=`SD 0;
        tail <=`SD 0;
        filled_num <= `SD 0;
    end else begin
        head <= `SD wrapped_head;
        tail <= `SD wrapped_tail;
        filled_num <= `SD wrapped_filled_num;
    end
end


// struct_stall (dependent only on retire)
logic [`LSQ-1:0] num_empty_entries;
assign num_empty_entries = filled_num - num_retire;
always_comb begin
    case(num_empty_entries)
        0: struct_stall = 3'b111;
        1: struct_stall = 3'b011;
        2: struct_stall = 3'b001;
        default: struct_stall = 3'b000;
    endcase
end

// set dispatch index
always_comb begin
    new_entry_idx = 0;
    case(dispatch)
    3'b001: new_entry_idx[0] = head;
    3'b010: new_entry_idx[1] = head;
    3'b011: begin
        new_entry_idx[0] = head + 1;
        new_entry_idx[1] = head;
    end
    3'b100: new_entry_idx[2] = head;
    3'b101: begin
        new_entry_idx[2] = head;
        new_entry_idx[0] = head + 1;
    end
    3'b110: begin
        new_entry_idx[2] = head;
        new_entry_idx[1] = head + 1;
    end
    3'b111: begin
        new_entry_idx[2] = head;
        new_entry_idx[1] = head + 1;
        new_entry_idx[0] = head + 2;
    end
    endcase
end

// writeback retire stores
always_comb begin
    cache_wb = 0;
    if (num_retire >= 1) cache_wb[2] = sq_reg[tail];
    if (num_retire >= 2) cache_wb[1] = sq_reg[tail+1];
    if (num_retire >= 3) cache_wb[0] = sq_reg[tail+2];
end


SQ_ENTRY_PACKET [2**`LSQ-1:0] sq_reg_after_retire;
SQ_ENTRY_PACKET [2**`LSQ-1:0] sq_reg_next;


// clear retire entries
always_comb begin
    sq_reg_after_retire = sq_reg;
    if (num_retire >= 1) sq_reg_after_retire[tail] = 0;
    if (num_retire >= 2) sq_reg_after_retire[tail+1] = 0;
    if (num_retire >= 3) sq_reg_after_retire[tail+2] = 0;
end

always_comb begin
    sq_reg_next = sq_reg_after_retire;
    sq_reg_next[exe_idx[0]] = exe_store[0];
    sq_reg_next[exe_idx[1]] = exe_store[1];
end


always_ff @(posedge clock) begin
    if (reset)
        sq_reg <= `SD 0;
    else sq_reg <= `SD sq_reg_next;
end
endmodule


// module LQ(
//     output logic [2:0]          lq_struct_stall
// );

// endmodule

// module LSQ(
//     input                       clock,
//     input                       reset,
//     // DISPATCH
//     input [2:0]                 dis_load, 
//     // hot coding for dispatching load ins. (rule out struct_stall first)
//     input [2:0]                 dis_store,
//     output [2:0][`LSQ:0]        new_lsq_idx,
//     output [2:0]                struct_stall,

//     // Write from store exe
//     intput          

//     // Send data to memory

// );
// assign lsq_struct_stall = lq_stall | sq_stall;


// endmodule


`endif // __LSQUE_V__
