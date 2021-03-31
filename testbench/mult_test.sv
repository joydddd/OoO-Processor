`timescale 1ns/100ps

`define TEST_MODE


module testbench;

    //general
    logic clock, reset;
    logic [31:0] cycle_count;

    logic complete_stall;
    ISSUE_FU_PACKET fu_packet_store;
    logic fu_ready;
    logic want_to_complete;
    FU_COMPLETE_PACKET fu_packet_out;

    logic [64:0] product;



    fu_mult tmp(
        .clock(clock),
        .reset(reset),
        .complete_stall(complete_stall),			// complete stage structural hazard
        .fu_packet_in(fu_packet_store),
        .fu_ready(fu_ready),			
        .want_to_complete(want_to_complete),		// TODO: deal with this value when we have more FUs
        .fu_packet_out(fu_packet_out)
    );

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
    

    task show_mult_fu;
        begin
            $display("Fu_ready: %b", fu_ready);
            $display("want_to_complete: %b", want_to_complete);
            $display("| if_take_branch | valid | halt | target_pc | dest_pr |  dest_value  | rob_entry |");
            $display("|      %1d         |   %b   |   %d  |  %8h |    %2d   |   %8h   |     %d    |",
                    fu_packet_out.if_take_branch, fu_packet_out.valid, fu_packet_out.halt, fu_packet_out.target_pc, fu_packet_out.dest_pr, fu_packet_out.dest_value, fu_packet_out.rob_entry);
        end
    endtask

    always_ff@(posedge clock) begin
        if (reset)
            cycle_count <= 0;
        else 
            cycle_count <= cycle_count + 1;
    end

    always_ff@(negedge clock) begin
        $display("======= Cycle %2d, complete_stall: %b =======", cycle_count, complete_stall);
        show_mult_fu;
    end

    initial begin
        $dumpvars;
        clock = 1'b0;
        reset = 1'b1;
        complete_stall = 0;
        fu_packet_store.valid = 0;

        @(negedge clock)
        reset = 1'b0;

        @(posedge clock)
        fu_packet_store.valid = 1;
        fu_packet_store.op_sel.mult = MUL;
        fu_packet_store.NPC = 4;
        fu_packet_store.PC = 0;
        fu_packet_store.opa_select = OPA_IS_PC;
        fu_packet_store.opb_select = OPB_IS_B_IMM;
        fu_packet_store.inst = `XLEN'h00028463;
        fu_packet_store.halt = 0;
        fu_packet_store.rob_entry = 0;
        fu_packet_store.dest_pr = 32;
        fu_packet_store.r1_value = 32'h00001f1e;
        fu_packet_store.r2_value = 32'hffffffff;
        product = fu_packet_store.r2_value * fu_packet_store.r1_value;
        $display("Expected product: %h", product[31:0]);
        @(posedge clock)
        fu_packet_store.valid = 0;
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)



        @(posedge clock)
        #1;
        fu_packet_store.valid = 1;
        complete_stall = 1;
        fu_packet_store.r1_value = 32'h89301f1e;
        fu_packet_store.r2_value = 32'hffffffff;
        product = fu_packet_store.r2_value * fu_packet_store.r1_value;
        $display("Expected product: %h", product[31:0]);
        @(posedge clock)
        fu_packet_store.valid = 0;
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        #1;
        complete_stall = 0;
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        @(posedge clock)
        $finish;
    end

endmodule
