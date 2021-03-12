`define TEST_MODE
// `define RS_ALLOCATE_DEBUG
`define IS_DEBUG
`ifndef __RS_V__
`define __RS_V__

`timescale 1ns/100ps

module Issue_Select
(
    input RS_IN_PACKET [`RSW-1:0]   rs_entries,
    input FU_STATE_PACKET           fu_ready,
    output FU_STATE_PACKET          fu_ready_next,
    
    /* if the entry is using alu & ready */
    input [`RSW-1:0]                alu_ready_in, 
    input [`RSW-1:0]                mult_ready_in,
    input [`RSW-1:0]                ls_ready_in,
    input [`RSW-1:0]                br_ready_in,
    output logic [`RSW-1:0]         alu_ready_next,
    output logic [`RSW-1:0]         mult_ready_next,
    output logic [`RSW-1:0]         ls_ready_next,
    output logic [`RSW-1:0]         br_ready_next,
    output RS_IN_PACKET             issue_pckt,
    output logic [`RSW-1:0]         tag_issue // one hot coding
);
/* if there is fu available */
logic [`RSW-1:0] alu_ready;
logic [`RSW-1:0] mult_ready;
logic [`RSW-1:0] ls_ready;
logic [`RSW-1:0] br_ready;
logic alu_av, mult_av, ls_av, br_av;
assign alu_av = fu_ready.alu_1 | fu_ready.alu_2 | fu_ready.alu_3;
assign mult_av = fu_ready.mult_1 | fu_ready.mult_2;
assign ls_av = fu_ready.storeload_1 | fu_ready.storeload_2;
assign br_av = fu_ready.branch;
always_comb begin
    for(int i=0; i<`RSW; i++) begin
        alu_ready[i] = alu_ready_in[i] & alu_av;
        mult_ready[i] = mult_ready_in[i] & mult_av;
        ls_ready[i] = ls_ready_in[i] & ls_av;
        br_ready[i] = br_ready_in[i] & br_av;
    end
end

/* select entry to issue */
logic yes_issue;
logic [`RSW-1:0]            tag_ready;
logic [`RSW-1:0][`XLEN-1:0] pc_comb;
logic [`XLEN-1:0]           pc_up_waste;
always_comb begin
    for (int i = 0; i < `RSW; i++) begin
        pc_comb[i] = rs_entries[i].PC;
    end
end
assign tag_ready = alu_ready | mult_ready | ls_ready | br_ready;
pc_sel16 sel_small_pc(.pc(pc_comb), .req(tag_ready), .en(1'b1), .gnt(tag_issue), .req_up(yes_issue), .pc_up(pc_up_waste));

/* update ready entries for each fu */
assign alu_ready_next = alu_ready_in & ~tag_issue;
assign mult_ready_next = mult_ready_in & ~tag_issue;
assign ls_ready_next = ls_ready_in & ~tag_issue;
assign br_ready_next = br_ready_in & ~tag_issue;

/* assign the selected entry to output */
RS_IN_PACKET issue_pckt_temp;

always_comb begin
    issue_pckt_temp = 0;
    for (int i=0; i<`RSW; i++) begin
        if(tag_issue[i]==1'b1)
            issue_pckt_temp = rs_entries[i];
    end
end


/* select fu for issue and upadte fu_ready */ 
FU_SELECT issue_fu;
always_comb begin
    fu_ready_next = fu_ready;
    issue_fu = ALU_1;
    if (yes_issue) begin 
    priority case(issue_pckt_temp.fu_sel)
        ALU_1: begin
            if (fu_ready.alu_1) begin
                fu_ready_next.alu_1 = 1'b0;
                issue_fu = ALU_1;
            end else if (fu_ready.alu_2) begin
                fu_ready_next.alu_2 = 1'b0;
                issue_fu = ALU_2;
            end else if (fu_ready.alu_3) begin
                fu_ready_next.alu_3 = 1'b0;
                issue_fu = ALU_3;
            end
        end
        LS_1: begin
            if (fu_ready.storeload_1) begin
                fu_ready_next.storeload_1 = 1'b0;
                issue_fu = LS_1;
            end else if (fu_ready.storeload_2 == 1'b1) begin
                fu_ready_next.storeload_2 = 1'b0;
                issue_fu = LS_2;
            end
        end
        MULT_1: begin
            if (fu_ready.mult_1 == 1'b1) begin
                fu_ready_next.mult_1 = 1'b0;
                issue_fu = MULT_1;
            end else if (fu_ready.mult_2 == 1'b1) begin
                fu_ready_next.mult_2 = 1'b0;
                issue_fu = MULT_2;
            end
        end
        BRANCH: begin
            if (fu_ready.branch == 1'b1) begin
                fu_ready_next.branch = 1'b0;
                issue_fu = BRANCH;
            end
        end
    endcase
    end
end

/* output issue pckt */
always_comb begin
    issue_pckt = issue_pckt_temp;
    issue_pckt.fu_sel = issue_fu;
end

endmodule

`timescale 1ns/100ps

module RS(
    input                       clock,
    input                       reset,
    input RS_IN_PACKET [2:0]    rs_in,
    input CDB_T_PACKET          cdb_t,
    input FU_STATE_PACKET       fu_ready,       // high if fu is ready to issue to
    output RS_S_PACKET [2:0]    issue_insts,
    output logic [2:0]           struct_stall    // if high, stall corresponding dispatch, dependent on fu_req
`ifdef TEST_MODE
    , output RS_IN_PACKET [`RSW-1:0] rs_entries_display
`endif

`ifdef IS_DEBUG
    , input RS_IN_PACKET [`RSW-1:0] rs_entries_debug
`endif
);

/* The struct array that stores all RS entries */
RS_IN_PACKET [`RSW-1:0]        rs_entries;
`ifdef TEST_MODE
    assign rs_entries_display = rs_entries;
`endif

/* select next entry to allocate */
logic [2:0][`RSW-1:0] new_entry;    // one hot coding
logic [`RSW-1:0] issue_EN;          // which entry to issue next



logic [2:0] not_stall; 
logic [`RSW-1:0] entry_av, entry_av_after2, entry_av_after1;


assign struct_stall = ~not_stall;
always_comb 
    for(int i=0; i<`RSW; i++) begin
        entry_av[i] = ~rs_entries[i].valid;
    end
assign entry_av_after2 = entry_av & ~new_entry[2];
assign entry_av_after1 = entry_av_after2 & ~new_entry[1];


ps16 sel_av2(.req(entry_av), .en(1'b1), .gnt(new_entry[2]), .req_up(not_stall[2]));
ps16 sel_av1(.req(entry_av_after2), .en(1'b1), .gnt(new_entry[1]), .req_up(not_stall[1]));
ps16 sel_av0(.req(entry_av_after1), .en(1'b1), .gnt(new_entry[0]), .req_up(not_stall[0]));


/* update ready tag while cdb_t broadcasts */
logic [`RSW-1:0] reg1_ready_next;
logic [`RSW-1:0] reg2_ready_next;
always_comb begin
    for(int i=0; i<`RSW; i++)begin
        reg1_ready_next[i] = rs_entries[i].reg1_pr==cdb_t.t0 ||
                             rs_entries[i].reg1_pr==cdb_t.t1 ||
                             rs_entries[i].reg1_pr==cdb_t.t2 ? 
                             1'b1 : rs_entries[i].reg1_ready;
        reg2_ready_next[i] = rs_entries[i].reg2_pr==cdb_t.t0 ||
                             rs_entries[i].reg2_pr==cdb_t.t1 ||
                             rs_entries[i].reg2_pr==cdb_t.t2 ? 
                             1'b1 : rs_entries[i].reg2_ready;
    end
end

/* allocate new entry & modify ready bit */ 
RS_IN_PACKET [`RSW-1:0] rs_entries_next;
always_comb begin
    for(int i=0; i < `RSW; i++) begin
        if (new_entry[2][i])
            rs_entries_next[i] = rs_in[2];
        else if (new_entry[1][i])
            rs_entries_next[i] = rs_in[1];
        else if (new_entry[0][i])
            rs_entries_next[i] = rs_in[0];
        else begin
            rs_entries_next[i] = rs_entries[i];
            rs_entries_next[i].reg1_ready = reg1_ready_next[i];
            rs_entries_next[i].reg2_ready = reg2_ready_next[i];
            if (issue_EN[i]) rs_entries_next[i].valid = 0;
        end
    end
end

always_ff @(posedge clock) begin
    if (reset)
    `ifndef IS_DEBUG
        rs_entries <= `SD 0; 
    `else
        rs_entries <= `SD rs_entries_debug;
    `endif
    else 
        rs_entries <= `SD rs_entries_next;
end

/***********End of allocate logic***********/

RS_S_PACKET [2:0]   issue_insts_temp;

/*****NEW*****/
FU_STATE_PACKET fu_ready_one_to_two;
FU_STATE_PACKET fu_ready_two_to_three;

logic [`RSW-1:0] alu_ready_init;
logic [`RSW-1:0] alu_ready_one_to_two;
logic [`RSW-1:0] alu_ready_two_to_three;
logic [`RSW-1:0] ls_ready_init;
logic [`RSW-1:0] ls_ready_one_to_two;
logic [`RSW-1:0] ls_ready_two_to_three;
logic [`RSW-1:0] br_ready_init;
logic [`RSW-1:0] br_ready_one_to_two;
logic [`RSW-1:0] br_ready_two_to_three;
logic [`RSW-1:0] mult_ready_init;
logic [`RSW-1:0] mult_ready_one_to_two;
logic [`RSW-1:0] mult_ready_two_to_three;

logic [2:0][`RSW-1:0] tag_issue_separate;
RS_IN_PACKET [2:0] issue_pckts;


logic [`RSW-1:0] tag_ready;
always_comb begin
    for(int i=0; i<`RSW; i++) begin
        tag_ready[i] = reg1_ready_next[i] & reg2_ready_next[i] & rs_entries[i].valid;
    end
end
always_comb begin
    for(int i=0; i<`RSW; i++) begin
        alu_ready_init[i] = tag_ready[i] && rs_entries[i].fu_sel == ALU_1;
        mult_ready_init[i] = tag_ready[i] && rs_entries[i].fu_sel == MULT_1;
        ls_ready_init[i] = tag_ready[i] && rs_entries[i].fu_sel == LS_1;
        br_ready_init[i] = tag_ready[i] && rs_entries[i].fu_sel == BRANCH;
    end
end

Issue_Select issue_first(.rs_entries(rs_entries), .fu_ready(fu_ready), .fu_ready_next(fu_ready_one_to_two), .alu_ready_in(alu_ready_init), .mult_ready_in(mult_ready_init), .ls_ready_in(ls_ready_init), .br_ready_in(br_ready_init), .alu_ready_next(alu_ready_one_to_two), .mult_ready_next(mult_ready_one_to_two), .ls_ready_next(ls_ready_one_to_two), .br_ready_next(br_ready_one_to_two), .issue_pckt(issue_pckts[2]), .tag_issue(tag_issue_separate[2]));

Issue_Select issue_sec(.rs_entries(rs_entries), .fu_ready(fu_ready_one_to_two), .fu_ready_next(fu_ready_two_to_three), .alu_ready_in(alu_ready_one_to_two), .mult_ready_in(mult_ready_one_to_two), .ls_ready_in(ls_ready_one_to_two), .br_ready_in(br_ready_one_to_two), .alu_ready_next(alu_ready_two_to_three), .mult_ready_next(mult_ready_two_to_three), .ls_ready_next(ls_ready_two_to_three), .br_ready_next(br_ready_two_to_three), .issue_pckt(issue_pckts[1]), .tag_issue(tag_issue_separate[1]));

Issue_Select issue_third(.rs_entries(rs_entries), .fu_ready(fu_ready_two_to_three), .fu_ready_next(), .alu_ready_in(alu_ready_two_to_three), .mult_ready_in(mult_ready_two_to_three), .ls_ready_in(ls_ready_two_to_three), .br_ready_in(br_ready_two_to_three), .alu_ready_next(), .mult_ready_next(), .ls_ready_next(), .br_ready_next(), .issue_pckt(issue_pckts[0]), .tag_issue(tag_issue_separate[0]));



`ifdef RS_ALLOCATE_DEBUG
    assign issue_EN = 0;
`else
    assign issue_EN = tag_issue_separate[0] | tag_issue_separate[1] | tag_issue_separate[2];
`endif

always_comb begin
    for(int i=0; i<3; i++)begin
        issue_insts[i].valid = issue_pckts[i].valid;
        issue_insts[i].fu_sel = issue_pckts[i].fu_sel;
        issue_insts[i].op_sel = issue_pckts[i].op_sel;
        issue_insts[i].NPC = issue_pckts[i].NPC;
        issue_insts[i].PC = issue_pckts[i].PC;
        issue_insts[i].opa_select = issue_pckts[i].opa_select;
        issue_insts[i].opb_select = issue_pckts[i].opb_select;
        issue_insts[i].inst = issue_pckts[i].inst;
        issue_insts[i].halt = issue_pckts[i].halt;
        issue_insts[i].dest_pr = issue_pckts[i].dest_pr;
        issue_insts[i].reg1_pr = issue_pckts[i].reg1_pr;
        issue_insts[i].reg2_pr = issue_pckts[i].reg2_pr;
    end
end
endmodule

`endif