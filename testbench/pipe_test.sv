`timescale 1ns/100ps
`ifndef __PIPE_TEST_SV__
`define __PIPE_TEST_SV__

`define TEST_MODE 
`define DIS_DEBUG

/* import freelist simulator */
import "DPI-C" function void fl_init();
import "DPI-C" function int fl_new_pr_valid();
import "DPI-C" function int fl_new_pr2();
import "DPI-C" function int fl_new_pr1();
import "DPI-C" function int fl_new_pr0();
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
IF_ID_PACKET [2:0]         if_d_packet_display;

// ID stage output
RS_IN_PACKET [2:0]         dis_rs_packet_display;
ROB_ENTRY_PACKET [2:0]     dis_rob_packet_display;
logic [2:0]                dis_stall_display;

// RS
RS_IN_PACKET [`RSW-1:0]    rs_entries_display;
RS_S_PACKET [2:0]          rs_is_packet_display;
logic [2:0]                rs_stall_display;

`endif

`ifdef DIS_DEBUG
IF_ID_PACKET [2:0]          if_d_packet_debug;
logic [2:0]                 dis_new_pr_en_out;
/* free list simulation */
logic [2:0]                 free_pr_valid_debug;
logic [2:0][`PR-1:0]        free_pr_debug;

/* maptable simulation */
logic [2:0] [4:0]           maptable_lookup_reg1_ar_out;
logic [2:0] [4:0]           maptable_lookup_reg2_ar_out;
logic [2:0] [4:0]           maptable_allocate_ar_out;
logic [2:0] [`PR-1:0]       maptable_allocate_pr_out;
logic [2:0][`PR-1:0]        maptable_old_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg1_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg2_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg1_ready_debug;
logic [2:0][`PR-1:0]        maptable_reg2_ready_debug;

logic [2:0]                 rob_stall_debug;
FU_STATE_PACKET             fu_ready_debug;
CDB_T_PACKET                cdb_t_debug;
`endif

pipeline tbd(
    .clock(clock),
    .reset(reset)
`ifdef TEST_MODE
    // IF to Dispatch
    , .if_d_packet_display(if_d_packet_display)
    // ID stage output
    , .dis_rs_packet_display(dis_rs_packet_display)
    , .dis_rob_packet_display(dis_rob_packet_display)
    , .dis_stall_display(dis_stall_display)
    // RS
    , .rs_entries_display(rs_entries_display)
    , .rs_is_packet_display(rs_is_packet_display)
    , .rs_stall_display(rs_stall_display)
`endif // TEST_MODE

`ifdef DIS_DEBUG
    , .if_d_packet_debug(if_d_packet_debug)
    , .dis_new_pr_en_out(dis_new_pr_en_out)
    /* free list simulation */
    , .free_pr_valid_debug(free_pr_valid_debug)
    , .free_pr_debug(free_pr_debug)
    /* maptable simulation */
    , .maptable_lookup_reg1_ar_out(maptable_lookup_reg1_ar_out)
    , .maptable_lookup_reg2_ar_out(maptable_lookup_reg2_ar_out)
    , .maptable_allocate_ar_out(maptable_allocate_ar_out)
    , .maptable_allocate_pr_out(maptable_allocate_pr_out)
    , .maptable_old_pr_debug(maptable_old_pr_debug)
    , .maptable_reg1_pr_debug(maptable_reg1_pr_debug)
    , .maptable_reg2_pr_debug(maptable_reg2_pr_debug)
    , .maptable_reg1_ready_debug(maptable_reg1_ready_debug)
    , .maptable_reg2_ready_debug(maptable_reg2_ready_debug)
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
always @(negedge clock) begin
    free_pr_valid_debug = fl_new_pr_valid();
    free_pr_debug[2] = fl_new_pr2();
    free_pr_debug[1] = fl_new_pr1();
    free_pr_debug[0] = fl_new_pr0();
end

/* map table simulator */
always @(posedge clock) begin
    if (reset) begin
        mt_init();
    end else begin
        mt_map(maptable_allocate_ar_out, maptable_allocate_pr_out);
    end
end
always @(negedge clock) begin
    maptable_old_pr_debug = mt_look_up(maptable_allocate_ar_out);
    maptable_reg1_pr_debug = mt_look_up(maptable_lookup_reg1_ar_out);
    maptable_reg2_pr_debug = mt_look_up(maptable_lookup_reg2_ar_out);
    maptable_reg1_ready_debug = mt_look_up_ready(maptable_lookup_reg1_ar_out);
    maptable_reg2_ready_debug = mt_look_up_ready(maptable_lookup_reg2_ar_out);
end



//////////////////////////////////////////////////////////////
//////////////                  DISPLAY
/////////////////////////////////////////////////////////////
always @(negedge clock) begin
    if (!reset)  begin
        print_pipeline;
        show_rs_in;
        show_rs_table;
        show_rs_out;
    end
end


task show_rs_in;
    begin
        $display("=====   RS_IN Packet   =====");
        $display("| WAY |     inst    | fu_sel | op_sel  |");
        for (int i=0; i < 3; i++) begin
            print_select(i, dis_rs_packet_display[i].valid, dis_rs_packet_display[i].fu_sel, dis_rs_packet_display[i].NPC, dis_rs_packet_display[i].fu_sel, dis_rs_packet_display[i].op_sel);
        end
        $display("| WAY | dest_pr | reg1_pr | reg1_ready | reg2_pr | reg2_ready |");
        for (int i=0; i < 3; i++) begin
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
        for (int i=0; i < 3; i++) begin
            print_select(i, rs_is_packet_display[i].valid, rs_is_packet_display[i].inst, rs_is_packet_display[i].NPC, rs_is_packet_display[i].fu_sel, rs_is_packet_display[i].op_sel);
        end
        $display("| WAY | valid |    PC    | dest_pr | reg1_pr | reg2_pr |       inst | halt |");
        for (int i=0; i < 3; i++) begin
            $display("|  %1d  |     %b | %4h |      %2d |      %2d |     %2d  |",
                i, rs_is_packet_display[i].valid, rs_is_packet_display[i].PC, rs_is_packet_display[i].dest_pr, rs_is_packet_display[i].reg1_pr, rs_is_packet_display[i].reg2_pr, rs_is_packet_display[i].inst, rs_is_packet_display[i].halt
            );
        end
    end
endtask

task show_rs_table;
    for(int i=2**`RS-1; i>=0; i--) begin  // For RS entry, it allocates from 15-0
        print_stage("*", rs_entries_display[i].fu_sel, rs_entries_display[i].NPC[31:0], rs_entries_display[i].valid);
        $display("dest_pr:%d reg1_pr:%d reg1_ready: %b reg2_pr:%d reg2_ready %b", rs_entries_display[i].dest_pr, rs_entries_display[i].reg1_pr, rs_entries_display[i].reg1_ready, rs_entries_display[i].reg2_pr, rs_entries_display[i].reg2_ready);
    end
    $display("structual_stall:%b", rs_stall_display);
endtask; // show_rs_table


task print_pipeline;
    print_cycles();
    print_header("\n |     IF      |     DIS    |     IS      |\n");
    for(int i=2; i>=0; i--) begin
        print_num(i);
        /* if_d packet */
        print_stage("|", if_d_packet_display[i].inst, if_d_packet_display[i].NPC, if_d_packet_display[i].valid);
        /* dispatch to rs */
        print_stage("|", dis_rs_packet_display[i].inst, dis_rs_packet_display[i].NPC, dis_rs_packet_display[i].valid);
        print_header("\n");
    end
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


initial begin
    $dumpvars;
    clock = 1'b0;
    reset = 1'b1;
    rob_stall_debug = 3'b000;
    fu_ready_debug = 8'hff;
    cdb_t_debug = {`RS'b0, `RS'b0, `RS'b0};
    @(posedge clock)
    
    @(posedge clock)
    reset = 1'b0;
    set_if_d_packet(2, 32'h40418133, 0);
    set_if_d_packet(1, 32'h40418133, 4);
    set_if_d_packet(0, 32'h40418133, 8);

    @(posedge clock)
    set_if_d_packet(2, 32'h40418133, 12);
    set_if_d_packet(1, 32'h40418133, 16);
    set_if_d_packet(0, 32'h40418133, 20);

    @(posedge clock)
    set_if_d_packet(2, 32'h40418133, 24);
    set_if_d_packet(1, 32'h40418133, 28);
    set_if_d_packet(0, 32'h40418133, 32);

    @(posedge clock)
    set_if_d_packet(2, 32'h40418133, 36);
    set_if_d_packet(1, 32'h40418133, 40);
    set_if_d_packet(0, 32'h40418133, 44);
    

    
    
    $display("@@@Pass: test finished");
    $finish;
end

endmodule




`endif // __PIPE_TEST_SV__