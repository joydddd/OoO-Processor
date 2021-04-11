
`define TEST_MODE
// `define RS_ALLOCATE_DEBUG
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
	input [2:0][`XLEN-1:0] target_pc,
	input BPRecoverEN,
	output logic [2:0][`ROB-1:0] dispatch_index,
	output ROB_ENTRY_PACKET[2:0]  retire_entry,  // which ENTRY to be retired

	output logic [2:0] struct_stall,

	output logic                      	update_EN,
    output logic [`XLEN-1:0]           update_pc,
    output logic                       update_direction,
    output logic [`XLEN-1:0]           update_target
	`ifdef TEST_MODE
    	, output ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries_display
		, output [`ROB-1:0] head_display
		, output [`ROB-1:0] tail_display
	`endif
);

ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries;
ROB_ENTRY_PACKET [`ROBW-1:0] rob_entries_next;
logic empty;
logic empty_temp;
logic empty_next;

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
logic [2:0] input_num;
logic [`ROB-1:0] head_next;
logic [`ROB-1:0] tail_next;
logic [2:0] head_incre;
logic [2:0]  tail_incre;
logic [`ROB-1:0] head_tail_diff;
logic [`ROB:0] space_left;

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
assign tail_incre = (rob_in[0].valid & rob_in[1].valid & rob_in[2].valid) ? 3 :
					(rob_in[1].valid & rob_in[2].valid) ? 2 :
					(rob_in[2].valid) ? 1 : 0;
assign head_tail_diff = tail - head;
assign space_left = (empty) ? 32 : 31 - head_tail_diff + head_incre;
assign struct_stall = 	(space_left == 0) ? 3'b111 :
						(space_left == 1) ? 3'b011 :
						(space_left == 2) ? 3'b001 : 3'b000;
/* move head */

always_comb begin
	head_incre = 0;
	empty_temp = empty;
	if(rob_entries[head].completed) begin
		head_incre = 1;
		if(rob_entries[head_incre1].completed) begin
			head_incre = 2;
			if(rob_entries[head_incre2].completed) begin
				head_incre = 3;			
			end
		end
	end
	priority case (head_incre)
		3: begin
			if (head_incre2 == tail) begin
				head_next = head + 2;
				empty_temp = 1;
			end
			else begin
				head_next = head + head_incre;
				empty_temp = 0;
			end
		end
		2: begin
			if (head_incre1 == tail) begin
				head_next = head + 1;
				empty_temp = 1;
			end
			else begin
				head_next = head + head_incre;
				empty_temp = 0;
			end
		end
		1: begin
			if (head == tail) begin
				head_next = head;
				empty_temp = 1;
			end
			else begin
				head_next = head + head_incre;
				empty_temp = 0;
			end
		end
		default begin
			head_next = head;
			empty_temp = empty;
		end
	endcase
end

/* move tail */
always_comb begin
	tail_next = tail + tail_incre;
	input_start = tail + 1;
	empty_next = 0;
	if (tail == head_next && empty_temp) begin
		input_start = tail;
		tail_next = (tail_incre > 0) ? tail + tail_incre - 1 : tail;
		input_num = (tail_incre == 3) ? 3'b111 :
					(tail_incre == 2) ? 3'b110 :
					(tail_incre == 1) ? 3'b100 : 3'b000;
		empty_next = (tail_incre > 0) ? 0 : 1;
	end
	else begin
		priority case (tail_incre)
			3: begin
				if (tail_incre1 == head_next) begin
					tail_next = tail;
					input_num = 3'b000;
				end
				else if (tail_incre2 == head_next) begin
					tail_next = tail + 1;
					input_num = 3'b100;
				end
				else if (tail_incre3 == head_next) begin
					tail_next = tail + 2;
					input_num = 3'b110;
				end
				else begin
					tail_next = tail + 3;
					input_num = 3'b111;
				end
			end
			2: begin
				if (tail_incre1 == head_next) begin
					tail_next = tail;
					input_num = 3'b000;
				end
				else if (tail_incre2 == head_next) begin
					tail_next = tail + 1;
					input_num = 3'b100;
				end
				else begin
					tail_next = tail + 2;
					input_num = 3'b110;
				end
			end
			1: begin
				if (tail_incre1 == head_next) begin
					tail_next = tail;
					input_num = 3'b000;
				end
				else begin
					tail_next = tail + 1;
					input_num = 3'b100;
				end
			end
			default begin
				input_num = 3'b000;
				tail_next = tail;
			end
		endcase
	end
end

/* update ROB */
always_comb begin
	rob_entries_next = rob_entries;
	retire_entry = 0;
	dispatch_index = 0;
	priority case (head_incre)
		3: begin
			retire_entry[2] = rob_entries[head];
			retire_entry[1] = rob_entries[head_incre1];
			retire_entry[0] = rob_entries[head_incre2];
			rob_entries_next[head] = 0;
			rob_entries_next[head_incre1] = 0;
			rob_entries_next[head_incre2] = 0;		
		end
		2: begin
			retire_entry[2] = rob_entries[head];
			retire_entry[1] = rob_entries[head_incre1];
			rob_entries_next[head] = 0;
			rob_entries_next[head_incre1] = 0;
		end
		1: begin
			retire_entry[2] = rob_entries[head];
			rob_entries_next[head] = 0;
		end
		default: begin
			retire_entry = 0;
		end
	endcase
	priority case (input_num)
		3'b111: begin
			rob_entries_next[input_start] = rob_in[2];
			dispatch_index[2] = input_start;
			rob_entries_next[input_start_incre1] = rob_in[1];
			dispatch_index[1] = input_start_incre1;	
			rob_entries_next[input_start_incre2] = rob_in[0];
			dispatch_index[0] = input_start_incre2;	
		end
		3'b110: begin
			rob_entries_next[input_start] = rob_in[2];
			dispatch_index[2] = input_start;
			rob_entries_next[input_start_incre1] = rob_in[1];	
			dispatch_index[1] = input_start_incre1;	
		end
		3'b100: begin
			rob_entries_next[input_start] = rob_in[2];
			dispatch_index[2] = input_start;	
		end
		default: begin
			dispatch_index = 0;
		end
	endcase
	for (int i = 0; i < 3; i++) begin
		if (complete_valid[i]) begin
			//$display("%b %b %5d*************", precise_state_valid[i], rob_entries[complete_entry[i]].predict_direction, rob_entries[complete_entry[i]].NPC);
			rob_entries_next[complete_entry[i]].completed = 1;
			rob_entries_next[complete_entry[i]].precise_state_need = 0;
			if (precise_state_valid[i] == 0 && rob_entries[complete_entry[i]].predict_direction == 1) begin
				rob_entries_next[complete_entry[i]].precise_state_need = 1;
				rob_entries_next[complete_entry[i]].target_pc = rob_entries[complete_entry[i]].NPC;
			end
			else if (precise_state_valid[i] == 1 && rob_entries[complete_entry[i]].predict_direction == 0) begin
				rob_entries_next[complete_entry[i]].precise_state_need = 1;
				rob_entries_next[complete_entry[i]].target_pc = target_pc[i];
			end
			else if (precise_state_valid[i] == 1 && rob_entries[complete_entry[i]].predict_direction == 1 && target_pc[i] != rob_entries[complete_entry[i]].predict_pc) begin
				rob_entries_next[complete_entry[i]].precise_state_need = 1;
				rob_entries_next[complete_entry[i]].target_pc = target_pc[i];
			end
			else begin
				rob_entries_next[complete_entry[i]].precise_state_need = 0;
				rob_entries_next[complete_entry[i]].target_pc = 0;
			end
		end
	end
	//$display("%d %d %d %d******%d",head, tail, head_tail_diff, head_incre, space_left);	
end

always_ff @(posedge clock) begin
    if (reset | BPRecoverEN) begin
		head <= `SD 0;
		tail <= `SD 0;
		empty <= `SD 1;
        rob_entries <= `SD 0; 
	end	 
    else begin 
        rob_entries <= `SD rob_entries_next;
		head <= `SD head_next;
		tail <= `SD tail_next;
		empty <= `SD empty_next;
	end
end

endmodule
`endif