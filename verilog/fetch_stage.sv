`timescale 1ns/100ps

module fetch_stage (
    input                       clock,
    input                       reset,
    input   [2:0][31:0]         cache_data,         // <- icache.Icache_data_out
    input   [2:0]               cache_valid,        // <- Icache_valid_out
    input                       take_branch,        // taken-branch signal
	input   [`XLEN-1:0]         target_pc,          // target pc: use if take_branch is TRUE

    output  logic [1:0]         shift,              // -> icache.shift
    output  [2:0][`XLEN-1:0]    proc2Icache_addr,   // -> icache.proc2Icache_addr
    output  IF_ID_PACKET[2:0]   if_packet_out       // output data from fetch stage to dispatch stage
);

    logic   [2:0][`XLEN-1:0]    PC_reg;             // the three PC we are currently fetching
    logic   [2:0][`XLEN-1:0]    next_PC;            // the next three PC we are gonna fetch

	// the next_PC[2] (smallest PC) is:
    //  1. target_PC, if take branch
    //  2. PC_reg[2], if no branch and the current PC_reg[2] is not in the cache
	//  3. PC_reg[1], if no branch and the current PC_reg[1] is not in the cache
    //  4. PC_reg[0], if no branch and the current PC_reg[0] is not in the cache
    //  5. PC_reg[0] + 4 = PC_reg[2] + 12, if no branch and all three PCs are in the cache
	assign next_PC[2] = take_branch     ? target_pc :     // if take_branch, go to the target PC
                        ~cache_valid[2] ? PC_reg[2] :     // if the first inst isn't ready, wait until finish reading from memory
                        ~cache_valid[1] ? PC_reg[1] :     // same for the second inst
                        ~cache_valid[0] ? PC_reg[0] :     // and the third inst
                        PC_reg[0] + 4;
    assign next_PC[1] = next_PC[2] + 4;
    assign next_PC[0] = next_PC[1] + 4;

    assign count_down_shift = take_branch     ? 2'd0 :
                              ~cache_valid[2] ? 2'd0 :
                              ~cache_valid[1] ? 2'd1 :
                              ~cache_valid[0] ? 2'd2 :
                              2'd0;

    // Pass PC and NPC down pipeline w/instruction
	assign if_packet_out[2].NPC = PC_reg[2] + 4;
	assign if_packet_out[2].PC  = PC_reg[2];
    assign if_packet_out[1].NPC = PC_reg[1] + 4;
	assign if_packet_out[1].PC  = PC_reg[1];
    assign if_packet_out[0].NPC = PC_reg[0] + 4;
	assign if_packet_out[0].PC  = PC_reg[0];

    // Assign the valid bits of output
    assign if_packet_out[2].valid = cache_valid[2] ? 1'b1 : 1'b0;
    assign if_packet_out[1].valid = ~if_packet_out[2].valid ? 1'b0 :
                                    cache_valid[1] ? 1'b1 : 1'b0;
    assign if_packet_out[0].valid = ~if_packet_out[1].valid ? 1'b0 :
                                    cache_valid[0] ? 1'b1 : 1'b0;

    // Assign the inst part of output
    assign if_packet_out[2].inst  = ~cache_valid[2] ? 32'b0 : cache_data[2];
    assign if_packet_out[1].inst  = ~cache_valid[1] ? 32'b0 : cache_data[1];
    assign if_packet_out[0].inst  = ~cache_valid[0] ? 32'b0 : cache_data[0];

    assign proc2Icache_addr[2] = PC_reg[2];
    assign proc2Icache_addr[1] = PC_reg[1];
    assign proc2Icache_addr[0] = PC_reg[0];

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
			PC_reg <= `SD {`XLEN'd0, `XLEN'd4, `XLEN'd8};       // initial PC value
        end
		else begin
			PC_reg <= `SD next_PC; // transition to next PC
        end
    end

endmodule
