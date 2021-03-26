//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  ex_stage.v                                           //
//                                                                      //
//  Description :  instruction execute (EX) stage of the pipeline;      //
//                 given the instruction command code CMD, select the   //
//                 proper input A and B for the ALU, compute the result,// 
//                 and compute the condition for branches, and pass all //
//                 the results down the pipeline. MWB                   // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef __EX_STAGE_V__
`define __EX_STAGE_V__

`timescale 1ns/100ps

//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//
// This module is purely combinational
//
module alu(
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	ALU_SELECT     func,

	output logic [`XLEN-1:0] result
);
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;
	assign signed_opa = opa;
	assign signed_opb = opb;
	assign signed_mul = signed_opa * signed_opb;
	assign unsigned_mul = opa * opb;
	assign mixed_mul = signed_opa * opb;

	always_comb begin
		case (func)
			ALU_ADD:      result = opa + opb;
			ALU_SUB:      result = opa - opb;
			ALU_AND:      result = opa & opb;
			ALU_SLT:      result = signed_opa < signed_opb;
			ALU_SLTU:     result = opa < opb;
			ALU_OR:       result = opa | opb;
			ALU_XOR:      result = opa ^ opb;
			ALU_SRL:      result = opa >> opb[4:0];
			ALU_SLL:      result = opa << opb[4:0];
			ALU_SRA:      result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
			ALU_MUL:      result = signed_mul[`XLEN-1:0];
			ALU_MULH:     result = signed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHSU:   result = mixed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHU:    result = unsigned_mul[2*`XLEN-1:`XLEN];

			default:      result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end
endmodule // alu



module alu_stage(
	input clock,               						// system clock
	input reset,               						// system reset
	input FU_STATE_PACKET complete_stall,			// complete stage structural hazard
	input ISSUE_FU_PACKET [2:0]   fu_packet_in,
	output FU_STATE_PACKET fu_ready,				// TODO: combine complete_stall and the FU currently running, forward to issue stage
	output FU_STATE_PACKET want_to_complete,		// TODO: deal with this value when we have more FUs
	output FU_COMPLETE_PACKET [2:0] fu_packet_out
);

	// TODO: change this assignment when we have more FUs
	assign fu_ready = 8'b00011111;		// always ready for now, since we only have ALU

	// TODO: also change this combinational block when we have more FUs
	always_comb begin
		want_to_complete = 0;
		if (fu_packet_out[0].dest_value != `XLEN'hfacebeec) want_to_complete.alu_1 = 1'b1;
		if (fu_packet_out[1].dest_value != `XLEN'hfacebeec) want_to_complete.alu_2 = 1'b1;
		if (fu_packet_out[2].dest_value != `XLEN'hfacebeec) want_to_complete.alu_3 = 1'b1;
	end

	// Pass-throughs
	assign fu_packet_out[2].if_take_branch = 0;		// TODO: change this line when we have branch FU
	assign fu_packet_out[2].target_pc = 0;			// TODO: change this line when we have branch FU
	assign fu_packet_out[2].dest_pr = fu_packet_in[2].dest_pr;
	assign fu_packet_out[2].rob_entry = fu_packet_in[2].rob_entry;
	assign fu_packet_out[2].halt = fu_packet_in[2].halt;
	assign fu_packet_out[2].valid = fu_packet_in[2].valid;

	assign fu_packet_out[1].if_take_branch = 0;		// TODO: change this line when we have branch FU
	assign fu_packet_out[1].target_pc = 0;			// TODO: change this line when we have branch FU
	assign fu_packet_out[1].dest_pr = fu_packet_in[1].dest_pr;
	assign fu_packet_out[1].rob_entry = fu_packet_in[1].rob_entry;
	assign fu_packet_out[1].halt = fu_packet_in[1].halt;
	assign fu_packet_out[1].valid = fu_packet_in[1].valid;

	assign fu_packet_out[0].if_take_branch = 0;		// TODO: change this line when we have branch FU
	assign fu_packet_out[0].target_pc = 0;			// TODO: change this line when we have branch FU
	assign fu_packet_out[0].dest_pr = fu_packet_in[0].dest_pr;
	assign fu_packet_out[0].rob_entry = fu_packet_in[0].rob_entry;
	assign fu_packet_out[0].halt = fu_packet_in[0].halt;
	assign fu_packet_out[0].valid = fu_packet_in[0].valid;

	logic [2:0][`XLEN-1:0] opa_mux_out, opb_mux_out;
	//
	// ALU opA mux
	//
	always_comb begin
		opa_mux_out[2] = `XLEN'hdeadfbac;
		case (fu_packet_in[2].opa_select)
			OPA_IS_RS1:  opa_mux_out[2] = fu_packet_in[2].r1_value;
			OPA_IS_NPC:  opa_mux_out[2] = fu_packet_in[2].NPC;
			OPA_IS_PC:   opa_mux_out[2] = fu_packet_in[2].PC;
			OPA_IS_ZERO: opa_mux_out[2] = 0;
		endcase
	end

    always_comb begin
		opa_mux_out[1] = `XLEN'hdeadfbac;
		case (fu_packet_in[1].opa_select)
			OPA_IS_RS1:  opa_mux_out[1] = fu_packet_in[1].r1_value;
			OPA_IS_NPC:  opa_mux_out[1] = fu_packet_in[1].NPC;
			OPA_IS_PC:   opa_mux_out[1] = fu_packet_in[1].PC;
			OPA_IS_ZERO: opa_mux_out[1] = 0;
		endcase
	end

    always_comb begin
		opa_mux_out[0] = `XLEN'hdeadfbac;
		case (fu_packet_in[0].opa_select)
			OPA_IS_RS1:  opa_mux_out[0] = fu_packet_in[0].r1_value;
			OPA_IS_NPC:  opa_mux_out[0] = fu_packet_in[0].NPC;
			OPA_IS_PC:   opa_mux_out[0] = fu_packet_in[0].PC;
			OPA_IS_ZERO: opa_mux_out[0] = 0;
		endcase
	end

	 //
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out[2] = `XLEN'hfacefeed;
		case (fu_packet_in[2].opb_select)
			OPB_IS_RS2:   opb_mux_out[2] = fu_packet_in[2].r2_value;
			OPB_IS_I_IMM: opb_mux_out[2] = `RV32_signext_Iimm(fu_packet_in[2].inst);
			OPB_IS_S_IMM: opb_mux_out[2] = `RV32_signext_Simm(fu_packet_in[2].inst);
			OPB_IS_B_IMM: opb_mux_out[2] = `RV32_signext_Bimm(fu_packet_in[2].inst);
			OPB_IS_U_IMM: opb_mux_out[2] = `RV32_signext_Uimm(fu_packet_in[2].inst);
			OPB_IS_J_IMM: opb_mux_out[2] = `RV32_signext_Jimm(fu_packet_in[2].inst);
		endcase 
	end

    always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out[1] = `XLEN'hfacefeed;
		case (fu_packet_in[1].opb_select)
			OPB_IS_RS2:   opb_mux_out[1] = fu_packet_in[1].r2_value;
			OPB_IS_I_IMM: opb_mux_out[1] = `RV32_signext_Iimm(fu_packet_in[1].inst);
			OPB_IS_S_IMM: opb_mux_out[1] = `RV32_signext_Simm(fu_packet_in[1].inst);
			OPB_IS_B_IMM: opb_mux_out[1] = `RV32_signext_Bimm(fu_packet_in[1].inst);
			OPB_IS_U_IMM: opb_mux_out[1] = `RV32_signext_Uimm(fu_packet_in[1].inst);
			OPB_IS_J_IMM: opb_mux_out[1] = `RV32_signext_Jimm(fu_packet_in[1].inst);
		endcase 
	end

    always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out[0] = `XLEN'hfacefeed;
		case (fu_packet_in[0].opb_select)
			OPB_IS_RS2:   opb_mux_out[0] = fu_packet_in[0].r2_value;
			OPB_IS_I_IMM: opb_mux_out[0] = `RV32_signext_Iimm(fu_packet_in[0].inst);
			OPB_IS_S_IMM: opb_mux_out[0] = `RV32_signext_Simm(fu_packet_in[0].inst);
			OPB_IS_B_IMM: opb_mux_out[0] = `RV32_signext_Bimm(fu_packet_in[0].inst);
			OPB_IS_U_IMM: opb_mux_out[0] = `RV32_signext_Uimm(fu_packet_in[0].inst);
			OPB_IS_J_IMM: opb_mux_out[0] = `RV32_signext_Jimm(fu_packet_in[0].inst);
		endcase 
	end

	//
	// instantiate the ALU
	//
	alu fu_alu_2 (// Inputs
		.opa(opa_mux_out[2]),
		.opb(opb_mux_out[2]),
		.func(fu_packet_in[2].op_sel.alu),

		// Output
		.result(fu_packet_out[2].dest_value)
	);

    alu fu_alu_1 (// Inputs
		.opa(opa_mux_out[1]),
		.opb(opb_mux_out[1]),
		.func(fu_packet_in[1].op_sel.alu),

		// Output
		.result(fu_packet_out[1].dest_value)
	);

    alu fu_alu_0 (// Inputs
		.opa(opa_mux_out[0]),
		.opb(opb_mux_out[0]),
		.func(fu_packet_in[0].op_sel.alu),

		// Output
		.result(fu_packet_out[0].dest_value)
	);
endmodule // module ex_stage
`endif // __EX_STAGE_V__
