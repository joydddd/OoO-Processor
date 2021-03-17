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
    , output IF_ID_PACKET [2:0]         if_d_packet_display
    
    // ID stage output
    , output RS_IN_PACKET [2:0]         dis_rs_packet_display
    , output ROB_ENTRY_PACKET [2:0]     dis_rob_packet_display
    , output logic [2:0]                dis_stall_display

    // RS
    , output RS_IN_PACKET [`RSW-1:0]    rs_entries_display
    , output RS_S_PACKET [2:0]          rs_is_packet_display
    , output logic [2:0]                rs_stall_display
`endif

`ifdef DIS_DEBUG
    , input IF_ID_PACKET                if_d_packet_debug
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
    , input [2:0][`PR-1:0]              maptable_reg1_ready_debug
    , input [2:0][`PR-1:0]              maptable_reg2_ready_debug
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



/* Reorder Buffer */
logic [2:0]             rob_stall;

/* functional unit */
FU_STATE_PACKET         fu_ready;


/* Complete Stage */
CDB_T_PACKET            cdb_t;

/////////////////////////////////////////////////////////
//          DEBUG  IN/OUTPUT                
////////////////////////////////////////////////////////
`ifdef TEST_MODE
assign if_d_packet_display = if_d_packet;
    
// ID stage output
assign dis_rs_packet_display = dis_rs_packet;
assign dis_rob_packet_display = dis_rob_packet;
assign dis_stall_display = dis_stall;

// RS
assign rs_is_packet_display = rs_is_packet;
assign rs_stall_display = rs_stall;
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
        dis_packet_in.valid <= `SD 0;
        dis_packet_in.inst <= `SD `NOP;
        dis_packet_in.NPC <= `SD 0;
        dis_packet_in.PC <= `SD 0;
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
    .reg1_ar(maptable_reg1_pr),
    .reg2_ar(maptable_reg2_pr),
    .reg1_ready(maptable_reg1_ready),
    .reg2_ready(maptable_reg2_ready),


    .valid(dis_new_pr_en),
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
    .fu_ready(fu_ready),
    
    // Outputs
    .issue_insts(rs_is_packet),
    .struct_stall(rs_stall)
    `ifdef TEST_MODE
    , .rs_entries_display(rs_entries_display)
    `endif
);


endmodule

`endif __PIPELINE_V__