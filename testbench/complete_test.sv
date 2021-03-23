`timescale 1ns/100ps
`ifndef __COMPLETE_TEST_SV__
`define __COMPLETE_TEST_SV__

module testbench();

    logic                       clock;
    FU_STATE_PACKET             fu_finish;
    FU_COMPLETE_PACKET [2:0]    fu_c_in;
    FU_STATE_PACKET             fu_c_stall;
    CDB_T_PACKET                cdb_t;
    logic [2:0][`XLEN-1:0]      wb_value;

    complete_stage cs(
        .fu_finish(fu_finish), 
        .fu_c_in(fu_c_in), 
        .fu_c_stall(fu_c_stall), 
        .cdb_t(cdb_t), 
        .wb_value(wb_value)
    );

    always begin
		#5;
		clock=~clock;
	end

    initial begin
		$dumpvars;
		$monitor("Time:%4.0f fu_finish:%b fu_c_stall:%b",$time,fu_finish,fu_c_stall);
		clock=0;
        ////////////////////////////////////////
        fu_c_in[0].if_take_branch = 1'b0;
        fu_c_in[0].dest_pr = `PR'b001001;
        fu_c_in[0].dest_value = `XLEN'h71a230f1;
        ////////////////////////////////////////
        fu_c_in[1].if_take_branch = 1'b1;
        fu_c_in[1].dest_pr = `PR'b101110;
        fu_c_in[1].dest_value = `XLEN'h091ec84b;
        ////////////////////////////////////////
        fu_c_in[2].if_take_branch = 1'b0;
        fu_c_in[2].dest_pr = `PR'b010101;
        fu_c_in[2].dest_value = `XLEN'h20a1d324;
        ////////////////////////////////////////
        fu_finish = 8'b11111111;
		@(negedge clock);
		@(negedge clock);
		
		// 1st change
		@(negedge clock);
        fu_finish = 8'b01010111;

		// 2nd change
		@(negedge clock);
        ////////////////////////////////////////
        fu_c_in[0].if_take_branch = 1'b0;
        fu_c_in[0].dest_pr = `PR'b000000;
        fu_c_in[0].dest_value = `XLEN'h00000000;
        ////////////////////////////////////////
        fu_c_in[1].if_take_branch = 1'b1;
        fu_c_in[1].dest_pr = `PR'b101001;
        fu_c_in[1].dest_value = `XLEN'h8251dabe;
        ////////////////////////////////////////
        fu_c_in[2].if_take_branch = 1'b0;
        fu_c_in[2].dest_pr = `PR'b001110;
        fu_c_in[2].dest_value = `XLEN'ha8c1e910;
        ////////////////////////////////////////
		fu_finish = 8'b10100001;

        // 3rd change
		@(negedge clock);
		fu_finish = 8'b00101000;
        @(negedge clock);
        @(negedge clock);

        $display("@@@Finished\n");
		$finish;
	end


endmodule

`endif