`timescale 1ns/100ps
`ifndef __TESTBENCH_FIN_SV__
`define __TESTBENCH_FIN_SV__

`define TEST_MODE 
`define DIS_DEBUG
`define CACHE_MODE
`define CACHE_SIM // TODO: comment this line to use real cache instead of simulation

/* import freelist simulator */
import "DPI-C" function void fl_init();
import "DPI-C" function int fl_new_pr_valid();
import "DPI-C" function int fl_new_pr2(int new_pr_en);
import "DPI-C" function int fl_new_pr1(int new_pr_en);
import "DPI-C" function int fl_new_pr0(int new_pr_en);
import "DPI-C" function int fl_pop(int new_pr_en);

/* import map table simulator */ 
import "DPI-C" function void mt_init();
import "DPI-C" function int mt_look_up(int i);
import "DPI-C" function int mt_look_up_ready(int i);
import "DPI-C" function void mt_map(int ar, int pr);

/* import print pipeline */
import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_num(int num);
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);

/* import print rs */ 
import "DPI-C" function void print_select(int index,  int valid, int inst,  int npc, int fu_select, int op_select);

/* import simulate cache & memory */
import "DPI-C" function void mem_init();
import "DPI-C" function void mem_write(int addr, int data, int byte3, byte2, byte1, byte0);
import "DPI-C" function int mem_read(int addr);
import "DPI-C" function void mem_print();

module testbench;
logic clock, reset;
logic program_halt;
logic [1:0] inst_count;

`ifdef TEST_MODE
// IF to Dispatch 


// ID stage output
IF_ID_PACKET [2:0]         dis_in_display;
ROB_ENTRY_PACKET [2:0]     dis_rob_packet_display;
logic [2:0]                dis_stall_display;

// RS
RS_IN_PACKET [2:0]         dis_rs_packet_display;
RS_IN_PACKET [`RSW-1:0]    rs_entries_display;
RS_S_PACKET [2:0]          rs_out_display;
logic [2:0]                rs_stall_display;

// Maptable
logic [31:0][`PR-1:0] map_array_display;
logic [31:0] ready_array_display;
logic [31:0][`PR-1:0] archi_map_display;

// IS
RS_S_PACKET [2:0]          is_in_display;
FU_FIFO_PACKET             fu_fifo_stall_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] alu_fifo_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] mult_fifo_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] br_fifo_display;
ISSUE_FU_PACKET [`IS_FIFO_DEPTH-1:0] ls_fifo_display;


// FU 
ISSUE_FU_PACKET [2**`FU-1:0] fu_in_display;
FU_STATE_PACKET            fu_ready_display;
FU_STATE_PACKET            fu_finish_display;
FU_COMPLETE_PACKET [2**`FU-1:0]   fu_packet_out_display;

// SQ
SQ_ENTRY_PACKET [0:2**`LSQ-1]  sq_display;
logic [`LSQ-1:0]               head_dis;
logic [`LSQ-1:0]               tail_dis;
logic [`LSQ:0]                 filled_num_dis;
SQ_ENTRY_PACKET [2**`LSQ-1:0]  older_stores;
logic [2**`LSQ-1:0]            older_stores_valid;
LOAD_SQ_PACKET [1:0]           load_sq_pckt_display;

// Complete
CDB_T_PACKET               cdb_t_display;
FU_COMPLETE_PACKET [2:0]    complete_pckt_in_display;
logic [2**`FU-1:0]          complete_stall_display;

//ROB
	ROB_ENTRY_PACKET [`ROBW-1:0]    rob_entries_display;
    logic       [`ROB-1:0]          head_display;
    logic       [`ROB-1:0]          tail_display;
    logic       [2:0]               rob_stall_display;

// PR
    logic [2**`PR-1:0][`XLEN-1:0] pr_display;

// Archi Map Table
    logic [2:0][`PR-1:0]       map_ar_pr;
    logic [2:0][4:0]           map_ar;
    logic [2:0]                RetireEN;

    logic [31:0][`PR-1:0]            fl_array_display;
    logic [4:0]                      fl_head_display;
    logic [4:0]                      fl_tail_display;
    logic                            fl_empty_display;

`endif

`ifdef DIS_DEBUG
IF_ID_PACKET [2:0]          if_d_packet_debug;
logic [2:0]                 dis_new_pr_en_out;
/* free list simulation */
logic [2:0]                 free_pr_valid_debug;
logic [2:0][`PR-1:0]        free_pr_debug;

logic [2:0]                 rob_stall_debug;
FU_STATE_PACKET             fu_ready_debug;
CDB_T_PACKET                cdb_t_debug;
`endif


SQ_ENTRY_PACKET [2:0]          cache_wb_sim;
logic [1:0][`XLEN-1:0]         cache_read_addr_sim;
logic [1:0][`XLEN-1:0]         cache_read_data_sim;
logic [1:0]                    cache_read_start_sim;

logic  [3:0]        Imem2proc_response;
logic [63:0]        Imem2proc_data;
logic  [3:0]        Imem2proc_tag;
logic [`XLEN-1:0]   proc2Imem_addr;
logic [1:0]         proc2Imem_command;
logic [63:0]        proc2Imem_data;

logic [63:0]        debug_counter;
EXCEPTION_CODE      pipeline_error_status;

mem memory(
    .clk(clock),                            // Memory clock
    .proc2mem_addr(proc2Imem_addr),         // <- pipeline.proc2mem_addr
    //support for memory model with byte level addressing
    // TODO: change when we have store and load
    .proc2mem_data(64'b0),                  // write data, no need for this test 
`ifndef CACHE_MODE  
    .proc2mem_size(DOUBLE),                 //BYTE, HALF, WORD or DOUBLE, no need for this test
`endif
    .proc2mem_command(proc2Imem_command),   // `BUS_NONE `BUS_LOAD or `BUS_STORE
    
    .mem2proc_response(Imem2proc_response), // 0 = can't accept, other=tag of transaction
    .mem2proc_data(Imem2proc_data),         // data resulting from a load
    .mem2proc_tag(Imem2proc_tag)            // 0 = no value, other=tag of transaction
);

pipeline tbd(
    .clock(clock),
    .reset(reset),
    .mem2proc_response(Imem2proc_response),    // <- mem.mem2proc_response
	.mem2proc_data(Imem2proc_data),            // <- mem.mem2proc_data
	.mem2proc_tag(Imem2proc_tag),              // <- mem.mem2proc_tag
	
	.proc2mem_command(proc2Imem_command),      // -> mem.proc2Imem_command
	.proc2mem_addr(proc2Imem_addr),            // -> mem.proc2Imem_addr
    .proc2mem_data(proc2Imem_data),            // -> mem.proc2Imem_data
    .halt(program_halt),
    .inst_count(inst_count)
`ifdef TEST_MODE
    // ID
    , .dis_in_display(dis_in_display)
    , .dis_rob_packet_display(dis_rob_packet_display)
    , .dis_stall_display(dis_stall_display)
    // RS
    , .dis_rs_packet_display(dis_rs_packet_display)
    , .rs_entries_display(rs_entries_display)
    , .rs_out_display(rs_out_display)
    , .rs_stall_display(rs_stall_display)
    // Maptable
    , .map_array_disp(map_array_display)
    , .ready_array_disp(ready_array_display)
    , .archi_map_display(archi_map_display)
    // IS
    , .is_in_display(is_in_display)
    , .fu_fifo_stall_display(fu_fifo_stall_display)
    , .alu_fifo_display(alu_fifo_display)
    , .mult_fifo_display(mult_fifo_display)
    , .br_fifo_display(br_fifo_display)
    , .ls_fifo_display(ls_fifo_display)
    // FU
    , .fu_in_display(fu_in_display)
    , .fu_ready_display(fu_ready_display)
    , .fu_finish_display(fu_finish_display)
    , .fu_packet_out_display(fu_packet_out_display)
    // SQ
    , .sq_display(sq_display)
    , .head_dis(head_dis)
    , .tail_dis(tail_dis)
    , .filled_num_dis(filled_num_dis)
    , .older_stores(older_stores)
    , .older_stores_valid(older_stores_valid)
    , .load_sq_pckt_display(load_sq_pckt_display)
    // Complete
    , .cdb_t_display(cdb_t_display)
    , .wb_value_display(wb_value_display)
    , .complete_pckt_in_display(complete_pckt_in_display)
    , .complete_stall_display(complete_stall_display)
    // ROB
    , .rob_entries_display(rob_entries_display)
    , .head_display(head_display)
    , .tail_display(tail_display)
    , .rob_stall_display(rob_stall_display)
    // Freelist
    , .fl_array_display(fl_array_display)
    , .fl_head_display(fl_head_display)
    , .fl_tail_display(fl_tail_display)
    , .fl_empty_display(fl_empty_display)
    // PR
    , .pr_display(pr_display)
    // Archi Map Table
    , .map_ar_pr_disp(map_ar_pr)
    , .map_ar_disp(map_ar)
    , .RetireEN_disp(RetireEN)
`endif // TEST_MODE

`ifdef DIS_DEBUG
    , .if_d_packet_debug(if_d_packet_debug)
    , .dis_new_pr_en_out(dis_new_pr_en_out)
`endif
`ifdef CACHE_SIM
    , .cache_wb_sim(cache_wb_sim)
    , .cache_read_addr_sim(cache_read_addr_sim)
    , .cache_read_data_sim(cache_read_data_sim)
    , .cache_read_start_sim(cache_read_start_sim)
`endif
);

/* clock */
always begin
	#(`VERILOG_CLOCK_PERIOD/2.0);
	clock = ~clock;
end

/* halt */
task wait_until_halt;
	forever begin : wait_loop
		@(posedge program_halt);
		@(negedge clock);
		if(program_halt) begin 
            @(negedge clock);
            disable wait_until_halt;
        end
	end
endtask

////////////////////////////////////////////////////////////
/////////////       SIMULATORS
///////////////////////////////////////////////////////////

int cycle_count;
always @(posedge clock) begin
    if (reset) begin
        cycle_count <= `SD 0;
    end
    else begin
        cycle_count <= `SD cycle_count + 1;
    end
end

int inst_total;
logic halted;
always @(posedge clock) begin
    if (reset) halted <= `SD 0;
    else if (~halted) halted <= `SD program_halt;
    else halted <= `SD 1;
end
always @(negedge clock) begin
    if (reset) inst_total = 0;
    else if (~halted)
        inst_total += inst_count;
end

`ifdef CACHE_SIM
always @(posedge clock) begin
    if (reset) begin
        mem_init();
    end
end

always @(posedge clock) begin
    if (!reset) begin
        mem_write(cache_wb_sim[0].addr, cache_wb_sim[0].data, cache_wb_sim[0].usebytes[3], cache_wb_sim[0].usebytes[2], cache_wb_sim[0].usebytes[1], cache_wb_sim[0].usebytes[0]);
        mem_write(cache_wb_sim[1].addr, cache_wb_sim[1].data, cache_wb_sim[1].usebytes[3], cache_wb_sim[1].usebytes[2], cache_wb_sim[1].usebytes[1], cache_wb_sim[1].usebytes[0]);
        mem_write(cache_wb_sim[2].addr, cache_wb_sim[2].data, cache_wb_sim[2].usebytes[3], cache_wb_sim[2].usebytes[2], cache_wb_sim[2].usebytes[1], cache_wb_sim[2].usebytes[0]);
    end
end

always @(cache_read_addr_sim, cache_read_start_sim) begin
    if (cache_read_start_sim[0]) cache_read_data_sim[0] = mem_read(cache_read_addr_sim[0]);
    if (cache_read_start_sim[1]) cache_read_data_sim[1] = mem_read(cache_read_addr_sim[1]);
end

`endif

//////////////////////////////////////////////////////////////
//////////////                  DISPLAY
/////////////////////////////////////////////////////////////
// Task to display # of elapsed clock edges
task print_cpi;
    real cpi;
    begin
        cpi = (cycle_count) / (inst_total -1.0);
        $display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
                    cycle_count, inst_total - 1, cpi);
        $display("@@  %4.2f ns total time to execute\n@@\n",
                    cycle_count*`VERILOG_CLOCK_PERIOD);
    end
endtask


// Show contents of a range of Unified Memory, in both hex and decimal
task show_mem_with_decimal;
	input [31:0] start_addr;
	input [31:0] end_addr;
	int showing_data;
	begin
		$display("@@@");
		showing_data=0;
		for(int k=start_addr;k<=end_addr; k=k+1)
			if (memory.unified_memory[k] != 0) begin
				$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
			                                            memory.unified_memory[k]);
				showing_data=1;
			end else if(showing_data!=0) begin
				$display("@@@");
				showing_data=0;
			end
		$display("@@@");
	end
endtask  // task show_mem_with_decimal

always @(negedge clock) begin
    if(reset) begin
		$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
		         $realtime);
        debug_counter <= 0;
    end else begin
		`SD;
		`SD;
		
		// deal with any halting conditions
		if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin
			$display("@@@ Unified Memory contents hex on left, decimal on right: ");
			show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
			// 8Bytes per line, 16kB total
			
			$display("@@  %t : System halted\n@@", $realtime);
			
			case(pipeline_error_status)
				LOAD_ACCESS_FAULT:  
					$display("@@@ System halted on memory error");
				HALTED_ON_WFI:          
					$display("@@@ System halted on WFI instruction");
				ILLEGAL_INST:
					$display("@@@ System halted on illegal instruction");
				default: 
					$display("@@@ System halted on unknown error code %x", 
						pipeline_error_status);
			endcase
			$display("@@@\n@@");
			print_cpi;
			#100 $finish;
		end
        debug_counter <= debug_counter + 1;
	end  // if(reset)   
end 

// int PC; 
initial begin
    $dumpvars;
    clock = 1'b0;
    reset = 1'b0;
    pipeline_error_status = NO_ERROR;       // TODO
    // Pulse the reset signal
	$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
    reset = 1'b1;

    @(posedge clock);
    @(posedge clock)
    $readmemh("program.mem", memory.unified_memory);

    @(posedge clock);
	@(posedge clock);
	`SD;
	// This reset is at an odd time to avoid the pos & neg clock edges
	
	reset = 1'b0;
	$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);
    
    @(negedge clock);
    wait_until_halt;

    pipeline_error_status = HALTED_ON_WFI;

end

endmodule




`endif // __TESTBENCH_FIN_SV__