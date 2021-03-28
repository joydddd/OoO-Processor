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
	ROB_ENTRY_PACKET[2:0]          retire_entry;  // which ENTRY to be retired
	logic       [2:0]               rob_stall;
	ROB_ENTRY_PACKET[`ROBW-1:0]    rob_entries;
    logic       [`ROB-1:0]          head;
    logic       [`ROB-1:0]          tail;
    logic       [2:0][`ROB-1:0]     dispatch_index;
  
    logic       [2:0]               precise_state_valid;
	logic       [2:0][`XLEN-1:0]    target_pc;
    logic 				            BPRecoverEN;



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
        input [`PR-1:0] 	Tnew;
	    input [4:0] 		arch_reg;
	    input 			    completed;

        begin
            rob_in[rob_in_i].valid = valid;
            rob_in[rob_in_i].Told = Told;
            rob_in[rob_in_i].halt = 0;
            rob_in[rob_in_i].arch_reg = arch_reg;
            rob_in[rob_in_i].Tnew = Tnew;
            rob_in[rob_in_i].completed = completed;
            rob_in[rob_in_i].precise_state_need = 0;
            rob_in[rob_in_i].target_pc = 0;
        end
    endtask

    task set_complete_entry;
        input integer rob_in_i;

        input [`ROB-1:0] complete_index;

        input precise_state_temp;
	    input [`XLEN-1:0] target_pc_temp;

        begin
            complete_entry[rob_in_i] = complete_index;
            precise_state_valid[rob_in_i] = precise_state_temp;
            target_pc[rob_in_i] = target_pc_temp;
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
        rob_in = 0;
        complete_valid = 0;
        complete_entry = 0;
        precise_state_valid = 0;
        target_pc = 0;
        BPRecoverEN = 0;
        
        @(negedge clock);
        reset = 0;
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();



        @(posedge clock);
        set_rob_in_packet(2, 1, 1, 32, 1, 0);
        set_rob_in_packet(1, 1, 2, 33, 2, 0);
        set_rob_in_packet(0, 1, 3, 34, 3, 0);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();

    for (int i = 0; i< 33; i = i + 3) begin
        @(posedge clock);
        set_rob_in_packet(2, 1, 4 + i, 35 + i, 4 + i, 0);
        set_rob_in_packet(1, 1, 5 + i, 36 + i, 5 + i, 0);
        set_rob_in_packet(0, 1, 6 + i, 37 + i, 6 + i, 0);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
    end

    for (int i = 0; i< 30; i = i + 3) begin
        @(posedge clock);
        complete_valid = 3'b111;
        set_complete_entry(2,i,0,0);
        set_complete_entry(1,i+1,1,32);
        set_complete_entry(0,i+2,0,0);
        set_rob_in_packet(2, 0, 4, 35, 4, 0);
        set_rob_in_packet(1, 0, 5, 36, 5, 0);
        set_rob_in_packet(0, 0, 6, 37, 6, 0);
        
        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
    end

            @(posedge clock);
        complete_valid = 3'b110;
        set_complete_entry(2,30,0,0);
        set_complete_entry(1,31,1,32);
        
        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();

        @(posedge clock);
        complete_valid = 3'b000;

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();

        @(posedge clock);
        set_rob_in_packet(2, 1, 1, 32, 1, 0);
        set_rob_in_packet(1, 1, 2, 33, 2, 0);
        set_rob_in_packet(0, 1, 3, 34, 3, 0);


        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        
        @(posedge clock);
        BPRecoverEN = 1;

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        
                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        $finish;

    end

endmodule

`endif