`timescale 1ns/100ps


`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
`define TEST_MODE


import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_select(int index,  int valid, int inst,  int npc, int fu_select, int op_select);

module testbench;

    logic clock, reset;
    RS_IN_PACKET[2:0] rs_in;
    CDB_T_PACKET      cdb_t;
    FU_STATE_PACKET   fu_ready;
    logic[2:0]      rs_stall;
    RS_IN_PACKET [2**`RS-1:0] rs_entries;
    RS_IN_PACKET [2**`RS-1:0] rs_debug;

    RS_S_PACKET [2:0] issue_insts;

    logic [31:0] cycle_count;


    RS tbp(.clock(clock), .reset(reset), .rs_in(rs_in),
                     .cdb_t(cdb_t), .fu_ready(fu_ready), .struct_stall(rs_stall),
                     .issue_insts(issue_insts), .rs_entries_display(rs_entries), .rs_entries_debug(rs_debug));

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

    task show_cdb;
        begin
            $display("=====   CDB_T   =====");
            $display("|  CDB_T  |  %d  |  %d  |  %d  |", cdb_t.t0, cdb_t.t1, cdb_t.t2);
        end
    endtask

    task set_cdb_packet;
        input [`PR-1:0] t0;
        input [`PR-1:0] t1;
        input [`PR-1:0] t2;
        begin
            cdb_t.t0 = t0;
            cdb_t.t1 = t1;
            cdb_t.t2 = t2;
        end
    endtask

    task show_rs_in;
        begin
            $display("=====   RS_IN Packet   =====");
            $display("| WAY |     inst    | fu_sel | op_sel  |");
            for (int i=0; i < 3; i++) begin
                print_select(i, rs_in[i].valid, rs_in[i].inst, rs_in[i].NPC, rs_in[i].fu_sel, rs_in[i].op_sel);
            end
            $display("| WAY | dest_pr | reg1_pr | reg1_ready | reg2_pr | reg2_ready |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |      %2d |      %2d |          %b |     %2d  |          %b |",
                    i, rs_in[i].dest_pr, rs_in[i].reg1_pr, rs_in[i].reg1_ready, rs_in[i].reg2_pr, rs_in[i].reg2_ready
                );
            end
        end
    endtask

    task show_rs_out;
        begin
            $display("=====   RS_S Packet   =====");
            $display("| WAY |     inst    | fu_sel | op_sel  |");
            for (int i=0; i < 3; i++) begin
                print_select(i, issue_insts[i].valid, issue_insts[i].inst, issue_insts[i].NPC, issue_insts[i].fu_sel, issue_insts[i].op_sel);
            end
            $display("| WAY | valid |    PC    | dest_pr | reg1_pr | reg2_pr |       inst | halt |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b | %4h |      %2d |      %2d |     %2d  |",
                    i, issue_insts[i].valid, issue_insts[i].PC, issue_insts[i].dest_pr, issue_insts[i].reg1_pr, issue_insts[i].reg2_pr, issue_insts[i].inst, issue_insts[i].halt
                );
            end
        end
    endtask

    task set_rs_in_packet;
        input integer rs_in_i;

        input valid;
        input FU_SELECT fu_sel;
        input OP_SELECT op_sel;
        input [`XLEN-1:0] npc;
        input [`XLEN-1:0] pc;
        input INST inst;
        input halt;

        input [`PR-1:0] dest_pr;
        input [`PR-1:0] reg1_pr;
        input reg1_ready;
        input [`PR-1:0] reg2_pr;
        input reg2_ready;

        begin
            rs_in[rs_in_i].valid = valid;
            rs_in[rs_in_i].fu_sel = fu_sel;
            rs_in[rs_in_i].op_sel = op_sel;
            rs_in[rs_in_i].NPC = npc;
            rs_in[rs_in_i].PC = pc;
            rs_in[rs_in_i].inst = inst;
            rs_in[rs_in_i].halt = halt;
            rs_in[rs_in_i].dest_pr = dest_pr;
            rs_in[rs_in_i].reg1_pr = reg1_pr;
            rs_in[rs_in_i].reg1_ready = reg1_ready;
            rs_in[rs_in_i].reg2_pr = reg2_pr;
            rs_in[rs_in_i].reg2_ready = reg2_ready;
        end
    endtask

    task set_rs_entry;
        input integer rs_in_i;

        input valid;
        input FU_SELECT fu_sel;
        input OP_SELECT op_sel;
        input [`XLEN-1:0] npc;
        input [`XLEN-1:0] pc;
        input INST inst;
        input halt;

        input [`PR-1:0] dest_pr;
        input [`PR-1:0] reg1_pr;
        input reg1_ready;
        input [`PR-1:0] reg2_pr;
        input reg2_ready;

        begin
            rs_debug[rs_in_i].valid = valid;
            rs_debug[rs_in_i].fu_sel = fu_sel;
            rs_debug[rs_in_i].op_sel = op_sel;
            rs_debug[rs_in_i].NPC = npc;
            rs_debug[rs_in_i].PC = pc;
            rs_debug[rs_in_i].inst = inst;
            rs_debug[rs_in_i].halt = halt;
            rs_debug[rs_in_i].dest_pr = dest_pr;
            rs_debug[rs_in_i].reg1_pr = reg1_pr;
            rs_debug[rs_in_i].reg1_ready = reg1_ready;
            rs_debug[rs_in_i].reg2_pr = reg2_pr;
            rs_debug[rs_in_i].reg2_ready = reg2_ready;
        end
    endtask

    task show_fu_state;
        begin
            $display("=====   FU State   =====");
            $display("alu1: %b  alu2: %b  alu3: %b  sl1: %b  sl2: %b  mult1: %b  mult2: %b  branch: %b",
                fu_ready.alu_1, fu_ready.alu_2, fu_ready.alu_3, fu_ready.storeload_1, fu_ready.storeload_2, fu_ready.mult_1, fu_ready.mult_2, fu_ready.branch);
        end
    endtask

    task set_fu_ready;
        input [7:0] ready_bits;
        begin
            fu_ready = ready_bits;
        end
    endtask

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
        rs_debug = 0;
    
        @(negedge clock);
        @(negedge clock);
        reset = 1'b0;
        rs_in = 0;

        set_fu_ready(8'b11111111);
        set_cdb_packet(0, 0, 0);
        set_rs_entry(2, 1, ALU_1, SUB, 0, 4, 32'h40418133, 0,
            5, 3, 1, 2, 1);
        set_rs_entry(1, 1, ALU_2, ADD, 4, 8, 32'h00208033, 0,
            6, 5, 0, 2, 1);
        set_rs_entry(0, 1, ALU_3, ADD, 8, 12, 32'h007302b3, 0,
            7, 3, 1, 6, 0);
        set_rs_entry(3, 1, ALU_1, SUB, 12, 16, 32'h40418133, 0,
            5, 3, 1, 2, 1);
        set_rs_entry(4, 1, ALU_2, ADD, 16, 20, 32'h00208033, 0,
            6, 5, 0, 2, 1);
        set_rs_entry(5, 1, ALU_3, ADD, 20, 24, 32'h007302b3, 0,
            7, 3, 1, 6, 0);
        set_rs_entry(6, 1, ALU_1, SUB, 24, 28, 32'h40418133, 0,
            5, 3, 1, 2, 1);
        set_rs_entry(7, 1, ALU_2, ADD, 28, 32, 32'h00208033, 0,
            6, 5, 0, 2, 1);
        set_rs_entry(8, 1, ALU_3, ADD, 32, 36, 32'h007302b3, 0,
            7, 3, 1, 6, 0);
        set_rs_entry(9, 1, ALU_1, SUB, 36, 40, 32'h40418133, 0,
            5, 3, 1, 2, 1);
        set_rs_entry(10, 1, ALU_2, ADD, 40, 44, 32'h00208033, 0,
            6, 5, 0, 2, 1);
        set_rs_entry(11, 1, ALU_3, ADD, 44, 48, 32'h007302b3, 0,
            7, 3, 1, 6, 0);
            set_rs_entry(12, 1, ALU_1, SUB, 36, 40, 32'h40418133, 0,
            5, 3, 1, 2, 1);
        set_rs_entry(13, 1, ALU_2, ADD, 40, 44, 32'h00208033, 0,
            6, 5, 0, 2, 1);
        set_rs_entry(14, 1, ALU_3, ADD, 44, 48, 32'h007302b3, 0,
            7, 3, 1, 6, 0);
        @(negedge clock);
        show_rs_table();
        show_fu_state();
        show_cdb();
        show_rs_out();
        @(negedge clock);
        
        show_rs_table();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(negedge clock);
        show_rs_table();
        show_fu_state();
        show_cdb();
        show_rs_out();
        
        @(negedge clock);
        show_rs_table();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(negedge clock);
        reset = 1'b1;
        @(negedge clock);
        $finish;

    end

endmodule
