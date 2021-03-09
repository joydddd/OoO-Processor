module testbench;

    logic clock;
    logic reset;
    RS_IN_PACKET  [2:0] rs_in;
    CDB_T_PACKET        cdb_t;
    FU_STATE_PACKET     fu_ready;

    RS_S_PACKET   [2:0] issue_insts;
    logic [2:0]         struct_stall;

    RS rs0(
        .clock, .reset,
        .rs_in, .cdb_t, .fu_ready,
        .issue_insts, .struct_stall
    );

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end

    task show_cdb;
        begin
            $display("=====   CDB_T   =====");
            $display("|  CDB_T  |  %d  |  %d  |  %d  |", cdb_t.t0, cdb_t.t1, cdb_t.t2);
        end
    endtask

    task set_cdb_packet;
        input [`PR-1:0] t0;
        input [`PR-1:0] t1;
        input [`PR-1:0] t2;
        begin
            cdb_t.t0 = t0;
            cdb_t.t1 = t1;
            cdb_t.t2 = t2;
        end
    endtask

    task show_rs_in;
        begin
            $display("=====   RS_IN Packet   =====");
            $display("| WAY | valid | fu_sel | op_sel |       npc  |         pc |       inst | halt |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |     %b |      %1d |      %1d |  %h  |  %h  |  %h  |   %b  |",
                    i, rs_in[i].valid, rs_in[i].fu_sel, rs_in[i].op_sel, rs_in[i].NPC, rs_in[i].PC, rs_in[i].inst, rs_in[i].halt
                );
            end
            $display("| WAY | dest_pr | reg1_pr | reg1_ready | reg2_pr | reg2_ready |");
            for (int i=0; i < 3; i++) begin
                $display("|  %1d  |      %2d |      %2d |          %b |     %2d  |          %b |",
                    i, rs_in[i].dest_pr, rs_in[i].reg1_pr, rs_in[i].reg1_ready, rs_in[i].reg2_pr, rs_in[i].reg2_ready
                );
            end
        end
    endtask

    task set_rs_in_packet;
        input integer rs_in_i;

        input valid;
        input fu_sel;
        input op_sel;
        input npc;
        input pc;
        input inst;
        input halt;

        input dest_pr;
        input reg1_pr;
        input reg1_ready;
        input reg2_pr;
        input reg2_ready;

        begin
            rs_in[rs_in_i].valid = valid;
            rs_in[rs_in_i].fu_sel = fu_sel;
            rs_in[rs_in_i].op_sel = op_sel;
            rs_in[rs_in_i].NPC = npc;
            rs_in[rs_in_i].PC = pc;
            rs_in[rs_in_i].inst = inst;
            rs_in[rs_in_i].halt = halt;
            rs_in[rs_in_i].dest_pr = dest_pr;
            rs_in[rs_in_i].reg1_pr = reg1_pr;
            rs_in[rs_in_i].reg1_ready = reg1_ready;
            rs_in[rs_in_i].reg2_pr = reg2_pr;
            rs_in[rs_in_i].reg2_ready = reg2_ready;
        end
    endtask

    task show_fu_state;
        begin
            $display("=====   FU State   =====");
            $display("alu1: %b  alu2: %b  alu3: %b  sl1: %b  sl2: %b  mult1: %b  mult2: %b  branch: %b",
                fu_ready.alu_1, fu_ready.alu_2, fu_ready.alu_3, fu_ready.storeload_1, fu_ready.storeload_2, fu_ready.mult_1, fu_ready.mult_2, fu_ready.branch);
        end
    endtask

    task set_fu_ready;
        input [7:0] ready_bits;
        begin
            fu_ready = ready_bits;
        end
    endtask

    initial begin
        clock = 1'b0;
		reset = 1'b0;

        $display("@@Initialize");
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);

        set_cdb_packet(0, 0, 0);
        set_rs_in_packet(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        set_rs_in_packet(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        set_rs_in_packet(2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        show_cdb();
        show_rs_in();
        show_fu_state();

        $display("@@Set input");
        set_rs_in_packet(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        set_rs_in_packet(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        set_rs_in_packet(2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        reset = 1'b0;
        $finish;
    end

endmodule