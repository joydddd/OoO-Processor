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
`ifdef TEST_MODE
    assign rs_entries_display = rs_entries;
`endif

logic [2**`RS-1:0]      issue_ready;
// when an instruction in the RS is issued, set "issued" to 1 at the same cycle
// if "issued" is 1, clear the corresponding RS entry at the next cycle, and set "issued" to 0
logic [2**`RS-1:0]      issued;
logic [2**`RS-1:0]      issued_next;

// the current three smallest pc, 0 is the oldest, 2 is the newest
RS_ISSUE_READY [2:0]    ready_list;

RS_S_PACKET [2:0]   issue_insts_temp;
// TODO: design
always_comb begin
    for (int i = 0; i < 2**`RS; i++) begin
        if (issue_ready[i] == 0 && rs_entries[i].reg1_ready && rs_entries[i].reg2_ready) begin
            case(rs_entries[i].fu_sel)
                ALU_1: begin
                    if (fu_ready.alu_1 == 1'b1) begin
                        issue_ready[i] = 1'b1;
                    end
                    else if (fu_ready.alu_2 == 1'b1) begin
                        rs_entries[i].fu_sel = ALU_2;
                        issue_ready[i] = 1'b1;
                    end
                    else if (fu_ready.alu_3 == 1'b1) begin
                        rs_entries[i].fu_sel = ALU_3;
                        issue_ready[i] = 1'b1;
                    end
                end
                LS_1: begin
                    if (fu_ready.storeload_1 == 1'b1) begin
                        issue_ready[i] = 1'b1;
                    end
                    else if (fu_ready.storeload_2 == 1'b1) begin
                        rs_entries[i].fu_sel = LS_2;
                        issue_ready[i] = 1'b1;
                    end
                end
                MULT_1: begin
                    if (fu_ready.mult_1 == 1'b1) begin
                        issue_ready[i] = 1'b1;
                    end
                    else if (fu_ready.mult_2 == 1'b1) begin
                        rs_entries[i].fu_sel = MULT_2;
                        issue_ready[i] = 1'b1;
                    end
                end
                BRANCH: begin
                    if (fu_ready.branch == 1'b1) begin
                        issue_ready[i] = 1'b1;
                    end
                end
            endcase
        end
    end

    // hc
    issued_next = issued;
    ready_list = 0;
    issue_insts_temp = 0;
    // find the 3 oldest issuable instructions
    for (int i = 0; i < 2**`RS; i++) begin
        if (issue_ready[i]) begin
            if (!ready_list[0].valid || rs_entries[i].PC < ready_list[0].PC) begin
                ready_list[2] = ready_list[1];
                ready_list[1] = ready_list[0];
                ready_list[0].valid     = 1'b1;
                ready_list[0].rs_index  = i[RS-1:0];
                ready_list[0].PC        = rs_entries[i].PC;
            end
            else if (!ready_list[1].valid || rs_entries[i].PC < ready_list[1].PC) begin
                ready_list[2] = ready_list[1];
                ready_list[1].valid     = 1'b1;
                ready_list[1].rs_index  = i[RS-1:0];
                ready_list[1].PC        = rs_entries[i].PC;
            end
            else if (!ready_list[2].valid || rs_entries[i].PC < smallest_pc[2]) begin
                ready_list[2].valid     = 1'b1;
                ready_list[2].rs_index  = i[RS-1:0];
                ready_list[2].PC        = rs_entries[i].PC;
            end
            else begin
                issue_ready[i] = 0;
            end
        end
    end

    for (int i = 0; i < 3; i++) begin
        if (ready_list[i].valid) begin
            issued_next[ready_list[i].rs_index] = 1'b1;
            issue_insts_temp[i].fu_sel  = rs_entries[ready_list[i].rs_index].fu_sel;
            issue_insts_temp[i].op_sel  = rs_entries[ready_list[i].rs_index].op_sel;
            issue_insts_temp[i].NPC     = rs_entries[ready_list[i].rs_index].NPC;
            issue_insts_temp[i].PC      = rs_entries[ready_list[i].rs_index].PC;
            issue_insts_temp[i].opa_select = rs_entries[ready_list[i].rs_index].opa_select;
            issue_insts_temp[i].opb_select = rs_entries[ready_list[i].rs_index].opb_select;
            issue_insts_temp[i].inst    = rs_entries[ready_list[i].rs_index].inst;
            issue_insts_temp[i].halt    = rs_entries[ready_list[i].rs_index].halt;
            issue_insts_temp[i].dest_pr = rs_entries[ready_list[i].rs_index].dest_pr;
            issue_insts_temp[i].reg1_pr = rs_entries[ready_list[i].rs_index].reg1_pr;
            issue_insts_temp[i].reg2_pr = rs_entries[ready_list[i].rs_index].reg2_pr;
            issue_insts_temp[i].valid   = rs_entries[ready_list[i].rs_index].valid;
        end
        else begin
            break;
        end
    end
end


// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if (reset) begin
        issued <= 0;
        // TODO
    end
    else begin
        issued <= issued_next;
        issue_insts <= issue_insts_temp;
        // TODO
    end
end

endmodule