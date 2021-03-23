`timescale 1ns/100ps
`ifndef __FETCH_TEST_SV__
`define __FETCH_TEST_SV__

module testbench();

    logic               clock;
    logic               reset;
    logic  [3:0]        Imem2proc_response; // unused
    logic [63:0]        Imem2proc_data;
    logic  [3:0]        Imem2proc_tag;      // unused
    logic [63:0]        proc2Icache_addr;   // unused
    logic [63:0]        cachemem_data;      // unused
    logic               cachemem_valid;     // unused
    logic               mem_busy; 
    logic               take_branch;
    logic [`XLEN-1:0]   target_pc;
    logic [`XLEN-1:0]   proc2Imem_addr;
    IF_ID_PACKET[2:0]   if_packet_out;

    fetch_stage fs (
        .clock(clock),
        .reset(reset),
        .Imem2proc_response(Imem2proc_response),
        .Imem2proc_data(Imem2proc_data),    
        .Imem2proc_tag(Imem2proc_tag),    
        .proc2Icache_addr(proc2Icache_addr), 
        .cachemem_data(cachemem_data),    
        .cachemem_valid(cachemem_valid),   
        .mem_busy(mem_busy),         
        .take_branch(take_branch),       
	    .target_pc(target_pc),         
        .proc2Imem_addr(proc2Imem_addr),    
        .if_packet_out(if_packet_out)
    );

    task show_out();
        begin
            $display("================================");
            $display("proc2Imem_addr: %d", proc2Imem_addr);
            $display("|valid| Instruction|      PC      |      NPC     |");
            $display("|  %d  |  %h  |  %d  |  %d  |", if_packet_out[2].valid, if_packet_out[2].inst, if_packet_out[2].PC, if_packet_out[2].NPC);
            $display("|  %d  |  %h  |  %d  |  %d  |", if_packet_out[1].valid, if_packet_out[1].inst, if_packet_out[1].PC, if_packet_out[1].NPC);
            $display("|  %d  |  %h  |  %d  |  %d  |", if_packet_out[0].valid, if_packet_out[0].inst, if_packet_out[0].PC, if_packet_out[0].NPC);
        end
    endtask

    assign Imem2proc_response = 0;
    assign Imem2proc_data = 64'h12345678abcdef01;    
    assign Imem2proc_tag = 0;     
    assign proc2Icache_addr = 0;  
    assign cachemem_data = 0;     
    assign cachemem_valid = 0;    

    always begin
		#5;
		clock=~clock;
	end

    initial begin
		$dumpvars;
		clock=0;
        reset=1'b1;
        mem_busy=0; 
        take_branch=0;
        target_pc=0;
		@(negedge clock);
		@(negedge clock);
        reset=0;
        #2
        show_out();
		
		@(negedge clock);
        #2
        show_out();

        @(negedge clock);
        #2
        show_out();

        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();
        @(negedge clock);
        #2
        show_out();

        $display("@@@Finished\n");
		$finish;
	end


endmodule

`endif