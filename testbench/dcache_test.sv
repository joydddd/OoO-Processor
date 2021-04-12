`timescale 1ns/100ps
`ifndef __DCACHE_TEST_SV__
`define __DCACHE_TEST_SV__

`define TEST_MODE 


module testbench;
    logic   clock;
    logic   reset;
    integer cycle_count;

    /* with mem_controller */
    logic   [3:0] Ctlr2proc_response;
    logic  [63:0] Ctlr2proc_data;
    logic   [3:0] Ctlr2proc_tag;

    logic [1:0] dcache2ctlr_command;
    logic [`XLEN-1:0] dcache2ctlr_addr;
    logic [63:0] dcache2ctlr_data;
  

    /* with SQ */
    SQ_ENTRY_PACKET [2:0] sq_in;
    logic [2:0] sq_stall;

    /* with Load-FU/LQ */
    logic [1:0] [`XLEN-1:0] ld_addr_in;   // This addr is word aligned !
    logic [1:0] ld_start;
    logic [1:0] is_hit;
    logic [1:0] [`XLEN-1:0] ld_data;    //valid if hit
    logic [1:0] broadcast_fu;
    logic [`XLEN-1:0] broadcast_data;

    `ifdef TEST_MODE
      logic [31:0] [63:0] cache_data_disp;
      logic [31:0] [7:0] cache_tags_disp;
      MHSRS_ENTRY_PACKET [`MHSRS_W-1:0] MHSRS_disp;
      logic [`MHSRS-1:0] head_pointer;
      logic [`MHSRS-1:0] issue_pointer;
      logic [`MHSRS-1:0] tail_pointer;
      logic [31:0]       valids_disp;
    `endif

    dcache dche(
        .clock(clock),
        .reset(reset),
        .Ctlr2proc_response(Ctlr2proc_response),
        .Ctlr2proc_data(Ctlr2proc_data),
        .Ctlr2proc_tag(Ctlr2proc_tag),
        .dcache2ctlr_command(dcache2ctlr_command),
        .dcache2ctlr_addr(dcache2ctlr_addr),
        .dcache2ctlr_data(dcache2ctlr_data),
        .sq_in(sq_in),
        .sq_stall(sq_stall),
        .ld_addr_in(ld_addr_in),
        .ld_start(ld_start),
        .is_hit(is_hit),
        .ld_data(ld_data),
        .broadcast_fu(broadcast_fu),
        .broadcast_data(broadcast_data)
        `ifdef TEST_MODE
        , .cache_data_disp(cache_data_disp)
        , .cache_tags_disp(cache_tags_disp)
        , .valids_disp(valids_disp)
        , .MHSRS_disp(MHSRS_disp)
        , .head_pointer(head_pointer)
        , .issue_pointer(issue_pointer)
        , .tail_pointer(tail_pointer)
        `endif
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

task show_cache;
    begin
        $display("=====   Cache ram   =====");
        $display("|  Entry(idx) |      Tag |             data |");
        for (int i=0; i<32; ++i) begin
            $display("| %d | %b | %h |", i, cache_tags_disp[i], cache_data_disp[i]);
        end
        $display("-------------------------------------------------");
    end
endtask

task show_RS;
    begin
        $display("=====   MHSRS   =====");
        $display("head: %d, issue: %d, tail: %d", head_pointer, issue_pointer, tail_pointer);
        $display("|         No. |                              addr  |command|mem_tag|left_or_right|            data |issued|");
        for (int i = 0; i < 16; i++) begin
            $display("| %d |  %b  |     %d |    %d |           %b | %h | %b |", i, MHSRS_disp[i].addr, MHSRS_disp[i].command, MHSRS_disp[i].mem_tag, MHSRS_disp[i].left_or_right, MHSRS_disp[i].data, MHSRS_disp[i].issued);
        end
        $display("----------------------------------------------------------------- ");
    end
endtask

task show_input;
    begin
        $display("=====   Input   =====");
        $display("m_response: %d,  m_data: %h,  m_tag: %d", Ctlr2proc_response, Ctlr2proc_data, Ctlr2proc_tag);
        $display("Load_input");
        $display("| No.|                         addr_in |start|");
        for (int i=1; i>=0; --i) begin
            $display("| %1d: | %b | %b |", i, ld_addr_in[i], ld_start[i]);
        end
        $display("----------");
        $display("Store_input");
        $display("|No.| ready |usebytes|                             addr |     data |");
        for (int i=2; i>=0; --i) begin
            $display("| %1d |     %b |   %b | %b | %h |", i, sq_in[i].ready, sq_in[i].usebytes, sq_in[i].addr, sq_in[i].data);
        end
        $display("----------------------------------------------------------------- ");
    end
endtask

task show_output;
    begin
        $display("=====   Output   =====");
        $display("m_command: %d,  m_addr: %b,  m_data: %h", dcache2ctlr_command, dcache2ctlr_addr, dcache2ctlr_data);
        $display("Load_output");
        $display("| No.| is_hit |  ld_data |");
        for (int i=1; i>=0; --i) begin
            $display("| %1d: |      %b | %h |", i, is_hit[i], ld_data[i]);
        end
        $display("---------------------");
        $display("broadcast_fu : %d ,   broadcast_data : %h", broadcast_fu, broadcast_data);
        $display("SQ stall: %b", sq_stall);
    end
endtask


always @(negedge clock) begin
    if (!reset)  begin
        $display("====  Cycle  %4d  ====", cycle_count);
        show_cache();
        show_RS();
        show_input();
        show_output();
        $display("--------------------------------------------------------------------------------");
    end
end





//////////////////////////////////////////////////////////
///////////////         SET      
/////////////////////////////////////////////////////////

task set_mem_in;
    input   [3:0]                m_response;
    input   [63:0]               m_data;
    input   [3:0]                m_tag;
    begin
        Ctlr2proc_response = m_response;
        Ctlr2proc_data = m_data;
        Ctlr2proc_tag = m_tag;
    end
endtask


task set_SQ_in;
    input int i;
    input ready;
    input [3:0] usebytes;
    input [`XLEN-1:0] addr;
    input [31:0] data;
        begin
            sq_in[i].ready = ready;
            sq_in[i].usebytes = usebytes;
            sq_in[i].addr = addr;
            sq_in[i].data = data;
        end
endtask

task set_Ld_in;
    input int i; 
    input [`XLEN-1:0] ld_addr;
    input ld_startt;
        begin
            ld_addr_in[i] = ld_addr;
            ld_start[i] = ld_startt;
        end
endtask



initial begin
    $dumpvars;
    clock = 1'b0;
    reset = 1'b1;

    @(posedge clock)
    @(posedge clock)
    reset = 1'b0;
    set_Ld_in(1, 32'b00000000000000000000000100001100,1);
    set_Ld_in(0, 32'b00000000000000000000000100010000,1);
    set_SQ_in(2,1,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_SQ_in(1,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_SQ_in(0,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_mem_in(0, 0, 0);

    @(posedge clock)
    set_Ld_in(1, 32'b00000000000000000000000100001100,1);
    set_Ld_in(0, 32'b00000000000000000000000100010000,0);
    set_SQ_in(2,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_SQ_in(1,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_SQ_in(0,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_mem_in(1, 0, 0);
    

    @(posedge clock)
    set_Ld_in(1, 32'b00000000000000000000000100001100,0);
    set_Ld_in(0, 32'b00000000000000000000000100010000,0);
    set_SQ_in(2,1,4'b1100, 32'b00000000000000000000001000011000,32'h43215678);
    set_SQ_in(1,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_SQ_in(0,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_mem_in(2, 0, 0);
    @(posedge clock)
    set_SQ_in(2,0,4'b1100, 32'b00000000000000000000001000011000,32'h43215678);
    set_SQ_in(1,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_SQ_in(0,0,4'b1100, 32'b00000000000000000000000100011000,32'h12345678);
    set_mem_in(3, 64'h5555555555555555, 1);
    @(posedge clock)
    set_mem_in(4, 64'h4444444444444444, 2); 
    @(posedge clock)
    set_mem_in(0, 64'h5555555555555555, 3); 
    @(posedge clock)

    
    $display("@@@Pass: test finished");
    $finish;
end

endmodule




`endif // __PIPE_TEST_SV__