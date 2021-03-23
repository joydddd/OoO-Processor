
`define TEST_MODE
// `define RS_ALLOCATE_DEBUG
`define IS_DEBUG
`ifndef __ROB_V__
`define __ROB_V__

`timescale 1ns/100ps

module ROB(
	input clock,
	input reset,
	
    input ROB_ENTRY_PACKET[2:0] rob_in,

	input [2:0] complete_valid,
	input [2:0][`ROB-1:0] complete_entry,  // which ROB entry is done
	input [2:0] precise_state_valid,
	input [2:0][`XLEN`-1:0] target_pc,
	output [2:0][`ROB-1:0] dispatch_index,
	output ROB_ENTRY_PACKET [2:0]  retire_entry,  // which ENTRY to be retired

	output logic [2:0] struct_stall
	`ifdef TEST_MODE
    	, output ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries_display
		, output [`ROB-1:0] head_display
		, output [`ROB-1:0] tail_display
	`endif

	`ifdef IS_DEBUG
    	, input ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries_debug
	`endif
);

ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries;
ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries_next;
ROB_STATE [`ROBW-1:0] rob_states;
ROB_STATE [`ROBW-1:0] rob_states_next;

logic [`ROB-1:0] head;
logic [`ROB-1:0] head_incre1;
logic [`ROB-1:0] head_incre2;
logic [`ROB-1:0] head_incre3;
logic [`ROB-1:0] tail;
logic [`ROB-1:0] tail_incre1;
logic [`ROB-1:0] tail_incre2;
logic [`ROB-1:0] tail_incre3;
logic [`ROB-1:0] input_start;
logic [`ROB-1:0] input_start_incre1;
logic [`ROB-1:0] input_start_incre2;
logic [`ROB-1:0] input_start_incre3;
logic [`ROB-1:0] input_end;
logic [`ROB-1:0] input_diff;
logic [`ROB-1:0] output_end;
logic [`ROB-1:0] output_diff;
logic [`ROB-1:0] head_next;
logic [`ROB-1:0] tail_next;
logic [2:0] head_incre;
logic [2:0]  tail_incre;

`ifdef TEST_MODE
    assign rob_entries_display = rob_entries;
	assign head_display = head;
	assign tail_display = tail;
`endif

assign head_incre1 = head + 1;
assign head_incre2 = head + 2;
assign head_incre3 = head + 3;
assign tail_incre1 = tail + 1;
assign tail_incre2 = tail + 2;
assign tail_incre3 = tail + 3;
assign input_start_incre1 = input_start + 1;
assign input_start_incre2 = input_start + 2;
assign input_start_incre3 = input_start + 3;
assign input_diff = input_end - input_start;
assign output_diff = output_end - head;
assign tail_incre = (rob_in[0].valid & rob_in[1].valid & rob_in[2].valid) ? 3 :
					(rob_in[1].valid & rob_in[2].valid) ? 2 :
					(rob_in[2].valid) ? 1 : 0;
/* move head */

always_comb begin
	head_incre = 0;
	if(rob_states[head] == COMPLETE || rob_entries[head].completed) begin
		head_incre = 1;
		if(rob_states[head_incre1] == COMPLETE || rob_entries[head_incre1].completed) begin
			head_incre = 2;
			if(rob_states[head_incre2] == COMPLETE || rob_entries[head_incre2].completed) begin
				head_incre = 3;			
			end
		end
	end
	priority case (head_incre)
		3: begin
			if (head_incre1 == tail) begin
				head_next = head + 1;
				output_end = tail + 1;
			end
			else if (head_incre2 == tail) begin
				head_next = head + 2;
				output_end = tail + 1;
			end
			else if (head_incre3 == tail) begin
				head_next = head + 3;
				output_end = tail + 1;
			end
			else begin
				head_next = head + head_incre;
				output_end = head_next;
			end
			end
		2: begin
			if (head_incre1 == tail) begin
				head_next = head + 1;
				output_end = tail + 1;
			end
			else if (head_incre2 == tail) begin
				head_next = head + 2;
				output_end = tail + 1;
			end
			else begin
				head_next = head + head_incre;
				output_end = head_next;
			end
		end
		1: begin
			if (head_incre1 == tail) begin
				head_next = head + 1;
				output_end = tail + 1;
			end
			else begin
				head_next = head + head_incre;
				output_end = head_next;
			end
		end
		default begin
			head_next = head + head_incre;
			output_end = head_next;
		end
	endcase
end

/* move tail */
always_comb begin
	tail_next = tail + tail_incre;
	input_start = tail + 1;
	if (tail == head_next) begin
		if (rob_states[tail] == EMPTY || output_end == tail + 1 ) begin
			input_start = tail;
			tail_next = (tail_incre > 0) ? tail + tail_incre - 1 : tail;
			input_end = (tail_incre > 0) ? tail + tail_incre : tail;
		end
		else begin
			input_start = tail + 1;
			tail_next =  tail + tail_incre;
			input_end = tail_next + 1;
		end
	end
	else begin
		priority case (tail_incre)
			3: begin
				if (tail_incre1 == head_next) begin
					tail_next = tail;
					struct_stall = 3'b111;
				end
				else if (tail_incre2 == head_next) begin
					tail_next = tail + 1;
					struct_stall = 3'b011;
				end
				else if (tail_incre3 == head_next) begin
					tail_next = tail + 2;
					struct_stall = 3'b001;
				end
				else begin
					tail_next = tail + 3;
					struct_stall = 3'b000;
				end
			end
			2: begin
				if (tail_incre1 == head_next) begin
					tail_next = tail;
					struct_stall = 3'b110;
				end
				else if (tail_incre2 == head_next) begin
					tail_next = tail + 1;
					struct_stall = 3'b100;
				end
				else begin
					tail_next = tail + 2;
					struct_stall = 3'b000;
				end
			end
			1: begin
				if (tail_incre1 == head_next) begin
					tail_next = tail;
					struct_stall = 3'b100;
				end
				else begin
					tail_next = tail + 1;
					struct_stall = 3'b000;
				end
			end
			default begin
				struct_stall = 3'b000;
				tail_next = tail;
			end
		endcase
		input_end = tail_next + 1;
	end
end

/* update ROB */
always_comb begin
	rob_states_next = rob_states;
	rob_entries_next = rob_entries;
	retire_entry = 0;
	priority case (output_diff)
		3: begin
			retire_entry[2] = rob_entries[head];
			retire_entry[1] = rob_entries[head_incre1];
			retire_entry[0] = rob_entries[head_incre2];
			rob_states_next[head] = EMPTY;
			rob_entries_next[head].completed = 0;
			rob_states_next[head_incre1] = EMPTY;
			rob_entries_next[head_incre1].completed = 0;
			rob_states_next[head_incre2] = EMPTY;
			rob_entries_next[head_incre2].completed = 0;		
		end
		2: begin
			retire_entry[2] = rob_entries[head];
			retire_entry[1] = rob_entries[head_incre1];
			rob_states_next[head] = EMPTY;
			rob_entries_next[head].completed = 0;
			rob_states_next[head_incre1] = EMPTY;
			rob_entries_next[head_incre1].completed = 0;
		end
		1: begin
			retire_entry[2] = rob_entries[head];
			rob_states_next[head] = EMPTY;
			rob_entries_next[head].completed = 0;
		end
		0: begin
			
		end
	endcase
	priority case (input_diff)
		3: begin
			rob_entries_next[input_start] = rob_in[2];
			rob_states_next[input_start] = INUSED;
			rob_entries_next[input_start_incre1] = rob_in[1];
			rob_states_next[input_start_incre1] = INUSED;	
			rob_entries_next[input_start_incre2] = rob_in[0];
			rob_states_next[input_start_incre2] = INUSED;		
		end
		2: begin
			rob_entries_next[input_start] = rob_in[2];
			rob_states_next[input_start] = INUSED;
			rob_entries_next[input_start_incre1] = rob_in[1];
			rob_states_next[input_start_incre1] = INUSED;		
		end
		1: begin
			rob_entries_next[input_start] = rob_in[2];
			rob_states_next[input_start] = INUSED;	
		end
		0: begin
			
		end
	endcase
	for (int i = 0; i < 3; i++) begin
		if (complete_valid[i]) begin
			rob_states_next[complete_entry[i]] = COMPLETE;
			rob_entries_next[complete_entry[i]].completed = 1;
			rob_entries_next[complete_entry[i]].precise_state_need = (precise_state_valid[i]) ? 1 : 0;
		end
	end	
end

always_ff @(posedge clock) begin
    if (reset) begin
		head <= `SD 0;
		tail <= `SD 0;
		rob_states <= `SD 0;
		`ifndef IS_DEBUG
        	rob_entries <= `SD 0; 
    	`else
        	rob_entries <= `SD rob_entries_debug;
    	`endif
	end	 
    else begin 
        rob_entries <= `SD rob_entries_next;
		head <= `SD head_next;
		tail <= `SD tail_next;
		rob_states <= `SD rob_states_next;
	end
end

endmodule
`endif