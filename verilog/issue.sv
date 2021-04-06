`define TEST_MODE
`ifndef __ISSUE_V__
`define __ISSUE_V__




`timescale 1ns/100ps
module issue_stage(
    input                               clock,
    input                               reset,
	input 	RS_S_PACKET [2:0]	        rs_out,
	input 	[2:0][`XLEN-1:0] 			read_rda, read_rdb,  //from PRF
    input   FU_STATE_PACKET             fu_ready,
	output  logic [2:0][`PR-1:0]		rda_idx, rdb_idx,
	output 	ISSUE_FU_PACKET [2**`FU-1:0] issue_2_fu,
    output  FU_FIFO_PACKET              fu_fifo_stall
    `ifdef TEST_MODE
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] alu_fifo_display
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] mult_fifo_display
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] br_fifo_display
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] ls_fifo_display
    `endif
);

ISSUE_FU_PACKET [2:0]   issue;

/* read pr value */
always_comb begin
    for(int i=0; i<3; i++) begin
        rda_idx[i] = rs_out[i].reg1_pr;
        rdb_idx[i] = rs_out[i].reg2_pr;
    end
end
always_comb begin
    for(int i=0; i<3; i++) begin
        issue[i].valid = rs_out[i].valid;
        issue[i].op_sel = rs_out[i].op_sel;
        issue[i].NPC = rs_out[i].NPC;
        issue[i].PC = rs_out[i].PC;
        issue[i].opa_select = rs_out[i].opa_select;
        issue[i].opb_select = rs_out[i].opb_select;
        issue[i].inst = rs_out[i].inst;
        issue[i].halt = rs_out[i].halt;
        issue[i].rob_entry = rs_out[i].rob_entry;
        issue[i].sq_tail = rs_out[i].sq_tail;
        issue[i].dest_pr = rs_out[i].dest_pr;
        issue[i].r1_value = read_rda[i];
        issue[i].r2_value = read_rdb[i];
    end
end

/////////////////////////////////////////////////////
///////////////    FU FIFO
/////////////////////////////////////////////////////

ISSUE_FU_PACKET [2:0]   alu_fifo_in;
ISSUE_FU_PACKET [2:0]   mult_fifo_in;
ISSUE_FU_PACKET [2:0]   ls_fifo_in;
ISSUE_FU_PACKET [2:0]   br_fifo_in;
/* assign packet to fu fifo */
always_comb begin
    alu_fifo_in = 0;
    mult_fifo_in = 0;
    ls_fifo_in = 0;
    br_fifo_in = 0;
    for(int i=0; i<3; i++) begin
        alu_fifo_in[i] = rs_out[i].fu_sel == ALU_1 ? issue[i]:0;
        mult_fifo_in[i] = rs_out[i].fu_sel == MULT_1 ? issue[i]:0;
        ls_fifo_in[i] = rs_out[i].fu_sel == LS_1 ? issue[i]:0;
        br_fifo_in[i] = rs_out[i].fu_sel == BRANCH ? issue[i]:0;
    end
end

logic [3:0] fifo_full;

ISSUE_FU_PACKET [3:0] issue_waste;

fu_FIFO_3 alu_fifo(
    .clock(clock),
    .reset(reset),
    .fu_pckt_in(alu_fifo_in),
    .rd_EN({fu_ready.alu_1, fu_ready.alu_2, fu_ready.alu_3}),
    .full(fifo_full[0]),
    .almost_full(fu_fifo_stall.alu),
    .fu_pckt_out({issue_2_fu[ALU_1], issue_2_fu[ALU_2], issue_2_fu[ALU_3]})
    `ifdef TEST_MODE
    , .fifo_display(alu_fifo_display)
    `endif
);

fu_FIFO_3 ls_fifo(
    .clock(clock),
    .reset(reset),
    .fu_pckt_in(ls_fifo_in),
    .rd_EN({fu_ready.loadstore_1, fu_ready.loadstore_2, 1'b0}),
    .full(fifo_full[1]),
    .almost_full(fu_fifo_stall.ls),
    .fu_pckt_out({issue_2_fu[LS_1], issue_2_fu[LS_2], issue_waste[0]})
    `ifdef TEST_MODE
    , .fifo_display(ls_fifo_display)
    `endif
);

fu_FIFO_3 mult_fifo(
    .clock(clock),
    .reset(reset),
    .fu_pckt_in(mult_fifo_in),
    .rd_EN({fu_ready.mult_1, fu_ready.mult_2, 1'b0}),
    .full(fifo_full[2]),
    .almost_full(fu_fifo_stall.mult),
    .fu_pckt_out({issue_2_fu[MULT_1], issue_2_fu[MULT_2], issue_waste[1]})
    `ifdef TEST_MODE
    , .fifo_display(mult_fifo_display)
    `endif
);

fu_FIFO_3 br_fifo(
    .clock(clock),
    .reset(reset),
    .fu_pckt_in(br_fifo_in),
    .rd_EN({fu_ready.branch, 2'b0}),
    .full(fifo_full[3]),
    .almost_full(fu_fifo_stall.branch),
    .fu_pckt_out({issue_2_fu[BRANCH], issue_waste[3:2]})
    `ifdef TEST_MODE
    , .fifo_display(br_fifo_display)
    `endif
);

endmodule


`endif // _ISSUE_V_