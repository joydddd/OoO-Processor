`timescale 1ns/100ps
`ifndef __PIPELINE_TEST_SV__
`define __PIPELINE_TEST_SV__

`define TEST_MODE 
`define DIS_DEBUG

/* import freelist simulator */
import "DPI-C" function void fl_init();
import "DPI-C" function int fl_new_pr_valid();
import "DPI-C" function int fl_new_pr2(int new_pr_en);
import "DPI-C" function int fl_new_pr1(int new_pr_en);
import "DPI-C" function int fl_new_pr0(int new_pr_en);
import "DPI-C" function int fl_pop(int new_pr_en);

/* import map table simulator */ 
import "DPI-C" function void mt_init();
import "DPI-C" function int mt_look_up(int i);
import "DPI-C" function int mt_look_up_ready(int i);
import "DPI-C" function void mt_map(int ar, int pr);

/* import print pipeline */
import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_num(int num);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);

/* import print rs */ 
import "DPI-C" function void print_select(int index,  int valid, int inst,  int npc, int fu_select, int op_select);


module testbench;
logic clock, reset;

`ifdef TEST_MODE
// IF to Dispatch 


// ID stage output
IF_ID_PACKET [2:0]         dis_in_display;
ROB_ENTRY_PACKET [2:0]     dis_rob_packet_display;
logic [2:0]                dis_stall_display;

// RS
RS_IN_PACKET [2:0]         dis_rs_packet_display;
RS_IN_PACKET [`RSW-1:0]    rs_entries_display;
RS_S_PACKET [2:0]          rs_out_display;
logic [2:0]                rs_stall_display;

// Maptable
logic [31:0][`PR-1:0] map_array_display;
logic [31:0] ready_array_display;

// IS
RS_S_PACKET [2:0]          is_in_display;
FU_FIFO_PACKET             fu_fifo_stall_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] alu_fifo_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] mult_fifo_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] br_fifo_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] ls_fifo_display;


// FU 
ISSUE_FU_PACKET [2**`FU-1:0] fu_in_display;
FU_STATE_PACKET            fu_ready_display;
FU_STATE_PACKET            fu_finish_display;
FU_COMPLETE_PACKET [2:0]   fu_packet_out_display;

// Complete
CDB_T_PACKET               cdb_t_display;

//ROB
	ROB_ENTRY_PACKET [`ROBW-1:0]    rob_entries_display;
    logic       [`ROB-1:0]          head_display;
    logic       [`ROB-1:0]          tail_display;

`endif

`ifdef DIS_DEBUG
IF_ID_PACKET [2:0]          if_d_packet_debug;
logic [2:0]                 dis_new_pr_en_out;
/* free list simulation */
logic [2:0]                 free_pr_valid_debug;
logic [2:0][`PR-1:0]        free_pr_debug;

/* maptable simulation */
/*
logic [2:0] [4:0]           maptable_lookup_reg1_ar_out;
logic [2:0] [4:0]           maptable_lookup_reg2_ar_out;
logic [2:0] [4:0]           maptable_allocate_ar_out;
logic [2:0] [`PR-1:0]       maptable_allocate_pr_out;
logic [2:0][`PR-1:0]        maptable_old_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg1_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg2_pr_debug;
logic [2:0]                 maptable_reg1_ready_debug;
logic [2:0]                 maptable_reg2_ready_debug;
*/

logic [2:0]                 rob_stall_debug;
FU_STATE_PACKET             fu_ready_debug;
CDB_T_PACKET                cdb_t_debug;
`endif

pipeline tbd(
    .clock(clock),
    .reset(reset)
`ifdef TEST_MODE
    // ID
    , .dis_in_display(dis_in_display)
    , .dis_rob_packet_display(dis_rob_packet_display)
    , .dis_stall_display(dis_stall_display)
    // RS
    , .dis_rs_packet_display(dis_rs_packet_display)
    , .rs_entries_display(rs_entries_display)
    , .rs_out_display(rs_out_display)
    , .rs_stall_display(rs_stall_display)
    // Maptable
    , .map_array_disp(map_array_display)
    , .ready_array_disp(ready_array_display)
    // IS
    , .is_in_display(is_in_display)
    , .fu_fifo_stall_display(fu_fifo_stall_display)
    , .alu_fifo_display(alu_fifo_display)
    , .mult_fifo_display(mult_fifo_display)
    , .br_fifo_display(br_fifo_display)
    , .ls_fifo_display(ls_fifo_display)
    // FU
    , .fu_in_display(fu_in_display)
    , .fu_ready_display(fu_ready_display)
    , .fu_finish_display(fu_finish_display)
    , .fu_packet_out_display(fu_packet_out_display)
    // Complete
    , .cdb_t_display(cdb_t_display)
    , .wb_value_display(wb_value_display)
    // ROB
    , .rob_entries_display(rob_entries_display)
    , .head_display(head_display)
    , .tail_display(tail_display)
    // Freelist
    , .fl_array_display(fl_array_display)
    , .fl_head_display(fl_head_display)
    , .fl_tail_display(fl_tail_display)
    , .fl_empty_display(fl_empty_display)
`endif // TEST_MODE

`ifdef DIS_DEBUG
    , .if_d_packet_debug(if_d_packet_debug)
    , .dis_new_pr_en_out(dis_new_pr_en_out)
    /* free list simulation */
    , .free_pr_valid_debug(free_pr_valid_debug)
    , .free_pr_debug(free_pr_debug)
    /* maptable simulation */
    /*
    , .maptable_lookup_reg1_ar_out(maptable_lookup_reg1_ar_out)
    , .maptable_lookup_reg2_ar_out(maptable_lookup_reg2_ar_out)
    , .maptable_allocate_ar_out(maptable_allocate_ar_out)
    , .maptable_allocate_pr_out(maptable_allocate_pr_out)
    , .maptable_old_pr_debug(maptable_old_pr_debug)
    , .maptable_reg1_pr_debug(maptable_reg1_pr_debug)
    , .maptable_reg2_pr_debug(maptable_reg2_pr_debug)
    , .maptable_reg1_ready_debug(maptable_reg1_ready_debug)
    , .maptable_reg2_ready_debug(maptable_reg2_ready_debug)
    */

    , .rob_stall_debug(rob_stall_debug)
    , .fu_ready_debug(fu_ready_debug)
    , .cdb_t_debug(cdb_t_debug)
`endif
);

/* clock */
always begin
	#(`VERILOG_CLOCK_PERIOD/2.0);
	clock = ~clock;
end

////////////////////////////////////////////////////////////
/////////////       SIMULATORS
///////////////////////////////////////////////////////////

/* free list simulator */
always @(posedge clock) begin
    if (reset) begin
        fl_init();
    end else begin
        fl_pop(dis_new_pr_en_out);
    end
end
always @(dis_new_pr_en_out, clock) begin
    `SD;
    if (!reset) begin
        free_pr_valid_debug = fl_new_pr_valid();
        free_pr_debug[2] = fl_new_pr2(dis_new_pr_en_out);
        free_pr_debug[1] = fl_new_pr1(dis_new_pr_en_out);
        free_pr_debug[0] = fl_new_pr0(dis_new_pr_en_out);
    end
end

/* map table simulator */
/*
always @(posedge clock) begin
    if (reset) begin
        mt_init();
    end else begin
        for(int i=0; i<3; i++) begin
            mt_map(maptable_allocate_ar_out[i], maptable_allocate_pr_out[i]); 
        end
    end
end
always @(maptable_allocate_ar_out) begin
    maptable_old_pr_debug[2] = mt_look_up(maptable_allocate_ar_out[2]);
    maptable_old_pr_debug[1] = mt_look_up(maptable_allocate_ar_out[1]);
    maptable_old_pr_debug[0] = mt_look_up(maptable_allocate_ar_out[0]);
end
always @(maptable_lookup_reg1_ar_out) begin
    for(int i=0; i<3; i++) begin
        maptable_reg1_pr_debug[i] = mt_look_up(maptable_lookup_reg1_ar_out[i]);
        maptable_reg1_ready_debug[i] = mt_look_up_ready(maptable_lookup_reg1_ar_out[i]);
    end
end
always @(maptable_lookup_reg2_ar_out) begin
    for(int i=0; i<3; i++) begin
        maptable_reg2_pr_debug[i] = mt_look_up(maptable_lookup_reg2_ar_out[i]);
        maptable_reg2_ready_debug[i] = mt_look_up_ready(maptable_lookup_reg2_ar_out[i]);
    end
end

*/

//////////////////////////////////////////////////////////////
//////////////                  DISPLAY
/////////////////////////////////////////////////////////////
always @(negedge clock) begin
    if (!reset)  begin
        #1;
        $display();
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display();
        print_pipeline;
        print_is_fifo;
        print_alu;
        show_fu_stat;
        show_cdb;
        // show_rs_in;
        show_rs_table;
        show_rs_out;
        show_rob_table;
        show_rob_in;
    end
end


task show_rs_in;
    begin
        $display("=====   RS_IN Packet   =====");
        $display("| WAY |     inst    | fu_sel | op_sel  |");
        for (int i=2; i >= 0 ; i--) begin
            print_select(i, dis_rs_packet_display[i].valid, dis_rs_packet_display[i].inst, dis_rs_packet_display[i].PC, dis_rs_packet_display[i].fu_sel, dis_rs_packet_display[i].op_sel);
        end
        $display("| WAY | dest_pr | reg1_pr | reg1_ready | reg2_pr | reg2_ready |");
        for (int i=2; i>=0; i--) begin
            $display("|  %1d  |      %2d |      %2d |          %b |     %2d  |          %b |",
                i, dis_rs_packet_display[i].dest_pr, dis_rs_packet_display[i].reg1_pr, dis_rs_packet_display[i].reg1_ready, dis_rs_packet_display[i].reg2_pr, dis_rs_packet_display[i].reg2_ready
            );
        end
    end
endtask

task show_rs_out;
    begin
        $display("=====   RS_S Packet   =====");
        $display("| WAY |     inst    | fu_sel | op_sel  |");
        for (int i=2; i>=0; i--) begin
            print_select(i, rs_out_display[i].valid, rs_out_display[i].inst, rs_out_display[i].PC, rs_out_display[i].fu_sel, rs_out_display[i].op_sel);
        end
        $display("| WAY | valid |  PC  | dest_pr | reg1_pr | reg2_pr |       inst | halt |");
        for (int i=2; i>=0; i--) begin
            $display("|  %1d  |     %b | %4h |      %2d |      %2d |     %2d  |",
                i, rs_out_display[i].valid, rs_out_display[i].PC, rs_out_display[i].dest_pr, rs_out_display[i].reg1_pr, rs_out_display[i].reg2_pr, rs_out_display[i].inst, rs_out_display[i].halt
            );
        end
    end
endtask

task show_rs_table;
    for(int i=2**`RS-1; i>=0; i--) begin  // For RS entry, it allocates from 15-0
        print_stage("*", rs_entries_display[i].inst, rs_entries_display[i].PC[31:0], rs_entries_display[i].valid);
        $display("dest_pr:%d reg1_pr:%d reg1_ready: %b reg2_pr:%d reg2_ready %b", rs_entries_display[i].dest_pr, rs_entries_display[i].reg1_pr, rs_entries_display[i].reg1_ready, rs_entries_display[i].reg2_pr, rs_entries_display[i].reg2_ready);
    end
    $display("structual_stall:%b", rs_stall_display);
endtask; // show_rs_table


task show_fu_stat;
    $display("fu ready: %8b", fu_ready_debug);
    $display("fu finish: %8b", fu_finish_display);
    $display("| valid | halt | take_branch | target_pc | dest_pr | dest_value | rob_entry |");
    for(int i = 2; i >=0; i--) begin
        $display("| %1d | %1d | %1d | %4h | %2d | %d | %2d |", 
                fu_packet_out_display[i].valid, fu_packet_out_display[i].halt, fu_packet_out_display[i].if_take_branch,
                fu_packet_out_display[i].target_pc, fu_packet_out_display[i].dest_pr, fu_packet_out_display[i].dest_value,
                fu_packet_out_display[i].rob_entry);
    end
endtask; 

task show_cdb;
    $display("CDB: %d  %d  %d", cdb_t_display.t0, cdb_t_display.t1, cdb_t_display.t2);
endtask;

task show_rob_in;
    $display("|ROB|valid| Tnew | Told | Reg  |Completed|");
    for(int i=2; i>=0; i--) begin
        $display("| %1d |  %1d  |  %2d  |  %2d  |  %2d  |    %1d    |", i, dis_rob_packet_display[i].valid, dis_rob_packet_display[i].Tnew, dis_rob_packet_display[i].Told, dis_rob_packet_display[i].arch_reg, dis_rob_packet_display[i].completed);
    end
endtask

task show_rob_table;
    for(int i=2**`ROB-1; i>=0; i--) begin  
        $display("valid: %d  Tnew: %d  Told: %d  arch_reg: %d  completed: %b  precise_state: %b  target_pc: %3d", rob_entries_display[i].valid, rob_entries_display[i].Tnew, rob_entries_display[i].Told, rob_entries_display[i].arch_reg, rob_entries_display[i].completed, rob_entries_display[i].precise_state_need, rob_entries_display[i].target_pc);
    end
    $display("head:%d tail:%d", head_display, tail_display);
endtask; // show_rs_table


task print_pipeline;
    print_cycles();
    print_header("\n |     IF      |     DIS     |     IS      |\n");
    for(int i=2; i>=0; i--) begin
        print_num(i);
        `ifdef DIS_DEBUG
        /* IF debug */
        print_stage("|", if_d_packet_debug[i].inst, if_d_packet_debug[i].PC, if_d_packet_debug[i].valid);
        `endif
        /* DIS */
        print_stage("|", dis_in_display[i].inst, dis_in_display[i].PC, dis_in_display[i].valid);
        // /* dispatch to rs */
        // print_stage("|", dis_rs_packet_display[i].inst, dis_rs_packet_display[i].PC, dis_rs_packet_display[i].valid);
        /* IS */
        print_stage("|", is_in_display[i].inst, is_in_display[i].PC, is_in_display[i].valid);
        print_header("|\n");
    end
endtask

task print_is_fifo;
    $display("IS FIFO stall: %4b", fu_fifo_stall_display);
    print_header("\n|     ALU     |     LS      |    MULT     |   BRANCH    |\n");
    for(int i=0; i<`IS_FIFO_DEPTH; i++) begin
        print_stage("|", alu_fifo_display[i].inst, alu_fifo_display[i].PC, alu_fifo_display[i].valid);
        print_stage("|", ls_fifo_display[i].inst, ls_fifo_display[i].PC, ls_fifo_display[i].valid);
        print_stage("|", mult_fifo_display[i].inst, mult_fifo_display[i].PC, mult_fifo_display[i].valid);
        print_stage("|", br_fifo_display[i].inst, br_fifo_display[i].PC, br_fifo_display[i].valid);
        print_header("|\n");
    end
endtask

task print_alu;
    print_header("\n|    ALU_1    |    ALU_2    |    ALU_3    |     LS_1    |     LS_2    |    MULT_1   |    MULT_2   |    BRANCH   |\n");
    for (int i=0; i<2**`FU; i++) begin
        print_stage("|", fu_in_display[i].inst, fu_in_display[i].PC, fu_in_display[i].valid);
    end
    $display();
endtask

//////////////////////////////////////////////////////////
///////////////         SET      
/////////////////////////////////////////////////////////

task set_if_d_packet;
    input int i;
    input INST inst;
    input [`XLEN-1:0] pc;
    if_d_packet_debug[i].inst = inst;
    if_d_packet_debug[i].PC = pc;
    if_d_packet_debug[i].NPC = pc+4;
    if_d_packet_debug[i].valid = 1;
endtask

task set_if_d_packet_invalid;
    input int i;
    if_d_packet_debug[i].valid = 0;
endtask

int PC; 
initial begin
    $dumpvars;
    clock = 1'b0;
    reset = 1'b1;
    rob_stall_debug = 3'b000;
    fu_ready_debug = 8'b00011111;
    cdb_t_debug = {`RS'b0, `RS'b0, `RS'b0};
    PC = 0;
    @(posedge clock)
    #2 reset = 1'b0;
    
    @(negedge clock)
    set_if_d_packet(2, 32'h03f301b3, PC);
    set_if_d_packet(1, 32'h00312023, PC+4);
    set_if_d_packet(0, 32'h00012203, PC+8);
    `SD PC = PC + 12;

    @(negedge clock)
    set_if_d_packet(2, 32'h10412023, PC);
    set_if_d_packet(1, 32'h00810113, PC+4);
    set_if_d_packet(0, 32'h00130313, PC+8);
    `SD PC = PC + 12;

    @(negedge clock)
    set_if_d_packet(2, 32'h01032293, PC);
    set_if_d_packet(1, 32'h00000013, PC+4);
    set_if_d_packet(0, 32'h00000513, PC+8);
    `SD PC = PC + 12;

    @(negedge clock)
    set_if_d_packet(2, 32'h000035b7, PC);
    set_if_d_packet(1, 32'h01a58593, PC+4);
    set_if_d_packet(0, 32'h15600613, PC+8);
    `SD PC = PC + 12;

    

    @(negedge clock)
    set_if_d_packet_invalid(2);
    set_if_d_packet_invalid(1);
    set_if_d_packet_invalid(0);
    @(negedge clock)
    @(negedge clock)
    @(negedge clock)
    @(negedge clock)
    #2;
    $display("@@@Pass: test finished");
    $finish;
end

endmodule




`endif // __PIPELINE_TEST_SV__