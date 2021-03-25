`timescale 1ns/100ps
`ifndef __ROB_TEST_SV__
`define __ROB_TEST_SV__

//`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
`define TEST_MODE


module testbench;

    //general
    logic clock, reset;
    logic [31:0] cycle_count;

    //rob
    ROB_ENTRY_PACKET[2:0]           rob_in;
	logic       [2:0]               complete_valid;
	logic       [2:0][`ROB-1:0]     complete_entry;  // which ROB entry is done
	ROB_ENTRY_PACKET [2:0]          retire_entry;  // which ENTRY to be retired
	logic       [2:0]               rob_stall;
	ROB_ENTRY_PACKET [`ROBW-1:0]    rob_entries;
    ROB_ENTRY_PACKET [`ROBW-1:0]    rob_debug;
    logic       [`ROB-1:0]          head;
    logic       [`ROB-1:0]          tail;

  

    //complete
    FU_STATE_PACKET                 fu_finish;
    FU_COMPLETE_PACKET [2:0]        fu_c_in;
    FU_STATE_PACKET                 fu_c_stall;
    CDB_T_PACKET                    cdb_t;
    logic       [2:0][`XLEN-1:0]    wb_value;
    logic       [2:0]               precise_state_valid;
	logic       [2:0][`XLEN-1:0]    target_pc;
	logic       [2:0][`ROB-1:0]     dispatch_index;

    //freelist
    logic 		[2:0]		        DispatchEN;
    logic 		[2:0] 		        RetireEN;
    logic  		[2:0][`PR-1:0] 	    RetireReg;
    logic 				            BPRecoverEN;
    logic 		[`ROB-1:0] 	        BPRecoverHead;
    logic 	    [2:0][`PR-1:0] 	    FreeReg;
    logic 	    [`PR-1:0] 	        FreelistHead;
    logic 	    [2:0] 		        FreeRegValid;
    logic       [4:0]               fl_distance;
    logic       [31:0][`PR-1:0]     array;
	logic       [4:0]               fl_head;
	logic       [4:0]               fl_tail;
    logic                           empty;

    //retire
    logic       [31:0][`PR-1:0]         archi_maptable;
    logic       [2:0][`PR-1:0]			map_ar_pr;
    logic       [2:0][4:0]			    map_ar;
    logic       [31:0][`PR-1:0]         recover_maptable;
    logic       [`XLEN-1:0]             fetch_pc;


    ROB tbp(
        .clock(clock), 
        .reset(reset), 
        .rob_in(rob_in),                            // <- dispatch.rob_in
        .complete_valid(complete_valid),            // <- complete.complete_valid
        .complete_entry(complete_entry),            // <- complete.complete_entry
        .precise_state_valid(precise_state_valid),  // <- complete.precise_state_valid
        .target_pc(target_pc),                      // <- complete.target_pc
        .BPRecoverEN(BPRecoverEN),                  // <- retire.BPRecoverEN
        .dispatch_index(dispatch_index),            // -> dispatch.rob_index
        .retire_entry(retire_entry),                // -> retire.rob_head_entry
        .struct_stall(rob_stall)                    // -> dispatch.rob_stall
        `ifdef TEST_MODE
        , .rob_entries_display(rob_entries)         // -> display entries
        , .head_display(head)                       // -> display head
        , .tail_display(tail)                       // -> display tail
        `endif
        `ifdef IS_DEBUG
        , .rob_entries_debug(rob_debug)             // <- debug input
        `endif
    );

    complete_stage cs(
        .fu_finish(fu_finish),                      // <- TODO: fu_finish
        .fu_c_in(fu_c_in),                          // <- TODO: fu_c_in
        .fu_c_stall(fu_c_stall),                    // -> TODO: fu_c_stall
        .cdb_t(cdb_t),                              // -> TODO: cdb broadcast
        .wb_value(wb_value),                        // -> TODO: wb_value, to register file
        .complete_valid(complete_valid),            // -> ROB.complete_valid
	    .complete_entry(complete_entry),            // -> ROB.complete_entry
        .precise_state_valid(precise_state_valid),  // -> ROB.precise_state_valid
	    .target_pc(target_pc)                       // -> ROB.target_pc
    );

    retire_stage uut(
        .rob_head_entry(retire_entry),              // <- ROB.retire_entry
        .fl_distance(fl_distance),                  // <- Freelist.fl_distance
        .BPRecoverEN(BPRecoverEN),                  // -> ROB.BPRecoverEN, Freelist.BPRecoverEN, fetch.take_branch
        .target_pc(fetch_pc),                       // -> TODO: fetch.target_pc
        .archi_maptable(archi_maptable),            // <- TODO: arch map
        .map_ar_pr(map_ar_pr),                      // -> TODO: arch map
        .map_ar(map_ar),                            // -> TODO: arch map
        .recover_maptable(recover_maptable),        // -> TODO: map table
        .FreelistHead(FreelistHead),                // <- Freelist.FreelistHead
        .Retire_EN(RetireEN),                       // -> Freelist.RetireEN
        .Tolds_out(RetireReg),                      // -> Freelist.RetireReg
        .BPRecoverHead(BPRecoverHead)               // -> Freelist.BPRecoverHead
    );


    Freelist fl(
        .clock(clock), 
        .reset(reset), 
        .DispatchEN(DispatchEN),                    // <- TODO: 
        .RetireEN(RetireEN),                        // <- retire.RetireEN
        .RetireReg(RetireReg),                      // <- retire.RetireReg
        .BPRecoverEN(BPRecoverEN),                  // <- retire.BPRecoverEN
        .BPRecoverHead(BPRecoverHead),              // <- retire.BPRecoverHead
        .FreeReg(FreeReg),                          // -> TODO
        .Head(FreelistHead),                        // -> retire.FreelistHead
        .FreeRegValid(FreeRegValid),                // -> TODO
        .fl_distance(fl_distance)                   // -> retire.fl_distance
        `ifdef TEST_MODE
        , .array_display(array)                     // -> display
        , .head_display(fl_head)                    // -> display
        , .tail_display(fl_tail)                    // -> display
        , .empty_display(empty)                     // -> display
        `endif
    );

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
    

    task show_rob_table;
        $display("####### Cycle %d ##########", cycle_count);
        for(int i=2**`ROB-1; i>=0; i--) begin  // For RS entry, it allocates from 15-0
            $display("valid: %d  Tnew: %d  Told: %d  arch_reg: %d  completed: %b  precise_state: %b  target_pc: %3d", rob_entries[i].valid, rob_entries[i].Tnew, rob_entries[i].Told, rob_entries[i].arch_reg, rob_entries[i].completed, rob_entries[i].precise_state_need, rob_entries[i].target_pc);
        end
        $display("head:%d tail:%d", head, tail);
        $display("structual_stall:%b", rob_stall);
    endtask; // show_rs_table

    task show_rob_complete;
        begin
            $display("=====   ROB_Complete Packet   =====");
            $display("| WAY | valid |  ROB_entry | precise_state | target_pc |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |     %2d     |       %b       |    %3d    |",
                    i, complete_valid[i], complete_entry[i], precise_state_valid[i], target_pc[i]);
            end
        end
    endtask

    
    task show_rob_in;
        begin
            $display("=====   ROB_IN Packet   =====");
            $display("| WAY | valid |  Tnew | Told | arch_reg | completed | precise_state | target_pc |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |   %2d  |   %2d |     %2d   |     %b     |       %b       |    %3d    |",
                    i, rob_in[i].valid, rob_in[i].Tnew, rob_in[i].Told, rob_in[i].arch_reg, rob_in[i].completed, rob_in[i].precise_state_need, rob_in[i].target_pc);
            end
        end
    endtask

    task show_rob_out;
        begin
            $display("=====   ROB_Retire Packet   =====");
            $display("| WAY | valid |  Tnew | Told | arch_reg | completed | precise_state | target_pc |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |   %2d  |   %2d |     %2d   |     %b     |       %b       |  %3d      |",
                    i, retire_entry[i].valid, retire_entry[i].Tnew, retire_entry[i].Told, retire_entry[i].arch_reg, retire_entry[i].completed, retire_entry[i].precise_state_need, retire_entry[i].target_pc);
            end
        end
    endtask

    task set_rob_in_packet;
        input integer rob_in_i;

        input               valid;
        input [`PR-1:0] 	Told;
	    input [4:0] 		arch_reg;
	    input 			    completed;

        begin
            rob_in[rob_in_i].valid = valid;
            rob_in[rob_in_i].Told = Told;
            rob_in[rob_in_i].arch_reg = arch_reg;
             rob_in[rob_in_i].Tnew = FreeReg[rob_in_i];
            rob_in[rob_in_i].completed = completed;
            rob_in[rob_in_i].precise_state_need = 0;
            rob_in[rob_in_i].target_pc = 0;
        end
    endtask


    task show_freelist_table;
        $display("DispatchEN:%d", DispatchEN);
        for(int i=31; i>=0; i--) begin  // For RS entry, it allocates from 15-0
            $display("Index: %d        PR: %5d", i, array[i]);
        end
        $display("head:%d tail:%d empty:%d", fl_head, fl_tail, empty);
    endtask; // show_rs_table

    task show_free_reg;
        begin
            $display("=====   Free Reg   =====");
            $display("FreeReg Valid: %d", FreeRegValid);
            $display("| WAY |   PR  |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |   %2d  |", i, FreeReg[i]);
            end
        end
    endtask

    task show_retire_reg;
        begin
            $display("=====   Retire Reg   =====");
            $display("RetireReg Valid: %d", RetireEN);
            $display("| WAY |   PR  |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |   %2d  |", i, RetireReg[i]);
            end
        end
    endtask

    task show_retire;
        show_input();
        $display("fl_distance: %d      Head: %d", fl_distance, FreelistHead);
        $display("Output:");
        $display("Retire_EN: %b    %b    %b", RetireEN[2], RetireEN[1], RetireEN[0]);
        $display("arch maptable AR: %d    %d    %d", map_ar[2], map_ar[1], map_ar[0]);
        $display("arch maptable PR: %d    %d    %d", map_ar_pr[2], map_ar_pr[1], map_ar_pr[0]);
        $display("Tolds out: %d    %d    %d", RetireReg[2], RetireReg[1], RetireReg[0]);
        $display("BPRecoverEN: %b,  target_pc: %d", BPRecoverEN, fetch_pc);
        $display("BPRecoverHead:    %d", BPRecoverHead);
        show_mpt_entry();
    endtask

    task show_input;
        begin
            $display("=====   Retire Input   =====");
            for (int i=2; i>=0; --i) begin
                $display("Entry No. %3d: valid-%b,   Tnew-%d,    Told-%d,    AR-%d,    exception-%b,    target_pc-%d,    completed-%b",
                i, retire_entry[i].valid, retire_entry[i].Tnew, retire_entry[i].Told, retire_entry[i].arch_reg, retire_entry[i].precise_state_need, retire_entry[i].target_pc,
                retire_entry[i].completed);
            end
        end
    endtask

    task show_mpt_entry;
        begin
            $display("=====   Recover Maptable Entry   =====");
            $display("| AR |   PR   |");
            for (int i = 0; i < 32; i++) begin
                $display("| %2d |   %d   |", i, recover_maptable[i]);
            end
            $display(" ");
        end
    endtask

    task set_armpt;
            begin
                for (int i=0; i<32; ++i) begin
                    archi_maptable[i] = i;
                end
            end
    endtask

    always_ff@(posedge clock) begin
        if (reset)
            cycle_count <= 0;
        else 
            cycle_count <= cycle_count + 1;
    end

    initial begin
        //$dumpvars;
        clock = 1'b0;
        reset = 1'b1;
        rob_debug = 0;
        rob_in = 0;
        fu_finish = 0;
        fu_c_in = 0;
        DispatchEN = 0;
        set_armpt();
        
        @(negedge clock);
        reset = 0;
                DispatchEN = 3'b111;
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        show_freelist_table();
        show_free_reg();
        show_retire_reg();
        show_retire();



        @(posedge clock);
        set_rob_in_packet(2, 1, 1, 1, 0);
        set_rob_in_packet(1, 1, 2, 2, 0);
        set_rob_in_packet(0, 1, 3, 3, 0);

        @(negedge clock);
                DispatchEN = 3'b111;
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        show_freelist_table();
        show_free_reg();
        show_retire_reg();
        show_retire();


        @(posedge clock);
        set_rob_in_packet(2, 1, 4, 4, 0);
        set_rob_in_packet(1, 1, 5, 5, 0);
        set_rob_in_packet(0, 1, 6, 6, 0);


        fu_c_in[0].if_take_branch = 1'b0;
        fu_c_in[0].target_pc = `XLEN'b0;
        fu_c_in[0].dest_pr = 34;
        fu_c_in[0].dest_value = `XLEN'h71a230f1;
        fu_c_in[0].rob_entry = 2;
        ////////////////////////////////////////
        fu_c_in[1].if_take_branch = 1'b1;
        fu_c_in[1].target_pc = `XLEN'b100000;
        fu_c_in[1].dest_pr = 33;
        fu_c_in[1].dest_value = `XLEN'h091ec84b;
        fu_c_in[1].rob_entry = 1;
        ////////////////////////////////////////
        fu_c_in[2].if_take_branch = 1'b0;
        fu_c_in[2].target_pc = `XLEN'b0;
        fu_c_in[2].dest_pr = 32;
        fu_c_in[2].dest_value = `XLEN'h20a1d324;
        fu_c_in[2].rob_entry = 0;
        fu_finish = 8'b11111111;

        @(negedge clock);
                DispatchEN = 3'b000;
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        show_freelist_table();
        show_free_reg();
        show_retire_reg();
        show_retire();

        @(posedge clock);
        set_rob_in_packet(2, 0, 4, 4, 0);
        set_rob_in_packet(1, 0, 5, 5, 0);
        set_rob_in_packet(0, 0, 6, 6, 0);
        
        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        show_freelist_table();
        show_free_reg();
        show_retire_reg();
        show_retire();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        show_freelist_table();
        show_free_reg();
        show_retire_reg();
        show_retire();
        $finish;


        @(posedge clock);
        fu_c_in = 0;
        fu_finish = 0;

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        $finish;

    end

endmodule

`endif