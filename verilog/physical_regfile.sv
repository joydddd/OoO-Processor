`ifndef __PR_V__
`define __PR_V__
`define TEST_MODE

`timescale 1ns/100ps

module physical_regfile(
    input  [2:0][`PR-1:0] 		rda_idx, rdb_idx,   // read index
    input  [2:0][`XLEN-1:0] 	wr_data,   // write data
    input   CDB_T_PACKET 	    wr_idx,
    input   clock,
    input   reset,
 
    output logic [2:0][`XLEN-1:0] rda_out, rdb_out    // read data
`ifdef TEST_MODE
    , output logic [2**`PR-1:0][`XLEN-1:0] pr_reg_display           
`endif
);

logic [2**`PR-1:0][`XLEN-1:0] pr_reg;
logic [2**`PR-1:0][`XLEN-1:0] pr_next;

`ifdef TEST_MODE
assign pr_reg_display = pr_reg;
`endif

// Write 
always_comb begin
    pr_next = pr_reg;
    if (wr_idx.t0 != `ZERO_PR)
        pr_next[wr_idx.t0] = wr_data[0];
    if (wr_idx.t1 != `ZERO_PR)
        pr_next[wr_idx.t1] = wr_data[1];
    if (wr_idx.t2 != `ZERO_PR)
        pr_next[wr_idx.t2] = wr_data[2];
end

// Read 
always_comb begin
    for(int i=0; i<3; i++) begin
        rda_out[i] = pr_reg[rda_idx[i]];
        rdb_out[i] = pr_reg[rdb_idx[i]];
    end
end

always_ff @(posedge clock) begin
    if (reset)
        pr_reg <= `SD 0;
    else pr_reg <= `SD pr_next;
end



endmodule; // physical_regfile


`endif //__PR_V__