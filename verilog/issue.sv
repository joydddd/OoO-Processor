`define TEST_MODE
`ifndef __ISSUE_V__
`define __ISSUE_V__

`timescale 1ns/100ps
module issue_stage(
	input 	RS_S_PACKET [2:0]	        rs_out,
	input 	[2:0][`XLEN-1:0] 			read_rda, read_rdb,  //from PRF
	output  logic [2:0][`PR-1:0]		rda_idx, rdb_idx,
	output 	ISSUE_FU_PACKET [2**`FU-1:0] issue_2_fu
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
        issue[i].dest_pr = rs_out[i].dest_pr;
        issue[i].r1_value = read_rda[i];
        issue[i].r2_value = read_rdb[i];
    end
end

/* assign packet to fu */
always_comb begin
    issue_2_fu = 0;
    for(int i=0; i<3; i++) begin
        if (rs_out[i].valid)
            issue_2_fu[rs_out[i].fu_sel] = issue[i];
    end
end

endmodule


`endif // _ISSUE_V_