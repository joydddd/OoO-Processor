`define TEST_MODE

`timescale 1ns/100ps

module branch_predictor(
    input                       clock,
    input                       reset,

    // branch_fu
    input                       update_EN,
    input [`XLEN-1:0]           update_pc,
    input                       update_direction,
    input [`XLEN-1:0]           update_target,

    // dispatch
    input [2:0]                 dispatch_EN,
    input [2:0] [`XLEN-1:0]     dispatch_pc,

    // fetch
    input [2:0]                 fetch_EN,
    input [2:0] [`XLEN-1:0]     fetch_pc,
    output logic [2:0]          predict_found,
    output logic [2:0]          predict_direction,
    output logic [2:0] [`XLEN-1:0]    predict_pc


    `ifdef  TEST_MODE
        , output BP_ENTRY_PACKET [`BPW-1:0] bp_entries_display
    `endif
);

    BP_ENTRY_PACKET [`BPW-1:0] bp_entries;
    BP_ENTRY_PACKET [`BPW-1:0] bp_entries_next;

    `ifdef TEST_MODE
        assign bp_entries_display = bp_entries;
    `endif

    // fetch
    always_comb begin
        predict_direction = 0;
        predict_pc = 0;
        predict_found = 0;
        if (fetch_EN[2] && bp_entries[fetch_pc[2][`BP-1:0]].tag == fetch_pc[2][`XLEN-1:`BP]) begin
            predict_found[2] = 1;
            predict_direction[2] = ( bp_entries[fetch_pc[2][`BP-1:0]].direction == WEAK_T |  bp_entries[fetch_pc[2][`BP-1:0]].direction == STRONG_T) ? 1 : 0;
            predict_pc[2] = (predict_direction[2] == 1) ?  bp_entries[fetch_pc[2][`BP-1:0]].target_pc : 0;
        end
        if (fetch_EN[1] && bp_entries[fetch_pc[1][`BP-1:0]].tag == fetch_pc[1][`XLEN-1:`BP]) begin
            predict_found[1] = 1;
            predict_direction[1] = ( bp_entries[fetch_pc[1][`BP-1:0]].direction == WEAK_T |  bp_entries[fetch_pc[1][`BP-1:0]].direction == STRONG_T) ? 1 : 0;
            predict_pc[1] = (predict_direction[1] == 1) ?  bp_entries[fetch_pc[1][`BP-1:0]].target_pc : 0;
        end
        if (fetch_EN[0] && bp_entries[fetch_pc[0][`BP-1:0]].tag == fetch_pc[0][`XLEN-1:`BP]) begin
            predict_found[0] = 1;
            predict_direction[0] = ( bp_entries[fetch_pc[0][`BP-1:0]].direction == WEAK_T |  bp_entries[fetch_pc[0][`BP-1:0]].direction == STRONG_T) ? 1 : 0;
            predict_pc[0] = (predict_direction[0] == 1) ?  bp_entries[fetch_pc[0][`BP-1:0]].target_pc : 0;
        end
    end


    //update
    always_comb begin
        bp_entries_next = bp_entries;
        if (dispatch_EN[2]) begin
            if ((bp_entries[dispatch_pc[2][`BP-1:0]].valid && bp_entries[dispatch_pc[2][`BP-1:0]].tag != dispatch_pc[2][`XLEN-1:`BP]) || ~bp_entries[dispatch_pc[2][`BP-1:0]].valid) begin
                bp_entries_next[dispatch_pc[2][`BP-1:0]].valid = 1;
                bp_entries_next[dispatch_pc[2][`BP-1:0]].tag = dispatch_pc[2][`XLEN-1:`BP];
                bp_entries_next[dispatch_pc[2][`BP-1:0]].direction = STRONG_NT;
                bp_entries_next[dispatch_pc[2][`BP-1:0]].target_pc = 0;
            end
        end
        if (dispatch_EN[1]) begin
            if ((bp_entries[dispatch_pc[1][`BP-1:0]].valid && bp_entries[dispatch_pc[1][`BP-1:0]].tag != dispatch_pc[1][`XLEN-1:`BP]) || ~bp_entries[dispatch_pc[1][`BP-1:0]].valid) begin
                bp_entries_next[dispatch_pc[1][`BP-1:0]].valid = 1;
                bp_entries_next[dispatch_pc[1][`BP-1:0]].tag = dispatch_pc[1][`XLEN-1:`BP];
                bp_entries_next[dispatch_pc[1][`BP-1:0]].direction = STRONG_NT;
                bp_entries_next[dispatch_pc[1][`BP-1:0]].target_pc = 0;
            end
        end
        if (dispatch_EN[0]) begin
            if ((bp_entries[dispatch_pc[0][`BP-1:0]].valid && bp_entries[dispatch_pc[0][`BP-1:0]].tag != dispatch_pc[0][`XLEN-1:`BP]) || ~bp_entries[dispatch_pc[0][`BP-1:0]].valid) begin
                bp_entries_next[dispatch_pc[0][`BP-1:0]].valid = 1;
                bp_entries_next[dispatch_pc[0][`BP-1:0]].tag = dispatch_pc[0][`XLEN-1:`BP];
                bp_entries_next[dispatch_pc[0][`BP-1:0]].direction = STRONG_NT;
                bp_entries_next[dispatch_pc[0][`BP-1:0]].target_pc = 0;
            end
        end

        if (update_EN && bp_entries[update_pc[`BP-1:0]].valid && bp_entries[update_pc[`BP-1:0]].tag == update_pc[`XLEN-1:`BP]) begin
            bp_entries_next[update_pc[`BP-1:0]].target_pc = update_target;
            //$display("%b^^^^^^^^^^^^^^^^6", update_direction);
            priority case (bp_entries[update_pc[`BP-1:0]].direction)
                STRONG_NT: begin
                    bp_entries_next[update_pc[`BP-1:0]].direction = update_direction ? WEAK_NT : STRONG_NT;
                end
                WEAK_NT: begin
                    bp_entries_next[update_pc[`BP-1:0]].direction = update_direction ? WEAK_T : STRONG_NT;
                end
                WEAK_T: begin
                    bp_entries_next[update_pc[`BP-1:0]].direction = update_direction ? STRONG_T : WEAK_NT;
                end
                STRONG_T: begin
                    bp_entries_next[update_pc[`BP-1:0]].direction = update_direction ? STRONG_T : WEAK_T;
                end
                default: begin
                end
            endcase
        end
    end


    always_ff @(posedge clock) begin
        if (reset) begin
            bp_entries <= `SD 0;
        end	 
        else begin 
            bp_entries <= `SD bp_entries_next;
        end
    end


endmodule