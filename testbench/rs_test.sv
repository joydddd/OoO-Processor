`timescale 1ns/100ps


`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
`define TEST_MODE


import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);


module testbench;

    logic clock, reset;
    RS_IN_PACKET[2:0] rs_in;
    CDB_T_PACKET      cdb_t;
    logic[2:0]      rs_stall;
    RS_IN_PACKET [2**`RS-1:0] rs_entries;

    logic [31:0] cycle_count;


    RS tbp(.clock(clock), .reset(reset), .rs_in(rs_in),
                     .cdb_t(cdb_t), .struct_stall(rs_stall), .rs_entries_display(rs_entries));

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
    

    task show_rs_table;
        $display("####### Cycle %d ##########", cycle_count);
        for(int i=2**`RS-1; i>=0; i--) begin  // For RS entry, it allocates from 15-0
            print_stage("*", rs_entries[i].inst, rs_entries[i].NPC[31:0], rs_entries[i].valid);
            $display("dest_pr:%d reg1_pr:%d reg1_ready: %b reg2_pr:%d reg2_ready %b", rs_entries[i].dest_pr, rs_entries[i].reg1_pr, rs_entries[i].reg1_ready, rs_entries[i].reg2_pr, rs_entries[i].reg2_ready);
        end
        $display("structual_stall:%b", rs_stall);
    endtask; // show_rs_table
    always_ff@(negedge clock) begin
        show_rs_table;
    end

    always_ff@(posedge clock) begin
        if (reset)
            cycle_count <= 0;
        else 
            cycle_count <= cycle_count + 1;
    end



    initial begin
        $dumpvars;
        clock = 1'b0;
        reset = 1'b1;
    
        @(negedge clock);
        @(negedge clock);
        reset = 1'b0;
        rs_in = 0;
        rs_in[2].valid = 1;
        rs_in[2].NPC = 4;
        rs_in[2].inst = 32'h40418133;
        rs_in[1].valid = 1;
        rs_in[1].NPC = 8;
        rs_in[1].inst = 32'h00208033;
        rs_in[0].valid = 1;
        rs_in[0].NPC = 12;
        rs_in[0].inst = 32'h007302b3;
        @(negedge clock);
        rs_in[2].valid = 1;
        rs_in[2].NPC = 16;
        rs_in[2].inst = 32'h40418133;
        rs_in[1].valid = 1;
        rs_in[1].NPC = 20;
        rs_in[1].inst = 32'h00208033;
        rs_in[0].valid = 1;
        rs_in[0].NPC = 24;
        rs_in[0].inst = 32'h007302b3;
        rs_in[2].valid = 1;
        @(negedge clock);
        rs_in[2].valid = 1;
        rs_in[2].NPC = 28;
        rs_in[2].inst = 32'h40418133;
        rs_in[1].valid = 1;
        rs_in[1].NPC = 32;
        rs_in[1].inst = 32'h00208033;
        rs_in[0].valid = 1;
        rs_in[0].NPC = 36;
        rs_in[0].inst = 32'h007302b3;
        rs_in[2].valid = 1;
        @(negedge clock);
        rs_in[2].valid = 1;
        rs_in[2].NPC = 40;
        rs_in[2].inst = 32'h40418133;
        rs_in[1].valid = 1;
        rs_in[1].NPC = 44;
        rs_in[1].inst = 32'h00208033;
        rs_in[0].valid = 1;
        rs_in[0].NPC = 48;
        rs_in[0].inst = 32'h007302b3;
        rs_in[2].valid = 1;
        @(negedge clock);
        rs_in[2].valid = 1;
        rs_in[2].NPC = 52;
        rs_in[2].inst = 32'h40418133;
        rs_in[1].valid = 1;
        rs_in[1].NPC = 56;
        rs_in[1].inst = 32'h00208033;
        rs_in[0].valid = 1;
        rs_in[0].NPC = 60;
        rs_in[0].inst = 32'h007302b3;
        rs_in[2].valid = 1;
        @(negedge clock);
        reset = 1'b1;
        @(negedge clock);
        $finish;

    end

endmodule
