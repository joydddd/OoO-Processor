`define TEST_MODE
`define RS_ALLOCATE_DEBUG
`ifndef __RS_V__
`define __RS_V__

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
    , output RS_IN_PACKET [2**`RS-1:0] rs_entries_display
`endif
);

RS_IN_PACKET [2**`RS-1:0]        rs_entries;
`ifdef TEST_MODE
    assign rs_entries_display = rs_entries;
`endif


/* select next entry to allocate */
logic [2:0][`RSW-1:0] new_entry; // one hot coding
logic [`RSW-1:0] issue_EN; // which entry to issue next
`ifdef RS_ALLOCATE_DEBUG
    assign issue_EN = 0;
`endif

logic [2:0] not_stall; 
logic [`RSW-1:0] entry_av, entry_av_after2, entry_av_after1;

assign struct_stall = ~not_stall;
always_comb 
    for(int i=0; i<`RSW-1; i++) begin
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
    for(int i=0; i<`RSW-1; i++)begin
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
    for(int i=0; i < `RSW-1; i++) begin
        if (new_entry[2][i])
            rs_entries_next[i] = rs_in[2];
        else if (new_entry[1][i])
            rs_entries_next[i] = rs_in[1];
        else if (new_entry[0][i])
            rs_entries_next[i] = rs_in[0];
        else begin
            rs_entries_next[i] = rs_entries;
            rs_entries_next[i].reg1_ready = reg1_ready_next[i];
            rs_entries_next[i].reg2_ready = reg2_ready_next[i];
        end
    end
end

always_ff @(posedge clock) begin
    if (reset)
        rs_entries <= `SD 0; 
    else 
        rs_entries <= `SD rs_entries_next;
end

// logic [2**`RS-1:0]      issue_ready;
// // when an instruction in the RS is issued, set "issued" to 1 at the same cycle
// // if "issued" is 1, clear the corresponding RS entry at the next cycle, and set "issued" to 0
// logic [2**`RS-1:0]      issued;
// logic [2**`RS-1:0]      issued_next;

// // the current three smallest pc, 0 is the oldest, 2 is the newest
// RS_ISSUE_READY [2:0]    ready_list;

// RS_S_PACKET [2:0]   issue_insts_temp;
// // TODO: design
// always_comb begin
//     for (int i = 0; i < 2**`RS; i++) begin
//         if (issue_ready[i] == 0 && rs_entries[i].reg1_ready && rs_entries[i].reg2_ready) begin
//             case(rs_entries[i].fu_sel)
//                 ALU_1: begin
//                     if (fu_ready.alu_1 == 1'b1) begin
//                         issue_ready[i] = 1'b1;
//                     end
//                     else if (fu_ready.alu_2 == 1'b1) begin
//                         rs_entries[i].fu_sel = ALU_2;
//                         issue_ready[i] = 1'b1;
//                     end
//                     else if (fu_ready.alu_3 == 1'b1) begin
//                         rs_entries[i].fu_sel = ALU_3;
//                         issue_ready[i] = 1'b1;
//                     end
//                 end
//                 LS_1: begin
//                     if (fu_ready.storeload_1 == 1'b1) begin
//                         issue_ready[i] = 1'b1;
//                     end
//                     else if (fu_ready.storeload_2 == 1'b1) begin
//                         rs_entries[i].fu_sel = LS_2;
//                         issue_ready[i] = 1'b1;
//                     end
//                 end
//                 MULT_1: begin
//                     if (fu_ready.mult_1 == 1'b1) begin
//                         issue_ready[i] = 1'b1;
//                     end
//                     else if (fu_ready.mult_2 == 1'b1) begin
//                         rs_entries[i].fu_sel = MULT_2;
//                         issue_ready[i] = 1'b1;
//                     end
//                 end
//                 BRANCH: begin
//                     if (fu_ready.branch == 1'b1) begin
//                         issue_ready[i] = 1'b1;
//                     end
//                 end
//             endcase
//         end
//     end

//     // hc
//     issued_next = issued;
//     ready_list = 0;
//     issue_insts_temp = 0;
//     // find the 3 oldest issuable instructions
//     for (int i = 0; i < 2**`RS; i++) begin
//         if (issue_ready[i]) begin
//             if (!ready_list[0].valid || rs_entries[i].PC < ready_list[0].PC) begin
//                 ready_list[2] = ready_list[1];
//                 ready_list[1] = ready_list[0];
//                 ready_list[0].valid     = 1'b1;
//                 ready_list[0].rs_index  = i[RS-1:0];
//                 ready_list[0].PC        = rs_entries[i].PC;
//             end
//             else if (!ready_list[1].valid || rs_entries[i].PC < ready_list[1].PC) begin
//                 ready_list[2] = ready_list[1];
//                 ready_list[1].valid     = 1'b1;
//                 ready_list[1].rs_index  = i[RS-1:0];
//                 ready_list[1].PC        = rs_entries[i].PC;
//             end
//             else if (!ready_list[2].valid || rs_entries[i].PC < smallest_pc[2]) begin
//                 ready_list[2].valid     = 1'b1;
//                 ready_list[2].rs_index  = i[RS-1:0];
//                 ready_list[2].PC        = rs_entries[i].PC;
//             end
//             else begin
//                 issue_ready[i] = 0;
//             end
//         end
//     end

//     for (int i = 0; i < 3; i++) begin
//         if (ready_list[i].valid) begin
//             issued_next[ready_list[i].rs_index] = 1'b1;
//             issue_insts_temp[i].fu_sel  = rs_entries[ready_list[i].rs_index].fu_sel;
//             issue_insts_temp[i].op_sel  = rs_entries[ready_list[i].rs_index].op_sel;
//             issue_insts_temp[i].NPC     = rs_entries[ready_list[i].rs_index].NPC;
//             issue_insts_temp[i].PC      = rs_entries[ready_list[i].rs_index].PC;
//             issue_insts_temp[i].opa_select = rs_entries[ready_list[i].rs_index].opa_select;
//             issue_insts_temp[i].opb_select = rs_entries[ready_list[i].rs_index].opb_select;
//             issue_insts_temp[i].inst    = rs_entries[ready_list[i].rs_index].inst;
//             issue_insts_temp[i].halt    = rs_entries[ready_list[i].rs_index].halt;
//             issue_insts_temp[i].dest_pr = rs_entries[ready_list[i].rs_index].dest_pr;
//             issue_insts_temp[i].reg1_pr = rs_entries[ready_list[i].rs_index].reg1_pr;
//             issue_insts_temp[i].reg2_pr = rs_entries[ready_list[i].rs_index].reg2_pr;
//             issue_insts_temp[i].valid   = rs_entries[ready_list[i].rs_index].valid;
//         end
//         else begin
//             break;
//         end
//     end
// end


// // synopsys sync_set_reset "reset"
// always_ff @(posedge clock) begin
//     if (reset) begin
//         issued <= 0;
//         // TODO
//     end
//     else begin
//         issued <= issued_next;
//         issue_insts <= issue_insts_temp;
//         // TODO
//     end
// end

endmodule

`endif // __RS_V__