
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
assign Head = array_next[head_next];



/* update tail */
always_comb begin
    $display("%d", RetireEN);
    if (head == tail && array_state[tail] == 0) begin
	    tail_next = (RetireEN > 0) ? tail + RetireEN - 1 : tail;
        input_start = tail;
    end
    else begin
        input_start = tail + 1;
        tail_next = tail + RetireEN;
    end    
end



/* update head */

always_comb begin
    //$display("%d %d %d %d", head, tail, tail_next, RetireEN);
	priority case (DispatchEN)
		3: begin
            if (head == tail_next && RetireEN == 0) begin
				head_next = head;
				FreeRegValid = 0;
			end
            else if (head == tail_next && RetireEN > 0) begin
				head_next = head;
				FreeRegValid = 1;
			end
			else if (head_incre1 == tail_next) begin
				head_next = head + 1;
				FreeRegValid = 2;
			end
			else if (head_incre2 == tail_next) begin
				head_next = head + 2;
				FreeRegValid = 3;
			end
			else begin
				head_next = head + DispatchEN;
				FreeRegValid = 3;
			end
		end
		2: begin
            if (head == tail_next && RetireEN == 0) begin
				head_next = head;
				FreeRegValid = 0;
			end
            else if (head == tail_next && RetireEN > 0) begin
				head_next = head;
				FreeRegValid = 1;
			end
			else if (head_incre1 == tail_next) begin
				head_next = head + 1;
				FreeRegValid = 2;
			end
			else begin
				head_next = head + DispatchEN;
				FreeRegValid = 2;
			end
		end
		1: begin
            if (head == tail_next && RetireEN == 0) begin
				head_next = head;
				FreeRegValid = 0;
			end
            else if (head == tail_next && RetireEN > 0) begin
				head_next = head;
				FreeRegValid = 1;
			end
			else begin
				head_next = head + DispatchEN;
				FreeRegValid = 1;
			end
		end
		default begin
			head_next = head + DispatchEN;
			FreeRegValid = 0;
		end
	endcase
end


/* update Freelist */
always_comb begin
	array_next = array;
    FreeReg = 0;
    priority case (RetireEN)  
		3: begin
			array_next[input_start] = RetireReg[0];
			array_state_next[input_start] = 1;
			array_next[input_start_incre1] = RetireReg[1];
			array_state_next[input_start_incre1] = 1;	
			array_next[input_start_incre2] = RetireReg[2];
			array_state_next[input_start_incre2] = 1;		
		end
		2: begin
			array_next[input_start] = RetireReg[0];
			array_state_next[input_start] = 1;
			array_next[input_start_incre1] = RetireReg[1];
			array_state_next[input_start_incre1] = 1;		
		end
		1: begin
			array_next[input_start] = RetireReg[0];
			array_state_next[input_start] = 1;	
		end
		0: begin
			
		end
	endcase
	priority case (FreeRegValid)
		3: begin
			FreeReg[0] = array_next[head];
			FreeReg[1] = array_next[head_incre1];
			FreeReg[2] = array_next[head_incre2];
            array_next[head] = 0;
            array_state_next[head] = 0;
            array_next[head_incre1] = 0;
            array_state_next[head_incre1] = 0;
            array_next[head_incre2] = 0;
            array_state_next[head_incre2] = 0;
		end
		2: begin
			FreeReg[0] = array_next[head];
			FreeReg[1] = array_next[head_incre1];
            array_next[head] = 0;
            array_state_next[head] = 0;
            array_next[head_incre1] = 0;
            array_state_next[head_incre1] = 0;
		end
		1: begin
			FreeReg[0] = array_next[head];
            array_next[head] = 0;
            array_state_next[head] = 0;
		end
		0: begin
			
		end
	endcase	
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