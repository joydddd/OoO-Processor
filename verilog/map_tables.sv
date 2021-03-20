`define TEST_MODE 

module map_table(
    input 					            clock,
    input 					            reset,
    input 		    [31:0][`PR-1:0] 	archi_maptable,
    input 					            BPRecoverEN,
    input 		    CDB_T_PACKET 	    cdb_t_in,
    input 		    [2:0][`PR-1:0]		maptable_new_pr, 
    input 		    [2:0][4:0]		    maptable_new_ar,
    input 		    [2:0][4:0]		    reg1_ar,
    input		    [2:0][4:0]		    reg2_ar,
    output logic 	[2:0][`PR-1:0] 		reg1_tag,
    output logic 	[2:0][`PR-1:0] 		reg2_tag,
    output logic 	[2:0]			    reg1_ready,
    output logic	[2:0]			    reg2_ready,
    output logic	[2:0][`PR-1:0] 		Told_out
    `ifdef TEST_MODE
    , output logic [31:0][`PR-1:0] map_array_disp,
      output logic [31:0] ready_array_disp
    `endif
);

    //The registers inside map_table
    logic [31:0][`PR-1:0] map_array;
    logic [31:0][`PR-1:0] map_array_next;
    logic [31:0] ready_array;
    logic [31:0] ready_array_next;
    logic [31:0][`PR-1:0] map_array_reset;
    logic [31:0] ready_array_reset;
    logic [31:0][`PR-1:0] map_array_PS;
    logic [31:0] ready_array_PS;

    `ifdef TEST_MODE
    assign map_array_disp = map_array;
    assign ready_array_disp = ready_array;
    `endif

    always_comb begin : Compute_reset
        for (int i = 0; i < 32; i++) begin
            map_array_reset[i] = i;
            ready_array_reset[i] = 1'b1;
        end
    end

    always_comb begin : Precise_stage
        map_array_PS = archi_maptable;
        ready_array_PS = 32'hffffffff;
        /* TODO: There must be someting */
    end


    always_ff @( posedge clock ) begin : Map_table_reg
        if (reset) begin
            map_array <= `SD map_array_reset;
            ready_array <= `SD ready_array_reset;
        end
        else if (BPRecoverEN) begin
            map_array <= `SD map_array_PS;
            ready_array <= `SD ready_array_PS;
        end
        else begin
            map_array <= `SD map_array_next;
            ready_array <= `SD ready_array_next;
        end
    end

    always_comb begin : Lookup_logic
        for (int i = 0; i < 3; i++) begin
            reg1_tag[i] = map_array[reg1_ar[i]];
            reg2_tag[i] = map_array[reg2_ar[i]];
            reg1_ready[i] = ready_array[reg1_ar[i]];
            reg2_ready[i] = ready_array[reg2_ar[i]];
        end
    end

    always_comb begin : Update_logic
        map_array_next = map_array;
        ready_array_next = ready_array;
        for (int i = 0; i < 3; i++) begin
            map_array_next[maptable_new_ar[i]] = maptable_new_pr[i];
            Told_out[i] = map_array[maptable_new_ar[i]];
            if (maptable_new_ar[i]!=0) begin
                ready_array_next[maptable_new_ar[i]] = 1'b0;
            end
        end
        for (int j = 0; j < 32; j++) begin
            if (map_array[j]==cdb_t_in.t0) begin
                ready_array_next[j] = 1'b1;
            end
            else if (map_array[j]==cdb_t_in.t1) begin
                ready_array_next[j] = 1'b1;
            end
            else if (map_array[j]==cdb_t_in.t2) begin
                ready_array_next[j] = 1'b1;
            end
        end
    end

endmodule


module arch_maptable(
    input 					        clock,
    input 					        reset,
	input 		    [2:0][`PR-1:0] 	Tnew_in,
	input 		    [2:0][4:0] 		Retire_AR,
	input 		    [2:0] 			Retire_EN,
	output logic    [31:0][`PR-1:0] archi_maptable
);

    logic [31:0][`PR-1:0] archi_maptable_reset;
    logic [31:0][`PR-1:0] archi_maptable_next;

    always_comb begin : Compute_reset
        for (int i = 0; i < 32; i++) begin
            archi_maptable_reset[i] = i;
        end
    end

    always_ff @( posedge clock ) begin : Arch_maptable_reg
        if (reset) begin
            archi_maptable <= `SD archi_maptable_reset;
        end
        else begin
            archi_maptable <= `SD archi_maptable_next;
        end
    end

    always_comb begin : Update_logic
        archi_maptable_next = archi_maptable;
        for (int i = 0; i < 3 ; i++) begin
            if (Retire_EN[i]==1'b1) begin
                archi_maptable_next[Retire_AR[i]] = Tnew_in[i];
            end
        end
    end

endmodule


