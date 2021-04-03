`define TEST_MODE

module testbench;
logic                       clock, reset;
// dispatch
wire [2:0]                  struct_stall;
logic [2:0]                 dispatch; // with struct_stall considered
wire [2:0][`LSQ-1:0]        new_entry_idx;

// write addr and value
logic [1:0]                 exe_valid;
SQ_ENTRY_PACKET [1:0]       exe_store;
logic [1:0][`LSQ-1:0]       exe_idx;

// retire
logic [2:0]                 retire;
SQ_ENTRY_PACKET [2:0]       cache_wb;
//display
SQ_ENTRY_PACKET [2**`LSQ-1:0] sq_display;
logic [`LSQ-1:0]       head_dis, tail_dis, filled_num_dis;


SQ tdb(
    .clock(clock),
    .reset(reset),
    .struct_stall(struct_stall),
    .dispatch(dispatch),
    .new_entry_idx(new_entry_idx),
    .exe_valid(exe_valid),
    .exe_store(exe_store),
    .exe_idx(exe_idx),
    .retire(retire),
    .cache_wb(cache_wb),
    .sq_display(sq_display),
    .head_dis(head_dis),
    .tail_dis(tail_dis),
    .filled_num_dis(filled_num_dis)
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
        $display("%1d|  %d  | %8h | %4b  | %8h |", i, sq_display[i].ready, sq_display[i].usebytes, sq_display[i].addr, sq_display[i].data);
    end
endtask

always @(negedge clock) begin
    $display("cycle %d", cycle_count);
    show_sq;
end

initial begin
    clock = 0;
    reset = 1;
    cycle_count = 0;
    

    @(posedge clock)
    @(posedge clock)
    #1;
    dispatch = 3'b101;
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    #1;
    exe_valid = 3'b111;
    exe_idx[1] = 5;
    exe_idx[0] = 7;
    exe_store[0].usebytes = 4'b0011;
    exe_store[0].ready = 1;
    exe_store[0].addr = 32'hff;
    exe_store[0].data = 32'h00002345;
    exe_store[1].usebytes = 4'b0011;
    exe_store[1].ready = 1;
    exe_store[1].addr = 32'hbc;
    exe_store[1].data = 32'h00002300;
    @(posedge clock)
    exe_store = 0;
    retire = 3'b101;
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    $display("@@@@@@@@finish");
    $finish;
end

endmodule