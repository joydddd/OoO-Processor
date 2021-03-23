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


    ROB tbp(.clock(clock), .reset(reset), .rob_in(rob_in), .complete_valid(complete_valid), .complete_entry(complete_entry), .retire_entry(retire_entry), .struct_stall(rob_stall),.rob_entries_display(rob_entries), .head_display(head), .tail_display(tail), .rob_entries_debug(rob_debug));

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
    

    task show_rob_table;
        $display("####### Cycle %d ##########", cycle_count);
        for(int i=2**`ROB-1; i>=0; i--) begin  // For RS entry, it allocates from 15-0
            $display("valid:%d Tnew:%d Told: %d arch_reg:%d completed:%b", rob_entries[i].valid, rob_entries[i].Tnew, rob_entries[i].Told, rob_entries[i].arch_reg, rob_entries[i].completed);
        end
        $display("head:%d tail:%d", head, tail);
        $display("structual_stall:%b", rob_stall);
    endtask; // show_rs_table

    task show_rob_in;
        begin
            $display("=====   ROB_IN Packet   =====");
            $display("| WAY | valid |  Tnew | Told | arch_reg | completed |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |      %2d |      %2d   |     %2d  |          %b |",
                    i, rob_in[i].valid, rob_in[i].Tnew, rob_in[i].Told, rob_in[i].arch_reg, rob_in[i].completed);
            end
        end
    endtask

    task show_rob_out;
        begin
            $display("=====   ROB_Retire Packet   =====");
            $display("| WAY | valid | busy | Tnew | Told | arch_reg | completed |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |      %2d |      %2d   |     %2d  |          %b |",
                    i, retire_entry[i].valid, retire_entry[i].Tnew, retire_entry[i].Told, retire_entry[i].arch_reg, retire_entry[i].completed);
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
        end
    endtask

    task set_complete_entry;
        input integer rob_in_i;

        input [`ROB-1:0] complete_index;

        begin
            complete_entry[rob_in_i] = complete_index;
        end
    endtask

    task set_rob_entry;
        input integer rob_debug_i;

        input               valid;
	    input [`PR-1:0] 	Tnew;
        input [`PR-1:0] 	Told;
	    input [4:0] 		arch_reg;
	    input 			    completed;

        begin
            rob_debug[rob_debug_i].valid = valid;
            rob_debug[rob_debug_i].Tnew = Tnew;
            rob_debug[rob_debug_i].Told = Told;
            rob_debug[rob_debug_i].arch_reg = arch_reg;
            rob_debug[rob_debug_i].completed = completed;
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
        complete_valid = 0;
        complete_entry = 0;
        rob_in = 0;
        
        @(negedge clock);
        reset = 0;
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        set_rob_in_packet(0, 1, 4, 5, 1, 0);
        set_rob_in_packet(1, 1, 5, 6, 2, 1);
        set_rob_in_packet(2, 1, 1, 2, 3, 0);
        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        set_rob_in_packet(0, 0, 4, 5, 1, 0);
        set_rob_in_packet(1, 0, 5, 6, 2, 1);
        set_rob_in_packet(2, 0, 1, 2, 3, 0);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        complete_valid = 1;
        set_complete_entry(0,0);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();


        @(posedge clock);
        complete_valid = 3'b111;
        set_complete_entry(0,2);
        set_complete_entry(1,3);
        set_complete_entry(2,5);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        set_complete_entry(0,6);
        set_complete_entry(1,8);
        set_complete_entry(2,9);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        set_complete_entry(0,11);
        set_complete_entry(1,12);
        set_complete_entry(2,14);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        set_complete_entry(0,15);
        set_complete_entry(1,17);
        set_complete_entry(2,18);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(posedge clock);
        set_complete_entry(0,20);
        set_complete_entry(1,21);
        set_complete_entry(2,23);
        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        set_complete_entry(0,24);
        set_complete_entry(1,26);
        set_complete_entry(2,27);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        complete_valid = 3'b011;
        set_complete_entry(0,29);
        set_complete_entry(1,30);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(negedge clock);
        complete_valid = 3'b000;
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

                @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();

        @(posedge clock);
        set_rob_in_packet(0, 1, 9, 5, 1, 0);
        set_rob_in_packet(1, 1, 8, 6, 2, 1);
        set_rob_in_packet(2, 1, 7, 2, 3, 0);

        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();
 @(posedge clock);
        set_rob_in_packet(0, 0, 9, 5, 1, 0);
        set_rob_in_packet(1, 0, 8, 6, 2, 1);
        set_rob_in_packet(2, 0, 7, 2, 3, 0);


        @(negedge clock);
        show_rob_table();
        show_rob_in();
        show_rob_out();
        $finish;

    end

endmodule

`endif