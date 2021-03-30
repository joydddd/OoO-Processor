// cachemem4x64, 3 reading ports, 1 writing port

`timescale 1ns/100ps

module cache(
        input clock, reset, wr1_en,             // <- icache.data_write_enable
        input  [4:0] wr1_idx,                   // <- icache.wr_index
        input  [2:0][4:0] rd1_idx,              // <- icache.current_index
        input  [7:0] wr1_tag,                   // <- icache.wr_tag
        input  [2:0][7:0] rd1_tag,              // <- icache.current_tag
        input  [63:0] wr1_data,                 // <- mem.mem2proc_data

        output [2:0][63:0] rd1_data,            // -> icache.cachemem_data
        output [2:0] rd1_valid                  // -> icache.cachemem_valid
);

  logic [31:0] [63:0] data;
  logic [31:0] [7:0]  tags;
  logic [31:0]        valids;

  assign rd1_data[2] = data[rd1_idx[2]];
  assign rd1_data[1] = data[rd1_idx[1]];
  assign rd1_data[0] = data[rd1_idx[0]];
  assign rd1_valid[2] = valids[rd1_idx[2]] && (tags[rd1_idx[2]] == rd1_tag[2]);
  assign rd1_valid[1] = valids[rd1_idx[1]] && (tags[rd1_idx[1]] == rd1_tag[1]);
  assign rd1_valid[0] = valids[rd1_idx[0]] && (tags[rd1_idx[0]] == rd1_tag[0]);

  always_ff @(posedge clock) begin
    if(reset)
      valids <= `SD 32'b0;
    else if(wr1_en) 
      valids[wr1_idx] <= `SD 1;
  end
  
  always_ff @(posedge clock) begin
    if(wr1_en) begin
      data[wr1_idx] <= `SD wr1_data;
      tags[wr1_idx] <= `SD wr1_tag;
    end
  end

endmodule
