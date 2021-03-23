`define TEST_MODE
`ifndef __IS_FIFO_V__
`define __IS_FIFO_V__
`timescale 1ns/100ps
module fu_FIFO_3 #(parameter FIFO_DEPTH=`IS_FIFO_DEPTH)(
    input                       clock,
    input                       reset,
    input ISSUE_FU_PACKET[2:0]  fu_pckt_in,
    input [2:0]                 rd_EN,
    output logic                full,
    output logic                almost_full,
    output ISSUE_FU_PACKET[2:0] fu_pckt_out
    `ifdef TEST_MODE
    , output ISSUE_FU_PACKET [FIFO_DEPTH-1:0] fifo_display
    `endif
);
/* sync registers */
ISSUE_FU_PACKET [FIFO_DEPTH-1:0] fifo_entries;
logic [$clog2(FIFO_DEPTH)-1:0] tail;


`ifdef TEST_MODE
assign fifo_display = fifo_entries;
`endif

/* write count and EN */
logic [2:0] wr_EN;
logic [1:0]     wr_count;
always_comb begin
    for(int i=0; i<3; i++) begin
        wr_EN[i] = fu_pckt_in[i].valid;
    end
end
assign wr_count = wr_EN[0] + wr_EN[1] + wr_EN[2];




/* reorder input */
ISSUE_FU_PACKET[2:0] fifo_push; 
always_comb begin
    fifo_push = 0;
    case (wr_EN)
    3'b000: fifo_push = 0;
    3'b001: fifo_push[2] = fu_pckt_in[0];
    3'b010: fifo_push[2] = fu_pckt_in[1];
    3'b011: fifo_push[2:1] = fu_pckt_in[1:0];
    3'b100: fifo_push[2] = fu_pckt_in[2];
    3'b101: begin
        fifo_push[2] = fu_pckt_in[2];
        fifo_push[1] = fu_pckt_in[0];
    end
    3'b110: fifo_push[2:1] = fu_pckt_in[2:1];
    3'b111: fifo_push = fu_pckt_in;
    endcase
end


/* update tail & full */
logic [$clog2(FIFO_DEPTH):0] tail_next;
assign tail_next = tail + wr_count;
assign full = tail_next >= FIFO_DEPTH;
assign almost_full = (tail_next + 3 >= FIFO_DEPTH);



/* write to fifo */
ISSUE_FU_PACKET [FIFO_DEPTH-1+3:0] fifo_entries_next;
always_comb begin
    fifo_entries_next = 0;
    fifo_entries_next[FIFO_DEPTH-1:0] = fifo_entries;
    for(int i=0; i<FIFO_DEPTH; i++) begin
        if (i == tail) begin
            fifo_entries_next[i] = fifo_push[2];
            fifo_entries_next[i+1] = fifo_push[1];
            fifo_entries_next[i+2] = fifo_push[0];
        end
    end
    
end

/* read FIFO */
logic [1:0]     rd_count;
logic [2:0]     valid_out;
always_comb begin
    fu_pckt_out = 0;
    case(rd_EN)
        3'b000: fu_pckt_out = 0;
        3'b001: fu_pckt_out[0] = fifo_entries_next[0];
        3'b010: fu_pckt_out[1] = fifo_entries_next[0];
        3'b011: fu_pckt_out[1:0] = fifo_entries_next[1:0];
        3'b100: fu_pckt_out[2] = fifo_entries_next[0];
        3'b101: begin
            fu_pckt_out[2] = fifo_entries_next[1];
            fu_pckt_out[0] = fifo_entries_next[0];
        end
        3'b110: fu_pckt_out[2:1] = fifo_entries_next[1:0];
        3'b111: fu_pckt_out[2:0] = fifo_entries_next[2:0];
    endcase
end

always_comb begin
    valid_out[2] = fu_pckt_out[2].valid;
    valid_out[1] = fu_pckt_out[1].valid;
    valid_out[0] = fu_pckt_out[0].valid;
end
assign rd_count = valid_out[0] + valid_out[1] + valid_out[2];


/* shift fifo */
ISSUE_FU_PACKET [FIFO_DEPTH-1:0] fifo_entries_shifted;
logic [$clog2(FIFO_DEPTH)-1:0] tail_shifted;
assign tail_shifted = (tail_next > rd_count)? tail_next-rd_count:0;
always_comb begin
    fifo_entries_shifted = 0;
    case(rd_count) 
        3: begin
            for (int i=0; i<FIFO_DEPTH; i++) begin
                fifo_entries_shifted[i] = fifo_entries_next[i+3];
            end
        end
        2: begin
            for (int i=0; i<FIFO_DEPTH; i++) begin
                fifo_entries_shifted[i] = fifo_entries_next[i+2];
            end
        end
        1: begin
            for (int i=0; i<FIFO_DEPTH; i++) begin
                fifo_entries_shifted[i] = fifo_entries_next[i+1];
            end
        end
        0: begin
            for (int i=0; i<FIFO_DEPTH; i++) begin
                fifo_entries_shifted[i] = fifo_entries_next[i];
            end
        end
    endcase
end



/* sync update */
always_ff @(posedge clock) begin
    if (reset) begin 
        fifo_entries <= `SD 0;
        tail <= `SD 0;
    end else begin
        fifo_entries <= `SD fifo_entries_shifted;
        tail <= `SD tail_shifted;
    end
end

endmodule

`endif