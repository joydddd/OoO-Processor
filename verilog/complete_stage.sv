`timescale 1ns/100ps

// complete_stage is a combinational module
// fu_finish:  given by FU, 1 means the corresponding functional unit is gonna finish its calculation
// fu_c_in:    given by FU, specifies the next three values and PRs that are gonna be written back,
//             if the number of written back pairs are less than 3, the missing pairs should have PRs and values all be 0
// fu_c_stall: if the number of finishing FU is more than 3, the first 3 will be chosen, and the other will be 
//             discared by setting the corresponding bits in fu_c_stall to 1
// cdb_t:      destination PR, 0 for no-writting-back
// wb_value:   values to be written back to PR, 0 for no-writting-back
module complete_stage(
    input   FU_STATE_PACKET             fu_finish,
    input   FU_COMPLETE_PACKET [2:0]    fu_c_in,

    output  FU_STATE_PACKET             fu_c_stall, // stall on complete hazard
    /* write physical register */
    output  CDB_T_PACKET                cdb_t,      // destination pr
    output  [2:0][`XLEN-1:0]            wb_value
);

    wire [7:0]      sel_1, sel_2, sel_3;
    wire [7:0]      fu_finish_12, fu_finish_23;

    ps8 sel_1st(fu_finish   , 1'b1, sel_1, req1_waste);
    ps8 sel_2nd(fu_finish_12, 1'b1, sel_2, req2_waste);
    ps8 sel_3rd(fu_finish_23, 1'b1, sel_3, req3_waste);

    assign fu_finish_12 = fu_finish    & ~sel_1;
    assign fu_finish_23 = fu_finish_12 & ~sel_2;
    assign fu_c_stall   = fu_finish_23 & ~sel_3;

    assign cdb_t.t0 = fu_c_in[0].dest_pr;
    assign cdb_t.t1 = fu_c_in[1].dest_pr;
    assign cdb_t.t2 = fu_c_in[2].dest_pr;
    
    assign wb_value[0] = fu_c_in[0].dest_value;
    assign wb_value[1] = fu_c_in[1].dest_value;
    assign wb_value[2] = fu_c_in[2].dest_value;

endmodule