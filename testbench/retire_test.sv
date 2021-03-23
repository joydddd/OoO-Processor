`timescale 1ns/100ps
`ifndef __RETIRE_TEST_SV__
`define __RETIRE_TEST_SV__

`define TEST_MODE 


module testbench;
    logic                                       clock;
    logic                                       reset;
    integer                                     cycle_count;   
    ROB_ENTRY_PACKET    [2:0]                   rob_head_entry; // connected to ROB::retire_entry
    logic               [`ROB-1:0]              fl_distance;  //connected to FL, how many reg-write insts are in ROB
    logic                                       BPRecoverEN;
    logic               [`XLEN-1]               target_pc;
	/* write Archi Map table */
    logic               [31:0][`PR-1:0]         archi_maptable;
    logic               [2:0][`PR-1:0]			map_ar_pr;
    logic               [2:0][4:0]			    map_ar;
    /* write Map table */
    logic               [31:0][`PR-1:0]         recover_maptable;
	/*write Free list */
    logic               [`ROB-1:0]              FreelistHead;
    logic               [2:0]				    Retire_EN;    // connect to arch map table and freelist the same time
    logic               [2:0][`PR-1:0] 		    Tolds_out;   //3 Tolds connected to Freelist,
    logic               [`ROB-1:0]              BPRecoverHead;

retire_stage uut(
    .rob_head_entry(rob_head_entry),
    .fl_distance(fl_distance),
    .BPRecoverEN(BPRecoverEN),
    .target_pc(target_pc),
    .archi_maptable(archi_maptable),
    .map_ar_pr(map_ar_pr),
    .map_ar(map_ar),
    .recover_maptable(recover_maptable),
    .FreelistHead(FreelistHead),
    .Retire_EN(Retire_EN),
    .Tolds_out(Tolds_out),
    .BPRecoverHead(BPRecoverHead)
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



//////////////////////////////////////////////////////////////
//////////////                  DISPLAY
/////////////////////////////////////////////////////////////
always @(negedge clock) begin
    if (!reset)  begin
        $display("====  Cycle  %4d  ====", cycle_count);
        show_input;
        $display("fl_distance: %d      Head: %d", fl_distance, FreelistHead);
        $display("Output:");
        $display("Retire_EN: %b    %b    %b", Retire_EN[2], Retire_EN[1], Retire_EN[0]);
        $display("arch maptable AR: %d    %d    %d", map_ar[2], map_ar[1], map_ar[0]);
        $display("arch maptable PR: %d    %d    %d", map_ar_pr[2], map_ar_pr[1], map_ar_pr[0]);
        $display("Tolds out: %d    %d    %d", Tolds_out[2], Tolds_out[1], Tolds_out[0]);
        $display("BPRecoverEN: %b,  target_pc: %d", BPRecoverEN, target_pc);
        $display("BPRecoverHead:    %d", BPRecoverHead);
        show_mpt_entry;
    end
end

task show_input;
    begin
        $display("=====   Input   =====");
        for (int i=2; i>=0; --i) begin
            $display("Entry No. %3d: valid-%b,   Tnew-%d,    Told-%d,    AR-%d,    exception-%b,    target_pc-%d,    completed-%b",
            i, rob_head_entry[i].valid, rob_head_entry[i].Tnew, rob_head_entry[i].Told, rob_head_entry[i].arch_reg, rob_head_entry[i].precise_state_need, rob_head_entry[i].target_pc,
            rob_head_entry[i].completed);
        end
    end
endtask

task show_mpt_entry;
    begin
        $display("=====   Recover Maptable Entry   =====");
        $display("| AR |   PR   |");
        for (int i = 0; i < 32; i++) begin
            $display("| %2d |   %d   |", i, recover_maptable[i]);
        end
        $display(" ");
    end
endtask


//////////////////////////////////////////////////////////
///////////////         SET      
/////////////////////////////////////////////////////////

task set_rob_in;
    input   int             i;
    input                   valid;
    input   [`PR-1:0]       Tnew;
    input   [`PR-1:0]       Told;
    input   [4:0]           arch_reg;
    input                   exception;
    input   [`XLEN-1:0]     target_pc;
    input                   completed;   
    begin
        rob_head_entry[i].valid = valid;
        rob_head_entry[i].Tnew = Tnew;
        rob_head_entry[i].Told = Told;
        rob_head_entry[i].arch_reg = arch_reg;
        rob_head_entry[i].precise_state_need = exception;
        rob_head_entry[i].target_pc = target_pc;
        rob_head_entry[i].completed = completed;
    end
endtask


task set_armpt;
        begin
            for (int i=0; i<32; ++i) begin
                archi_maptable[i] = i;
            end
        end
endtask



initial begin
    $dumpvars;
    clock = 1'b0;
    reset = 1'b1;
    FreelistHead = 5'd10;
    set_armpt;
    fl_distance = 6;
    @(posedge clock)
    @(posedge clock)
    reset = 1'b0;
    set_rob_in(2,1,32,7,7,0,0,1);
    set_rob_in(1,1,0,0,0,0,0,1);
    set_rob_in(0,1,33,8,8,0,0,1);
    @(posedge clock)
    set_rob_in(2,1,34,9,9,0,0,1);
    set_rob_in(1,1,0,0,0,0,0,1);
    set_rob_in(0,1,35,10,20,0,0,0);
    @(posedge clock)
    set_rob_in(2,1,36,11,11,0,0,1);
    set_rob_in(1,1,0,0,0,0,0,1);
    set_rob_in(0,1,37,12,12,1,365,1);
    @(posedge clock)
    set_rob_in(2,1,38,13,13,0,0,1);
    set_rob_in(1,1,0,0,0,0,0,0);
    set_rob_in(0,1,39,14,14,1,365,1);
    @(posedge clock)
    set_rob_in(2,1,40,15,15,0,0,1);
    set_rob_in(1,1,41,16,16,1,738,1);
    set_rob_in(0,1,42,17,18,0,0,1);
    @(posedge clock)
    @(posedge clock)

    
    $display("@@@Pass: test finished");
    $finish;
end

endmodule




`endif // __PIPE_TEST_SV__