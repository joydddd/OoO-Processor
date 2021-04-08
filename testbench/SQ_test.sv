`define TEST_MODE

module testbench;
logic                       clock, reset;
// dispatch
wire [2:0]                  stall;
logic [2:0]                 dispatch_req;
logic [2:0]                 dispatch; 
wire [2:0][`LSQ-1:0]        tail_pos;

// write addr and value
logic [2:0]                 exe_valid;
SQ_ENTRY_PACKET [2:0]       exe_store;
logic [2:0][`LSQ-1:0]       exe_idx;

// LOAD
LOAD_SQ_PACKET [1:0]        load_lookup;
SQ_LOAD_PACKET [1:0]        load_forward;

// retire
logic [2:0]                 retire;
SQ_ENTRY_PACKET [2:0]       cache_wb;

//display
SQ_ENTRY_PACKET [0:2**`LSQ-1] sq_display;
logic [`LSQ-1:0]       head_dis, tail_dis;
logic [`LSQ:0]              filled_num_dis;
SQ_ENTRY_PACKET [2**`LSQ-1:0]  older_stores;
logic [2**`LSQ-1:0]            older_stores_valid;


SQ tdb(
    .clock(clock),
    .reset(reset),
    .stall(stall),
    .dispatch(dispatch),
    .tail_pos(tail_pos),
    .exe_valid(exe_valid),
    .exe_store(exe_store),
    .exe_idx(exe_idx),
    .load_lookup(load_lookup),
    .load_forward(load_forward),
    .retire(retire),
    .cache_wb(cache_wb),
    .sq_display(sq_display),
    .head_dis(head_dis),
    .tail_dis(tail_dis),
    .filled_num_dis(filled_num_dis),
    .older_stores_display(older_stores),
    .older_stores_valid_display(older_stores_valid)
);

int cycle_count;
always begin
    #5;
    clock = ~clock;
end
always@(posedge clock) begin
   cycle_count++; 
end



task show_sq;
    $display("HEAD: %d, Tail: %d, Filled num: %d", head_dis, tail_dis, filled_num_dis);
    $display(" |ready|   addr   |usebytes|   data   |");
    for(int i=0; i<2**`LSQ; i++) begin
        $display("%1d|  %d  | %8h |  %4b  | %8h |", i, sq_display[i].ready, sq_display[i].addr, sq_display[i].usebytes, sq_display[i].data);
    end
endtask

task show_older_stores;
    $display("##### older stores, tail_pos at %d", load_lookup[0].tail_pos);
    $display(" |valid|ready|   addr   |usebytes|   data   |");
    for(int i=0; i<2**`LSQ; i++) begin
        $display("%1d|  %d  |  %d  | %8h |  %4b  | %8h |", i, older_stores_valid[i], older_stores[i].ready, older_stores[i].addr, older_stores[i].usebytes, older_stores[i].data);
    end
endtask

task show_load_forward;
    $display("LOAD forward: ");
    $display("LOAD1: stall: %b, usebyptes: %4b, data: %h", load_forward[0].stall, load_forward[0].usebytes, load_forward[0].data);
    $display("LOAD2: stall: %b, usebyptes: %4b, data: %h", load_forward[1].stall, load_forward[1].usebytes, load_forward[1].data);
endtask

always @(negedge clock) begin
    $display(" =============== cycle %d ==============", cycle_count);
    show_sq;
    show_older_stores;
    show_load_forward;
    $display("dispatch: %3b return idx: %d, %d, %d stall： %3b", dispatch, tail_pos[2], tail_pos[1], tail_pos[0], stall);
    $display("retire: %3b retire addr| %h | %h | %h |", retire, cache_wb[2].addr, cache_wb[1].addr, cache_wb[0].addr);
end

always @(dispatch_req, stall) begin
    dispatch = dispatch_req & ~stall;
end

initial begin
    $dumpvars;
    clock = 0;
    reset = 1;
    cycle_count = 0;
    exe_valid = 0;
    exe_store = 0;
    retire = 0;
    dispatch_req = 0;
    

    @(negedge clock)
    @(negedge clock)
    #1;
    reset = 0;
    dispatch_req = 3'b101;
    load_lookup[0].tail_pos = 0;
    $display("GOLDEN: head 0, tail 0, num 0");
    @(posedge clock)
    $display("GOLDEN: head 0, tail 2, num 2");
    @(posedge clock)
    $display("GOLDEN: head 0, tail 4, num 4");
    @(posedge clock)
    load_lookup[0].tail_pos = 4;
    load_lookup[0].addr = 32'hc0;
    $display("GLODEN: head 0, tail 6, num 6, stall: 001");
    dispatch_req = 3'b101;
    @(posedge clock)
    $display("GLODEN: head 0, tail 7, num 7, stall: 111");
    @(posedge clock)
    $display("GLODEN: head 0, tail 7, num 7, stall: 111");
    @(posedge clock)
    $display("GLODEN: head 0, tail 7, num 7, stall: 111");
    #1;
    exe_valid = 3'b111;
    exe_idx[1] = 0;
    exe_idx[0] = 5;
    exe_idx[2] = 3;
    exe_store[0].usebytes = 4'b0011;
    exe_store[0].ready = 1;
    exe_store[0].addr = 32'hff;
    exe_store[0].data = 32'h00002345;
    exe_store[1].usebytes = 4'b1111;
    exe_store[1].ready = 1;
    exe_store[1].addr = 32'hbc;
    exe_store[1].data = 32'h87ffffff;
    exe_store[2].usebytes = 4'b0001;
    exe_store[2].ready = 1;
    exe_store[2].addr = 32'hc0;
    exe_store[2].data = 32'hffffff21;
    @(posedge clock)
    $display("GLODEN: head 0, tail 7, num 7, stall: 111");
    #1;
    exe_store[0].addr = 32'hf1;
    exe_store[1].addr = 32'hc0;
    exe_store[2].addr = 32'hc1;
    exe_idx[1] = 1;
    exe_store[1].data = 32'hff65ffff;
    exe_store[1].usebytes = 4'b0100;
    exe_idx[0] = 2;
    exe_store[0].data = 32'hffff43ff;
    exe_store[0].usebytes = 4'b0011;
    exe_idx[2] = 4;
    exe_store[2].data = 32'hffffffff;
    dispatch_req = 3'b100;
    retire = 3'b010;
    @(posedge clock)
    $display("GLODEN: head 1, tail 0, num 7, stall: 000");
    #1;
    exe_store[0].addr = 32'hf2;
    exe_store[1].addr = 32'hb2;
    exe_idx[1] = 6;
    exe_idx[0] = 7;
    exe_valid[2] = 0;
    dispatch_req = 0;
    @(posedge clock)
    $display("GLODEN: head 2, tail 0, num 6, stall: 000");
    #1;
    exe_valid = 0;
    retire = 3'b011;
    @(posedge clock)
    $display("GLODEN: head 4, tail 0, num 4, stall: 000");
    @(posedge clock)
    $display("GLODEN: head 6, tail 0, num 2, stall: 000");
    #1;
    retire = 3'b010;
    load_lookup[0].tail_pos = 0;
    @(posedge clock)
    $display("GLODEN: head 7, tail 0, num 1, stall: 000");
    @(posedge clock)
    $display("GLODEN: head 0, tail 0, num 1, stall: 000");
    @(posedge clock)
    $display("@@@@@@@@finish");
    $finish;
end

endmodule