`timescale 1ns/100ps
`ifndef __PIPELINE_TEST_SV__
`define __PIPELINE_TEST_SV__

`define TEST_MODE 
`define DIS_DEBUG
`define CACHE_MODE

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
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_wb(int reg_index, int value);
import "DPI-C" function void print_inst(int inst_total);

/* import print rs */ 
import "DPI-C" function void print_select(int index,  int valid, int inst,  int npc, int fu_select, int op_select);

/* import simulate cache & memory */
import "DPI-C" function void mem_init();
import "DPI-C" function void mem_write(int addr, int data, int byte3, byte2, byte1, byte0);
import "DPI-C" function int mem_read(int addr);
import "DPI-C" function void mem_print();

module testbench;
logic clock, reset;
logic program_halt;
logic [2:0] inst_count;

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
logic [31:0][`PR-1:0] archi_map_display;

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
FU_COMPLETE_PACKET [2**`FU-1:0]   fu_packet_out_display;

// SQ
SQ_ENTRY_PACKET [0:2**`LSQ-1]  sq_display;
logic [`LSQ-1:0]               head_dis;
logic [`LSQ-1:0]               tail_dis;
logic [`LSQ:0]                 filled_num_dis;
SQ_ENTRY_PACKET [2**`LSQ-1:0]  older_stores;
logic [2**`LSQ-1:0]            older_stores_valid;
LOAD_SQ_PACKET [1:0]           load_sq_pckt_display;
logic [2:0]                    sq_stall_display;

// Freelist
logic [2:0]                    free_pr_valid_display;

// Complete
CDB_T_PACKET               cdb_t_display;
FU_COMPLETE_PACKET [2:0]    complete_pckt_in_display;
logic [2**`FU-1:0]          complete_stall_display;

//ROB
	ROB_ENTRY_PACKET [`ROBW-1:0]    rob_entries_display;
    logic       [`ROB-1:0]          head_display;
    logic       [`ROB-1:0]          tail_display;
    logic       [2:0]               rob_stall_display;

// PR
    logic [2**`PR-1:0][`XLEN-1:0] pr_display;

// Archi Map Table
    logic [2:0][`PR-1:0]       map_ar_pr;
    logic [2:0][4:0]           map_ar;
    logic [2:0]                RetireEN;

    logic [31:0][`PR-1:0]            fl_array_display;
    logic [4:0]                      fl_head_display;
    logic [4:0]                      fl_tail_display;
    logic                            fl_empty_display;
// Branch Predictor
    BP_ENTRY_PACKET [`BPW-1:0] bp_entries_display;
    logic       [2:0]                   predict_direction_display;
    logic       [2:0] [`XLEN-1:0]       predict_pc_display;

// Data cache
    logic [31:0] [63:0] cache_data_disp;
    logic [31:0] [7:0] cache_tags_disp;
    logic [31:0]       valids_disp;
    MHSRS_ENTRY_PACKET [`MHSRS_W-1:0] MHSRS_disp;
    logic [`MHSRS-1:0] head_pointer;
    logic [`MHSRS-1:0] issue_pointer;
    logic [`MHSRS-1:0] tail_pointer;
    logic [2:0]        sq_stall_cache_display;

// Retire
    ROB_ENTRY_PACKET [2:0]  retire_display;
    logic BPRecoverEN_display;
`endif

`ifdef DIS_DEBUG
IF_ID_PACKET [2:0]          if_d_packet_debug;
logic [2:0]                 dis_new_pr_en_out;
/* free list simulation */
logic [2:0]                 free_pr_valid_debug;
logic [2:0][`PR-1:0]        free_pr_debug;

logic [2:0]                 rob_stall_debug;
FU_STATE_PACKET             fu_ready_debug;
CDB_T_PACKET                cdb_t_debug;
`endif


SQ_ENTRY_PACKET [2:0]          cache_wb_sim;
logic [1:0][`XLEN-1:0]         cache_read_addr_sim;
logic [1:0][`XLEN-1:0]         cache_read_data_sim;
logic [1:0]                    cache_read_start_sim;

logic  [3:0]        Imem2proc_response;
logic [63:0]        Imem2proc_data;
logic  [3:0]        Imem2proc_tag;
logic [`XLEN-1:0]   proc2Imem_addr;
logic [1:0]         proc2Imem_command;
logic [63:0]        proc2Imem_data;

logic [63:0]        debug_counter;
EXCEPTION_CODE      pipeline_error_status;

mem memory(
    .clk(clock),                            // Memory clock
    .proc2mem_addr(proc2Imem_addr),         // <- pipeline.proc2mem_addr
    //support for memory model with byte level addressing
    // TODO: change when we have store and load
    .proc2mem_data(proc2Imem_data),         // write data, no need for this test 
`ifndef CACHE_MODE  
    .proc2mem_size(DOUBLE),                 //BYTE, HALF, WORD or DOUBLE, no need for this test
`endif
    .proc2mem_command(proc2Imem_command),   // `BUS_NONE `BUS_LOAD or `BUS_STORE
    
    .mem2proc_response(Imem2proc_response), // 0 = can't accept, other=tag of transaction
    .mem2proc_data(Imem2proc_data),         // data resulting from a load
    .mem2proc_tag(Imem2proc_tag)            // 0 = no value, other=tag of transaction
);

pipeline tbd(
    .clock(clock),
    .reset(reset),
    .mem2proc_response(Imem2proc_response),    // <- mem.mem2proc_response
	.mem2proc_data(Imem2proc_data),            // <- mem.mem2proc_data
	.mem2proc_tag(Imem2proc_tag),              // <- mem.mem2proc_tag
	
	.proc2mem_command(proc2Imem_command),      // -> mem.proc2Imem_command
	.proc2mem_addr(proc2Imem_addr),            // -> mem.proc2Imem_addr
    .proc2mem_data(proc2Imem_data),            // -> mem.proc2Imem_data
    .halt(program_halt),
    .inst_count(inst_count)
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
    , .archi_map_display(archi_map_display)
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
    // SQ
    , .sq_display(sq_display)
    , .head_dis(head_dis)
    , .tail_dis(tail_dis)
    , .filled_num_dis(filled_num_dis)
    , .older_stores(older_stores)
    , .older_stores_valid(older_stores_valid)
    , .load_sq_pckt_display(load_sq_pckt_display)
    , .sq_stall_display(sq_stall_display)
    // Complete
    , .cdb_t_display(cdb_t_display)
    , .wb_value_display(wb_value_display)
    , .complete_pckt_in_display(complete_pckt_in_display)
    , .complete_stall_display(complete_stall_display)
    // ROB
    , .rob_entries_display(rob_entries_display)
    , .head_display(head_display)
    , .tail_display(tail_display)
    , .rob_stall_display(rob_stall_display)
    // Freelist
    , .fl_array_display(fl_array_display)
    , .fl_head_display(fl_head_display)
    , .fl_tail_display(fl_tail_display)
    , .fl_empty_display(fl_empty_display)
    , .free_pr_valid_display(free_pr_valid_display)
    // PR
    , .pr_display(pr_display)
    // Archi Map Table
    , .map_ar_pr_disp(map_ar_pr)
    , .map_ar_disp(map_ar)
    , .RetireEN_disp(RetireEN)
    // Data Cache
    , .cache_data_disp(cache_data_disp)
    , .cache_tags_disp(cache_tags_disp)
    , .valids_disp(valids_disp)
    , .MHSRS_disp(MHSRS_disp)
    , .head_pointer(head_pointer)
    , .issue_pointer(issue_pointer)
    , .tail_pointer(tail_pointer)
    , .sq_stall_cache_display(sq_stall_cache_display)
    // Retire
    , .retire_display(retire_display)
    , .BPRecoverEN_display(BPRecoverEN_display)

    , .bp_entries_display(bp_entries_display)
    , .predict_direction_display(predict_direction_display)
    , .predict_pc_display(predict_pc_display)
`endif // TEST_MODE

`ifdef DIS_DEBUG
    , .if_d_packet_debug(if_d_packet_debug)
    , .dis_new_pr_en_out(dis_new_pr_en_out)
`endif
    , .cache_wb_sim(cache_wb_sim)
    , .cache_read_addr_sim(cache_read_addr_sim)
    , .cache_read_start_sim(cache_read_start_sim)
`ifdef CACHE_SIM


    , .cache_read_data_sim(cache_read_data_sim)

`endif
);

/* clock */
always begin
	#(`VERILOG_CLOCK_PERIOD/2.0);
	clock = ~clock;
end

int cycle_count; 
always @(posedge clock) begin
    if (reset) cycle_count = 0;
    else cycle_count++;
end

int inst_total;
logic halted;
always @(posedge clock) begin
    if (reset) halted <= `SD 0;
    else if (~halted) halted <= `SD program_halt;
    else halted <= `SD 1;
end
always @(negedge clock) begin
    if (reset) inst_total = 0;
    else if (~halted)
        inst_total = inst_total + inst_count[0] + inst_count[1] + inst_count[2];
end

/* halt */
task wait_until_halt;
		forever begin : wait_loop
			@(posedge program_halt);
			@(negedge clock);
            if (cycle_count > 50000) begin
                $display("NOOOOOOO!!!!!!");
                $finish;
            end
			if(program_halt) begin 
                @(negedge clock);
                disable wait_until_halt;
            end
		end
endtask

////////////////////////////////////////////////////////////
/////////////       SIMULATORS
///////////////////////////////////////////////////////////


`ifdef CACHE_SIM
// always @(posedge clock) begin
//     if (reset) begin
//         mem_init();
//     end
// end

// always @(posedge clock) begin
//     if (!reset) begin
//         mem_write(cache_wb_sim[0].addr, cache_wb_sim[0].data, cache_wb_sim[0].usebytes[3], cache_wb_sim[0].usebytes[2], cache_wb_sim[0].usebytes[1], cache_wb_sim[0].usebytes[0]);
//         mem_write(cache_wb_sim[1].addr, cache_wb_sim[1].data, cache_wb_sim[1].usebytes[3], cache_wb_sim[1].usebytes[2], cache_wb_sim[1].usebytes[1], cache_wb_sim[1].usebytes[0]);
//         mem_write(cache_wb_sim[2].addr, cache_wb_sim[2].data, cache_wb_sim[2].usebytes[3], cache_wb_sim[2].usebytes[2], cache_wb_sim[2].usebytes[1], cache_wb_sim[2].usebytes[0]);
//     end
// end

// always @(cache_read_addr_sim, cache_read_start_sim) begin
//     if (cache_read_start_sim[0]) cache_read_data_sim[0] = mem_read(cache_read_addr_sim[0]);
//     if (cache_read_start_sim[1]) cache_read_data_sim[1] = mem_read(cache_read_addr_sim[1]);
// end

`endif
// /* free list simulator */
// always @(posedge clock) begin
//     if (reset) begin
//         fl_init();
//     end else begin
//         fl_pop(dis_new_pr_en_out);
//     end
// end
// always @(dis_new_pr_en_out, clock) begin
//     `SD;
//     if (!reset) begin
//         free_pr_valid_debug = fl_new_pr_valid();
//         free_pr_debug[2] = fl_new_pr2(dis_new_pr_en_out);
//         free_pr_debug[1] = fl_new_pr1(dis_new_pr_en_out);
//         free_pr_debug[0] = fl_new_pr0(dis_new_pr_en_out);
//     end
// end

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
        //print_inst(inst_total);
        // $display("Cycle: %d", cycle_count);
        print_retire_wb();
        show_retire_store;
        if (cycle_count == 1 ) $dumpon;
        if (cycle_count == 500) $dumpoff;
        if(cycle_count > 0 && cycle_count < 500) begin
        //     // $dumpvars;
            // if (cache_read_start_sim[0]) $display("Cache Read: %d", cache_read_addr_sim[0]);
            // if (cache_read_start_sim[1]) $display("Cache Read: %d", cache_read_addr_sim[1]);
        
        // //   $display("Cycle: %d inst_count: %d, cum: %d", cycle_count, inst_count, inst_total);
        // show_dcache;
        // show_MHSRS;
        // // $display();
        // // $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        // // $display();
        
        // print_pipeline;
        // print_alu;
        // // show_fu_stat;
        // // if(cycle_count > 660 && cycle_count < 700) print_is_fifo;
        // // show_sq;
        // // show_sq_age;
        // // show_cdb;
        // // show_rs_in;
        // show_rs_table;
        // // show_complete;
        // show_rs_table;
        // show_rob_table;
        // $display(" dis_stall: %b, sq_stall: %b, rob_stall: %b, rs_stall: %b, free_reg_valid: %b", dis_stall_display, sq_stall_display, rob_stall_display, rs_stall_display, free_pr_valid_display);
        // $display( "sq cache stall: %b", sq_stall_cache_display);
        // // show_rs_out;
        // show_bp_entry;
        end
    end else
        print_header("### Reset ###\n");
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
        $display("dest_pr:%d reg1_pr:%d reg1_ready: %b reg2_pr:%d reg2_ready %b rob_entry:%d", rs_entries_display[i].dest_pr, rs_entries_display[i].reg1_pr, rs_entries_display[i].reg1_ready, rs_entries_display[i].reg2_pr, rs_entries_display[i].reg2_ready, rs_entries_display[i].rob_entry);
    end
    $display("structual_stall:%b", rs_stall_display);
endtask; // show_rs_table


task show_fu_stat;
    $display("fu ready: %8b", fu_ready_display);
    $display("fu finish: %8b", fu_finish_display);
    $display("| valid | halt | take_branch | target_pc | dest_pr | dest_value | rob_entry |");
    for(int i=0; i<2**`FU; i++) begin
        $display("| %1d | %1d | %1d | %4h | %2d | %d | %2d |", 
                fu_packet_out_display[i].valid, fu_packet_out_display[i].halt, fu_packet_out_display[i].if_take_branch,
                fu_packet_out_display[i].target_pc, fu_packet_out_display[i].dest_pr, fu_packet_out_display[i].dest_value,
                fu_packet_out_display[i].rob_entry);
    end
endtask; 

task show_sq;
    $display("HEAD: %d, Tail: %d, Filled num: %d", head_dis, tail_dis, filled_num_dis);
    $display(" |ready|   addr   |usebytes|   data   |");
    for(int i=0; i<2**`LSQ; i++) begin
        $display("%1d|  %d  | %8h |  %4b  | %8h |", i, sq_display[i].ready, sq_display[i].addr, sq_display[i].usebytes, sq_display[i].data);
    end
endtask

task show_sq_age;
    $display("##### older stores, tail_pos at %d", load_sq_pckt_display[0].tail_pos);
    $display(" |valid|ready|   addr   |usebytes|   data   |");
    for(int i=0; i<2**`LSQ; i++) begin
        $display("%1d|  %d  |  %d  | %8h |  %4b  | %8h |", i, older_stores_valid[i], older_stores[i].ready, older_stores[i].addr, older_stores[i].usebytes, older_stores[i].data);
    end
endtask


task show_complete;
    $display("fu ready: %8b", fu_ready_display);
    $display("complete stall: %8b", complete_stall_display);
    $display("======== Completing =============");
    $display("| valid | halt | take_branch | target_pc | dest_pr | dest_value | rob_entry |");
    for(int i=0; i<3; i++) begin
        $display("| %1d | %1d | %1d | %4h | %2d | %d | %2d |", 
                complete_pckt_in_display[i].valid, complete_pckt_in_display[i].halt, complete_pckt_in_display[i].if_take_branch,
                complete_pckt_in_display[i].target_pc, complete_pckt_in_display[i].dest_pr, complete_pckt_in_display[i].dest_value,
                complete_pckt_in_display[i].rob_entry);
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
        $display("%d| valid: %d  Tnew: %d  Told: %d  arch_reg: %d  completed: %b  precise_state: %b  target_pc: %3d is_store: %b pc: %d", i, rob_entries_display[i].valid, rob_entries_display[i].Tnew, rob_entries_display[i].Told, rob_entries_display[i].arch_reg, rob_entries_display[i].completed, rob_entries_display[i].precise_state_need, rob_entries_display[i].target_pc, rob_entries_display[i].is_store, rob_entries_display[i].PC, rob_entries_display[i].predict_direction, rob_entries_display[i].predict_pc);
    end
    $display("head:%d tail:%d", head_display, tail_display);
    $display("structual_stall:%b", rob_stall_display);
endtask; // show_rs_table


task print_pipeline;
    $display(" ============ Cycle %d ==============", cycle_count);
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
        print_stage("|", retire_display[i].inst, retire_display[i].PC, inst_count[i]);
        print_header("|\n");
    end
    for(int i=2; i>=0; i--) begin
        `ifdef DIS_DEBUG
        /* IF debug */
        $display("%5d", dis_in_display[i].predict_pc);
        `endif
    end
endtask

task print_final;
    $display("+++++++++++++++++++++ Result ++++++++++++++++++++++");
    $display("Arch Map Table");
    $display("|  AR  |  PR  |");
    for(int i=0; i<32; i++)begin
        $display("|  %2d  |  %2d  |", i, archi_map_display[i]);
    end
    $display("Physical Register");
    $display("|  PR  |  value  |");
    for(int i=0; i<64; i++)begin
        $display("|  %2d  |  %10d  |", i, pr_display[i]);
    end
    `ifdef CACHE_SIM
    mem_print();
    `endif
endtask

task print_retire_wb;
    for(int i=2; i>=0; i--) begin;
        if (inst_count[i]) begin
            print_stage("\n|", retire_display[i].inst, retire_display[i].PC+4, inst_count[i]);
            if (map_ar[i] != 0 && RetireEN[i]==1'b1) print_wb(map_ar[i], $signed(pr_display[map_ar_pr[i]]));
            else print_header("\n");
        end
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

task show_freelist_table;
    for(int i=31; i>=0; i--) begin  // For RS entry, it allocates from 15-0
        $display("Index: %d        PR: %5d", i, fl_array_display[i]);
    end
    $display("head:%d tail:%d empty:%d", fl_head_display, fl_tail_display, fl_empty_display);
endtask; // show_rs_table

task show_mpt_entry;
    begin
        $display("=====   Maptable Entry   =====");
        $display("| AR |   PR   | ready |");
        for (int i = 0; i < 32; i++) begin
            $display("| %2d |   %d   |   %b  |", i, map_array_display[i], ready_array_display[i]);
        end
        $display(" ");
    end
endtask

task print_cpi;
    real cpi;
    begin
        cpi = (cycle_count) / (inst_total -1.0);
        $display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
                    cycle_count, inst_total - 1, cpi);
        $display("@@  %4.2f ns total time to execute\n@@\n",
                    cycle_count*`VERILOG_CLOCK_PERIOD);
    end
endtask

task show_dcache;
    begin
        $display("=====   Cache ram   =====");
        $display("|  Entry(idx) |      Tag |             data |");
        for (int i=0; i<32; ++i) begin
            $display("| %d | %b | %h |", i, cache_tags_disp[i], cache_data_disp[i]);
        end
        $display("-------------------------------------------------");
    end
endtask

task show_MHSRS;
    begin
        $display("=====   MHSRS   =====");
        $display("head: %d, issue: %d, tail: %d", head_pointer, issue_pointer, tail_pointer);
        $display("|         No. |                              addr  |command|mem_tag|left_or_right|            data |issued| usedbytes | dirty |");
        for (int i = 0; i < 16; i++) begin
            $display("| %d |  %b  |     %d |    %d |           %b | %h | %b | %b |  %b |", i, MHSRS_disp[i].addr, MHSRS_disp[i].command, MHSRS_disp[i].mem_tag, MHSRS_disp[i].left_or_right, MHSRS_disp[i].data, MHSRS_disp[i].issued, MHSRS_disp[i].usebytes, MHSRS_disp[i].dirty);
        end
        $display("----------------------------------------------------------------- ");
    end
endtask

task show_retire_store;
    for(int i=0; i<3; i++) begin
        if (cache_wb_sim[i].ready)
        $display("MEM[%d]=%d, use%b", cache_wb_sim[i].addr, cache_wb_sim[i].data, cache_wb_sim[i].usebytes );
    end
endtask

// always @(posedge clock) begin
//     int total_pr;
//     total_pr=0;
//     for (int i=0; i< 32; i++) begin
//         total_pr += fl_array_display[i];
//         total_pr += archi_map_display[i];
//     end
//         $display("CYCLE: %d, Total PR: %d ", cycle_count, total_pr);
//         if (total_pr != 2016) $display("ERRRRRRRRRRRRRRRRRRORRRRRR missing PR");
// end



/*
task show_Dcache_input;
    begin
        $display("=====   Input   =====");
        $display("m_response: %d,  m_data: %h,  m_tag: %d", Ctlr2proc_response, Ctlr2proc_data, Ctlr2proc_tag);
        $display("Load_input");
        $display("| No.|                         addr_in |start|");
        for (int i=1; i>=0; --i) begin
            $display("| %1d: | %b | %b |", i, ld_addr_in[i], ld_start[i]);
        end
        $display("----------");
        $display("Store_input");
        $display("|No.| ready |usebytes|                             addr |     data |");
        for (int i=2; i>=0; --i) begin
            $display("| %1d |     %b |   %b | %b | %h |", i, sq_in[i].ready, sq_in[i].usebytes, sq_in[i].addr, sq_in[i].data);
        end
        $display("----------------------------------------------------------------- ");
    end
endtask

task show_Dcache_output;
    begin
        $display("=====   Output   =====");
        $display("m_command: %d,  m_addr: %b,  m_data: %h", dcache2ctlr_command, dcache2ctlr_addr, dcache2ctlr_data);
        $display("Load_output");
        $display("| No.| is_hit |  ld_data |");
        for (int i=1; i>=0; --i) begin
            $display("| %1d: |      %b | %h |        %b |", i, is_hit[i], ld_data[i]);
        end
        $display("---------------------");
        $display("broadcast_fu : %d ,   broadcast_data : %h", broadcast_fu, broadcast_data);
        $display("SQ stall: %b", sq_stall);
    end
endtask
*/



task show_bp_entry;
    begin
        $display("=====   Branch Predictor Entry   =====");
        for(int i=`BPW - 1; i>=0; i--) begin
            $display("Index: %2d  Valid: %2d  Tag: %5d  Direction: %1d  Target_pc: %5d", i, bp_entries_display[i].valid, bp_entries_display[i].tag, bp_entries_display[i].direction, bp_entries_display[i].target_pc);
        end
        for (int i = 2; i >= 0; i--) begin
            $display("Index: %1d Direction: %b   PC: %5d ",i, dis_in_display[i].predict_direction, dis_in_display[i].predict_pc);
        end
    end
endtask

//////////////////////////////////////////////////////////
///////////////         SET      
/////////////////////////////////////////////////////////

// task set_if_d_packet;
//     input int i;
//     input INST inst;
//     input [`XLEN-1:0] pc;
//     if_d_packet_debug[i].inst = inst;
//     if_d_packet_debug[i].PC = pc;
//     if_d_packet_debug[i].NPC = pc+4;
//     if_d_packet_debug[i].valid = 1;
// endtask

// task set_if_d_packet_invalid;
//     input int i;
//     if_d_packet_debug[i].valid = 0;
// endtask

// int PC; 
initial begin
    $dumpvars;
    $dumpoff;
    clock = 1'b0;
    reset = 1'b1;
    cycle_count = 0;
    // rob_stall_debug = 3'b000;
    // fu_ready_debug = 8'b00011111;
    // cdb_t_debug = {`RS'b0, `RS'b0, `RS'b0};
    // PC = 0;
    @(posedge clock)
    $readmemh("program.mem", memory.unified_memory);
    @(posedge clock)
    #2 reset = 1'b0;
    
    @(negedge clock);
    for (int i = 0; i < 1000; i++) begin
        if (halted) begin
            $display("Halt on WFI");
            print_final;
            print_cpi;
            $finish;
        end
    @(negedge clock);
    end
    //wait_until_halt;

    #2;
    print_final;
    // $display("@@  %t : System halted\n@@", $realtime);
    // $display("@@");
    // $display("@@@ System halted on WFI instruction");
    // $display("@@@");
    print_cpi;
    $finish;
end

endmodule




`endif // __PIPELINE_TEST_SV__