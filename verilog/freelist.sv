
`define TEST_MODE
// `define RS_ALLOCATE_DEBUG
`ifndef __FREELIST_V__
`define __FREELIST_V__

`timescale 1ns/100ps

module Freelist(
    input 				            clock,
    input 				            reset,
    input 		[2:0]		        DispatchEN,
    input 		[2:0] 		        RewindEN,
    input 		[2:0] 		        RetireEN,
    input  		[2:0][`PR-1:0] 	    RetireReg,
    input 				            BPRecoverEN,  
    input 		[`ROB-1:0] 	        BPRecoverHead,
    output logic 	[2:0][`PR-1:0] 	FreeReg,
    output logic 	[`PR-1:0] 	    Head,
    output logic 	[2:0] 		    FreeRegValid
    `ifdef TEST_MODE
    	, output [31:0][`PR-1:0] array_display
		, output [4:0] head_display
		, output [4:0] tail_display
	`endif
);

logic [31:0][`PR-1:0] array;
logic [31:0][`PR-1:0] array_next;
logic [4:0] array_state;
logic [4:0] array_state_next;

logic [4:0] head;
logic [4:0] head_incre1;
logic [4:0] head_incre2;
logic [4:0] head_incre3;
logic [4:0] tail;
logic [4:0] input_start;
logic [4:0] input_start_incre1;
logic [4:0] input_start_incre2;
logic [4:0] input_start_incre3;
logic [4:0] head_next;
logic [4:0] tail_next;

logic [2:0] retire_count;
logic retire_first;
logic retire_second;
logic retire_third;

logic [2:0] dispatch_count;
logic dispatch_first;
logic dispatch_second;
logic dispatch_third;


`ifdef TEST_MODE
    assign array_display = array;
	assign head_display = head;
	assign tail_display = tail;
`endif

assign head_incre1 = head + 1;
assign head_incre2 = head + 2;
assign head_incre3 = head + 3;
assign input_start_incre1 = input_start + 1;
assign input_start_incre2 = input_start + 2;
assign input_start_incre3 = input_start + 3;
assign Head = head;

assign retire_first = RetireEN & 3'b001;
assign retire_second = (RetireEN & 3'b010) >> 1;
assign retire_third = (RetireEN & 3'b100) >> 2;
assign retire_count =  retire_first + retire_second + retire_third;

assign dispatch_first = DispatchEN & 3'b001;
assign dispatch_second = (DispatchEN & 3'b010) >> 1;
assign dispatch_third = (DispatchEN & 3'b100) >> 2;
assign dispatch_count =  dispatch_first + dispatch_second + dispatch_third;

/* update tail */
always_comb begin
    if (head == tail && array_state[tail] == 0) begin
	    tail_next = (retire_count > 0) ? tail + retire_count - 1 : tail;
        input_start = tail;
    end
    else begin
        input_start = tail + 1;
        tail_next = tail + retire_count;
    end    
end



/* update head */

always_comb begin
    //$display("%d %d %d %d", head, tail, tail_next, RetireEN);
	priority case (dispatch_count)
		3: begin
            if (head == tail_next && retire_count == 0) begin
				head_next = head;
				FreeRegValid = 3'b000;
			end
            else if (head == tail_next && retire_count > 0) begin
				head_next = head;
				FreeRegValid = 3'b001;
			end
			else if (head_incre1 == tail_next) begin
				head_next = head + 1;
				FreeRegValid = 3'b011;
			end
			else if (head_incre2 == tail_next) begin
				head_next = head + 2;
				FreeRegValid = 3'b111;
			end
			else begin
				head_next = head + dispatch_count;
				FreeRegValid = 3'b111;
			end
		end
		2: begin
            if (head == tail_next && retire_count == 0) begin
				head_next = head;
				FreeRegValid = 3'b000;
			end
            else if (head == tail_next && retire_count > 0) begin
				head_next = head;
				FreeRegValid = 	(dispatch_first) ? 3'b001 : 
								(dispatch_second) ? 3'b010 : 3'b100;
			end
			else if (head_incre1 == tail_next) begin
				head_next = head + 1;
				FreeRegValid = 	(dispatch_first & dispatch_second) ? 3'b011 : 
								(dispatch_first & dispatch_third) ? 3'b101 : 3'b110;
			end
			else begin
				head_next = head + dispatch_count;
								FreeRegValid = 	(dispatch_first & dispatch_second) ? 3'b011 : 
								(dispatch_first & dispatch_third) ? 3'b101 : 3'b110;
			end
		end
		1: begin
            if (head == tail_next && retire_count == 0) begin
				head_next = head;
				FreeRegValid = 3'b000;
			end
            else if (head == tail_next && retire_count > 0) begin
				head_next = head;
				FreeRegValid = 	(dispatch_first) ? 3'b001 : 
								(dispatch_second) ? 3'b010 : 3'b100;
			end
			else begin
				head_next = head + dispatch_count;
				FreeRegValid = 	(dispatch_first) ? 3'b001 : 
								(dispatch_second) ? 3'b010 : 3'b100;
			end
		end
		default begin
			head_next = head + dispatch_count;
			FreeRegValid = 3'b000;
		end
	endcase
end


/* update Freelist */
always_comb begin
	array_next = array;
    FreeReg = 0;
	if (retire_count == 3) begin
		array_state_next[input_start] = 1;
		array_state_next[input_start_incre1] = 1;
		array_state_next[input_start_incre2] = 1;
	end
	else if (retire_count == 2) begin
		array_state_next[input_start] = 1;
		array_state_next[input_start_incre1] = 1;
	end
	else if (retire_count == 1) begin
		array_state_next[input_start] = 1;
	end
    priority case (RetireEN) 
		3'b111: begin
			array_next[input_start] = RetireReg[0];
			array_next[input_start_incre1] = RetireReg[1];	
			array_next[input_start_incre2] = RetireReg[2];	
		end
		3'b011: begin
			array_next[input_start] = RetireReg[0];
			array_next[input_start_incre1] = RetireReg[1];		
		end
		3'b101: begin
			array_next[input_start] = RetireReg[0];
			array_next[input_start_incre1] = RetireReg[2];	
		end
		3'b110: begin
			array_next[input_start] = RetireReg[1];
			array_next[input_start_incre1] = RetireReg[2];	
		end
		3'b001: begin
			array_next[input_start] = RetireReg[0];	
		end
		3'b010: begin
			array_next[input_start] = RetireReg[1];
		end
		3'b100: begin
			array_next[input_start] = RetireReg[2];
		end
		0: begin	
		end
	endcase
	priority case (FreeRegValid)
		3'b111: begin
			FreeReg[0] = array_next[head];
			FreeReg[1] = array_next[head_incre1];
			FreeReg[2] = array_next[head_incre2];
		end
		3'b011: begin
			FreeReg[0] = array_next[head];
			FreeReg[1] = array_next[head_incre1];
		end
		3'b101: begin
			FreeReg[0] = array_next[head];
			FreeReg[2] = array_next[head_incre1];
		end
		3'b110: begin
			FreeReg[1] = array_next[head];
			FreeReg[2] = array_next[head_incre1];
		end
		3'b001: begin
			FreeReg[0] = array_next[head];
		end
		3'b010: begin
			FreeReg[1] = array_next[head];
		end
		3'b100: begin
			FreeReg[2] = array_next[head];
		end
		3'b000: begin
			
		end
	endcase
	if (FreeRegValid == 3'b111) begin
		array_next[head] = 0;
        array_state_next[head] = 0;
        array_next[head_incre1] = 0;
        array_state_next[head_incre1] = 0;
        array_next[head_incre2] = 0;
        array_state_next[head_incre2] = 0;
	end
	else if (FreeRegValid == 3'b011 || FreeRegValid == 3'b101 || FreeRegValid == 3'b110) begin
		array_next[head] = 0;
        array_state_next[head] = 0;
        array_next[head_incre1] = 0;
        array_state_next[head_incre1] = 0;
	end
	else if (FreeRegValid == 3'b100 || FreeRegValid == 3'b010 || FreeRegValid == 3'b001) begin
		array_next[head] = 0;
        array_state_next[head] = 0;
	end
end




always_ff @(posedge clock) begin
    if (reset) begin
		head <= `SD 0;
		tail <= `SD 31;
        array_state <= `SD 0;
        for (int i = 0; i < 32; i++) begin
            array[i] <= `SD i + 32;
        end
	end	 
    else begin 
        array <= `SD array_next;
        array_state <= `SD array_state_next;
		head <= `SD head_next;
		tail <= `SD tail_next;
	end
end

endmodule
`endif