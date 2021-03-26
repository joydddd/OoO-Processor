`define TEST_MODE
`ifndef __DISPATCH_V__
`define __DISPATCH_V__

`timescale 1ns/100ps
module decoder(

	//input [31:0] inst,
	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	input IF_ID_PACKET 		if_packet,
	output ALU_OPA_SELECT 	opa_select,
	output ALU_OPB_SELECT 	opb_select,
	output logic [4:0]   	dest_reg,
	output logic [4:0]		reg1,
	output logic [4:0]		reg2,
	output FU_SELECT      	fu_sel,
	output OP_SELECT	  	op_sel,
	                        //a cheap way to get the return code out
	output logic 			halt,      // non-zero on a halt
	output logic 			valid_inst, // for counting valid instructions executed
	                        // and for making the fetch stage die on halts/
	                        // keeping track of when to allow the next
	                        // instruction out of fetch
	                        // 0 for HALT and illegal instructions (die on halt)
	output logic 			illegal

);

	INST inst;
	logic valid_inst_in;
	
	assign inst          = if_packet.inst;
	assign valid_inst_in = if_packet.valid;
	assign valid_inst    = valid_inst_in;
	
	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		opa_select = OPA_IS_RS1;
		opb_select = OPB_IS_RS2;
		dest_reg = `ZERO_REG;
		reg1 = `ZERO_REG;
		reg2 = `ZERO_REG;
		fu_sel = ALU_1;
		op_sel = 0;
		halt = `FALSE;
		illegal = `FALSE;
		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
					fu_sel = LS_1;
					op_sel.ls = LUPP;
					dest_reg = inst.r.rd;
					opa_select = OPA_IS_ZERO;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_AUIPC: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_ADD;
					dest_reg = inst.r.rd;
					opa_select = OPA_IS_PC;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_JAL: begin
					fu_sel = BRANCH;
					op_sel.br = UNCOND;
					dest_reg      = inst.r.rd;
					opa_select    = OPA_IS_PC;
					opb_select    = OPB_IS_J_IMM;
				end
				`RV32_JALR: begin
					fu_sel = BRANCH;
					op_sel.br = UNCOND;
					dest_reg      = inst.r.rd;
					opa_select    = OPA_IS_RS1;
					reg1 		  = inst.r.rs1;
					opb_select    = OPB_IS_I_IMM;
				end
				`RV32_BEQ: begin
					op_sel.br = BEQ;
					fu_sel = BRANCH;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					reg2 = inst.r.rs2;
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
				end
				`RV32_BNE: begin
					op_sel.br = BNE;
					fu_sel = BRANCH;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					reg2 = inst.r.rs2;
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
				end
				`RV32_BLT: begin
					op_sel.br = BLT;
					fu_sel = BRANCH;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					reg2 = inst.r.rs2;
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
				end
				`RV32_BGE: begin
					op_sel.br = BGE;
					fu_sel = BRANCH;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					reg2 = inst.r.rs2;
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
				end
				`RV32_BLTU: begin
					op_sel.br = BLTU;
					fu_sel = BRANCH;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					reg2 = inst.r.rs2;
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
				end
				`RV32_BGEU: begin
					op_sel.br = BGEU;
					fu_sel = BRANCH;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					reg2 = inst.r.rs2;
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					fu_sel = LS_1;
					op_sel.ls = LOAD;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					fu_sel = LS_1;
					op_sel.ls = STORE;
					reg1 = inst.r.rs1;
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_S_IMM;
				end
				`RV32_ADDI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_ADD;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SLTI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SLT;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SLTIU: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SLTU;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_ANDI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_AND;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_ORI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_OR;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_XORI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_XOR;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SLLI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SLL;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SRLI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SRL;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SRAI: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SRA;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_ADD: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_ADD;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_SUB: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SUB;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_SLT: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SLT;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_SLTU: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SLTU;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_AND: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_AND;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_OR: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_OR;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_XOR: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_XOR;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_SLL: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SLL;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_SRL: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SRL;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_SRA: begin
					fu_sel = ALU_1;
					op_sel.alu = ALU_SRA;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_MUL: begin
					fu_sel = MULT_1;
					op_sel.mult = MULT;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_MULH: begin
					fu_sel = MULT_1;
					op_sel.mult = MULH;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_MULHSU: begin
					fu_sel = MULT_1;
					op_sel.mult = MULHSU;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`RV32_MULHU: begin
					fu_sel = MULT_1;
					op_sel.mult = MULHU;
					dest_reg = inst.r.rd;
					reg1 = inst.r.rs1; 
					reg2 = inst.r.rs2;
					opa_select = OPA_IS_RS1;
					opb_select = OPB_IS_RS2;
				end
				`WFI: begin
					halt = `TRUE;
				end
				default: 
					illegal = `TRUE;
		endcase // casez (inst)
		end // if(valid_inst_in)
	end // always
endmodule // decoder


`timescale 1ns/100ps
module dispatch_stage (
	input IF_ID_PACKET[2:0] 	if_id_packet_in,

	/* allocate new RS */
	input [2:0]					rs_stall, // if rs allocation stall. 
	output RS_IN_PACKET[2:0]	rs_in,

	/* allocate new ROB */
	input [2:0]					rob_stall, // rob expect structural stall
	input [2:0][`ROB-1:0]		rob_index,
	output ROB_ENTRY_PACKET[2:0] rob_in,

	/* allocate new PR */
	output logic [2:0]			new_pr_en, // connect to Free_List::Dispatch_EN & MT valid_new. Is 1 if the corresponding inst allocates a new pr 
	input [2:0] 				free_reg_valid, // Free_List::FreeRegValid
	input [2:0][`PR-1:0] 		free_pr_in, //  Free_List::FreeReg

	/* update map table */
	output logic [2:0][`PR-1:0]	maptable_new_pr,
	output logic [2:0][4:0]		maptable_ar,
	input [2:0][`PR-1:0]		maptable_old_pr,

	/* look up in map table */
	output logic [2:0][4:0]		reg1_ar,
	output logic [2:0][4:0]		reg2_ar,
	input [2:0][`PR-1:0]		reg1_pr,
	input [2:0][`PR-1:0]		reg2_pr,
	input [2:0]					reg1_ready,
	input [2:0]					reg2_ready,
	output logic [2:0]			d_stall // if is 1, corresponding inst stall due to structural hazard. 
);
/* rule out invalid inst and struct stall */
IF_ID_PACKET [2:0] dis_packet;
logic [2:0] valid_og;
logic [2:0] valid_one_to_two;
logic [2:0] valid_two_to_three;
assign d_stall = rs_stall | rob_stall | ~free_reg_valid; 


always_comb begin
	dis_packet = if_id_packet_in;
	for(int i=0; i<3; i++) begin
		dis_packet[i].valid = if_id_packet_in[i].valid & ~d_stall[i];
	end
end

/* decode */
FU_SELECT [2:0]fu_sel;
OP_SELECT [2:0]op_sel;
logic [2:0][4:0] dest_arch, reg1_arch, reg2_arch;
ALU_OPA_SELECT [2:0] opa_select;
ALU_OPB_SELECT [2:0] opb_select;
logic [2:0] halt;


decoder decode_0(
	.if_packet(dis_packet[0]),
	.fu_sel(fu_sel[0]), 
	.op_sel(op_sel[0]),
	.opa_select(opa_select[0]),
	.opb_select(opb_select[0]),
	.dest_reg(dest_arch[0]),
	.reg1(reg1_arch[0]), 
	.reg2(reg2_arch[0]),
	.halt(halt[0])      // non-zero on a haltn
);

decoder decode_1(
	.if_packet(dis_packet[1]),
	.fu_sel(fu_sel[1]), 
	.op_sel(op_sel[1]),
	.opa_select(opa_select[1]),
	.opb_select(opb_select[1]),
	.dest_reg(dest_arch[1]),
	.reg1(reg1_arch[1]),
	.reg2(reg2_arch[1]),
	.halt(halt[1])      // non-zero on a haltn
);

decoder decode_2(
	.if_packet(dis_packet[2]),
	.fu_sel(fu_sel[2]), 
	.op_sel(op_sel[2]),
	.opa_select(opa_select[2]),
	.opb_select(opb_select[2]),
	.dest_reg(dest_arch[2]),
	.reg1(reg1_arch[2]),
	.reg2(reg2_arch[2]),
	.halt(halt[2])      // non-zero on a haltn
);



logic [2:0][`PR-1:0] dest_pr;
always_comb begin
	for(int i=0; i<3; i++) begin
		new_pr_en[i] = dis_packet[i].valid & (dest_arch[i] != `ZERO_REG);
	end
end

always_comb begin
	for(int i=0; i<3; i++) begin
		dest_pr[i] = (dis_packet[i].valid && dest_arch[i]!=`ZERO_REG)?free_pr_in[i]:`ZERO_REG;
	end
end

/* update and looking up MT */
always_comb begin
	for(int i=0; i<3; i++) begin
		maptable_ar[i] = dis_packet[i].valid?dest_arch[i]:`ZERO_REG;
		maptable_new_pr[i] = dest_pr[i];
	end
end
assign reg1_ar = reg1_arch;
assign reg2_ar = reg2_arch;

/* allocate rob */
always_comb begin
	for(int i=0; i<3; i++) begin
		rob_in[i].valid = dis_packet[i].valid;
		rob_in[i].Tnew = dest_pr[i];
		rob_in[i].Told = maptable_old_pr[i];
		rob_in[i].halt = halt[i];
		rob_in[i].arch_reg = dest_arch[i];
		rob_in[i].completed = 0;
		rob_in[i].precise_state_need = 0;
		rob_in[i].target_pc = 0;
	end
end

/* allocate rs */
always_comb begin
	for(int i=0; i<3; i++) begin
		rs_in[i].valid = dis_packet[i].valid;
		rs_in[i].fu_sel = fu_sel[i];
		rs_in[i].op_sel = op_sel[i];
		rs_in[i].NPC = dis_packet[i].NPC;
		rs_in[i].PC = dis_packet[i].PC;
		rs_in[i].opa_select = opa_select[i];
		rs_in[i].opb_select = opb_select[i];
		rs_in[i].inst = dis_packet[i].inst;
		rs_in[i].halt = halt;
		rs_in[i].rob_entry = rob_index[i];
		rs_in[i].dest_pr = dest_pr[i];
		rs_in[i].reg1_pr = reg1_pr[i];
		rs_in[i].reg1_ready = reg1_ready[i];
		rs_in[i].reg2_pr = reg2_pr[i];
		rs_in[i].reg2_ready = reg2_ready[i];
	end
end


endmodule
`endif // _DISPATCH_V_