
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
    input 		[`ROB-1:0] 	        BPRecoverHead,
    output logic 	[2:0][`PR-1:0] 	FreeReg,
    output logic 	[`ROB-1:0] 	    Head,
    output logic 	[2:0] 		    FreeRegValid,
	output logic    [4:0]              fl_distance
    `ifdef TEST_MODE
    	, output [31:0][`PR-1:0] array_display
		, output [4:0] head_display
		, output [4:0] tail_display
		, output empty_display
	`endif
);

logic 	[2:0][`PR-1:0] 	FreeReg_next;
logic 	[2:0] 		    FreeRegValid_next;

logic [31:0][`PR-1:0] array;
logic [31:0][`PR-1:0] array_next;
logic empty;
logic empty_next;

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

logic [4:0] recover_index;

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
	assign empty_display = empty;
`endif

assign head_incre1 = head + 1;
assign head_incre2 = head + 2;
assign head_incre3 = head + 3;
assign input_start_incre1 = input_start + 1;
assign input_start_incre2 = input_start + 2;
assign input_start_incre3 = input_start + 3;
assign Head = head;
assign fl_distance = (head == tail && empty == 1) ? 32 :
					  (head == tail && empty == 0) ? 31 : 31 - tail + head;

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
    if (head == tail && empty) begin
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
	empty_next = empty;
	priority case (dispatch_count)
		3: begin
            if (head == tail_next && retire_count == 0) begin
				head_next = head;
				FreeRegValid_next = 3'b000;
				empty_next = 1;
			end
            else if (head == tail_next && retire_count > 0) begin
				head_next = head;
				FreeRegValid_next = 3'b001;
				empty_next = 1;
			end
			else if (head_incre1 == tail_next) begin
				head_next = head + 1;
				FreeRegValid_next = 3'b011;
				empty_next = 1;
			end
			else if (head_incre2 == tail_next) begin
				head_next = head + 2;
				FreeRegValid_next = 3'b111;
				empty_next = 1;
			end
			else begin
				head_next = head + 3;
				FreeRegValid_next = 3'b111;
				empty_next = 0;
			end
		end
		2: begin
            if (head == tail_next && retire_count == 0) begin
				head_next = head;
				FreeRegValid_next = 3'b000;
				empty_next = 1;
			end
            else if (head == tail_next && retire_count > 0) begin
				head_next = head;
				FreeRegValid_next = 	(dispatch_first) ? 3'b001 : 
								(dispatch_second) ? 3'b010 : 3'b100;
				empty_next = 1;
			end
			else if (head_incre1 == tail_next) begin
				head_next = head + 1;
				FreeRegValid_next = 	(dispatch_first & dispatch_second) ? 3'b011 : 
								(dispatch_first & dispatch_third) ? 3'b101 : 3'b110;
				empty_next = 1;
			end
			else begin
				head_next = head + 2;
				FreeRegValid_next = 	(dispatch_first & dispatch_second) ? 3'b011 : 
								(dispatch_first & dispatch_third) ? 3'b101 : 3'b110;
				empty_next = 0;
			end
		end
		1: begin
            if (head == tail_next && retire_count == 0) begin
				head_next = head;
				FreeRegValid_next = 3'b000;
				empty_next = 1;
			end
            else if (head == tail_next && retire_count > 0) begin
				head_next = head;
				FreeRegValid_next = 	(dispatch_first) ? 3'b001 : 
								(dispatch_second) ? 3'b010 : 3'b100;
				empty_next = 1;				
			end
			else begin
				head_next = head + 1;
				FreeRegValid_next = 	(dispatch_first) ? 3'b001 : 
								(dispatch_second) ? 3'b010 : 3'b100;
				empty_next = 0;				
			end
		end
		default begin
			head_next = head + dispatch_count;
			FreeRegValid_next = FreeRegValid;
			empty_next = 0;
		end
	endcase
		//$display("%d %d %d#############", dispatch_count, tail, head);
end


/* update Freelist */
always_comb begin
	array_next = array;
    FreeReg_next = FreeReg;
    priority case (RetireEN) 
		3'b111: begin
			array_next[input_start] = RetireReg[2];
			array_next[input_start_incre1] = RetireReg[1];	
			array_next[input_start_incre2] = RetireReg[0];	
		end
		3'b011: begin
			array_next[input_start] = RetireReg[1];
			array_next[input_start_incre1] = RetireReg[0];		
		end
		3'b101: begin
			array_next[input_start] = RetireReg[2];
			array_next[input_start_incre1] = RetireReg[0];	
		end
		3'b110: begin
			array_next[input_start] = RetireReg[2];
			array_next[input_start_incre1] = RetireReg[1];	
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
	
	priority case (FreeRegValid_next)
		3'b111: begin
			FreeReg_next[2] = array_next[head];
			FreeReg_next[1] = array_next[head_incre1];
			FreeReg_next[0] = array_next[head_incre2];
		end
		3'b011: begin
			FreeReg_next[1] = array_next[head];
			FreeReg_next[0] = array_next[head_incre1];
		end
		3'b101: begin
			FreeReg_next[2] = array_next[head];
			FreeReg_next[0] = array_next[head_incre1];
		end
		3'b110: begin
			FreeReg_next[2] = array_next[head];
			FreeReg_next[1] = array_next[head_incre1];
		end
		3'b001: begin
			FreeReg_next[0] = array_next[head];
		end
		3'b010: begin
			FreeReg_next[1] = array_next[head];
		end
		3'b100: begin
			FreeReg_next[2] = array_next[head];
		end
		3'b000: begin
			
		end
	endcase
end




always_ff @(posedge clock) begin
    if (reset) begin
		head <= `SD 0;
		tail <= `SD 31;
        empty <= `SD 0;
		FreeRegValid <= `SD 3'b111;
		FreeReg[2] <= `SD 32;
		FreeReg[1] <= `SD 33;
		FreeReg[0] <= `SD 34;
        for (int i = 0; i < 32; i++) begin
            array[i] <= `SD i + 32;
        end
	end
	else if (BPRecoverEN) begin
		array <= `SD array_next;
        empty <= `SD 0;
		head <= `SD BPRecoverHead;
		tail <= `SD tail_next;
		FreeReg <= `SD FreeReg_next;
		FreeRegValid <= `SD FreeRegValid_next;
	end
    else begin 
        array <= `SD array_next;
        empty <= `SD empty_next;
		FreeReg <= `SD FreeReg_next;
		FreeRegValid <= `SD FreeRegValid_next;
		head <= `SD head_next;
		tail <= `SD tail_next;
	end
end

endmodule
`endif