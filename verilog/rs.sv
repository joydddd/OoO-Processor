`define TEST_MODE
// `define RS_ALLOCATE_DEBUG
`define IS_DEBUG
`ifndef __RS_V__
`define __RS_V__

`timescale 1ns/100ps

module Issue_Select(
    input RS_IN_PACKET [`RSW-1:0]   rs_entries,
    input logic [`RSW-1:0]                tag_ready_in,
    input FU_STATE_PACKET           fu_ready,
    input FU_SELECT [`RSW-1:0]      fu_single_comb,
    output FU_STATE_PACKET          fu_ready_next,
    output logic [`RSW-1:0]         tag_ready_next,
    output FU_SELECT [`RSW-1:0]     fu_single_comb_next
);

logic no_issue;
logic [`RSW-1:0] tag_ready_temp;
logic [`RSW-1:0] tag_ready;

ps16 sel_av2(.req(tag_ready), .en(1'b1), .gnt(tag_ready_temp), .req_up(no_issue));

assign tag_ready_next = tag_ready_temp | tag_ready_in;

always_comb begin
    fu_single_comb_next = fu_single_comb;
    tag_ready = tag_ready_in;
    for (int i = 0; i < 2**`RS; i++) begin
        if (~tag_ready[i] && rs_entries[i].valid && rs_entries[i].reg1_ready && rs_entries[i].reg2_ready) begin
            case(rs_entries[i].fu_sel)
                ALU_1: begin
                    if (fu_ready.alu_1 == 1'b1 || fu_ready.alu_2 == 1'b1 || fu_ready.alu_3 == 1'b1)
                        tag_ready[i] = 1'b1;
                end
                LS_1: begin
                    if (fu_ready.storeload_1 == 1'b1 || fu_ready.storeload_2 == 1'b1) begin
                        tag_ready[i] = 1'b1;
                    end
                end
                MULT_1: begin
                    if (fu_ready.mult_1 == 1'b1 || fu_ready.mult_2 == 1'b1) begin
                        tag_ready[i] = 1'b1;
                    end
                end
                BRANCH: begin
                    if (fu_ready.branch == 1'b1) begin
                        tag_ready[i] = 1'b1;
                    end
                end
            endcase
        end
        else if (tag_ready[i]) begin
            tag_ready[i] = 1'b0;
        end    
    end
    fu_ready_next = fu_ready;
    for (int i = 0; i < `RSW; i++) begin
        if (tag_ready_temp[i] == 1) begin
            case (rs_entries[i].fu_sel)
                ALU_1: begin
                    if (fu_ready.alu_1 == 1'b1) begin
                        fu_ready_next.alu_1 = 1'b0;
                        fu_single_comb_next[i] = ALU_1;
                    end
                    else if (fu_ready.alu_2 == 1'b1) begin
                        fu_ready_next.alu_2 = 1'b0;
                        fu_single_comb_next[i] = ALU_2;
                    end
                    else if (fu_ready.alu_3 == 1'b1) begin
                        fu_ready_next.alu_3 = 1'b0;
                        fu_single_comb_next[i] = ALU_3;
                    end
                end
                LS_1: begin
                    if (fu_ready.storeload_1 == 1'b1) begin
                        fu_ready_next.storeload_1 = 1'b0;
                        fu_single_comb_next[i] = LS_1;
                    end
                    else if (fu_ready.storeload_2 == 1'b1) begin
                        fu_ready_next.storeload_2 = 1'b0;
                        fu_single_comb_next[i] = LS_2;
                    end
                end
                MULT_1: begin
                    if (fu_ready.mult_1 == 1'b1) begin
                        fu_ready_next.mult_1 = 1'b0;
                        fu_single_comb_next[i] = MULT_1;
                    end
                    else if (fu_ready.mult_2 == 1'b1) begin
                        fu_ready_next.mult_2 = 1'b0;
                        fu_single_comb_next[i] = MULT_2;
                    end
                end
                BRANCH: begin
                    if (fu_ready.branch == 1'b1) begin
                        fu_ready_next.branch = 1'b0;
                        fu_single_comb_next[i] = BRANCH;
                    end
                end
            endcase
        end
    end
end

endmodule

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
        entry_av[i] = issue_EN[i] | ~rs_entries[i].valid;
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
FU_STATE_PACKET fu_ready_waste;

logic [`RSW-1:0] tag_ready_one_to_two;
logic [`RSW-1:0] tag_ready_two_to_three;
logic [`RSW-1:0] tag_ready_final;

FU_SELECT [`RSW-1:0] fu_single_comb_one_to_two;
FU_SELECT [`RSW-1:0] fu_single_comb_two_to_three;
FU_SELECT [`RSW-1:0] fu_single_comb_final;

int i,k;

Issue_Select issue_first(.rs_entries(rs_entries), .tag_ready_in(0), .fu_ready(fu_ready), .fu_single_comb(0), .fu_ready_next(fu_ready_one_to_two), .tag_ready_next(tag_ready_one_to_two), .fu_single_comb_next(fu_single_comb_one_to_two));

Issue_Select issue_second(.rs_entries(rs_entries), .tag_ready_in(tag_ready_one_to_two), .fu_ready(fu_ready_one_to_two), .fu_single_comb(fu_single_comb_one_to_two), .fu_ready_next(fu_ready_two_to_three), .tag_ready_next(tag_ready_two_to_three), .fu_single_comb_next(fu_single_comb_two_to_three));

Issue_Select issue_third(.rs_entries(rs_entries), .tag_ready_in(tag_ready_two_to_three), .fu_ready(fu_ready_two_to_three), .fu_single_comb(fu_single_comb_two_to_three), .fu_ready_next(fu_ready_waste), .tag_ready_next(tag_ready_final), .fu_single_comb_next(fu_single_comb_final));

always_comb begin
    // Initialize issue_EN to 0

    k = 0;

    // Set the output based on which RS entries are going to be issued
    for (int j = 0; j < 3; j++) begin
        for (i = k; i < `RSW; i++) begin
            if (tag_ready_final[i]) begin
                issue_insts_temp[j].fu_sel  = fu_single_comb_final[i];
                issue_insts_temp[j].op_sel  = rs_entries[i].op_sel;
                issue_insts_temp[j].NPC     = rs_entries[i].NPC;
                issue_insts_temp[j].PC      = rs_entries[i].PC;
                issue_insts_temp[j].opa_select = rs_entries[i].opa_select;
                issue_insts_temp[j].opb_select = rs_entries[i].opb_select;
                issue_insts_temp[j].inst    = rs_entries[i].inst;
                issue_insts_temp[j].halt    = rs_entries[i].halt;
                issue_insts_temp[j].dest_pr = rs_entries[i].dest_pr;
                issue_insts_temp[j].reg1_pr = rs_entries[i].reg1_pr;
                issue_insts_temp[j].reg2_pr = rs_entries[i].reg2_pr;
                issue_insts_temp[j].valid   = rs_entries[i].valid;
                k = i + 1;
                break;
            end
        end
        if (i == `RSW) begin
            for (int p = j; p < 3; p++) begin
                issue_insts_temp[p].valid   = 1'b0;
            end
        end
    end
end
`ifdef RS_ALLOCATE_DEBUG
    assign issue_EN = 0;
`else
    assign issue_EN = tag_ready_final;
`endif


assign issue_insts = issue_insts_temp;
endmodule

`endif