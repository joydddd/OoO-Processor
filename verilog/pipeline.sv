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
	input         reset                     // System reset
	// input [3:0]   mem2proc_response,        // Tag from memory about current request
	// input [63:0]  mem2proc_data,            // Data coming back from memory
	// input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	// output logic [1:0]  proc2mem_command,    // command sent to memory
	// output logic [`XLEN-1:0] proc2mem_addr,      // Address sent to memory
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


    // FU
    , output ISSUE_FU_PACKET [2**`FU-1:0] fu_in_display
    , output FU_STATE_PACKET            fu_ready_display
    
    // Complete
    , output CDB_T_PACKET               cdb_t_display

`endif

`ifdef DIS_DEBUG
    , input IF_ID_PACKET [2:0]          if_d_packet_debug
    , output logic [2:0]                dis_new_pr_en_out
    /* free list simulation */
    , input [2:0]                       free_pr_valid_debug
    , input [2:0][`PR-1:0]              free_pr_debug

    /* maptable simulation */
    , output logic [2:0] [4:0]          maptable_lookup_reg1_ar_out
    , output logic [2:0] [4:0]          maptable_lookup_reg2_ar_out
    , output logic [2:0] [4:0]          maptable_allocate_ar_out
    , output logic [2:0] [`PR-1:0]      maptable_allocate_pr_out
    , input [2:0][`PR-1:0]              maptable_old_pr_debug
    , input [2:0][`PR-1:0]              maptable_reg1_pr_debug
    , input [2:0][`PR-1:0]              maptable_reg2_pr_debug
    , input [2:0]                       maptable_reg1_ready_debug
    , input [2:0]                       maptable_reg2_ready_debug

    , input [2:0]                       rob_stall_debug
    , input FU_STATE_PACKET             fu_ready_debug
    , input CDB_T_PACKET                cdb_t_debug
`endif
    
);
/* Fetch Stage */
IF_ID_PACKET [2:0] if_d_packet;

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
logic [2:0]             rs_stall;
RS_S_PACKET [2:0]       rs_is_packet;

/* free list */
logic [2:0]             free_pr_valid;
logic [2:0][`PR-1:0]    free_pr;

/* map table */
logic [2:0][`PR-1:0]    maptable_old_pr;
logic [2:0][`PR-1:0]    maptable_reg1_pr;
logic [2:0][`PR-1:0]    maptable_reg2_pr;
logic [2:0]             maptable_reg1_ready;
logic [2:0]             maptable_reg2_ready;

/* Issue stage */
RS_S_PACKET [2:0]       is_packet_in;
ISSUE_FU_PACKET [2**`FU-1:0] is_fu_packet;
FU_FIFO_PACKET          fu_fifo_stall;
logic [2:0][`PR-1:0]    is_pr1_idx, is_pr2_idx; // access pr


/* physical register */
logic [2:0][`XLEN-1:0]  pr1_read, pr2_read;
// TODO: plug in pr
assign pr1_read = 0;
assign pr2_read = 0;


/* Reorder Buffer */
logic [2:0]             rob_stall;

/* functional unit */
FU_STATE_PACKET         fu_ready;
ISSUE_FU_PACKET [2**`FU-1:0] fu_packet_in;


/* Complete Stage */
CDB_T_PACKET            cdb_t;

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

// Complete
assign cdb_t_display = cdb_t;

`endif

`ifdef DIS_DEBUG
assign if_d_packet = if_d_packet_debug; 
assign dis_new_pr_en_out = dis_new_pr_en;
/* free list simulation */
assign free_pr_valid = free_pr_valid_debug;
assign free_pr = free_pr_debug;
/* maptable simulation */
assign maptable_lookup_reg1_ar_out = maptable_lookup_reg1_ar;
assign maptable_lookup_reg2_ar_out = maptable_lookup_reg2_ar;
assign maptable_allocate_ar_out = maptable_allocate_ar;
assign maptable_allocate_pr_out = maptable_allocate_pr;
assign maptable_old_pr = maptable_old_pr_debug;
assign maptable_reg1_pr = maptable_reg1_pr_debug;
assign maptable_reg2_pr = maptable_reg2_pr_debug;
assign maptable_reg1_ready = maptable_reg1_ready_debug;
assign maptable_reg2_ready = maptable_reg2_ready_debug;

assign rob_stall = rob_stall_debug;
assign fu_ready = fu_ready_debug;
assign cdb_t = cdb_t_debug;
`endif

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
//             Reservation Station              //
//                                              //
//////////////////////////////////////////////////

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
    if (reset) is_packet_in <= `SD 0;
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
//                IS-FU-Register                //
//                                              //
//////////////////////////////////////////////////

always_ff @(posedge clock) begin
    if (reset) fu_packet_in <= `SD 0;
    else fu_packet_in <= `SD is_fu_packet;
end


endmodule

`endif // __PIPELINE_V__