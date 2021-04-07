// cachemem4x64, 3 reading ports, 1 writing port

`timescale 1ns/100ps

module dcache_mem(
        input clock, reset, 
        input  [2:0] wr1_en                                     // <- icache.data_write_enable
        input  [2:0][4:0] wr1_idx,                                   // <- icache.wr_index
        input  [2:0][4:0] rd1_idx,                              // <- icache.current_index
        input  [2:0][7:0] wr1_tag,                                   // <- icache.wr_tag
        input  [2:0][7:0] rd1_tag,                              // <- icache.current_tag
        input  [2:0][63:0] wr1_data,                                 // <- mem.mem2proc_data

        output [2:0][63:0] rd1_data,            // -> icache.cachemem_data
        output [2:0] rd1_valid                  // -> icache.cachemem_valid
);

  logic [31:0] [63:0] data;
  logic [31:0] [7:0]  tags;
  logic [31:0]        valids;
  logic [31:0]        valids_next;
  logic [31:0] [63:0] data_next;
  logic [31:0] [7:0]  tags_next;

  assign rd1_data[2] = data[rd1_idx[2]];
  assign rd1_data[1] = data[rd1_idx[1]];
  assign rd1_data[0] = data[rd1_idx[0]];
  assign rd1_valid[2] = valids[rd1_idx[2]] && (tags[rd1_idx[2]] == rd1_tag[2]);
  assign rd1_valid[1] = valids[rd1_idx[1]] && (tags[rd1_idx[1]] == rd1_tag[1]);
  assign rd1_valid[0] = valids[rd1_idx[0]] && (tags[rd1_idx[0]] == rd1_tag[0]);

  always_comb begin
    valids_next = valids;
    data_next = data;
    tags_next = tags;
    for (int i = 2; i>=0; i--) begin
        if(wr1_en[i]) begin
            valids[wr1_idx[i]] = 1;
            data[wr1_idx[i]] = wr1_data[i];
            tags[wr1_idx[i]] = wr1_tag[i];
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
