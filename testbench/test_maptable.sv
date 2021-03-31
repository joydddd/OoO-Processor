`timescale 1ns/100ps
`ifndef __TEST_MAPTABLE_SV__
`define __TEST_MAPTABLE_SV__

`define TEST_MODE 



/* import map table simulator */ 
import "DPI-C" function void mt_init();
import "DPI-C" function int mt_look_up(int i);
import "DPI-C" function int mt_look_up_ready(int i);
import "DPI-C" function void mt_map(int ar, int pr);


module testbench;
logic clock, reset;

logic   [31:0][`PR-1:0] 	archi_maptable;
logic 					    BPRecoverEN;
CDB_T_PACKET 	            cdb_t_in;
logic   [2:0][`PR-1:0]		maptable_new_pr;
logic   [2:0][4:0]		    maptable_new_ar;
logic   [2:0][4:0]		    reg1_ar;
logic	[2:0][4:0]		    reg2_ar;
logic 	[2:0][`PR-1:0] 		reg1_tag;
logic 	[2:0][`PR-1:0] 		reg2_tag;
logic 	[2:0]			    reg1_ready;
logic	[2:0]			    reg2_ready;
logic	[2:0][`PR-1:0] 		Told_out;
logic   [31:0][`PR-1:0]     map_array_disp;
logic   [31:0]              ready_array_disp;
integer cycle_count;


map_table mpt (
    .archi_maptable(archi_maptable), .BPRecoverEN(BPRecoverEN), .cdb_t_in(cdb_t_in), .maptable_new_pr(maptable_new_pr), 
    .maptable_new_ar(maptable_new_ar), .reg1_ar(reg1_ar), .reg2_ar(reg2_ar), .reg1_tag(reg1_tag), .reg2_tag(reg2_tag), 
    .reg1_ready(reg1_ready), .reg2_ready(reg2_ready), .Told_out(Told_out), .clock(clock), .reset(reset),
    .map_array_disp(map_array_disp), .ready_array_disp(ready_array_disp)
);

/* clock */
always begin
	#(`VERILOG_CLOCK_PERIOD/2.0);
	clock = ~clock;
end

always_ff@(posedge clock) begin
    if (reset)
        cycle_count <= 0;
    else 
        cycle_count <= cycle_count + 1;
end


////////////////////////////////////////////////////////////
/////////////       SIMULATORS
///////////////////////////////////////////////////////////


/* map table simulator */
/*
always @(posedge clock) begin
    if (reset) begin
        mt_init();
    end else begin
        mt_map(maptable_allocate_ar_out, maptable_allocate_pr_out);
    end
end
always @(negedge clock) begin
    maptable_old_pr_debug = mt_look_up(maptable_allocate_ar_out);
    maptable_reg1_pr_debug = mt_look_up(maptable_lookup_reg1_ar_out);
    maptable_reg2_pr_debug = mt_look_up(maptable_lookup_reg2_ar_out);
    maptable_reg1_ready_debug = mt_look_up_ready(maptable_lookup_reg1_ar_out);
    maptable_reg2_ready_debug = mt_look_up_ready(maptable_lookup_reg2_ar_out);
end
*/


//////////////////////////////////////////////////////////////
//////////////                  DISPLAY
/////////////////////////////////////////////////////////////
always @(negedge clock) begin
    if (!reset)  begin
        $display("====  Cycle  %4d  ====", cycle_count);
        show_mpt_entry;
        show_mpt_in_out;
        show_cdb;
    end
end

task show_mpt_in_out;
    begin
        $display("=====   Maptable In/Out   =====");
        $display("| AR2 | AR1 | AR0 |");
        $display("| %d  | %d  | %d  |", maptable_new_ar[2], maptable_new_ar[1], maptable_new_ar[0]);
        $display("| PR2 | PR1 | PR0 |");
        $display("| %d  | %d  | %d  |", maptable_new_pr[2], maptable_new_pr[1], maptable_new_pr[0]);
        $display("| Told2 | Told1 | Told0 |");
        $display("|   %d  |   %d  |   %d  |", Told_out[2], Told_out[1], Told_out[0]);
        $display("| Reg1_AR2 | Reg1_AR1 | Reg1_AR0 |");
        $display("|    %d    |    %d    |    %d    |", reg1_ar[2], reg1_ar[1], reg1_ar[0]);
        $display("| Reg1_T+2 | Reg1_T+1 | Reg1_T+0 |");
        $display("| %d     %b | %d     %b | %d     %b |", reg1_tag[2], reg1_ready[2], reg1_tag[1], reg1_ready[1], reg1_tag[0], reg1_ready[0]);
        $display("| Reg2_AR2 | Reg2_AR1 | Reg2_AR0 |");
        $display("|    %d    |    %d    |    %d    |", reg2_ar[2], reg2_ar[1], reg2_ar[0]);
        $display("| Reg2_T+2 | Reg2_T+1 | Reg2_T+0 |");
        $display("| %d     %b | %d     %b | %d     %b |", reg2_tag[2], reg2_ready[2], reg2_tag[1], reg2_ready[1], reg2_tag[0], reg2_ready[0]);
    end
endtask


task show_cdb;
        begin
            $display("=====   CDB_T   =====");
            $display("|  CDB_T  |  %d  |  %d  |  %d  |", cdb_t_in.t0, cdb_t_in.t1, cdb_t_in.t2);
        end
endtask


task show_mpt_entry;
    begin
        $display("=====   Maptable Entry   =====");
        $display("| AR |   PR   | ready |");
        for (int i = 0; i < 32; i++) begin
            $display("| %2d |   %d   |   %b  |", i, map_array_disp[i], ready_array_disp[i]);
        end
        $display(" ");
    end
endtask


//////////////////////////////////////////////////////////
///////////////         SET      
/////////////////////////////////////////////////////////

task set_mpt_in;
    input   int             i;
    input   [4:0]		    dispatch_ar;
    input   [`PR-1:0]		dispatch_pr;
    input   [4:0]		    rg1_ar;
    input   [4:0]		    rg2_ar;
    begin
        maptable_new_pr[i] = dispatch_pr;
        maptable_new_ar[i] = dispatch_ar;
        reg1_ar[i] = rg1_ar;
        reg2_ar[i] = rg2_ar;
    end
endtask


task set_cdb_packet;
        input [`PR-1:0] t0;
        input [`PR-1:0] t1;
        input [`PR-1:0] t2;
        begin
            cdb_t_in.t0 = t0;
            cdb_t_in.t1 = t1;
            cdb_t_in.t2 = t2;
        end
endtask



initial begin
    $dumpvars;
    clock = 1'b0;
    reset = 1'b1;
    BPRecoverEN = 1'b0;
    archi_maptable = 0;
    cdb_t_in = 0;
    @(posedge clock)
    
    @(posedge clock)
    reset = 1'b0;
    set_mpt_in(2,1,33,15,16);
    set_mpt_in(1,2,34,17,0);
    set_mpt_in(0,3,35,15,0);


    @(posedge clock)
    set_mpt_in(2,4,36,15,16);
    set_mpt_in(1,5,37,17,30);
    set_mpt_in(0,0,0,0,0);

    @(posedge clock)
    set_mpt_in(2,15,63,15,16);
    set_mpt_in(1,16,62,17,0);
    set_mpt_in(0,17,61,0,0);
    set_cdb_packet(33,34,0);

    @(posedge clock)
    set_mpt_in(2,11,40,35,16);
    set_mpt_in(1,11,41,17,0);
    set_mpt_in(0,11,42,0,0);
    set_cdb_packet(35,63,0);


    @(posedge clock)
    @(posedge clock)
    @(posedge clock)
    BPRecoverEN = 1'b1;
    @(posedge clock)
    @(posedge clock)
    
    
    $display("@@@Pass: test finished");
    $finish;
end

endmodule




`endif // __PIPE_TEST_SV__