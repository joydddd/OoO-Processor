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
logic [1:0]                 fu_load_ready;
logic [1:0]                 want_to_complete;
FU_COMPLETE_PACKET [1:0]    fu_packet_out;

// complete
logic [2:0]                 complete_stall;

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
    .stall(stall),                                  // -> TODO
    .dispatch(dispatch),                            // <- dispatch.TODO
    .tail_pos(tail_pos),                            // -> TODO
    .exe_valid(exe_valid),                          // <- alu.exe_valid
    .exe_store(exe_store),                          // <- alu.exe_store
    .exe_idx(exe_idx),                              // <- alu.exe_idx
    .load_lookup(load_lookup),                      // <- load.load_lookup
    .load_forward(load_forward),                    // -> load.load_forward
    .retire(retire),                                // <- retire.TODO
    .cache_wb(cache_wb),                            // -> TODO
    .sq_display(sq_display),
    .head_dis(head_dis),
    .tail_dis(tail_dis),
    .filled_num_dis(filled_num_dis),
    .older_stores_display(older_stores),
    .older_stores_valid_display(older_stores_valid)
);

ISSUE_FU_PACKET[2:0] alu_pckt_in;

fu_alu ALU_0(
    .clock(clock),
    .reset(reset),
    .complete_stall(complete_stall[0]),
    .fu_packet_in(alu_pckt_in[0]),
    // STORE
    .if_store(exe_valid[0]),
    .store_pckt(exe_store[0]),
    .sq_idx(exe_idx[0])
);

fu_alu ALU_1(
    .clock(clock),
    .reset(reset),
    .complete_stall(complete_stall[1]),
    .fu_packet_in(alu_pckt_in[1]),
    // STORE
    .if_store(exe_valid[1]),
    .store_pckt(exe_store[1]),
    .sq_idx(exe_idx[1])
);

fu_alu ALU_2(
    .clock(clock),
    .reset(reset),
    .complete_stall(complete_stall[2]),
    .fu_packet_in(alu_pckt_in[2]),
    // STORE
    .if_store(exe_valid[2]),
    .store_pckt(exe_store[2]),
    .sq_idx(exe_idx[2])
);

ISSUE_FU_PACKET [1:0] load_pckt_in;

fu_load LD_0(
    .clock(clock),
    .reset(reset),
    .complete_stall(0),
    .fu_packet_in(load_pckt_in[0]),

    // output
    .fu_ready(fu_load_ready[0]),
    .want_to_complete(want_to_complete[0]),
    .fu_packet_out(fu_packet_out[0]),

    // SQ
    .sq_lookup(load_lookup[0]),    // output
    .sq_result(load_forward[0])    // input

    // Cache
);


int cycle_count;
always begin
    #5;
    clock = ~clock;
end
always@(posedge clock) begin
   cycle_count++; 
end

task show_fu_load;
    $display("#########  LOAD OUT  #########");
    $display("| fu_ready | want_to_complete | valid |  halt  | branch | target_pc | dest_pr | dest_value | rob_entry |");
    for (int i = 0; i < 2; i++) begin
        $display("|    %b     |        %b         |   %b   |   %b    |   %b    | %8h  |   %d    |  %8h  |    %d     |", 
            fu_load_ready[i], want_to_complete[i], fu_packet_out[i].valid, fu_packet_out[i].halt, fu_packet_out[i].if_take_branch, 
            fu_packet_out[i].target_pc, fu_packet_out[i].dest_pr, fu_packet_out[i].dest_value, fu_packet_out[i].rob_entry);
    end
endtask

task show_look_up;
    $display("##########  LOOK UP  ##########");
    $display("| tail_pos | addr |");
    for (int i = 0; i < 2; i++) begin
        $display("|    %d     |        %h        |", load_lookup[i].tail_pos, load_lookup[i].addr);
    end
endtask

task show_exe;
    $display("############  EXE  ############");
    $display("| valid | index | ready | usebytes |   addr   |   data   |");
    for (int i = 0; i < 3; i++) begin
        $display("|   %b   |   %d   |   %b   |   %b   | %8h | %8h |", exe_valid[i], exe_idx[i], exe_store[i].ready, exe_store[i].usebytes, exe_store[i].addr, exe_store[i].data);
    end
endtask

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
    $display("LOAD1: stall: %b, usebytes: %4b, data: %h", load_forward[0].stall, load_forward[0].usebytes, load_forward[0].data);
    $display("LOAD2: stall: %b, usebytes: %4b, data: %h", load_forward[1].stall, load_forward[1].usebytes, load_forward[1].data);
endtask

always @(negedge clock) begin
    $display(" =============== cycle %d ==============", cycle_count);
    show_exe;
    //show_fu_load;
    show_look_up;
    show_sq;
    //show_older_stores;
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
    complete_stall = 3'b000;
    alu_pckt_in = 0;
    load_pckt_in = 0;
    cycle_count = 0;
    retire = 0;
    dispatch_req = 0;
    
    

    @(negedge clock)
    @(negedge clock)
    #1;
    reset = 0;
    dispatch_req = 3'b101;
    //load_lookup[0].tail_pos = 0;
    $display("GOLDEN: head 0, tail 0, num 0");
    @(posedge clock)
    $display("GOLDEN: head 0, tail 2, num 2");
    @(posedge clock)
    $display("GOLDEN: head 0, tail 4, num 4");
    @(posedge clock)
    //load_lookup[0].tail_pos = 4;
    //load_lookup[0].addr = 32'hc0;
    $display("GOLDEN: head 0, tail 6, num 6, stall: 001");
    dispatch_req = 3'b101;
    @(posedge clock)
    $display("GOLDEN: head 0, tail 7, num 7, stall: 111");
    @(posedge clock)
    $display("GOLDEN: head 0, tail 7, num 7, stall: 111");

    //////////////////////////////////////////////////////////////////////////////

    @(posedge clock)
    $display("GOLDEN: head 0, tail 7, num 7, stall: 111");
    #1;
    
    // MEM[r2+0] = r3
    // r2 = 16 = x10
    // r3 = 32 = x20
    alu_pckt_in[0] = {
        1'b1,           // valid
        SW,             // op_sel
        `XLEN'd16,      // NPC
        `XLEN'd12,      // PC
        OPA_IS_RS1,     // opa_select
        OPB_IS_RS2,     // opb_select
        `XLEN'h00312023,// inst (imm = 0, rs2 = 3, rs1 = 2, funct3 = 0x2, imm = 0, opcode = SW)
        1'b0,           // halt
        `ROB'd1,        // rob_entry
        `LSQ'd0,        // sq_tail
        `PR'd0,         // dest_pr (no dest reg)
        `XLEN'd16,      // r1_value
        `XLEN'd32       // r2_value
    };
    // MEM[r20+0] = r4
    // r20 = 40 = x28
    // r4 = 56 = x38
    alu_pckt_in[1] = {
        1'b1,           // valid
        SW,             // op_sel
        `XLEN'd20,      // NPC
        `XLEN'd16,      // PC
        OPA_IS_RS1,     // opa_select
        OPB_IS_RS2,     // opb_select
        `XLEN'h004a2023,// inst (imm = 0, rs2 = 4, rs1 = 20, funct3 = 0x2, imm = 0, opcode = SW)
        1'b0,           // halt
        `ROB'd2,        // rob_entry
        `LSQ'd1,        // sq_tail
        `PR'd0,         // dest_pr (no dest reg)
        `XLEN'd40,      // r1_value
        `XLEN'd56       // r2_value
    };
    // MEM[r20+0] = r15
    // r20 = 120 = x78
    // r15 = 136 = x88
    alu_pckt_in[2] = {
        1'b1,           // valid
        SW,             // op_sel
        `XLEN'd24,      // NPC
        `XLEN'd20,      // PC
        OPA_IS_RS1,     // opa_select
        OPB_IS_RS2,     // opb_select
        `XLEN'h00fa2023,// inst (imm = 0, rs2 = 15, rs1 = 20, funct3 = 0x2, imm = 0, opcode = SW)
        1'b0,           // halt
        `ROB'd3,        // rob_entry
        `LSQ'd2,        // sq_tail
        `PR'd0,         // dest_pr
        `XLEN'd120,     // r1_value
        `XLEN'd136      // r2_value
    };

    //////////////////////////////////////////////////////////////////////////////

    @(posedge clock)
    $display("GOLDEN: head 0, tail 7, num 7, stall: 111");
    #1;
    alu_pckt_in = 0;

    //////////////////////////////////////////////////////////////////////////////

    @(posedge clock)
    $display("GOLDEN: head 0, tail 7, num 7, stall: 111");
    #1;
    
    // r4 = MEM[r10+0]
    // r10 = 32 = x20
    load_pckt_in[0] = {
        1'b1,           // valid
        LW,             // op_sel
        `XLEN'd28,      // NPC
        `XLEN'd24,      // PC
        OPA_IS_RS1,     // opa_select
        OPB_IS_I_IMM,   // opb_select
        `XLEN'h00052203,// inst (imm = 0, rs2 = 0, rs1 = 10, funct3 = 0x2, imm = 0, opcode = LW)
        1'b0,           // halt
        `ROB'd4,        // rob_entry
        `LSQ'd3,        // sq_tail
        `PR'd4,         // dest_pr
        `XLEN'd32,      // r1_value
        `XLEN'd0        // r2_value (useless)
    };

    retire = 3'b010;

    //////////////////////////////////////////////////////////////////////////////

    @(posedge clock)
    $display("GOLDEN: head 1, tail 0, num 7, stall: 000");
    #1;

    // r17 = MEM[r31+0]
    // r31 = 56 = x38
    load_pckt_in[0] = {
        1'b1,           // valid
        LW,             // op_sel
        `XLEN'd32,      // NPC
        `XLEN'd28,      // PC
        OPA_IS_RS1,     // opa_select
        OPB_IS_I_IMM,   // opb_select
        `XLEN'h000fa883,// inst (imm = 0, rs2 = 0, rs1 = 31, funct3 = 0x2, imm = 0, opcode = LW)
        1'b0,           // halt
        `ROB'd5,        // rob_entry
        `LSQ'd4,        // sq_tail
        `PR'd17,        // dest_pr
        `XLEN'd56,      // r1_value
        `XLEN'd0        // r2_value (useless)
    };    
    
    dispatch_req = 0;
    @(posedge clock)
    $display("GOLDEN: head 2, tail 0, num 6, stall: 000");
    #1;

    // r27 = MEM[r31+24]
    // r31 = 56 = x38
    load_pckt_in[0] = {
        1'b1,           // valid
        LW,             // op_sel
        `XLEN'd36,      // NPC
        `XLEN'd32,      // PC
        OPA_IS_RS1,     // opa_select
        OPB_IS_I_IMM,   // opb_select
        `XLEN'h018fad83,// inst (imm = 0, rs2 = 0, rs1 = 31, funct3 = 0x2, imm = 0, opcode = LW)
        1'b0,           // halt
        `ROB'd6,        // rob_entry
        `LSQ'd5,        // sq_tail
        `PR'd27,        // dest_pr
        `XLEN'd56,      // r1_value
        `XLEN'd0        // r2_value (useless)
    };
    
    retire = 3'b011;
    @(posedge clock)
    $display("GOLDEN: head 4, tail 0, num 4, stall: 000");
    @(posedge clock)
    $display("GOLDEN: head 6, tail 0, num 2, stall: 000");
    #1;

    retire = 3'b010;
    //load_lookup[0].tail_pos = 0;
    @(posedge clock)
    $display("GOLDEN: head 7, tail 0, num 1, stall: 000");
    @(posedge clock)
    $display("GOLDEN: head 0, tail 0, num 1, stall: 000");
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    $display("@@@@@@@@finish");
    $finish;
end

endmodule