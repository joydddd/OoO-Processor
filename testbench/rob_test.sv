`timescale 1ns/100ps
`ifndef __ROB_TEST_SV__
`define __ROB_TEST_SV__

//`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
`define TEST_MODE


module testbench;

    logic clock, reset;
    ROB_ENTRY_PACKET[2:0] rob_in;

	logic [2:0] complete_valid;
	logic [2:0][`ROB-1:0] complete_entry;  // which ROB entry is done
	
	ROB_ENTRY_PACKET [2:0]  retire_entry;  // which ENTRY to be retired

	logic [2:0] rob_stall;
	ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries;
    ROB_ENTRY_PACKET [`ROBW-1:0] rob_debug;
    logic [`ROB-1:0] head;
    logic [`ROB-1:0] tail;

    logic [31:0] cycle_count;

    FU_STATE_PACKET             fu_finish;
    FU_COMPLETE_PACKET [2:0]    fu_c_in;
    FU_STATE_PACKET             fu_c_stall;
    CDB_T_PACKET                cdb_t;
    logic [2:0][`XLEN-1:0]      wb_value;
    
    logic [2:0] precise_state_valid;
	logic [2:0][`XLEN-1:0] target_pc;
	logic [2:0][`ROB-1:0] dispatch_index;

    complete_stage cs(
        .fu_finish(fu_finish), 
        .fu_c_in(fu_c_in), 
        .fu_c_stall(fu_c_stall), 
        .cdb_t(cdb_t), 
        .wb_value(wb_value),
        .complete_valid(complete_valid),
	    .complete_entry(complete_entry),
        .precise_state_valid(precise_state_valid),
	    .target_pc(target_pc)
    );


    ROB tbp(.clock(clock), 
            .reset(reset), 
            .rob_in(rob_in), 
            .complete_valid(complete_valid), 
            .complete_entry(complete_entry), 
            .precise_state_valid(precise_state_valid), 
            .target_pc(target_pc), 
            .dispatch_index(dispatch_index), 
            .retire_entry(retire_entry), 
            .struct_stall(rob_stall),
            .rob_entries_display(rob_entries), 
            .head_display(head), 
            .tail_display(tail), 
            .rob_entries_debug(rob_debug)
        );

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
    

    task show_rob_table;
        $display("####### Cycle %d ##########", cycle_count);
        for(int i=2**`ROB-1; i>=0; i--) begin  // For RS entry, it allocates from 15-0
            $display("valid:%d Tnew:%d Told: %d arch_reg:%d completed:%b precise_state_need:%b target_pc:%b", rob_entries[i].valid, rob_entries[i].Tnew, rob_entries[i].Told, rob_entries[i].arch_reg, rob_entries[i].completed, rob_entries[i].precise_state_need, rob_entries[i].target_pc);
        end
        $display("head:%d tail:%d", head, tail);
        $display("structual_stall:%b", rob_stall);
    endtask; // show_rs_table

    task show_rob_complete;
        begin
            $display("=====   ROB_Complete Packet   =====");
            $display("|   %d  |    %d   |    %d    |", complete_valid[2], complete_valid[1], complete_valid[0]);
            $display("|  %d  |   %d   |   %d    |", complete_entry[2], complete_entry[1], complete_entry[0]);
        end
    endtask

    
    task show_rob_in;
        begin
            $display("=====   ROB_IN Packet   =====");
            $display("| WAY | valid |  Tnew | Told | arch_reg | completed | precise_state | target_pc |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |   %2d  |   %2d |     %2d   |     %b     |       %b       |    %b      |",
                    i, rob_in[i].valid, rob_in[i].Tnew, rob_in[i].Told, rob_in[i].arch_reg, rob_in[i].completed, rob_in[i].precise_state_need, rob_in[i].target_pc);
            end
        end
    endtask

    task show_rob_out;
        begin
            $display("=====   ROB_Retire Packet   =====");
            $display("| WAY | valid |  Tnew | Told | arch_reg | completed | precise_state | target_pc |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |   %2d  |   %2d |     %2d   |     %b     |       %b       |    %b      |",
                    i, retire_entry[i].valid, retire_entry[i].Tnew, retire_entry[i].Told, retire_entry[i].arch_reg, retire_entry[i].completed, retire_entry[i].precise_state_need, retire_entry[i].target_pc);
            end
        end
    endtask

    task set_rob_in_packet;
        input integer rob_in_i;

        input               valid;
	    input [`PR-1:0] 	Tnew;
        input [`PR-1:0] 	Told;
	    input [4:0] 		arch_reg;
	    input 			    completed;

        begin
            rob_in[rob_in_i].valid = valid;
            rob_in[rob_in_i].Tnew = Tnew;
            rob_in[rob_in_i].Told = Told;
            rob_in[rob_in_i].arch_reg = arch_reg;
            rob_in[rob_in_i].completed = completed;
            rob_in[rob_in_i].precise_state_need = 0;
            rob_in[rob_in_i].target_pc = 0;
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
        
        @(negedge clock);
        reset = 0;
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();

        @(posedge clock);
        set_rob_in_packet(0, 1, 4, 5, 1, 0);
        set_rob_in_packet(1, 1, 5, 6, 2, 0);
        set_rob_in_packet(2, 1, 1, 2, 3, 0);

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

        for (int i = 0; i < 30; i=i+3) begin
        @(posedge clock);
        fu_c_in[0].if_take_branch = 1'b0;
        fu_c_in[0].dest_pr = `PR'b001001;
        fu_c_in[0].dest_value = `XLEN'h71a230f1;
        fu_c_in[0].rob_entry = i;
        ////////////////////////////////////////
        fu_c_in[1].if_take_branch = 1'b1;
        fu_c_in[1].dest_pr = `PR'b101110;
        fu_c_in[1].dest_value = `XLEN'h091ec84b;
        fu_c_in[1].rob_entry = i+1;
        ////////////////////////////////////////
        fu_c_in[2].if_take_branch = 1'b0;
        fu_c_in[2].dest_pr = `PR'b010101;
        fu_c_in[2].dest_value = `XLEN'h20a1d324;
        fu_c_in[2].rob_entry = i+2;
        fu_finish = 8'b11111111;

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_complete();
        show_rob_out();
        end
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