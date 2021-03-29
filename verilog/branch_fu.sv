//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  branch_fu.sv                                         //
//                                                                      //
//                                                                      //
//                                                                      //
//                                                                      // 
//                                                                      //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef __BRANCH_FU_SV__
`define __BRANCH_FU_SV__

`timescale 1ns/100ps

//
// The branch_fu
//
//
// This module is purely combinational
//
//
// BrCond module
//
// Given the instruction code, compute the proper condition for the
// instruction; for branches this condition will indicate whether the
// target is taken.
//
// This module is purely combinational
//
module brcond(// Inputs
	input [`XLEN-1:0] rs1,    // Value to check against condition
	input [`XLEN-1:0] rs2,
	input BR_SELECT br,  // Specifies which condition to check
	output logic cond    // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		cond = 0;
		case (br)
            UNCOND: cond = 1'b1;
		    BEQ:    cond = signed_rs1 == signed_rs2;  // BEQ
			BNE:    cond = signed_rs1 != signed_rs2;  // BNE
			BLT:    cond = signed_rs1 < signed_rs2;   // BLT
			BGE:    cond = signed_rs1 >= signed_rs2;  // BGE
			BLTU:   cond = rs1 < rs2;                 // BLTU
			BGEU:   cond = rs1 >= rs2;                // BGEU
		endcase
	end
	
endmodule // brcond


module branch_stage(
	input FU_STATE_PACKET complete_stall,			// complete stage structural hazard
	input ISSUE_FU_PACKET fu_packet_in,
	output 				  fu_ready,				// TODO: combine complete_stall and the FU currently running, forward to issue stage
	output logic want_to_complete_branch,		// TODO: deal with this value when we have more FUs
	output FU_COMPLETE_PACKET fu_packet_out
);

    // TODO: fu_ready and want_to_complete
	// Pass-throughs
	
	assign fu_packet_out.dest_pr = fu_packet_in.dest_pr;
	assign fu_packet_out.rob_entry = fu_packet_in.rob_entry;
	assign fu_packet_out.halt = fu_packet_in.halt;
	assign fu_packet_out.valid = fu_packet_in.valid;
	assign want_to_complete_branch = fu_ready & ~complete_stall.branch;

	logic [`XLEN-1:0] opa_mux_out, opb_mux_out;
	logic brcond_result;
	
    //
	// ALU opA mux
	//
    always_comb begin
		opa_mux_out = `XLEN'hdeadfbac;
		case (fu_packet_in.opa_select)
			OPA_IS_RS1:  opa_mux_out = fu_packet_in.r1_value;
			OPA_IS_NPC:  opa_mux_out = fu_packet_in.NPC;
			OPA_IS_PC:   opa_mux_out = fu_packet_in.PC;
			OPA_IS_ZERO: opa_mux_out = 0;
		endcase
	end

    //
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out = `XLEN'hfacefeed;
		case (fu_packet_in.opb_select)
			OPB_IS_RS2:   opb_mux_out = fu_packet_in.r2_value;
			OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(fu_packet_in.inst);
			OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(fu_packet_in.inst);
			OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(fu_packet_in.inst);
		endcase 
	end

	 //
	 // instantiate the branch condition tester
	 //
	brcond brcond (// Inputs
		.rs1(fu_packet_in.r1_value), 
		.rs2(fu_packet_in.r2_value),
		.br(fu_packet_in.op_sel.br), // inst bits to determine check

		// Output
		.cond(brcond_result)
	);

 	always_comb begin
    	fu_packet_out.if_take_branch = brcond_result;  //TODO: If not "assume all not taken", modify this
		
    	fu_packet_out.target_pc = brcond_result ? (opa_mux_out + opb_mux_out) : 0;
        fu_packet_out.dest_value = 0;
        if (fu_packet_in.op_sel.br==UNCOND) begin
            fu_packet_out.dest_value = fu_packet_in.NPC;
        end
    end
	assign fu_ready = 1;
endmodule 
`endif 
