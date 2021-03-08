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

// TODO: design

endmodule