
module retire_stage (
	input           ROB_ENTRY_PACKET[2:0] 	rob_head_entry, // connected to ROB::retire_entry
    input           [`ROB-1:0]              fl_distance,  //connected to FL, how many reg-write insts are in ROB
    output  logic                           BPRecoverEN,
    output  logic   [`XLEN-1:0]             target_pc,
	/* write Archi Map table */
    input           [31:0][`PR-1:0]         archi_maptable,
	output          [2:0][`PR-1:0]			map_ar_pr, 
	output          [2:0][4:0]			    map_ar,
    /* write Map table */
    output  logic   [31:0][`PR-1:0]         recover_maptable,
	/*write Free list */
    input           [`ROB-1:0]              FreelistHead,
	output  logic   [2:0]				    Retire_EN,    // connect to arch map table and freelist the same time
    output          [2:0][`PR-1:0] 		    Tolds_out,   //3 Tolds connected to Freelist,
    output  logic   [`ROB-1:0]              BPRecoverHead,
    /* retire SQ */
    input           [2:0]                   sq_stall,
    output logic    [2:0]                   SQRetireEN,
    /* halt the program */
    output logic                            halt,
    output logic [1:0]                      inst_count
);


logic [`ROB-1:0] fl_recover_dis;
logic [`ROB-1:0] fl_recover_dis_stage1;
logic [`ROB-1:0] fl_recover_dis_stage2;
logic [`ROB-1:0] fl_recover_dis_stage3;

logic is_write_bit2;
logic is_write_bit1;
logic is_write_bit0;

assign map_ar[2] = rob_head_entry[2].arch_reg;
assign map_ar[1] = rob_head_entry[1].arch_reg;
assign map_ar[0] = rob_head_entry[0].arch_reg;

assign map_ar_pr[2] = rob_head_entry[2].Tnew;
assign map_ar_pr[1] = rob_head_entry[1].Tnew;
assign map_ar_pr[0] = rob_head_entry[0].Tnew;

assign Tolds_out[2] = rob_head_entry[2].Told;
assign Tolds_out[1] = rob_head_entry[1].Told;
assign Tolds_out[0] = rob_head_entry[0].Told;


assign BPRecoverHead = (FreelistHead - fl_recover_dis);

assign fl_recover_dis_stage1 = rob_head_entry[2].arch_reg==5'b0 ? fl_distance : fl_distance - 1;
assign fl_recover_dis_stage2 = rob_head_entry[1].arch_reg==5'b0 ? fl_recover_dis_stage1 : fl_recover_dis_stage1 - 1;
assign fl_recover_dis_stage3 = rob_head_entry[0].arch_reg==5'b0 ? fl_recover_dis_stage2 : fl_recover_dis_stage2 - 1;

assign is_write_bit2 = rob_head_entry[2].arch_reg==5'b0 ? 1'b0 : 1'b1;
assign is_write_bit1 = rob_head_entry[1].arch_reg==5'b0 ? 1'b0 : 1'b1;
assign is_write_bit0 = rob_head_entry[0].arch_reg==5'b0 ? 1'b0 : 1'b1;


logic [2:0]         retire_valid;

always_comb begin
    Retire_EN = 3'b000;
    SQRetireEN = 3'b000;
    BPRecoverEN = 1'b0;
    retire_valid = 3'b000;
    halt = 0;
    fl_recover_dis = fl_distance;
    recover_maptable = archi_maptable;
    target_pc = 0;
    if (rob_head_entry[2].completed==1'b1 && !(rob_head_entry[2].is_store && sq_stall[2]==1'b1) && rob_head_entry[2].precise_state_need==1'b1) begin
        BPRecoverEN = 1'b1;
        target_pc = rob_head_entry[2].target_pc;
        recover_maptable[rob_head_entry[2].arch_reg] = rob_head_entry[2].Tnew;
        fl_recover_dis = fl_recover_dis_stage1;
        Retire_EN[2] = is_write_bit2;
        SQRetireEN[2] = rob_head_entry[2].is_store;
        retire_valid[2] = 1;
    end
    else if (rob_head_entry[2].completed==1'b1 && !(rob_head_entry[2].is_store && sq_stall[2]==1'b1) && rob_head_entry[2].precise_state_need==1'b0) begin
        recover_maptable[rob_head_entry[2].arch_reg] = rob_head_entry[2].Tnew;
        Retire_EN[2] = is_write_bit2;
        SQRetireEN[2] = rob_head_entry[2].is_store;
        retire_valid[2] = 1;
        halt = rob_head_entry[2].halt;
        if (rob_head_entry[2].halt==1'b0 && rob_head_entry[1].completed==1'b1 && !(rob_head_entry[1].is_store && sq_stall[1]==1'b1) && rob_head_entry[1].precise_state_need==1'b1) begin
            BPRecoverEN = 1'b1;
            target_pc = rob_head_entry[1].target_pc;
            recover_maptable[rob_head_entry[1].arch_reg] = rob_head_entry[1].Tnew;
            Retire_EN[1] = is_write_bit1;
            SQRetireEN[1] = rob_head_entry[1].is_store;
            retire_valid[1] = 1;
            fl_recover_dis = fl_recover_dis_stage2;
        end
        else if (rob_head_entry[2].halt==1'b0 && rob_head_entry[1].completed==1'b1 && !(rob_head_entry[1].is_store && sq_stall[1]==1'b1) && rob_head_entry[1].precise_state_need==1'b0) begin
            recover_maptable[rob_head_entry[1].arch_reg] = rob_head_entry[1].Tnew;
            Retire_EN[1] = is_write_bit1;
            SQRetireEN[1] = rob_head_entry[1].is_store;
            retire_valid[1] = 1;
            halt = rob_head_entry[1].halt;
            if (rob_head_entry[1].halt==1'b0 && rob_head_entry[0].completed==1'b1 && !(rob_head_entry[0].is_store && sq_stall[0]==1'b1) && rob_head_entry[0].precise_state_need==1'b1) begin
                BPRecoverEN = 1'b1;
                target_pc = rob_head_entry[0].target_pc;
                recover_maptable[rob_head_entry[0].arch_reg] = rob_head_entry[0].Tnew;
                Retire_EN[0] = is_write_bit0;
                SQRetireEN[0] = rob_head_entry[0].is_store;
                retire_valid[0] = 1;
                fl_recover_dis = fl_recover_dis_stage3;
            end
            else if (rob_head_entry[1].halt==1'b0 && rob_head_entry[0].completed==1'b1 && !(rob_head_entry[0].is_store && sq_stall[0]==1'b1) && rob_head_entry[0].precise_state_need==1'b0) begin
                Retire_EN[0] = is_write_bit0;
                SQRetireEN[0] = rob_head_entry[0].is_store;
                retire_valid[0] = 1;
                halt = rob_head_entry[0].halt;
            end
        end
    end
end

assign inst_count = retire_valid[0] + retire_valid[1] + retire_valid[2];

endmodule
