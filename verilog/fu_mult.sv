`define TEST_MODE
`ifndef __MULT_SV__
`define __MULT_SV__


`timescale 1ns/100ps
module mult #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
				input clock, reset,
				input start,
				input [1:0] sign,
				input [XLEN-1:0] mcand, mplier,
				
				output [(2*XLEN)-1:0] product,
				output logic [NUM_STAGE:0] dones
			);
	logic [(2*XLEN)-1:0] mcand_out, mplier_out, mcand_in, mplier_in;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_mcands, internal_mpliers;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_products;
	logic [NUM_STAGE:0] internal_dones;

	assign mcand_in  = sign[0] ? {{XLEN{mcand[XLEN-1]}}, mcand}   : {{XLEN{1'b0}}, mcand} ;
	assign mplier_in = sign[1] ? {{XLEN{mplier[XLEN-1]}}, mplier} : {{XLEN{1'b0}}, mplier};

	assign internal_mcands[0]   = mcand_in;
	assign internal_mpliers[0]  = mplier_in;
	assign internal_products[0] = 'h0;
	assign internal_dones[0]    = start;

	assign dones    = internal_dones;
	assign product = internal_products[NUM_STAGE];

	genvar i;
	for (i = 0; i < NUM_STAGE; ++i) begin : mstage
		mult_stage #(.XLEN(XLEN), .NUM_STAGE(NUM_STAGE)) ms (
			.clock(clock),
			.reset(reset),
			.product_in(internal_products[i]),
			.mplier_in(internal_mpliers[i]),
			.mcand_in(internal_mcands[i]),
			.start(internal_dones[i]),
			.product_out(internal_products[i+1]),
			.mplier_out(internal_mpliers[i+1]),
			.mcand_out(internal_mcands[i+1]),
			.done(internal_dones[i+1])
		);
	end
endmodule

`timescale 1ns/100ps
module mult_stage #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
					input clock, reset, start,
					input [(2*XLEN)-1:0] mplier_in, mcand_in,
					input [(2*XLEN)-1:0] product_in,

					output logic done,
					output logic [(2*XLEN)-1:0] mplier_out, mcand_out,
					output logic [(2*XLEN)-1:0] product_out
				);

	parameter NUM_BITS = (2*XLEN)/NUM_STAGE;

	logic [(2*XLEN)-1:0] prod_in_reg, partial_prod, next_partial_product, partial_prod_unsigned;
	logic [(2*XLEN)-1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[(NUM_BITS-1):0] * mcand_in;

	assign next_mplier = {{(NUM_BITS){1'b0}},mplier_in[2*XLEN-1:(NUM_BITS)]};
	assign next_mcand  = {mcand_in[(2*XLEN-1-NUM_BITS):0],{(NUM_BITS){1'b0}}};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg      <= `SD product_in;
		partial_prod     <= `SD next_partial_product;
		mplier_out       <= `SD next_mplier;
		mcand_out        <= `SD next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			done     <= `SD 1'b0;
		end else begin
		done     <= `SD start;
		end
	end

endmodule

`timescale 1ns/100ps
module fu_mult(
    input                       clock,
    input                       reset,
    input                       complete_stall,
    input ISSUE_FU_PACKET       fu_packet_in,
    output logic                fu_ready,
    output logic                want_to_complete,
    output FU_COMPLETE_PACKET   fu_packet_out
);
logic start;
logic [1:0] sign;
logic [`XLEN-1:0] rs1, rs2;
logic [2*`XLEN-1:0] product;
logic [`XLEN-1:0] result;
FU_COMPLETE_PACKET result_pckt;
logic [`MUL_STAGE:0] dones;

logic result_in_reg;
logic result_in_reg_next;
logic output_from_reg;

assign start = fu_packet_in.valid;
assign rs1 = fu_packet_in.r1_value;
assign rs2 = fu_packet_in.r2_value;
always_comb begin
    priority case (fu_packet_in.op_sel.mult)
        MULT: begin
            sign[0] = rs1[`XLEN-1];
            sign[1] = rs2[`XLEN-1];
        end
        MULH: begin
            sign[0] = rs1[`XLEN-1];
            sign[1] = rs2[`XLEN-1];
        end
        MULHSU: begin
            sign[0] = rs1[`XLEN-1];
            sign[1] = 0;
        end
        MULHU:sign = 2'b00;
    endcase
end


mult #(.XLEN(`XLEN), .NUM_STAGE(`MUL_STAGE)) mult_0 (
                .clock(clock), 
                .reset(reset),
				.start(start),
				.sign(sign),
				.mcand(rs1),
                .mplier(rs2),
				.product(product),
				.dones(dones)
);

always_comb begin
    if (fu_packet_in.op_sel.mult == MULT) result = product[`XLEN-1:0];
    else result = product[`XLEN*2-1:`XLEN];
end

// build output package
always_comb begin
    result_pckt = 0;
    result_pckt.halt = fu_packet_in.halt;
    result_pckt.valid = dones[`MUL_STAGE];
    result_pckt.dest_pr = fu_packet_in.dest_pr;
    result_pckt.dest_value = result;
    result_pckt.rob_entry = fu_packet_in.rob_entry;
end

// ctrl signals
assign want_to_complete = dones[`MUL_STAGE-1] | result_in_reg_next;
assign fu_ready = ~(|dones[`MUL_STAGE-2:0]) & ~complete_stall;

// reg that holds result
FU_COMPLETE_PACKET result_reg;

always_comb begin
    result_in_reg_next = 0;
    if (complete_stall & dones[`MUL_STAGE]) result_in_reg_next = 1;
    if (result_in_reg & ~output_from_reg) result_in_reg_next = 1;
end

always_ff @(posedge clock) begin
    if (reset) result_in_reg <= `SD 0;
    else result_in_reg <= `SD result_in_reg_next;
end

always_ff @(posedge clock) begin
    if (reset) output_from_reg <= `SD 0;
    else if (~complete_stall & ~output_from_reg) output_from_reg <= `SD result_in_reg;
    else output_from_reg <= `SD 0;
end

always_ff @(posedge clock) begin
    if (reset) result_reg <= `SD 0;
    else if (dones[`MUL_STAGE]) result_reg <= `SD result_pckt;
end


always_comb begin
    fu_packet_out = result_pckt;
    if (result_in_reg) fu_packet_out = result_reg;
end



endmodule // fu_mult
`endif //__MULT_SV__
