module retire_stage (
	input   ROB_ENTRY_PACKET[2:0] 	rob_head_entry, // connected to ROB::retire_entry
	/* write Archi Map table */
	output  [2:0][`PR-1:0]			map_ar_pr, 
	output  [2:0][4:0]			    map_ar,
	/*write Free list */
	output  [2:0]				    Retire_EN,    // connect to arch map table and freelist the same time
    output  [2:0][`PR-1:0] 		    Tolds_out   //3 Tolds connected to Freelist
);

assign map_ar[2] = rob_head_entry[2].arch_reg;
assign map_ar[1] = rob_head_entry[1].arch_reg;
assign map_ar[0] = rob_head_entry[0].arch_reg;

assign map_ar_pr[2] = rob_head_entry[2].Tnew;
assign map_ar_pr[1] = rob_head_entry[1].Tnew;
assign map_ar_pr[0] = rob_head_entry[0].Tnew;

assign Tolds_out[2] = rob_head_entry[2].Told;
assign Tolds_out[1] = rob_head_entry[1].Told;
assign Tolds_out[0] = rob_head_entry[0].Told;

always_comb begin
    Retire_EN = 3'b000;
    if (rob_head_entry[2].completed==1'b1) begin
        Retire_EN[2] = 1'b1;
        if (rob_head_entry[1].completed==1'b1) begin
            Retire_EN[1] = 1'b1;
            if (rob_head_entry[0].completed==1'b1) begin
                Retire_EN[0] = 1'b1;
            end
        end
    end
end

endmodule


module retire_stage_ps (
	input   ROB_ENTRY_PACKET[2:0] 	rob_head_entry, // connected to ROB::retire_entry
    input   [`ROB-1:0]              ROB_ht_distance,  //connected to ROB, how many insts are in ROB
    output  BPRecoverEN,
	/* write Archi Map table */
    input   [31:0][`PR-1:0]         archi_maptable,
	output  [2:0][`PR-1:0]			map_ar_pr, 
	output  [2:0][4:0]			    map_ar,
    /* write Map table */
    output  [31:0][`PR-1:0]         recover_maptable,
	/*write Free list */
    input   [`ROB-1:0]              FreelistHead,
	output  [2:0]				    Retire_EN,    // connect to arch map table and freelist the same time
    output  [2:0][`PR-1:0] 		    Tolds_out,   //3 Tolds connected to Freelist,
    output  [`ROB-1:0]              BPRecoverHead
);

logic [`ROB-1:0] fl_recover_dis;

assign map_ar[2] = rob_head_entry[2].arch_reg;
assign map_ar[1] = rob_head_entry[1].arch_reg;
assign map_ar[0] = rob_head_entry[0].arch_reg;

assign map_ar_pr[2] = rob_head_entry[2].Tnew;
assign map_ar_pr[1] = rob_head_entry[1].Tnew;
assign map_ar_pr[0] = rob_head_entry[0].Tnew;

assign Tolds_out[2] = rob_head_entry[2].Told;
assign Tolds_out[1] = rob_head_entry[1].Told;
assign Tolds_out[0] = rob_head_entry[0].Told;

//TODO:stf?

assign BPRecoverHead = (FreelistHead + 32 - fl_recover_dis) % 32;

always_comb begin
    Retire_EN = 3'b000;
    BPRecoverEN = 1'b0;
    fl_recover_dis = ROB_ht_distance;
    recover_maptable = archi_maptable;
    if (rob_head_entry[2].completed==1'b1 && rob_head_entry[2].exception==1'b1) begin
        Retire_EN[2] = 1'b1;
        BPRecoverEN = 1'b1;
        fl_recover_dis = ROB_ht_distance - 1;
        recover_maptable[rob_head_entry[2].arch_reg] = rob_head_entry[2].Tnew;
    end
    else if (rob_head_entry[2].completed==1'b1 && rob_head_entry[2].exception==1'b0) begin
        recover_maptable[rob_head_entry[2].arch_reg] = rob_head_entry[2].Tnew;
        Retire_EN[2] = 1'b1;
        if (rob_head_entry[1].completed==1'b1 && rob_head_entry[1].exception==1'b1) begin
            Retire_EN[1] = 1'b1;
            BPRecoverEN = 1'b1;
            fl_recover_dis = ROB_ht_distance - 2;
            recover_maptable[rob_head_entry[1].arch_reg] = rob_head_entry[1].Tnew;
        end
        else if (rob_head_entry[1].completed==1'b1 && rob_head_entry[1].exception==1'b0) begin
            recover_maptable[rob_head_entry[1].arch_reg] = rob_head_entry[1].Tnew;
            Retire_EN[1] = 1'b1;
            if (rob_head_entry[0].completed==1'b1 && rob_head_entry[1].exception==1'b1) begin
                Retire_EN[0] = 1'b1;
                BPRecoverEN = 1'b1;
                fl_recover_dis = ROB_ht_distance - 3;
                recover_maptable[rob_head_entry[0].arch_reg] = rob_head_entry[0].Tnew;
            end
            else if (rob_head_entry[0].completed==1'b1 && rob_head_entry[1].exception==1'b0) begin
                Retire_EN[0] = 1'b1;
            end
        end
    end
end

endmodule


