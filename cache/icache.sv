
module icache(
    input   clock,
    input   reset,
    input   [3:0] Imem2proc_response,           // <- mem.mem2proc_response
    input  [63:0] Imem2proc_data,               // <- mem.mem2proc_data
    input   [3:0] Imem2proc_tag,                // <- mem.mem2proc_tag

    input  [1:0]  shift,                        // <- fetch_stage.shift
    input  [2:0][`XLEN-1:0] proc2Icache_addr,   // <- fetch_stage.proc2Icache_addr
    input  [2:0][63:0] cachemem_data,           // <- cache.rd1_data
    input  [2:0] cachemem_valid,                // <- cache.rd1_valid

    output logic  [1:0] proc2Imem_command,      // -> mem.proc2mem_command
    output logic  [`XLEN-1:0] proc2Imem_addr,   // -> mem.proc2mem_addr

    output logic  [2:0][31:0] Icache_data_out,  // -> fetch_stage.cache_data
    output logic  [2:0]Icache_valid_out,        // -> fetch_stage.cache_valid

    output logic  [2:0][1:0] current_index,     // -> cache.rd1_idx
    output logic  [2:0][10:0] current_tag,      // -> cache.rd1_tag
    output logic  [1:0] wr_index,               // -> cache.wr1_idx
    output logic  [10:0] wr_tag,                // -> cache.wr1_tag
    output logic  data_write_enable             // -> cache.wr1_en
  
);

  logic [3:0] current_mem_tag;

  logic miss_outstanding;

  logic [3:0] last_Imem2proc_response;

  logic [1:0]   wr_index_next;
  logic [10:0]  wr_tag_next;

  assign {current_tag[2], current_index[2]} = proc2Icache_addr[2][`XLEN-1:3];
  assign {current_tag[1], current_index[1]} = proc2Icache_addr[1][`XLEN-1:3];
  assign {current_tag[0], current_index[0]} = proc2Icache_addr[0][`XLEN-1:3];

  wire changed_addr = (current_index[2] != wr_index) || (current_tag[2] != wr_tag); // still needed for "update_mem_tag"
  wire cache_miss = ~cachemem_valid[2] | ~cachemem_valid[1] | ~cachemem_valid[0];

  //wire send_request = miss_outstanding && !changed_addr;

  assign Icache_data_out[2] = proc2Icache_addr[2][2] ? cachemem_data[2][63:32] : cachemem_data[2][31:0];
  assign Icache_data_out[1] = proc2Icache_addr[1][2] ? cachemem_data[1][63:32] : cachemem_data[1][31:0];
  assign Icache_data_out[0] = proc2Icache_addr[0][2] ? cachemem_data[0][63:32] : cachemem_data[0][31:0];

  assign Icache_valid_out[2] = cachemem_valid[2];
  assign Icache_valid_out[1] = cachemem_valid[1];
  assign Icache_valid_out[0] = cachemem_valid[0];

  assign proc2Imem_command = unanswered_miss ? BUS_LOAD :
                                               BUS_NONE;

  assign data_write_enable =  (current_mem_tag == Imem2proc_tag) &&
                              (current_mem_tag != 0);

  wire update_mem_tag = changed_addr || miss_outstanding || data_write_enable;

  wire unanswered_miss = changed_addr ? cache_miss :
                                        miss_outstanding && (last_Imem2proc_response == 0);


  always_comb begin
    if (!cachemem_valid[2]) begin
      proc2Imem_addr = {proc2Icache_addr[2][`XLEN-1:3],3'b0};
    end
    else if (!cachemem_valid[1]) begin
      proc2Imem_addr = {proc2Icache_addr[1][`XLEN-1:3],3'b0};
    end
    else if (!cachemem_valid[0]) begin
      proc2Imem_addr = {proc2Icache_addr[0][`XLEN-1:3],3'b0};
    end
    else begin
      proc2Imem_addr = {proc2Icache_addr[2][`XLEN-1:3],3'b0};
    end

    if (count_down_shift == 2'd2) begin
      wr_index_next = current_index[0];
      wr_tag_next   = current_tag[0];
    end
    else if (shift == 2'd1) begin
      wr_index_next = current_index[1];
      wr_tag_next   = current_tag[1];
    end
    else begin
      wr_index_next = current_index[2];
      wr_tag_next   = current_tag[2];
    end
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if(reset) begin
      wr_index       <= `SD -1;   // These are -1 to get ball rolling when
      wr_tag         <= `SD -1;   // reset goes low because addr "changes"
      current_mem_tag  <= `SD 0;              
      miss_outstanding <= `SD 0;
      last_Imem2proc_response <= `SD 0;
    end else begin
      wr_index       <= `SD wr_index_next;
      wr_tag         <= `SD wr_tag_next;
      miss_outstanding <= `SD unanswered_miss;
      last_Imem2proc_response <= `SD Imem2proc_response;
      
      if(update_mem_tag)
        current_mem_tag <= `SD Imem2proc_response;
    end
  end

endmodule
