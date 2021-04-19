// cachemem4x64, 3 reading ports, 1 writing port
`define TEST_MODE

`timescale 1ns/100ps

module dcache_mem(
        input clock, reset, 
        input  [2:0] wr1_en,                                     // 
        input  [2:0][4:0] wr1_idx,                                   // 
        input  [2:0][7:0] wr1_tag,                                   // 
        input  [2:0][63:0] wr1_data,                                 //
        input  [2:0][7:0] used_bytes, 
        input [2:0] wr1_hit,
        input  [2:0][4:0] wrh_idx,                                   // 
        input  [2:0][7:0] wrh_tag,
        output [2:0] wrh_hit,

        input  [1:0][4:0] rd1_idx,                              // 
        input  [1:0][7:0] rd1_tag,                              // 
        output [1:0][63:0] rd1_data,            // 
        output [1:0] rd1_valid,                  // 

        output logic need_write_mem,
        output logic [63:0] wb_mem_data,
        output logic [`XLEN-1:0] wb_mem_addr,

        input        wr2_en,        //For the miss load back
        input  [4:0] wr2_idx,                                   // 
        input  [7:0] wr2_tag,                                   // 
        input  [63:0] wr2_data,
        input  [7:0] wr2_usebytes,
        input       wr2_dirty

        `ifdef TEST_MODE
        , output logic [31:0] [63:0] cache_data_disp
        , output logic [31:0] [7:0] cache_tags_disp
        , output logic [31:0]       valids_disp
        `endif 
);

  logic [31:0] [63:0] data;
  logic [31:0] [7:0]  tags;
  logic [31:0]        valids;
  logic [31:0]        valids_next;
  logic [31:0] [63:0] data_next;
  logic [31:0] [63:0] data_next2;
  logic [31:0] [7:0]  tags_next;
  logic [31:0]        dirties;
  logic [31:0]        dirties_next;
  logic [31:0]        dirties_next2;

  
  `ifdef TEST_MODE
    assign cache_data_disp = data;
    assign cache_tags_disp = tags;
    assign valids_disp = valids;
  `endif

  assign rd1_data[1] = data[rd1_idx[1]];
  assign rd1_data[0] = data[rd1_idx[0]];
  assign rd1_valid[1] = valids[rd1_idx[1]] && (tags[rd1_idx[1]] == rd1_tag[1]);
  assign rd1_valid[0] = valids[rd1_idx[0]] && (tags[rd1_idx[0]] == rd1_tag[0]);

  assign wrh_hit[2] = valids[wrh_idx[2]] && (tags[wrh_idx[2]] == wrh_tag[2]);
  assign wrh_hit[1] = valids[wrh_idx[1]] && (tags[wrh_idx[1]] == wrh_tag[1]);
  assign wrh_hit[0] = valids[wrh_idx[0]] && (tags[wrh_idx[0]] == wrh_tag[0]);

  //assign need_write_mem[2] = wr1_en[2] && !wr1_hit[2] && (valids[wr1_idx[2]] == 1'b1);
  //assign need_write_mem[1] = wr1_en[1] && !wr1_hit[1] && (valids[wr1_idx[1]] == 1'b1);
  //assign need_write_mem[0] = wr1_en[0] && !wr1_hit[0] && (valids[wr1_idx[0]] == 1'b1);
  
  //assign wb_mem_data[2] = data[wr1_idx[2]];
  //assign wb_mem_data[1] = data[wr1_idx[1]];
  //assign wb_mem_data[0] = data[wr1_idx[0]];



  always_comb begin
    valids_next = valids;
    data_next = data;
    data_next2 = data_next;
    tags_next = tags;
    need_write_mem = 0;
    wb_mem_data = 0;
    wb_mem_addr = 0;
    dirties_next = dirties;
    dirties_next2 = dirties_next;
    for (int i = 2; i >= 0; i--) begin
        if(wr1_en[i] && wr1_hit[i]) begin
            valids_next[wr1_idx[i]] = 1'b1;
            tags_next[wr1_idx[i]] = wr1_tag[i];
            dirties_next[wr1_idx[i]] = 1'b1;
            for ( int j = 7; j >= 0 ; j--) begin
              if (used_bytes[i][j]) begin
                data_next[wr1_idx[i]][8*j+7] = wr1_data[i][8*j+7];
                data_next[wr1_idx[i]][8*j+6] = wr1_data[i][8*j+6];
                data_next[wr1_idx[i]][8*j+5] = wr1_data[i][8*j+5];
                data_next[wr1_idx[i]][8*j+4] = wr1_data[i][8*j+4];
                data_next[wr1_idx[i]][8*j+3] = wr1_data[i][8*j+3];
                data_next[wr1_idx[i]][8*j+2] = wr1_data[i][8*j+2];
                data_next[wr1_idx[i]][8*j+1] = wr1_data[i][8*j+1];
                data_next[wr1_idx[i]][8*j+0] = wr1_data[i][8*j+0];
              end
            end
        end
    end
    data_next2 = data_next;
    dirties_next2 = dirties_next;
    if (wr2_en) begin
      if (valids[wr2_idx]==1'b0) begin
        valids_next[wr2_idx] = 1'b1;
        tags_next[wr2_idx] = wr2_tag;
        data_next2[wr2_idx] = wr2_data;
        dirties_next2[wr2_idx] = wr2_dirty;
      end
      else if (tags[wr2_idx]==wr2_tag) begin
        if (wr2_dirty==1'b1) begin
          dirties_next2[wr2_idx] = 1'b1;
          for ( int j = 7; j >= 0 ; j--) begin
            if (wr2_usebytes[j]) begin
              data_next2[wr2_idx][8*j+7] = wr2_data[8*j+7];
              data_next2[wr2_idx][8*j+6] = wr2_data[8*j+6];
              data_next2[wr2_idx][8*j+5] = wr2_data[8*j+5];
              data_next2[wr2_idx][8*j+4] = wr2_data[8*j+4];
              data_next2[wr2_idx][8*j+3] = wr2_data[8*j+3];
              data_next2[wr2_idx][8*j+2] = wr2_data[8*j+2];
              data_next2[wr2_idx][8*j+1] = wr2_data[8*j+1];
              data_next2[wr2_idx][8*j+0] = wr2_data[8*j+0];
            end
          end
        end
      end
      else begin
        if (dirties_next[wr2_idx]) begin
          need_write_mem = 1'b1;
          wb_mem_data = data_next[wr2_idx];
          wb_mem_addr = {16'b0, tags[wr2_idx], wr2_idx, 3'b0};
        end
        tags_next[wr2_idx] = wr2_tag;
        data_next2[wr2_idx] = wr2_data;
        dirties_next2[wr2_idx] = wr2_dirty;
      end
    end
  end


  always_ff @(posedge clock) begin
    if(reset) begin
      valids <= `SD 32'b0;
      tags <= `SD 0;
      data <= `SD 0;
      dirties <= `SD 0;
    end
    else begin
      valids <= `SD valids_next;
      tags <= `SD tags_next;
      data <= `SD data_next2;
      dirties <= `SD dirties_next2;
    end
  end

endmodule
