/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.v                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the stages of the    //
//                 RS and components                                   //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`define TEST_MODE
`define DIS_DEBUG

`timescale 1ns/100ps

module pipeline(
	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr      // Address sent to memory
	// output logic [63:0] proc2mem_data,      // Data sent to memory
	// output MEM_SIZE proc2mem_size,          // data size sent to memory

	// output logic [3:0]  pipeline_completed_insts,
	// output EXCEPTION_CODE   pipeline_error_status,
	// output logic [4:0]  pipeline_commit_wr_idx,
	// output logic [`XLEN-1:0] pipeline_commit_wr_data,
	// output logic        pipeline_commit_wr_en,
	// output logic [`XLEN-1:0] pipeline_commit_NPC

`ifdef TEST_MODE
    // IF to Dispatch 
    
    
    // ID 
    , output IF_ID_PACKET [2:0]         dis_in_display
    , output ROB_ENTRY_PACKET [2:0]     dis_rob_packet_display
    , output logic [2:0]                dis_stall_display

    // RS
    , output RS_IN_PACKET [2:0]         dis_rs_packet_display
    , output RS_IN_PACKET [`RSW-1:0]    rs_entries_display
    , output RS_S_PACKET [2:0]          rs_out_display
    , output logic [2:0]                rs_stall_display

    // IS
    , output RS_S_PACKET [2:0]          is_in_display
    , output FU_FIFO_PACKET             fu_fifo_stall_display
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] alu_fifo_display
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] mult_fifo_display
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] br_fifo_display
    , output ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] ls_fifo_display

    // Maptable
    , output logic [31:0][`PR-1:0] map_array_disp
    , output logic [31:0] ready_array_disp
    , output logic [31:0][`PR-1:0] archi_map_display

    // FU
    , output ISSUE_FU_PACKET [2**`FU-1:0] fu_in_display
    , output FU_STATE_PACKET            fu_ready_display
    , output FU_STATE_PACKET            fu_finish_display
    , output FU_COMPLETE_PACKET [2**`FU-1:0]         fu_packet_out_display
    
    // Complete
    , output CDB_T_PACKET               cdb_t_display
    , output FU_COMPLETE_PACKET [2:0]   complete_pckt_in_display
    , output [2:0][`XLEN-1:0]           wb_value_display
    , output [2**`FU-1:0]               complete_stall_display

    // ROB
    , output ROB_ENTRY_PACKET [`ROBW-1:0]   rob_entries_display
	, output [`ROB-1:0]                     head_display
	, output [`ROB-1:0]                     tail_display

    // Freelist
    , output [31:0][`PR-1:0]            fl_array_display
    , output [4:0]                      fl_head_display
    , output [4:0]                      fl_tail_display
    , output                            fl_empty_display

    // PR
    , output logic [2**`PR-1:0][`XLEN-1:0] pr_display

    // Archi Map Table
    , output logic [2:0][`PR-1:0]       map_ar_pr_disp
    , output logic [2:0][4:0]           map_ar_disp
`endif

`ifdef DIS_DEBUG
    , output IF_ID_PACKET [2:0]          if_d_packet_debug
    , output logic [2:0]                dis_new_pr_en_out
    /* free list simulation */
    // , input [2:0]                       free_pr_valid_debug
    // , input [2:0][`PR-1:0]              free_pr_debug

    /* maptable simulation */
    /*
    , output logic [2:0] [4:0]          maptable_lookup_reg1_ar_out
    , output logic [2:0] [4:0]          maptable_lookup_reg2_ar_out
    , output logic [2:0] [4:0]          maptable_allocate_ar_out
    , output logic [2:0] [`PR-1:0]      maptable_allocate_pr_out
    , input [2:0][`PR-1:0]              maptable_old_pr_debug
    , input [2:0][`PR-1:0]              maptable_reg1_pr_debug
    , input [2:0][`PR-1:0]              maptable_reg2_pr_debug
    , input [2:0]                       maptable_reg1_ready_debug
    , input [2:0]                       maptable_reg2_ready_debug
    */

    // , input [2:0]                       rob_stall_debug
    // , input FU_STATE_PACKET             fu_ready_debug
    // , input CDB_T_PACKET                cdb_t_debug
`endif
    
);
/* Fetch Stage */
IF_ID_PACKET [2:0]           if_d_packet;
logic    [2:0][31:0]         cache_data;
logic    [2:0]               cache_valid;

logic    [1:0]               fetch_shift;
logic    [2:0][`XLEN-1:0]    proc2Icache_addr;

logic    [2:0][63:0]         cachemem_data;
logic    [2:0]               cachemem_valid;
logic    [2:0][4:0]          current_index;
logic    [2:0][7:0]          current_tag;
logic    [4:0]               wr_index;
logic    [7:0]               wr_tag;
logic                        data_write_enable;

/* Dispatch Stage */
// Inputs
IF_ID_PACKET [2:0]      dis_packet_in; 
// outputs
RS_IN_PACKET [2:0]      dis_rs_packet;
ROB_ENTRY_PACKET [2:0]  dis_rob_packet;
logic [2:0]             dis_new_pr_en;
logic [2:0]             dis_stall; // if 1, corresponding inst stall due to structural hazard
// go to maptable
logic [2:0][`PR-1:0]	maptable_allocate_pr;
logic [2:0][4:0]		maptable_allocate_ar;
logic [2:0][4:0]		maptable_lookup_reg1_ar;
logic [2:0][4:0]		maptable_lookup_reg2_ar;

/* Reservation Station */
logic                   rs_reset;
logic [2:0]             rs_stall;
RS_S_PACKET [2:0]       rs_is_packet;

/* free list */
logic [2:0]             free_pr_valid;
logic [2:0][`PR-1:0]    free_pr;
logic [2:0]		        DispatchEN;
logic [2:0] 		    RetireEN;
logic [2:0][`PR-1:0] 	RetireReg;
logic [`ROB-1:0] 	    BPRecoverHead;
logic [`ROB-1:0] 	    FreelistHead;
logic [4:0]             fl_distance;

/* map table */
logic BPRecoverEN;
logic [31:0][`PR-1:0] 	archi_maptable;
logic [2:0][`PR-1:0]    maptable_old_pr;
logic [2:0][`PR-1:0]    maptable_reg1_pr;
logic [2:0][`PR-1:0]    maptable_reg2_pr;
logic [2:0]             maptable_reg1_ready;
logic [2:0]             maptable_reg2_ready;
logic [31:0][`PR-1:0] 	archi_maptable_out;

//assign BPRecoverEN = 1'b0;
//assign archi_maptable = 0;

/* arch map table */
logic 		    [2:0][`PR-1:0] 	Tnew_in;
logic 		    [2:0][4:0] 		Retire_AR;

/* Issue stage */
RS_S_PACKET [2:0]       is_packet_in;
ISSUE_FU_PACKET [2**`FU-1:0] is_fu_packet;
FU_FIFO_PACKET          fu_fifo_stall;
logic [2:0][`PR-1:0]    is_pr1_idx, is_pr2_idx; // access pr


/* physical register */
logic [2:0][`XLEN-1:0]  pr1_read, pr2_read;
// TODO: plug in pr
// assign pr1_read = 0;
// assign pr2_read = 0;


/* Reorder Buffer */
logic [2:0][`ROB-1:0]           new_rob_index;  // ROB.dispatch_index <-> dispatch.rob_index
//assign new_rob_index = 5;
//ROB_ENTRY_PACKET[2:0]           rob_in;       // rob_in = dis_rob_packet
logic       [2:0]               complete_valid;
logic       [2:0][`ROB-1:0]     complete_entry;  // which ROB entry is done
ROB_ENTRY_PACKET [2:0]          rob_retire_entry;  // which ENTRY to be retired
logic       [2:0]               rob_stall;
ROB_ENTRY_PACKET [`ROBW-1:0]    rob_entries;
ROB_ENTRY_PACKET [`ROBW-1:0]    rob_debug;
logic       [`ROB-1:0]          head;
logic       [`ROB-1:0]          tail;

/* functional unit */
FU_STATE_PACKET                     fu_ready;
ISSUE_FU_PACKET     [2**`FU-1:0]    fu_packet_in;
FU_STATE_PACKET                     complete_stall;


/* Complete Stage */
CDB_T_PACKET                    cdb_t;
FU_COMPLETE_PACKET [2**`FU-1:0]    fu_c_in;
FU_STATE_PACKET                 fu_finish;
logic       [2:0][`XLEN-1:0]    wb_value;
logic       [2:0]               precise_state_valid;
logic       [2:0][`XLEN-1:0]    target_pc;

/* Retire Stage */
logic       [2:0][`PR-1:0]			map_ar_pr;
logic       [2:0][4:0]			    map_ar;
logic       [31:0][`PR-1:0]         recover_maptable;
logic       [`XLEN-1:0]             fetch_pc;
//logic 		[2:0] 			        RetireEN;     
//ROB_ENTRY_PACKET [2:0]              retire_entry;

/////////////////////////////////////////////////////////
//          DEBUG  IN/OUTPUT                
////////////////////////////////////////////////////////
`ifdef TEST_MODE
    
// ID stage output
assign dis_in_display = dis_packet_in;
assign dis_rob_packet_display = dis_rob_packet;
assign dis_stall_display = dis_stall;

// RS
assign dis_rs_packet_display = dis_rs_packet;
assign rs_stall_display = rs_stall;
assign rs_out_display = rs_is_packet;

// IS
assign is_in_display = is_packet_in;
assign fu_in_display = fu_packet_in;
assign fu_fifo_stall_display = fu_fifo_stall;

// FU
assign fu_ready_display = fu_ready;
assign fu_finish_display = fu_finish;
assign fu_packet_out_display = fu_c_in;

// Maptable
assign archi_map_display = archi_maptable_out;

// Complete
assign cdb_t_display = cdb_t;
assign wb_value_display = wb_value;
assign complete_stall_display = complete_stall;

// Archi Map Table
assign map_ar_pr_disp = map_ar_pr;
assign map_ar_disp = map_ar;

// Retire stage


`endif

`ifdef DIS_DEBUG
assign if_d_packet_debug = if_d_packet; 
assign dis_new_pr_en_out = dis_new_pr_en;
/* free list simulation */
// assign free_pr_valid = free_pr_valid_debug;
// assign free_pr = free_pr_debug;
/* maptable simulation */
/*
assign maptable_lookup_reg1_ar_out = maptable_lookup_reg1_ar;
assign maptable_lookup_reg2_ar_out = maptable_lookup_reg2_ar;
assign maptable_allocate_ar_out = maptable_allocate_ar;
assign maptable_allocate_pr_out = maptable_allocate_pr;
assign maptable_old_pr = maptable_old_pr_debug;
assign maptable_reg1_pr = maptable_reg1_pr_debug;
assign maptable_reg2_pr = maptable_reg2_pr_debug;
assign maptable_reg1_ready = maptable_reg1_ready_debug;
assign maptable_reg2_ready = maptable_reg2_ready_debug;
assign fu_ready = fu_ready_debug;
*/
//assign rob_stall = rob_stall_debug;  
//assign cdb_t = cdb_t_debug;
`endif

//////////////////////////////////////////////////
//                                              //
//                  Fetch Stage                 //
//                                              //
//////////////////////////////////////////////////

cache ic_mem(
    .clock(clock),
    .reset(reset),
    .wr1_en(data_write_enable),     // <- icache.data_write_enable
    .wr1_idx(wr_index),             // <- icache.wr_index
    .rd1_idx(current_index),        // <- icache.current_index
    .wr1_tag(wr_tag),               // <- icache.wr_tag
    .rd1_tag(current_tag),          // <- icache.current_tag
    .wr1_data(mem2proc_data),       // <- mem.mem2proc_data

    .rd1_data(cachemem_data),       // -> icache.cachemem_data
    .rd1_valid(cachemem_valid)      // -> icache.mcachemem_valid
);

icache ic(
    .clock(clock),
    .reset(reset),
    .Imem2proc_response(mem2proc_response), // <- mem.mem2proc_response
    .Imem2proc_data(mem2proc_data),         // <- mem.mem2proc_data
    .Imem2proc_tag(mem2proc_tag),           // <- mem2proc_tag

    .shift(fetch_shift),                    // <- fetch.shift
    .proc2Icache_addr(proc2Icache_addr),    // <- fetch.proc2Icache_addr
    .cachemem_data(cachemem_data),          // <- cache.rd1_data
    .cachemem_valid(cachemem_valid),        // <- cache.rd1_valid

    .proc2Imem_command(proc2mem_command),   // -> mem.proc2mem_command
    .proc2Imem_addr(proc2mem_addr),         // -> mem.proc2mem_addr

    .Icache_data_out(cache_data),           // -> fetch.cache_data
    .Icache_valid_out(cache_valid),         // -> fetch.cache_valid

    .current_index(current_index),          // -> cache.rd1_idx
    .current_tag(current_tag),              // -> cache.rd1_tag
    .wr_index(wr_index),                    // -> cache.wr_idx
    .wr_tag(wr_tag),                        // -> cache.wr_tag
    .data_write_enable(data_write_enable)   // -> cache.wr1_en
);

fetch_stage fetch(
    .clock(clock), 
    .reset(reset), 
    .cache_data(cache_data),                // <- icache.Icache_data_out
    .cache_valid(cache_valid),              // <- icache.Icache_valid_out
    .take_branch(BPRecoverEN),              // <- retire.BPRecoverEN
    .target_pc(fetch_pc),                   // <- retire.target_pc
    
    .shift(fetch_shift),                    // -> icache.shift
    .proc2Icache_addr(proc2Icache_addr),    // -> icache.proc2Icache_addr
    .if_packet_out(if_d_packet)             // -> dispatch
);

//////////////////////////////////////////////////
//                                              //
//                 IF-D-Register                //
//                                              //
//////////////////////////////////////////////////
IF_ID_PACKET [2:0]      dis_packet_in_next;
always_comb begin
    priority case(dis_stall)
        3'b000: dis_packet_in_next = if_d_packet;
        3'b001: begin
            dis_packet_in_next[2] = dis_packet_in[0];
            dis_packet_in_next[1:0] = if_d_packet[2:1];
        end
        3'b011: begin
            dis_packet_in_next[2:1] = dis_packet_in[1:0];
            dis_packet_in_next[0] = if_d_packet[2];
        end
        3'b111: begin
            dis_packet_in_next = dis_packet_in;
        end
    endcase
end


always_ff @(posedge clock) begin
    if(reset) begin
        for(int i=0; i<3; i++) begin
            dis_packet_in[i].valid <= `SD 0;
            dis_packet_in[i].inst <= `SD `NOP;
            dis_packet_in[i].NPC <= `SD 0;
            dis_packet_in[i].PC <= `SD 0;
        end
    end else dis_packet_in <= `SD dis_packet_in_next;
end




//////////////////////////////////////////////////
//                                              //
//               DISPATCH-Stage                 //
//                                              //
//////////////////////////////////////////////////

dispatch_stage dipatch_0(
    // inputs
    .if_id_packet_in(dis_packet_in),

    // allocate new RS
    .rs_stall(rs_stall),
    .rs_in(dis_rs_packet),

    // allocate new ROB 
    .rob_stall(rob_stall),
    .rob_index(new_rob_index),
    .rob_in(dis_rob_packet),

    // allocate new PR 
    .free_reg_valid(free_pr_valid),
    .free_pr_in(free_pr),
    .maptable_new_pr(maptable_allocate_pr),
    .maptable_ar(maptable_allocate_ar),
    .maptable_old_pr(maptable_old_pr),
    .reg1_ar(maptable_lookup_reg1_ar),
    .reg2_ar(maptable_lookup_reg2_ar),
    .reg1_pr(maptable_reg1_pr),
    .reg2_pr(maptable_reg2_pr),
    .reg1_ready(maptable_reg1_ready),
    .reg2_ready(maptable_reg2_ready),


    .new_pr_en(dis_new_pr_en),
    .d_stall(dis_stall)

);

//////////////////////////////////////////////////
//                                              //
//               Maptable                       //
//                                              //
//////////////////////////////////////////////////

map_table map_table_0(
    .clock(clock),
    .reset(reset),
    .archi_maptable(archi_maptable),
    .BPRecoverEN(BPRecoverEN),
    .cdb_t_in(cdb_t),
    .maptable_new_ar(maptable_allocate_ar),
    .maptable_new_pr(maptable_allocate_pr),
    .reg1_ar(maptable_lookup_reg1_ar),
    .reg2_ar(maptable_lookup_reg2_ar),
    .reg1_tag(maptable_reg1_pr),
    .reg2_tag(maptable_reg2_pr),
    .reg1_ready(maptable_reg1_ready),
    .reg2_ready(maptable_reg2_ready),
    .Told_out(maptable_old_pr)
    `ifdef TEST_MODE
    , .map_array_disp(map_array_disp),
    .ready_array_disp(ready_array_disp)
    `endif
);

arch_maptable arch_maptable_0(
    .clock(clock),
    .reset(reset),
	.Tnew_in(map_ar_pr),
	.Retire_AR(map_ar),
	.Retire_EN(RetireEN),
	.archi_maptable(archi_maptable_out)
);


//////////////////////////////////////////////////
//                                              //
//             Reservation Station              //
//                                              //
//////////////////////////////////////////////////
assign rs_reset = reset | BPRecoverEN;


RS RS_0(
    // Inputs
    .clock(clock),
    .reset(reset),
    .rs_in(dis_rs_packet),
    .cdb_t(cdb_t),
    .fu_fifo_stall(fu_fifo_stall),
    
    // Outputs
    .issue_insts(rs_is_packet),
    .struct_stall(rs_stall)
    `ifdef TEST_MODE
    , .rs_entries_display(rs_entries_display)
    `endif
);


//////////////////////////////////////////////////
//                                              //
//                RS-IS-Register                //
//                                              //
//////////////////////////////////////////////////

always_ff @(posedge clock) begin
    if (reset | BPRecoverEN) is_packet_in <= `SD 0;
    else is_packet_in <= `SD rs_is_packet;
end


//////////////////////////////////////////////////
//                                              //
//                  ISSUE-Stage                 //
//                                              //
//////////////////////////////////////////////////

issue_stage issue_0(
    // Input
    .clock(clock),
    .reset(reset),
    .rs_out(is_packet_in),
    .read_rda(pr1_read),
    .read_rdb(pr2_read),
    .fu_ready(fu_ready),
    // Output
    .rda_idx(is_pr1_idx),
    .rdb_idx(is_pr2_idx),
    .issue_2_fu(is_fu_packet),
    .fu_fifo_stall(fu_fifo_stall)
    `ifdef TEST_MODE
    , .alu_fifo_display(alu_fifo_display)
    , .ls_fifo_display(ls_fifo_display)
    , .mult_fifo_display(mult_fifo_display)
    , .br_fifo_display(br_fifo_display)
    `endif
);

//////////////////////////////////////////////////
//                                              //
//                Physical Reg                  //
//                                              //
//////////////////////////////////////////////////

physical_regfile pr_0(
    // Inputs
    .rda_idx (is_pr1_idx),
    .rdb_idx (is_pr2_idx),
    .wr_data (wb_value),
    .wr_idx (cdb_t),
    .clock (clock),
    .reset (reset),
    // Output
    .rda_out(pr1_read),
    .rdb_out(pr2_read),
`ifdef TEST_MODE
    .pr_reg_display(pr_display)
`endif
);

//////////////////////////////////////////////////
//                                              //
//                IS-FU-Register                //
//                                              //
//////////////////////////////////////////////////

always_ff @(posedge clock) begin
    if (reset | BPRecoverEN) fu_packet_in <= `SD 0;
    else fu_packet_in <= `SD is_fu_packet;
end

//////////////////////////////////////////////////
//                                              //
//                 EXECUTE-Stage                //
//               (Functional Units)             //
//////////////////////////////////////////////////

fu_alu fu_alu_1(
	.clock(clock),                          // system clock
	.reset(reset),                          // system reset
    .complete_stall(complete_stall[ALU_1]),    // <- complete.fu_c_stall
	.fu_packet_in(fu_packet_in[ALU_1]),        // <- issue.issue_2_fu
    .fu_ready(fu_ready.alu_1),                // -> issue.fu_ready
    .want_to_complete(fu_finish.alu_1),// -> complete.fu_finish
	.fu_packet_out(fu_c_in[ALU_1])         // -> complete.fu_c_in
);

fu_alu fu_alu_2(
	.clock(clock),                          // system clock
	.reset(reset),                          // system reset
    .complete_stall(complete_stall[ALU_2]),    // <- complete.fu_c_stall
	.fu_packet_in(fu_packet_in[ALU_2]),        // <- issue.issue_2_fu
    .fu_ready(fu_ready.alu_2),                // -> issue.fu_ready
    .want_to_complete(fu_finish.alu_2),// -> complete.fu_finish
	.fu_packet_out(fu_c_in[ALU_2])         // -> complete.fu_c_in
);

fu_alu fu_alu_3(
	.clock(clock),                          // system clock
	.reset(reset),                          // system reset
    .complete_stall(complete_stall[ALU_3]),    // <- complete.fu_c_stall
	.fu_packet_in(fu_packet_in[ALU_3]),        // <- issue.issue_2_fu
    .fu_ready(fu_ready.alu_3),                // -> issue.fu_ready
    .want_to_complete(fu_finish.alu_3),// -> complete.fu_finish
	.fu_packet_out(fu_c_in[ALU_3])         // -> complete.fu_c_in
);

fu_mult fu_mult_1(
    .clock(clock),
    .reset(reset),
    .complete_stall(complete_stall.mult_1),
    .fu_packet_in(fu_packet_in[MULT_1]),
    .fu_ready(fu_ready.mult_1),
    .want_to_complete(fu_finish.mult_1),
    .fu_packet_out(fu_c_in[MULT_1])
);

fu_mult fu_mult_2(
    .clock(clock),
    .reset(reset),
    .complete_stall(complete_stall.mult_2),
    .fu_packet_in(fu_packet_in[MULT_2]),
    .fu_ready(fu_ready.mult_2),
    .want_to_complete(fu_finish.mult_2),
    .fu_packet_out(fu_c_in[MULT_2])
);

// TODO add more fus
assign fu_finish.loadstore_1 = 0;
assign fu_finish.loadstore_2 = 0;


assign fu_ready.loadstore_1 = 0;
assign fu_ready.loadstore_2 = 0;

assign fu_c_in[LS_2:LS_1] = 0;

branch_stage branc(
    .clock(clock),
    .reset(reset),
    .complete_stall(complete_stall.branch),
    .fu_packet_in(fu_packet_in[BRANCH]),
    .fu_ready(fu_ready.branch),
    .want_to_complete_branch(fu_finish.branch),
    .fu_packet_out_reg(fu_c_in[BRANCH])
);




//////////////////////////////////////////////////
//                                              //
//                      ROB                     //
//                                              //
//////////////////////////////////////////////////

ROB rob_0(
    .clock(clock), 
    .reset(reset), 
    .rob_in(dis_rob_packet),                    // <- dispatch.rob_in
    .complete_valid(complete_valid),            // <- complete.complete_valid
    .complete_entry(complete_entry),            // <- complete.complete_entry
    .precise_state_valid(precise_state_valid),  // <- complete.precise_state_valid
    .target_pc(target_pc),                      // <- complete.target_pc
    .BPRecoverEN(BPRecoverEN),                  // <- retire.BPRecoverEN
    .dispatch_index(new_rob_index),             // -> dispatch.rob_index
    .retire_entry(rob_retire_entry),                // -> retire.rob_head_entry
    .struct_stall(rob_stall)                    // -> dispatch.rob_stall
    `ifdef TEST_MODE
    , .rob_entries_display(rob_entries_display) // -> display entries
    , .head_display(head_display)               // -> display head
    , .tail_display(tail_display)               // -> display tail
    `endif
    `ifdef ROB_DEBUG
    , .rob_entries_debug(rob_debug)             // <- debug input
    `endif
);

//////////////////////////////////////////////////
//                                              //
//                Complete Stage                //
//                                              //
//////////////////////////////////////////////////

complete_stage cs(
    .clock(clock),
    .reset(reset),
    .fu_finish(fu_finish),                      // <- fu.fu_finish
    .fu_c_in(fu_c_in),                          // <- fu.fu_c_in
    .fu_c_stall(complete_stall),                // -> fu.complete_stall
    .cdb_t(cdb_t),                              // -> cdb_t broadcast
    .wb_value(wb_value),                        // -> wb_value, to register file
    .complete_valid(complete_valid),            // -> ROB.complete_valid
    .complete_entry(complete_entry),            // -> ROB.complete_entry
    .precise_state_valid(precise_state_valid),  // -> ROB.precise_state_valid
    .target_pc(target_pc)                       // -> ROB.target_pc
    `ifdef TEST_MODE
    , .complete_pckt_in_display(complete_pckt_in_display)
    `endif
);

//////////////////////////////////////////////////
//                                              //
//                 Retire Stage                 //
//                                              //
//////////////////////////////////////////////////
    
retire_stage retire_0(
    .rob_head_entry(rob_retire_entry),          // <- ROB.retire_entry
    .fl_distance(fl_distance),                  // <- Freelist.fl_distance
    .BPRecoverEN(BPRecoverEN),                  // -> ROB.BPRecoverEN, Freelist.BPRecoverEN, fetch.take_branch
    .target_pc(fetch_pc),                       // -> fetch.target_pc
    .archi_maptable(archi_maptable_out),        // <- arch map.archi_maptable
    .map_ar_pr(map_ar_pr),                      // -> arch map.Tnew_in
    .map_ar(map_ar),                            // -> arch map.Retire_AR
    .recover_maptable(archi_maptable),          // -> map table.archi_maptable
    .FreelistHead(FreelistHead),                // <- Freelist.FreelistHead
    .Retire_EN(RetireEN),                       // -> Freelist.RetireEN
    .Tolds_out(RetireReg),                      // -> Freelist.RetireReg
    .BPRecoverHead(BPRecoverHead)               // -> Freelist.BPRecoverHead
);

//////////////////////////////////////////////////
//                                              //
//                   Free List                  //
//                                              //
//////////////////////////////////////////////////

Freelist fl_0(
    .clock(clock), 
    .reset(reset), 
    .DispatchEN(dis_new_pr_en),                    //
    .RetireEN(RetireEN),                        // <- retire.RetireEN
    .RetireReg(RetireReg),                      // <- retire.RetireReg
    .BPRecoverEN(BPRecoverEN),                  // <- retire.BPRecoverEN
    .BPRecoverHead(BPRecoverHead),              // <- retire.BPRecoverHead
    .FreeReg(free_pr),                          // -> dispatch.free_pr_in 
    .Head(FreelistHead),                        // -> retire.FreelistHead
    .FreeRegValid(free_pr_valid),               // -> dispatch.free_reg_valid 
    .fl_distance(fl_distance)                   // -> retire.fl_distance
    `ifdef TEST_MODE
    , .array_display(fl_array_display)          // -> display
    , .head_display(fl_head_display)            // -> display
    , .tail_display(fl_tail_display)            // -> display
    , .empty_display(fl_empty_display)          // -> display
    `endif
);


endmodule

`endif // __PIPELINE_V__