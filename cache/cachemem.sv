// cachemem4x64

`timescale 1ns/100ps

module cache(
        input clock, reset, wr1_en,
        input  [1:0] wr1_idx, rd1_idx,
        input  [10:0] wr1_tag, rd1_tag,
        input [63:0] wr1_data, 

        output [63:0] rd1_data,
        output rd1_valid
        
      );

  logic [3:0] [63:0] data;
  logic [3:0] [10:0] tags; 
  logic [3:0]        valids;

  assign rd1_data = data[rd1_idx];
  assign rd1_valid = valids[rd1_idx] && (tags[rd1_idx] == rd1_tag);

  always_ff @(posedge clock) begin
    if(reset)
      valids <= `SD 4'b0;
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
