`timescale 1ns/100ps
`ifndef __FREELIST_TEST_SV__
`define __FREELIST_TEST_SV__

//`define RS_ALLOCATE_DEBUG // test only allocating new entry in rs
`define TEST_MODE


module testbench;

    logic 				            clock;
    logic 				            reset;
    logic 		[2:0]		        DispatchEN;
    logic 		[2:0] 		        RewindEN;
    logic 		[2:0] 		        RetireEN;
    logic  		[2:0][`PR-1:0] 	    RetireReg;
    logic 				            BPRecoverEN;
    logic 		[`ROB-1:0] 	        BPRecoverHead;
    logic 	    [2:0][`PR-1:0] 	    FreeReg;
    logic 	    [`PR-1:0] 	        Head;
    logic 	    [2:0] 		        FreeRegValid;
    logic       [31:0][`PR-1:0]      array;
	logic       [4:0]               head;
	logic       [4:0]               tail;
    logic       [4:0]               fl_distance;
    logic                           empty_display;
    logic [31:0] cycle_count;


    Freelist tbp(.clock(clock), .reset(reset), .DispatchEN(DispatchEN), .RetireEN(RetireEN), .RetireReg(RetireReg), .BPRecoverEN(BPRecoverEN), .BPRecoverHead(BPRecoverHead),.FreeReg(FreeReg), .Head(Head), .FreeRegValid(FreeRegValid), .fl_distance(fl_distance),.array_display(array), .head_display(head), .tail_display(tail), .empty_display(empty_display));

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
    

    task show_freelist_table;
        $display("####### Cycle %d ##########", cycle_count);
        $display("DispatchEN:%d", DispatchEN);
        for(int i=31; i>=0; i--) begin  // For RS entry, it allocates from 15-0
            $display("Index: %d        PR: %5d", i, array[i]);
        end
        $display("head:%d tail:%d HEAD:%d", head, tail, Head);
    endtask; // show_rs_table

    task show_free_reg;
        begin
            $display("=====   Free Reg   =====");
            $display("FreeReg Valid: %d", FreeRegValid);
            $display("| WAY |   PR  |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |   %2d  |", i, FreeReg[i]);
            end
        end
    endtask

    task show_retire_reg;
        begin
            $display("=====   Retire Reg   =====");
            $display("RetireReg Valid: %d", RetireEN);
            $display("| WAY |   PR  |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |   %2d  |", i, RetireReg[i]);
            end
        end
    endtask

    task set_retire_reg;
        input integer freelist_in_i;

	    input [`PR-1:0] 	Pr;

        begin
            RetireReg[freelist_in_i] = Pr;
        end
    endtask


    always_ff@(posedge clock) begin
        if (reset)
            cycle_count <= 0;
        else 
            cycle_count <= cycle_count + 1;
    end

    initial begin
        //$dumpvars;
        clock = 1'b0;
        reset = 1'b1;
        DispatchEN = 0;
        RewindEN = 0;
        RetireEN = 0;
        RetireReg = 0;
        BPRecoverEN = 0;
        BPRecoverHead = 0;
        
        @(negedge clock);
        reset = 0;
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

        @(posedge clock);
        DispatchEN = 3'b111;

        @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();


        @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

        @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

                @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

                @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

                @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

                @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

                @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

                @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

                @(negedge clock);
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

        @(posedge clock);  
        RetireEN = 3'b001;
        set_retire_reg(0,1);  

        @(negedge clock);        
        show_freelist_table();
        show_retire_reg();
        show_free_reg();

        @(negedge clock);
        RetireEN = 0;
        DispatchEN = 0;
        show_freelist_table();
        show_retire_reg();
        show_free_reg();
        $finish;

    end

endmodule

`endif