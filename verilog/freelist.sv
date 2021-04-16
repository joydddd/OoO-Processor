
`define TEST_MODE
// `define RS_ALLOCATE_DEBUG
`ifndef __FREELIST_V__
`define __FREELIST_V__

`timescale 1ns/100ps

module Freelist(
    input 				            clock,
    input 				            reset,
    input 		[2:0]		        DispatchEN,
    input 		[2:0] 		        RetireEN,
    input  		[2:0][`PR-1:0] 	    RetireReg,
    input 				            BPRecoverEN,  
    input 		[`ROB-1:0] 	        BPRecoverHead, // nope
    output logic 	[2:0][`PR-1:0] 	FreeReg,
    output logic 	[`ROB-1:0] 	    Head, // nope
    output logic 	[2:0] 		    FreeRegValid,
	output logic    [4:0]              fl_distance // nope
    `ifdef TEST_MODE
    	, output [31:0][`PR-1:0] array_display
		, output [4:0] head_display
		, output [4:0] tail_display
		, output empty_display
	`endif
);

logic [`ROB-1:0] head, head_inc1, head_inc2, head_inc3, head_next;
logic [`ROB-1:0] tail, tail_inc1, tail_inc2, tail_inc3, tail_next;
logic full, full_next;
logic [31:0][`PR-1:0] array, array_next;
assign head_inc1 = head + 1;
assign head_inc2 = head + 2;
assign head_inc3 = head + 3;
assign tail_inc1 = tail + 1;
assign tail_inc2 = tail + 2;
assign tail_inc3 = tail + 3;

logic [5:0] available_num;
logic [4:0] available_num_temp; 
assign available_num_temp = tail-head;
assign available_num = full ? 32 : available_num_temp;
always_comb begin
	if (available_num >= 3) FreeRegValid = 3'b111;
	else if (available_num == 2) FreeRegValid = 3'b110;
	else if (available_num == 1) FreeRegValid = 3'b100;
	else FreeRegValid = 3'b000;
end

/* sent to diapatch */
assign head_next = head + DispatchEN[0] + DispatchEN[1] + DispatchEN[2];
always_comb begin
	FreeReg = 0;
	case(DispatchEN)
	3'b000: begin
	end
	3'b001: FreeReg[0] = array[head];
	3'b010: FreeReg[1] = array[head];
	3'b011: begin
		FreeReg[0] = array[head_inc1];
		FreeReg[1] = array[head];
	end
	3'b100: FreeReg[2] = array[head];
	3'b101: begin
		FreeReg[2] = array[head];
		FreeReg[0] = array[head_inc1];
	end
	3'b110: begin
		FreeReg[2] = array[head];
		FreeReg[1] = array[head_inc1];
	end
	3'b111: begin
		FreeReg[2] = array[head];
		FreeReg[1] = array[head_inc1];
		FreeReg[0] = array[head_inc2];
	end
	endcase
end

/* retire add to tail */
assign full_next = (RetireEN != 0 || full) && (tail_next == head_next);
assign tail_next = RetireEN[0] + RetireEN[1] + RetireEN[2] + tail;
always_comb begin
	array_next = array;
	case(RetireEN)
	3'b000: begin
	end
	3'b001: array_next[tail] = RetireReg[0];
	3'b010: array_next[tail] = RetireReg[1];
	3'b011: begin
		array_next[tail] = RetireReg[1];
		array_next[tail_inc1] = RetireReg[0];
	end
	3'b100: array_next[tail] = RetireReg[2];
	3'b101: begin
		array_next[tail] = RetireReg[2];
		array_next[tail_inc1] = RetireReg[0];
	end
	3'b110: begin
		array_next[tail] = RetireReg[2];
		array_next[tail_inc1] = RetireReg[1];
	end
	3'b111: begin
		array_next[tail] = RetireReg[2];
		array_next[tail_inc1] = RetireReg[1];
		array_next[tail_inc2] = RetireReg[0];
	end
	endcase
end

always_ff @(posedge clock) begin
    if (reset) begin
		head <= `SD 0;
		tail <= `SD 0;
		full <= `SD 1;
        for (int i = 0; i < 32; i++) begin
            array[i] <= `SD i + 32;
        end
	end
	else if (BPRecoverEN) begin
		array <= `SD array_next;
		head <= `SD tail_next;
		tail <= `SD tail_next;
		full <= `SD 1;
	end
    else begin 
        array <= `SD array_next;
		head <= `SD head_next;
		tail <= `SD tail_next;
		full <= `SD full_next;
	end
end

assign array_display = array;
assign head_display = head;
assign tail_display = tail;

endmodule
`endif