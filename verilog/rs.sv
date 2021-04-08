`define TEST_MODE
// `define RS_ALLOCAfTE_DEBUG
// `define IS_DEBUG
`ifndef __RS_V__
`define __RS_V__

`timescale 1ns/100ps

module RS(
    input                       clock,
    input                       reset,
    input RS_IN_PACKET [2:0]    rs_in,
    input CDB_T_PACKET          cdb_t,
    input FU_FIFO_PACKET        fu_fifo_stall,  // high if fu FIFO has < 3 available
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

/*****NEW*****/


logic [`RSW-1:0] tag_ready;
logic [`RSW-1:0] entry_fu_ready;
logic [`RSW-1:0] entry_ready;
logic [`RSW-1:0] entry_ready_two2one;
logic [`RSW-1:0] entry_ready_one2zero;

logic [2:0][`RSW-1:0] tag_issue_separate;


/* determine which entries are ready */
always_comb begin
    for(int i=0; i<`RSW; i++) begin
        tag_ready[i] = reg1_ready_next[i] & reg2_ready_next[i] & rs_entries[i].valid;
    end
end
always_comb begin
    entry_fu_ready = 0;
    for(int i=0; i<`RSW; i++) begin
        priority case (rs_entries[i].fu_sel)
            ALU_1: entry_fu_ready[i] = ~fu_fifo_stall.alu;
            LS_1: entry_fu_ready[i] = ~fu_fifo_stall.ls;
            MULT_1: entry_fu_ready[i] = ~fu_fifo_stall.mult;
            BRANCH: entry_fu_ready[i] = ~fu_fifo_stall.branch;
        endcase
    end
end
assign entry_ready = tag_ready & entry_fu_ready;

/* select which entry to issue */

ps16 is_ps_2(.req(entry_ready), .en(1'b1), .gnt(tag_issue_separate[2]));
assign entry_ready_two2one = entry_ready & ~tag_issue_separate[2];
ps16 is_ps_1(.req(entry_ready_two2one), .en(1'b1), .gnt(tag_issue_separate[1]));
assign entry_ready_one2zero = entry_ready_two2one & ~tag_issue_separate[1];
ps16 is_ps_0(.req(entry_ready_one2zero), .en(1'b1), .gnt(tag_issue_separate[0]));


/* assign issue packet */
RS_IN_PACKET [2:0] issue_pckts;
always_comb begin
    issue_pckts = 0;
    for(int i=0; i<`RSW; i++) begin
        if (tag_issue_separate[2][i]) issue_pckts[2] = rs_entries[i];
        if (tag_issue_separate[1][i]) issue_pckts[1] = rs_entries[i];
        if (tag_issue_separate[0][i]) issue_pckts[0] = rs_entries[i];
    end
end

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
        issue_insts[i].rob_entry = issue_pckts[i].rob_entry;
        issue_insts[i].sq_tail = issue_pckts[i].sq_tail;
        issue_insts[i].dest_pr = issue_pckts[i].dest_pr;
        issue_insts[i].reg1_pr = issue_pckts[i].reg1_pr;
        issue_insts[i].reg2_pr = issue_pckts[i].reg2_pr;
    end
end
endmodule

`endif