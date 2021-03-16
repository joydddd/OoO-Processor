`timescale 1ns/100ps
`ifndef __RS_TEST_SV__
`define __RS_TEST_SV__

//`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
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

    task check_value;
        input [63:0] value1;
        input [63:0] value2;
        input string note;

        begin
            if (value1 != value2) begin
                $display("Cycle %2d %s not match", cycle_count, note);
                $display("Value1: %2d, Value2: %2d", value1, value2);
                $display("@@@Failed.");
                $finish;
            end
        end
    endtask

    task check_rs_entry;
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
            check_value(rs_entries[rs_in_i].valid, valid, $sformatf("RS entry %2d valid", rs_in_i));
            if (valid) begin
                check_value(rs_entries[rs_in_i].fu_sel, fu_sel, $sformatf("RS entry %2d fu_sel", rs_in_i));
                check_value(rs_entries[rs_in_i].op_sel, op_sel, $sformatf("RS entry %2d op_sel", rs_in_i));
                check_value(rs_entries[rs_in_i].NPC, npc, $sformatf("RS entry %2d npc", rs_in_i));
                check_value(rs_entries[rs_in_i].PC, pc, $sformatf("RS entry %2d pc", rs_in_i));
                check_value(rs_entries[rs_in_i].inst, inst, $sformatf("RS entry %2d inst", rs_in_i));
                check_value(rs_entries[rs_in_i].halt, halt, $sformatf("RS entry %2d halt", rs_in_i));

                check_value(rs_entries[rs_in_i].dest_pr, dest_pr, $sformatf("RS entry %2d dest_pr", rs_in_i));
                check_value(rs_entries[rs_in_i].reg1_pr, reg1_pr, $sformatf("RS entry %2d reg1_pr", rs_in_i));
                check_value(rs_entries[rs_in_i].reg1_ready, reg1_ready, $sformatf("RS entry %2d reg1_ready", rs_in_i));
                check_value(rs_entries[rs_in_i].reg2_pr, reg2_pr, $sformatf("RS entry %2d reg2_pr", rs_in_i));
                check_value(rs_entries[rs_in_i].reg2_ready, reg2_ready, $sformatf("RS entry %2d reg2_ready", rs_in_i));
            end
        end
    endtask

    task check_issue_inst;
        input integer issue_inst_i;

        input valid;
        input FU_SELECT fu_sel;
        input OP_SELECT op_sel;
        input [`XLEN-1:0] npc;
        input [`XLEN-1:0] pc;
        input INST inst;
        input halt;

        input [`PR-1:0] dest_pr;
        input [`PR-1:0] reg1_pr;
        input [`PR-1:0] reg2_pr;

        begin
            check_value(issue_insts[issue_inst_i].valid, valid, $sformatf("Issue insn %2d valid", issue_inst_i));

            if (valid) begin
                check_value(issue_insts[issue_inst_i].fu_sel, fu_sel, $sformatf("Issue insn %2d fu_sel", issue_inst_i));
                check_value(issue_insts[issue_inst_i].op_sel, op_sel, $sformatf("Issue insn %2d op_sel", issue_inst_i));
                check_value(issue_insts[issue_inst_i].NPC, npc, $sformatf("Issue insn %2d npc", issue_inst_i));
                check_value(issue_insts[issue_inst_i].PC, pc, $sformatf("Issue insn %2d pc", issue_inst_i));
                check_value(issue_insts[issue_inst_i].inst, inst, $sformatf("Issue insn %2d inst", issue_inst_i));
                check_value(issue_insts[issue_inst_i].halt, halt, $sformatf("Issue insn %2d halt", issue_inst_i));

                check_value(issue_insts[issue_inst_i].dest_pr, dest_pr, $sformatf("Issue insn %2d dest_pr", issue_inst_i));
                check_value(issue_insts[issue_inst_i].reg1_pr, reg1_pr, $sformatf("Issue insn %2d reg1_pr", issue_inst_i));
                check_value(issue_insts[issue_inst_i].reg2_pr, reg2_pr, $sformatf("Issue insn %2d reg2_pr", issue_inst_i));
            end
        end
    endtask

    task check_rs_stall;
        input [2:0] true_stall;

        begin
            check_value(rs_stall, true_stall, "RS stall");
        end
    endtask
    

    task show_rs_table;
        $display("####### Cycle %d ##########", cycle_count);
        for(int i=2**`RS-1; i>=0; i--) begin  // For RS entry, it allocates from 15-0
            print_stage("*", rs_entries[i].fu_sel, rs_entries[i].NPC[31:0], rs_entries[i].valid);
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
                print_select(i, rs_in[i].valid, rs_in[i].fu_sel, rs_in[i].NPC, rs_in[i].fu_sel, rs_in[i].op_sel);
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
                print_select(i, issue_insts[i].valid, issue_insts[i].fu_sel, issue_insts[i].NPC, issue_insts[i].fu_sel, issue_insts[i].op_sel);
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
        cdb_t = 0;
        @(negedge clock);
        rs_in = 0;
        reset = 0;
        set_cdb_packet(0, 0, 0);
        set_fu_ready(8'b11111111);
        //A simple test for allocating
        set_rs_in_packet(2, 1, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        set_rs_in_packet(1, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        set_rs_in_packet(0, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);

        check_issue_inst(0, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 2);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(negedge clock);
        check_rs_entry(15, 1, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(12, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(11, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(10, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(9, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(8, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(7, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(6, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(3, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(1, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(0, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        
        check_issue_inst(0, 1, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 2);

        check_rs_stall(3'b000);


        set_rs_in_packet(2, 1, LS_1, SLL, 16, 12, 32'h40418133, 0, 5, 3, 1, 2, 1);
        set_rs_in_packet(1, 1, ALU_1, ADD, 20, 16, 32'h00208033, 0, 6, 5, 1, 2, 1);
        set_rs_in_packet(0, 1, ALU_1, ADD, 24, 20, 32'h007302b3, 0, 7, 3, 1, 6, 1);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b01111111);
        @(negedge clock);
        check_rs_entry(15, 1, LS_1, SLL, 16, 12, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(12, 1, ALU_1, ADD, 20, 16, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 1, ALU_1, ADD, 24, 20, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(9, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(8, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(7, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(6, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(3, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(1, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(0, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        
        check_issue_inst(0, 1, LS_1, SLL, 16, 12, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 1, ALU_2, ADD, 20, 16, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(2, 1, ALU_3, ADD, 24, 20, 32'h007302b3, 0, 7, 3, 6);

        check_rs_stall(3'b000);

        
        set_rs_in_packet(2, 1, ALU_1, SUB, 20, 16, 32'h40418133, 0, 5, 3, 1, 2, 1);
        set_rs_in_packet(1, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 0, 2, 1);
        set_rs_in_packet(0, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 0);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();
        @(posedge clock);
        set_fu_ready(8'b00001111);
        @(negedge clock);
        check_rs_entry(15, 1, ALU_1, SUB, 20, 16, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(11, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(10, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(9, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(8, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(7, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(6, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(3, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(1, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(0, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);

        check_issue_inst(0, 0, LS_1, SLL, 16, 12, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 0, ALU_2, ADD, 20, 16, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(2, 0, ALU_3, ADD, 24, 20, 32'h007302b3, 0, 7, 3, 6);

        check_rs_stall(3'b000);

        set_rs_in_packet(2, 1, ALU_1, SUB, 36, 32, 32'h40418133, 0, 5, 3, 1, 2, 1);
        set_rs_in_packet(1, 1, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 0, 2, 1);
        set_rs_in_packet(0, 1, ALU_1, ADD, 44, 40, 32'h007302b3, 0, 7, 3, 1, 8, 0);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();
        @(posedge clock);
        set_fu_ready(8'b01001111);
        @(negedge clock);
        check_rs_entry(15, 1, ALU_1, SUB, 20, 16, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(11, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(10, 1, ALU_1, SUB, 36, 32, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(9, 1, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(8, 1, ALU_1, ADD, 44, 40, 32'h007302b3, 0, 7, 3, 1, 8, 0);
        check_rs_entry(7, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(6, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(3, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(1, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(0, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);

        check_issue_inst(2, 0, ALU_2, SUB, 20, 16, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 0, ALU_2, ADD, 20, 16, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(0, 1, ALU_2, SUB, 20, 16, 32'h40418133, 0, 5, 3, 2);

        check_rs_stall(3'b000);

        set_rs_in_packet(2, 1, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 0, 2, 1);
        set_rs_in_packet(1, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 0, 2, 1);
        set_rs_in_packet(0, 1, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 0);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();
        @(posedge clock);
        set_fu_ready(8'b10000000);
        set_cdb_packet(8, 0, 0);
        @(negedge clock);
        check_rs_entry(15, 1, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 0, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(11, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(10, 1, ALU_1, SUB, 36, 32, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(9, 1, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(8, 1, ALU_1, ADD, 44, 40, 32'h007302b3, 0, 7, 3, 1, 8, 0);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(6, 1, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(5, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(3, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(1, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(0, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);

        check_issue_inst(2, 0, ALU_2, SUB, 20, 16, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 0, ALU_2, ADD, 20, 16, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(0, 1, ALU_1, SUB, 36, 32, 32'h40418133, 0, 5, 3, 2);

        check_rs_stall(3'b000);

        set_rs_in_packet(2, 1, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 0, 2, 1);
        set_rs_in_packet(1, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 0, 2, 1);
        set_rs_in_packet(0, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 0);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();
        @(posedge clock);
        set_fu_ready(8'b00001111);
        set_cdb_packet(0, 0, 0);
        @(negedge clock);
        check_rs_entry(15, 1, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 0, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(11, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(10, 1, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 0, 2, 1);
        check_rs_entry(9, 1, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(8, 1, ALU_1, ADD, 44, 40, 32'h007302b3, 0, 7, 3, 1, 8, 1);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(6, 1, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(5, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 0, 2, 1);
        check_rs_entry(4, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 0);
        check_rs_entry(3, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(2, 0, ALU_1, SUB, 4, 0, 32'h40418133, 0, 5, 3, 1, 2, 1);
        check_rs_entry(1, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(0, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        
        check_issue_inst(2, 0, ALU_2, SUB, 20, 16, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 0, ALU_2, ADD, 20, 16, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(0, 0, ALU_1, SUB, 36, 32, 32'h40418133, 0, 5, 3, 2);

        check_rs_stall(3'b000);

        set_rs_in_packet(2, 1, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 0, 2, 1);
        set_rs_in_packet(1, 1, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 0, 2, 1);
        set_rs_in_packet(0, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b11110000);
        set_cdb_packet(0, 6, 10);
        @(negedge clock);
        check_rs_entry(15, 1, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 0, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(11, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(10, 1, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 0, 2, 1);
        check_rs_entry(9, 1, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(8, 1, ALU_1, ADD, 44, 40, 32'h007302b3, 0, 7, 3, 1, 8, 1);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(6, 1, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 0);
        check_rs_entry(5, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 0, 2, 1);
        check_rs_entry(4, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 0);
        check_rs_entry(3, 1, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 0, 2, 1);
        check_rs_entry(2, 1, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 0, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 0, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);

        check_issue_inst(2, 0, ALU_2, SUB, 20, 16, 32'h40418133, 0, 5, 3, 2);
        check_issue_inst(1, 0, ALU_2, ADD, 20, 16, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(0, 1, ALU_1, ADD, 44, 40, 32'h007302b3, 0, 7, 3, 8);

        check_rs_stall(3'b001);

        set_rs_in_packet(2, 1, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 0, 2, 1);
        set_rs_in_packet(1, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 0, 2, 1);
        set_rs_in_packet(0, 0, BRANCH, ADD, 92, 88, 32'h007302b3, 0, 7, 3, 1, 16, 0);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b11010111);
        set_cdb_packet(5, 15, 9);
        @(negedge clock);
        check_rs_entry(15, 1, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 0, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(13, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(11, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 1, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 1, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(8, 1, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 0, 2, 1);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 0, 2, 1);
        check_rs_entry(6, 1, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 0, 2, 1);
        check_rs_entry(4, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 0);
        check_rs_entry(3, 1, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 0, 2, 1);
        check_rs_entry(2, 1, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 0, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 0, 2, 1);

        check_issue_inst(0, 1, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 6);
        check_issue_inst(1, 1, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 6);
        check_issue_inst(2, 1, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 6);

        check_rs_stall(3'b000);

        rs_in = 0;

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b01100011);
        set_cdb_packet(0, 17, 0);
        @(negedge clock);
        check_rs_entry(15, 1, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 1, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 1, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 1, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 1, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 0, 2, 1);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 0, 2, 1);
        check_rs_entry(4, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 0);
        check_rs_entry(3, 1, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 0, 2, 1);
        check_rs_entry(2, 1, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 0, 2, 1);

        // check_issue_inst(2, 1, ALU_3, ADD, 8, 4, 32'h00208033, 0, 6, 5, 2);
        // check_issue_inst(1, 1, ALU_2, ADD, 40, 36, 32'h00208033, 0, 6, 5, 2);
        // check_issue_inst(0, 1, MULT_2, SUB, 48, 44, 32'h40418133, 0, 5, 9, 2);
        // CHECK: Is this order expected?
        check_issue_inst(2, 1, MULT_2, SUB, 48, 44, 32'h40418133, 0, 5, 9, 2);
        check_issue_inst(0, 1, ALU_2, ADD, 8, 4, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(1, 1, ALU_3, ADD, 40, 36, 32'h00208033, 0, 6, 5, 2);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b01000100);
        set_cdb_packet(0, 14, 0);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 1, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 1, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 0, 2, 1);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 0, 2, 1);
        check_rs_entry(4, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 0);
        check_rs_entry(3, 1, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 0, 2, 1);
        check_rs_entry(2, 1, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(2, 0, MULT_2, SUB, 48, 44, 32'h40418133, 0, 5, 9, 2);
        check_issue_inst(0, 1, ALU_2, SUB, 60, 56, 32'h40418133, 0, 5, 10, 2);
        check_issue_inst(1, 1, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 2);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b00111110);
        set_cdb_packet(0, 13, 12);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 1, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 0, 2, 1);
        check_rs_entry(4, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 0);
        check_rs_entry(3, 1, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(2, 0, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(0, 1, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(2, 1, MULT_2, SUB, 84, 80, 32'h40418133, 0, 5, 14, 2);
        check_issue_inst(1, 1, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 2);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b11101001);
        set_cdb_packet(0, 0, 0);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 0, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 0, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(7, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 1, 2, 1);
        check_rs_entry(4, 1, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 1);
        check_rs_entry(3, 0, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(2, 0, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(0, 1, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(1, 1, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 2);
        check_issue_inst(2, 1, ALU_2, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 13);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b10011110);
        set_cdb_packet(0, 0, 0);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 0, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 0, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(7, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 1, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 1);
        check_rs_entry(3, 0, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(2, 0, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(2, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(1, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 2);
        check_issue_inst(0, 1, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 2);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b11111111);
        set_cdb_packet(0, 16, 0);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 0, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 0, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(7, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 1, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 1);
        check_rs_entry(3, 0, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(2, 0, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 0);
        check_rs_entry(0, 0, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(2, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(1, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 2);
        check_issue_inst(0, 0, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 2);
        
        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b11111111);
        set_cdb_packet(0, 0, 0);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 0, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 0, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(7, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 1, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 1);
        check_rs_entry(3, 0, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(2, 0, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 1);
        check_rs_entry(0, 0, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(2, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(1, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 2);
        check_issue_inst(0, 1, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 16);
        
        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b11111111);
        set_cdb_packet(0, 0, 0);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 0, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 0, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(7, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 1, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 1);
        check_rs_entry(3, 0, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(2, 0, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 0, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 1);
        check_rs_entry(0, 0, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(2, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(1, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 2);
        check_issue_inst(0, 0, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 16);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        @(posedge clock);
        set_fu_ready(8'b11111111);
        set_cdb_packet(12, 13, 2);
        @(negedge clock);

        check_rs_entry(15, 0, MULT_1, SUB, 48, 44, 32'h40418133, 0, 5, 9, 1, 2, 1);
        check_rs_entry(14, 0, ALU_1, ADD, 8, 4, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(13, 0, ALU_1, ADD, 12, 8, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(12, 0, LS_1, SRL, 28, 24, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(11, 0, LS_1, ADD, 32, 28, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(10, 0, ALU_1, SUB, 60, 56, 32'h40418133, 0, 5, 10, 1, 2, 1);
        check_rs_entry(9, 0, ALU_1, ADD, 40, 36, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(8, 0, MULT_1, SUB, 84, 80, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(7, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 1, 2, 1);
        check_rs_entry(6, 0, MULT_1, ADD, 56, 52, 32'h007302b3, 0, 7, 3, 1, 6, 1);
        check_rs_entry(5, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 1, 2, 1);
        check_rs_entry(4, 0, ALU_1, ADD, 68, 64, 32'h007302b3, 0, 7, 3, 1, 13, 1);
        check_rs_entry(3, 0, MULT_1, SUB, 72, 68, 32'h40418133, 0, 5, 14, 1, 2, 1);
        check_rs_entry(2, 0, MULT_1, ADD, 76, 72, 32'h00208033, 0, 6, 15, 1, 2, 1);
        check_rs_entry(1, 0, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 1, 16, 1);
        check_rs_entry(0, 0, MULT_1, ADD, 88, 84, 32'h00208033, 0, 6, 17, 1, 2, 1);

        check_issue_inst(2, 0, BRANCH, ADD, 52, 48, 32'h00208033, 0, 6, 5, 2);
        check_issue_inst(1, 0, ALU_1, ADD, 64, 60, 32'h00208033, 0, 6, 12, 2);
        check_issue_inst(0, 0, BRANCH, ADD, 80, 76, 32'h007302b3, 0, 7, 3, 16);

        check_rs_stall(3'b000);

        show_rs_table();
        show_rs_in();
        show_fu_state();
        show_cdb();
        show_rs_out();

        $display(" ");
        $display("----------Finished running testbench--------------");
        $display("@@@Passed.");
        $finish;

    end

endmodule

`endif