`timescale 1ns/100ps
`ifndef __FREELIST_TEST_SV__
`define __FREELIST_TEST_SV__

//`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
`define TEST_MODE


module testbench;

    logic 				            clock;
    logic 				            reset;

    // branch_fu
    logic                           update_EN;
    logic [`XLEN-1:0]               update_pc;
    logic                           update_direction;
    logic [`XLEN-1:0]               update_target;

    // dispatch
    logic [2:0]                          dispatch_EN;
    logic [2:0][`XLEN-1:0]               dispatch_pc;

    // fetch
    logic [2:0]                          fetch_EN;
    logic [2:0][`XLEN-1:0]               fetch_pc;
    logic [2:0]                          predict_direction;
    logic [2:0] [`XLEN-1:0]               predict_pc;
    BP_ENTRY_PACKET [`BPW-1:0] bp_entries_display;
    logic [31:0]                    cycle_count;


    branch_predictor tbp(.clock(clock), .reset(reset), .update_EN(update_EN), .dispatch_EN(dispatch_EN), .dispatch_pc(dispatch_pc), .update_pc(update_pc), .update_direction(update_direction), .update_target(update_target), .fetch_EN(fetch_EN), .fetch_pc(fetch_pc), .predict_direction(predict_direction), .predict_pc(predict_pc), .bp_entries_display(bp_entries_display));

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
    

    task show_branch_predictor;
        $display("####### Cycle %d ##########", cycle_count);
        for(int i=`BPW - 1; i>=0; i--) begin
            $display("Index: %2d  Valid: %2d  Tag: %5d  Direction: %1d  Target_pc: %5d", i, bp_entries_display[i].valid, bp_entries_display[i].tag, bp_entries_display[i].direction, bp_entries_display[i].target_pc);
        end
    endtask; // show_rs_table

    task show_input;
        begin
            $display("=====   Input   =====");
            $display("Fetch_EN: %b  Dispatch_EN: %b", fetch_EN, dispatch_EN);
            for (int i = 0; i<3; i++) begin
                $display("Index: %1d  Fetch_pc: %5d  Dispatch_pc: %5d", i, fetch_pc[i], dispatch_pc[i]);
            end
            $display("Update_pc: %5d  Update_direction: %1d  Update_target: %5d", update_pc, update_direction, update_target);
        end
    endtask

    task show_output;
        begin
            $display("=====   Output   =====");
            for (int i = 0; i<3; i++) begin
                $display("Index: %1d  Predict_direction: %1d  Predict_pc: %5d", i, predict_direction[i], predict_pc[i]);
            end
        end
    endtask


    always_ff@(posedge clock) begin
        if (reset)
            cycle_count <= 0;
        else 
            cycle_count <= cycle_count + 1;
    end

    
    always_ff@(negedge clock) begin
        show_branch_predictor();
        show_input();
        show_output();
    end

    initial begin
        //$dumpvars;
        clock = 1'b0;
        reset = 1'b1;
        update_EN = 1'b0;
        update_pc = 0;
        update_direction = 1'b0;
        update_target = 0;
        dispatch_EN = 0;
        dispatch_pc = 0;
        fetch_EN = 0;
        fetch_pc = 0;
        
        @(negedge clock);
        reset = 0;

        @(posedge clock);
        fetch_EN = 3'b111;
        fetch_pc[0] = 4;
        fetch_pc[1] = 8;
        fetch_pc[2] = 12;

        @(posedge clock);
        fetch_pc[0] = 16;
        fetch_pc[1] = 20;
        fetch_pc[2] = 24;
        dispatch_EN = 3'b111;
        dispatch_pc[0] = 4;
        dispatch_pc[1] = 8;
        dispatch_pc[2] = 12;

        @(posedge clock);
        fetch_EN = 0;
        update_EN = 1'b1;
        update_pc = 4;
        update_direction = 1'b1;
        update_target = 80;
        dispatch_EN = 3'b101;
        dispatch_pc[0] = 16;
        dispatch_pc[2] = 24;

        @(posedge clock);
        fetch_EN = 3'b111;
        fetch_pc[0] = 4;
        fetch_pc[1] = 8;
        fetch_pc[2] = 12;
        dispatch_EN = 0;

        @(posedge clock);
        fetch_EN = 0;
        dispatch_EN = 3'b001;
        dispatch_pc[0] = 4;
        dispatch_pc[1] = 8;
        dispatch_pc[2] = 12;

        @(posedge clock);
        dispatch_EN = 0;
        update_EN = 1'b1;
        update_pc = 4;
        update_direction = 1'b1;
        update_target = 80;

        @(posedge clock);
        fetch_EN = 3'b111;
        fetch_pc[0] = 4;
        fetch_pc[1] = 8;
        fetch_pc[2] = 12;
        update_EN = 1'b0;
        

        @(posedge clock);
        fetch_EN = 0;
        dispatch_EN = 3'b010;
        dispatch_pc[0] = 4;
        dispatch_pc[1] = 36;
        dispatch_pc[2] = 12;

        @(posedge clock);
        dispatch_EN = 0;
        update_EN = 1'b1;
        update_pc = 4;
        update_direction = 1'b1;
        update_target = 80;

        @(posedge clock);

        $finish;
    end

endmodule

`endif