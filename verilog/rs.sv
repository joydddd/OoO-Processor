module RS(
    input                       clock,
    input                       reset,
    input RS_IN_PACKET [2:0]    rs_in,
    input CDB_T_PACKET          cdb_t,
    input FU_STATE_PACKET       fu_ready,       // high if fu is ready to issue to
    output RS_S_PACKET [2:0]    issue_insts,
    output [2:0]                struct_stall    // if high, stall corresponding dispatch, dependent on fu_req
`ifdef TEST_MODE
    , output RS_IN_PACKET [2**`RS-1:0] rs_entries_display
`endif
);

RS_IN_PACKET [2**`RS-1:0]        rs_entries;
logic [2**`RS-1:0]             issue_ready;
`ifdef TEST_MODE
    assign rs_entries_display = rs_entries;
`endif

// TODO: design
always_comb begin
    for (int i = 0; i < 2**`RS; i++) begin
        if (issue_ready[i] == 0 && rs_entries[i].reg1_ready && rs_entries[i].reg2_ready) begin
            case(rs_entries.fu_sel)
                ALU_1: begin
                    if (fu_ready.alu_1 == 1) begin
                        issue_ready[i] = 1;
                    end
                    else if (fu_ready.alu_2 == 1) begin
                        rs_entries.fu_sel = ALU_2;
                        issue_ready[i] = 1;
                    end
                    else if (fu_ready.alu_3 == 1) begin
                        rs_entries.fu_sel = ALU_3;
                        issue_ready[i] = 1;
                    end
                end
                LS_1: begin
                    if (fu_ready.storeload_1 == 1) begin
                        issue_ready[i] = 1;
                    end
                    else if (fu_ready.storeload_2 == 1) begin
                        rs_entries.fu_sel = LS_2;
                        issue_ready[i] = 1;
                    end
                end
                MULT_1: begin
                    if (fu_ready.mult_1 == 1) begin
                        issue_ready[i] = 1;
                    end
                    else if (fu_ready.mult_2 == 1) begin
                        rs_entries.fu_sel = MULT_2;
                        issue_ready[i] = 1;
                    end
                end
                BRANCH: begin
                    if (fu_ready.branch == 1) begin
                        issue_ready[i] = 1;
                    end
                end
            endcase
        end
    end
end
endmodule