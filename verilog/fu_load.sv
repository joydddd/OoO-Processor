`ifndef __LOAD_V__
`define __LOAD_V__

`timescale 1ns/100ps

typedef struct packet{
    FU_COMPLETE_PACKET  result; // valid bit here
    logic [`XLEN-1:0]   addr;
    logic [`LSQ-1:0]    tail_pos;
    LS_SELECT           load_sel;
    logic [3:0]		    usebytes, forward_bytes;
    logic [`XLEN-1:0]   aligned_data;
} LOAD_STAGE_REG;

typedef enum logic [1:0] {
    WAITING_INPUT = 0;
    WAITING_SQ;
    WAITING_CACHE;
    WAITING_OUTPUT;
} LOAD_STAGE_STATUS;

module fu_load(
    input                       clock,
    input                       reset,
    input                       complete_stall,
    input ISSUE_FU_PACKET       fu_packet_in,
    output logic                fu_ready,
    output logic                want_to_complete,
    output FU_COMPLETE_PACKET   fu_packet_out,

    // SQ
    output LOAD_SQ_PACKET       sq_lookup,
    input SQ_LOAD_PACKET        sq_result

    // Cache
);

LOAD_STAGE_STATUS status;
LOAD_STAGE_REG ins_reg; // the register that holds the instruction while executing 





// WAITING INPUT 
logic [`XLEN-1:0] new_addr = fu_packet_in.r1_value + `RV32_signext_Iimm(fu_packet_in.inst);

// build result packet passthrough
FU_COMPLETE_PACKET new_result_pckt;
always_comb begin
    new_result_pckt = 0;
    new_result_pckt.valid = fu_packet_in.valid;
    new_result_pckt.dest_pr = fu_packet_in.dest_pr;
    new_result_pckt.rob_entry = fu_packet_in.rob_entry;
end

// decode usebytes
logic [3:0] new_usebytes;
always_comb begin
    new_usebytes = 0; // dummy value
    case(fu_packet_in.op_sel.ls)
    LB, LBU: case(addr[1:0])
        2'b00: new_usebytes = 4'b0001;
        2'b01: new_usebytes = 4'b0010;
        2'b10: new_usebytes = 4'b0100;
        2'b11: new_usebytes = 4'b1000;
        endcase
    LH, LHU: case (addr[1:0])
        2'b00: new_usebytes = 4'b0011;
        2'b10: new_usebytes = 4'b1100;
    endcase
    LW: new_usebytes = 4'b1111;
    endcase
end

// WAITING_SQ
assign sq_lookup.addr = {ins_reg.addr[`XLEN-1:2], 2'b0};
assign sq_lookup.tail_pos = ins_reg.tail_pos;

logic [3:0] sq_forward_bytes;
assign sq_forward_bytes = ins_reg.usebytes & sq_result.usebytes;
assign sq_forward = (sq_forward_bytes == ins_reg.usebytes);

// WARITING CACHE
// TODO: look up cache word using ins_reg.addr (unaligned, ignore last two digits to align), write to cache_data; 
logic waiting_for_cache;
logic [`XLEN-1:0] cache_data, data_after_cache;
assign waiting_for_cache = 0; // TODO: change when we have cache
always_comb begin
    data_after_cache = cache_data;
    if (ins_reg.forward_bytes[3]) data_after_cache[31:24] = ins_reg.aligned_data[31:24];
    if (ins_reg.forward_bytes[2]) data_after_cache[23:16] = ins_reg.aligned_data[23:16];
    if (ins_reg.forward_bytes[1]) data_after_cache[15:8] = ins_reg.aligned_data[15:8];
    if (ins_reg.forward_bytes[0]) data_after_cache[7:0] = ins_reg.aligned_data[7:0];
end


// WAITING_OUTPUT
// Calculate result from usebytes and aligned_data
logic [`XLEN-1:0] wb_data;
always_comb begin
    wb_data = 0;
    case(ins_reg.load_sel)
    LB: case(ins_reg.addr[1:0])
        2'b00: begin
            wb_data[7:0] = ins_reg.aligned_data[7:0];
            wb_data[31:8] = {24{ins_reg.aligned_data[7]}};
            end
        2'b01: begin
            wb_data[7:0] = ins_reg.aligned_data[15:8];
            wb_data[31:8] = {24{ins_reg.aligned_data[15]}};
        end
        2'b10: begin
            wb_data[7:0] = ins_reg.aligned_data[23:16];
            wb_data[31:8] = {24{ins_reg.aligned_data[23]}};
        end
        2'b11: begin
            wb_data[7:0] = ins_reg.aligned_data[31:24];
            wb_data[31:8] = {24{ins_reg.aligned_data[31]}};
        end
        endcase
    LH: case(ins_reg.addr[1:0])
        2'b00: begin
            wb_data[15:0] = ins_reg.aligned_data[15:0];
            wb_data[31:16] = {16{ins_reg.alinged_data[15]}};
        end
        2'b10: begin
            wb_data[15:0] = ins_reg.aligned_data[31:16];
            wb_data[31:16] = {16{ins_reg.alinged_data[31]}};
        end
        endcase
    LW: wb_data = ins_reg.aligned_data;
    LBU: case(ins_reg.addr[1:0])
        2'b00: wb_data[7:0] = ins_reg.aligned_data[7:0];
        2'b01: wb_data[7:0] = ins_reg.aligned_data[15:8];
        2'b10: wb_data[7:0] = ins_reg.aligned_data[23:16];
        2'b11: wb_data[7:0] = ins_reg.aligned_data[31:24];
        endcase
    LHU: case(ins_reg.addr[1:0])
        2'b00: wb_data[15:0] = ins_reg.alinged_data[15:0];
        2'b10: wb_data[31:16] = ins_reg.alinged_data[31:16];
        endcase
    endcase
end
FU_COMPLETE_PACKET updated_result;
always_comb begin
    updated_result = ins_reg.result;
    updated_result.dest_value = wb_data;
end


always_ff @(posedge clock) begin
    if (reset) begin
        ins_reg <= `SD 0;
        status <= `SD WAITING_INPUT;
    end else case (status)
        WAITING_INPUT: begin
            status <= `SD fu_packet_in.valid ? WAITING_SQ : WAITING_INPUT;
            ins_reg.result <= `SD new_result_pckt;
            ins_reg.addr <= `SD new_addr;
            ins_reg.tail_pos <= `SD fu_packet_in.tail_pos;
            ins_reg.load_sel <= `SD fu_packet_in.op_sel.ls;
            ins_reg.usebytes <= `SD new_usebytes;
            ins_reg.forward_bytes <= `SD 0;
            ins_reg.aligned_data <= `SD 0;
        end
        WAITING_SQ: begin
            status <= `SD   sq_result.stall ? WAITING_SQ 
                            sq_forward ? WAITING_OUTPUT
                            : WAITING_CACHE;
            ins_reg.result <= `SD ins_reg.result;
            ins_reg.addr <= `SD ins_reg.addr;
            ins_reg.tail_pos <= `SD ins_reg.tail_pos;
            ins_reg.load_sel <= `SD ins_reg.load_sel;
            ins_reg.usebytes <= `SD ins_reg.usebytes;
            ins_reg.forward_bytes <= `SD sq_result.usebytes;
            ins_reg.aligned_data <= `SD sq_result.data;
        end
        WAITING_CACHE: begin
            status <= `SD waiting_for_cache ? WAITING_CACHE : WAITING_OUTPUT;
            ins_reg.result <= `SD ins_reg.result;
            ins_reg.addr <= `SD ins_reg.addr;
            ins_reg.tail_pos <= `SD ins_reg.tail_pos;
            ins_reg.load_sel <= `SD ins_reg.load_sel;
            ins_reg.usebytes <= `SD ins_reg.usebytes;
            ins_reg.forward_bytes <= `SD ins_reg.forward_bytes;
            ins_reg.aligned_data <= `SD data_after_cache;
        end
        WAITING_OUTPUT: begin
            status <= `SD complete_stall ? WAITING_OUTPUT : WAITING_INPUT;
            ins_reg.result <=  `SD updated_result;
            ins_reg.addr <= `SD ins_reg.addr;
            ins_reg.tail_pos <= `SD ins_reg.tail_pos;
            ins_reg.load_sel <= `SD ins_reg.load_sel;
            ins_reg.usebytes <= `SD ins_reg.usebytes;
            ins_reg.forward_bytes <= `SD ins_reg.forward_bytes;
            ins_reg.aligned_data <= `SD ins_reg.aligned_data;
        end
    endcase
end



endmodule

`endif // __LOAD_V__
