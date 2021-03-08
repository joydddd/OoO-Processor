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


RS_IN_PACKET [`RSW-1:0]        rs_entries;

`ifdef TEST_MODE
    assign rs_entries_display = rs_entries;
`endif


/* select next entry to allocate */
logic [2:0][`RSW-1:0] new_entry; // one hot coding
logic [`RSW-1:0] issue_EN; // which entry to issue next

logic [2:0] not_stall; 
logic [`RSW-1:0] entry_av, entry_av_after2, entry_av_after1;

assign struct_stall = ~not_stall;

assign entry_av = issue_EN | ~rs_entries.valid;
assign entry_av_after2 = entry_av & ~new_entry[2];
assign entry_av_after1 = entry_av_after2 & ~new_entry[1];


ps16 sel_av2(.req(entry_av), .en(1'b1), .gnt(new_entry[2]), .req_up(not_stall[2]));
ps16 sel_av1(.req(entry_av_after2), .en(1'b1), .gnt(new_entry[1]), .req_up(not_stall[1]));
ps16 sel_av0(.req(entry_av_after1), .en(1'b1), .gnt(new_entry[0]), .req_up(not_stall[0]));


/* allocate new entry */ 
RS_IN_PACKET [`RSW-1:0] rs_entries_next;
always_comb begin
    for(int i=0; i < `RSW-1; i++) begin
        rs_entries_next[i] = new_entry[2][i] ? rs_in[2] : 
                             new_entry[1][i] ? rs_in[1] :
                             new_entry[0][i] ? rs_in[0] :
                             rs_entries[i];
    end
end

always_ff @(posedge clock) begin
    if (reset)
        rs_entries <= `SD 0; 
    else 
        rs_entries <= `SD rs_entries_next;
end

/* update ready tag while cdb_t broadcasts */
logic [`RSW-1:0] reg1_ready_next;
logic [`RSW-1:0] reg2_ready_next;
always_comb begin
    for(int i=0; i<`RSW-1; i++)begin
        reg1_ready_next[i] = rs_entries.reg1_pr[i]==cdb_t.t0 ||
                             rs_entries.reg1_pr[i]==cdb_t.t1 ||
                             rs_entries.reg1_pr[i]==cdb_t.t2 ? 
                             1'b1 : rs_entries.reg1_ready[i];
        reg2_ready_next[i] = rs_entries.reg2_pr[i]==cdb_t.t0 ||
                             rs_entries.reg2_pr[i]==cdb_t.t1 ||
                             rs_entries.reg2_pr[i]==cdb_t.t2 ? 
                             1'b1 : rs_entries.reg2_ready[i];
    end
end
always_ff @( posedge clock ) begin : 
    rs_entries.reg1_ready <= `SD reg1_ready_next;
    rs_entries.reg2_ready <= `SD reg2_ready_next;
end

endmodule