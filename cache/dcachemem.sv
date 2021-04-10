// cachemem4x64, 3 reading ports, 1 writing port

`timescale 1ns/100ps

module dcache_mem(
        input clock, reset, 
        input  [2:0] wr1_en                                     // 
        input  [2:0][4:0] wr1_idx,                                   // 
        input  [2:0][7:0] wr1_tag,                                   // 
        input  [2:0][63:0] wr1_data,                                 //
        input  [2:0][7:0] used_bytes, 

        input  [1:0][4:0] rd1_idx,                              // 
        input  [1:0][7:0] rd1_tag,                              // 
        output [1:0][63:0] rd1_data,            // 
        output [1:0] rd1_valid,                  // 

        output [2:0] need_write_mem,
        output [2:0][63:0]  wb_mem_data,

        input        wr2_en,        //For the miss load back
        input  [4:0] wr2_idx,                                   // 
        input  [7:0] wr2_tag,                                   // 
        input  [63:0] wr2_data
);

  logic [31:0] [63:0] data;
  logic [31:0] [7:0]  tags;
  logic [31:0]        valids;
  logic [31:0]        valids_next;
  logic [31:0] [63:0] data_next;
  logic [31:0] [7:0]  tags_next;

  logic [2:0] wr1_hit;
  

  assign rd1_data[1] = data[rd1_idx[1]];
  assign rd1_data[0] = data[rd1_idx[0]];
  assign rd1_valid[1] = valids[rd1_idx[1]] && (tags[rd1_idx[1]] == rd1_tag[1]);
  assign rd1_valid[0] = valids[rd1_idx[0]] && (tags[rd1_idx[0]] == rd1_tag[0]);

  assign wr1_hit[2] = valids[wr1_idx[2]] && (tags[wr1_idx[2]] == wr1_tag[2]);
  assign wr1_hit[1] = valids[wr1_idx[1]] && (tags[wr1_idx[1]] == wr1_tag[1]);
  assign wr1_hit[0] = valids[wr1_idx[0]] && (tags[wr1_idx[0]] == wr1_tag[0]);

  assign need_write_mem[2] = wr1_en[2] && !wr1_hit[2] && (valids[wr1_idx[2]] == 1'b1);
  assign need_write_mem[1] = wr1_en[1] && !wr1_hit[1] && (valids[wr1_idx[1]] == 1'b1);
  assign need_write_mem[0] = wr1_en[0] && !wr1_hit[0] && (valids[wr1_idx[0]] == 1'b1);
  
  assign wb_mem_data[2] = data[wr1_idx[2]];
  assign wb_mem_data[1] = data[wr1_idx[1]];
  assign wb_mem_data[0] = data[wr1_idx[0]];



  always_comb begin
    valids_next = valids;
    data_next = data;
    tags_next = tags;
    if (wr2_en) begin
      valids_next[wr2_idx] = 1'b1;
      tags_next[wr2_idx] = wr2_tag;
      data_next[wr2_idx] = wr2_data;
    end
    for (int i = 2; i >= 0; i--) begin
        if(wr1_en[i]) begin
            valids_next[wr1_idx[i]] = 1'b1;
            tags_next[wr1_idx[i]] = wr1_tag[i];
            for ( int j = 7; j >= 0 ; j--) begin
              if (used_bytes[i][j]) begin
                data_next[wr1_idx[i]][(8*j+7):(8*j)] = wr1_data[i][(8*j+7):(8*j)];
              end
            end
        end
    end
  end


  always_ff @(posedge clock) begin
    if(reset)
      valids <= `SD 32'b0;
      tags <= `SD 0;
      data <= `SD 0;
    else
      valids <= `SD valids_next;
      tags <= `SD tags_next;
      data <= `SD data_next;
  end

endmodule
