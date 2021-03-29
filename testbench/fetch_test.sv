`timescale 1ns/100ps
`ifndef __FETCH_TEST_SV__
`define __FETCH_TEST_SV__

`define CACHE_MODE

module testbench();

    logic               clock;
    logic               reset;
    logic  [3:0]        Imem2proc_response;
    logic [63:0]        Imem2proc_data;
    logic  [3:0]        Imem2proc_tag;
    logic               take_branch;
    logic [`XLEN-1:0]   target_pc;
    logic [`XLEN-1:0]   proc2Imem_addr;
    IF_ID_PACKET[2:0]   if_packet_out;
    logic [1:0]         proc2Imem_command;

    pipeline_fetch pf_mut(
	    .clock(clock),                          // System clock
	    .reset(reset),                          // System reset
	    .mem2proc_response(Imem2proc_response), // Tag from memory about current request
	    .mem2proc_data(Imem2proc_data),         // Data coming back from memory
	    .mem2proc_tag(Imem2proc_tag),           // Tag from memory about current reply
	
	    .proc2mem_command(proc2Imem_command),   // command sent to memory
	    .proc2mem_addr(proc2Imem_addr),         // Address sent to memory

        .test_take_branch(take_branch),
        .test_target_pc(target_pc),
        .fetch_packet_out(if_packet_out)        // show the outputs of fetch stage
    );

    mem memory(
        .clk(clock),                            // Memory clock
        .proc2mem_addr(proc2Imem_addr),         // address for current command
        //support for memory model with byte level addressing
        .proc2mem_data(64'b0),                  // write data, no need for this test
    `ifndef CACHE_MODE  
        .proc2mem_size(DOUBLE),                 //BYTE, HALF, WORD or DOUBLE, no need for this test
    `endif
        .proc2mem_command(proc2Imem_command),   // `BUS_NONE `BUS_LOAD or `BUS_STORE
        
        .mem2proc_response(Imem2proc_response), // 0 = can't accept, other=tag of transaction
        .mem2proc_data(Imem2proc_data),         // data resulting from a load
        .mem2proc_tag(Imem2proc_tag)            // 0 = no value, other=tag of transaction
    );

    task show_out();
        begin
            $display("==================================================");
            $display("proc2Imem_command: %d (0: BUS_NONE, 1: BUS_LOAD, 2: BUS_STORE)", proc2Imem_command);       // 0: BUS_NONE, 1: BUS_LOAD
            $display("proc2Imem_addr: %d", proc2Imem_addr);
            $display("|valid| Instruction|      PC      |      NPC     |");
            $display("|  %d  |  %h  |  %d  |  %d  |", if_packet_out[2].valid, if_packet_out[2].inst, if_packet_out[2].PC, if_packet_out[2].NPC);
            $display("|  %d  |  %h  |  %d  |  %d  |", if_packet_out[1].valid, if_packet_out[1].inst, if_packet_out[1].PC, if_packet_out[1].NPC);
            $display("|  %d  |  %h  |  %d  |  %d  |", if_packet_out[0].valid, if_packet_out[0].inst, if_packet_out[0].PC, if_packet_out[0].NPC);
        end
    endtask

    always begin
		#5;
		clock=~clock;
	end

    assign take_branch = 1'b0;
    initial begin
		$dumpvars;
		clock=0;
        reset=1'b1;
        target_pc=0;
        @(negedge clock)
        $readmemh("program.mem", memory.unified_memory);

		@(negedge clock);
		@(negedge clock);
        reset=0;
        #2
        show_out();
		
        for (int i = 0; i < 28; i++) begin
            @(negedge clock);
            #2
            show_out();
        end

        show_out();
        $display("@@@Finished\n");
		$finish;
	end


endmodule

`endif