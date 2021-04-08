//`define TEST_MODE

`timescale 1ns/100ps

module branch_predictor(
    input                       clock,
    input                       reset,

    // branch_fu
    input [`XLEN-1:0]           update_pc,
    input                       update_direction,
    input [`XLEN-1:0]           update_target,

    // fetch
    input [`XLEN-1:0]           fetch_pc,
    output logic                predict_direction,
    output logic [`XLEN-1:0]    predict_pc


    `ifdef  TEST_MODE
        , output BP_ENTRY_PACKET [`BPW-1:0] bp_entries_display
    `endif
);

    BP_ENTRY_PACKET [`BPW-1:0] bp_entries;
    BP_ENTRY_PACKET [`BPW-1:0] bp_entries_next;
    logic [`BP:0] found_in_bp;
    logic [`BP-1:0] entry_to_replace;
    logic [`BP-1:0] entry_to_update;

    `ifdef TEST_MODE
        assign bp_entries_display = bp_entries;
    `endif

    // fetch
    always_comb begin
        found_in_bp = 32;
        entry_to_replace = 0;
        predict_direction = 0;
        predict_pc = 0;
        for (int i = 0; i < `BPW; i++) begin
            if (bp_entries[i].pc == fetch_pc) begin
                found_in_bp = i;
                predict_direction = (bp_entries[i].direction == WEAK_T | bp_entries[i].direction == STRONG_T) ? 1 : 0;
                predict_pc = (predict_direction == 1) ? bp_entries[i].target_pc : 0;
            end
            if (bp_entries[i].lru == 31) begin
                entry_to_replace = i;
            end
        end
    end

    // branch_fu
    always_comb begin
        entry_to_update = 0;
        for (int i = 0; i < `BPW; i++) begin
            if (bp_entries[i].pc == update_pc) begin
                entry_to_update = i;
            end
        end 
    end


    //update
    always_comb begin
        bp_entries_next = bp_entries;
        if (found_in_bp == 32) begin
            bp_entries_next[entry_to_replace].lru = 0;
            bp_entries_next[entry_to_replace].pc = fetch_pc;
            bp_entries_next[entry_to_replace].direction = STRONG_NT;
            bp_entries_next[entry_to_replace].target_pc = 0;
            for (int i = 0; i < `BPW; i++) begin
                if (i != entry_to_replace) begin
                    bp_entries_next[i].lru = bp_entries[i].lru + 1;
                end
            end
        end
        else begin
            bp_entries_next[found_in_bp].lru = 0;
            for (int i = 0; i < `BPW; i++) begin
                if (i != found_in_bp) begin
                    bp_entries_next[i].lru = bp_entries[i].lru + 1;
                end
            end 
        end
        bp_entries_next[entry_to_update].target_pc = update_target;
        priority case (bp_entries[entry_to_update].direction)
            STRONG_NT: begin
                bp_entries_next[entry_to_update].direction = predict_direction ? WEAK_NT : STRONG_NT;
            end
            WEAK_NT: begin
                bp_entries_next[entry_to_update].direction = predict_direction ? WEAK_T : STRONG_NT;
            end
            WEAK_T: begin
                bp_entries_next[entry_to_update].direction = predict_direction ? STRONG_T : WEAK_NT;
            end
            STRONG_T: begin
                bp_entries_next[entry_to_update].direction = predict_direction ? STRONG_T : WEAK_T;
            end
	    endcase
    end


    always_ff @(posedge clock) begin
        if (reset) begin
            bp_entries <= `SD 0;
            for (int i = 0; i < `BPW; i++) begin
                bp_entries[i].lru <= `SD 31 - i;
            end
        end	 
        else begin 
            bp_entries <= `SD bp_entries_next;
        end
    end


endmodule