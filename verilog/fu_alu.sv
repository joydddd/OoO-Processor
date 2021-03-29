//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  alu.sv                                               //
//                                                                      //
//  Description :  instruction execute (EX) stage of the pipeline;      //
//                 given the instruction command code CMD, select the   //
//                 proper input A and B for the ALU, compute the result,// 
//                 and compute the condition for branches, and pass all //
//                 the results down the pipeline. MWB                   // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef __ALU_V__
`define __ALU_V__

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
	input [`XLEN-1:0]   opa,
	input [`XLEN-1:0]   opb,
	ALU_SELECT          func,

	output logic [`XLEN-1:0] result
);
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	assign signed_opa = opa;
	assign signed_opb = opb;

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
			default:      result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end
endmodule // alu

`timescale 1ns/100ps

module fu_alu(
	input                       clock,      // system clock
	input                       reset,      // system reset
	input                       complete_stall,	// complete stage structural hazard
	input ISSUE_FU_PACKET       fu_packet_in,
	output logic                fu_ready,				
	output logic                want_to_complete,
	output FU_COMPLETE_PACKET   fu_packet_out
);

logic [`XLEN-1:0] opa_mux_out, opb_mux_out;
FU_COMPLETE_PACKET result;
ALU_SELECT alu_sel;

assign alu_sel = fu_packet_in.op_sel.alu;

///
//// Pass through
///

assign result.if_take_branch = `FALSE;
assign result.valid = fu_packet_in.valid;
assign result.halt = fu_packet_in.halt;
assign result.target_pc = 0;
assign result.dest_pr = fu_packet_in.dest_pr;
assign result.rob_entry = fu_packet_in.rob_entry;


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
        OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(fu_packet_in.inst);
        OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(fu_packet_in.inst);
        OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(fu_packet_in.inst);
        OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(fu_packet_in.inst);
    endcase 
end

alu alu_0(
    .opa(opa_mux_out),
    .opb(opb_mux_out),
    .func(alu_sel),
    .result(result.dest_value)
);



assign want_to_complete = fu_packet_in.valid;
assign fu_ready = ~complete_stall;
/* write result to finish reg */
always_ff @(posedge clock)begin
    if (reset) 
        fu_packet_out <= `SD 0;
    else if (complete_stall)
        fu_packet_out <= `SD fu_packet_out;
    else fu_packet_out <= `SD result;
end

endmodule // module 
`endif // __ALU_V__
