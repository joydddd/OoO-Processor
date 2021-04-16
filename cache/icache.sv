
module icache(
    input   clock,
    input   reset,
    input   take_branch,
    input   [3:0] Imem2proc_response,           // <- controller.mem2proc_response
    input  [63:0] Imem2proc_data,               // <- controller.mem2proc_data
    input   [3:0] Imem2proc_tag,                // <- controller.mem2proc_tag
    input         d_request,                    // <- controller.d_request

    input  [1:0]  shift,                        // <- fetch_stage.shift
    input  [2:0][`XLEN-1:0] proc2Icache_addr,   // <- fetch_stage.proc2Icache_addr
    input  [2:0][63:0] cachemem_data,           // <- cache.rd1_data
    input  [2:0] cachemem_valid,                // <- cache.rd1_valid

    input         hit_but_stall,                // <- fetch.hit_but_stall

    output logic  [1:0] proc2Imem_command,      // -> mem.proc2mem_command
    output logic  [`XLEN-1:0] proc2Imem_addr,   // -> mem.proc2mem_addr

    output logic  [2:0][31:0] Icache_data_out,  // -> fetch_stage.cache_data
    output logic  [2:0]Icache_valid_out,        // -> fetch_stage.cache_valid

    output logic  [2:0][4:0] current_index,     // -> cache.rd1_idx
    output logic  [2:0][7:0] current_tag,       // -> cache.rd1_tag
    output logic  [4:0] wr_index,               // -> cache.wr1_idx
    output logic  [7:0] wr_tag,                 // -> cache.wr1_tag
    output logic  data_write_enable             // -> cache.wr1_en
  
);

  logic [3:0] current_mem_tag;

  logic miss_outstanding;

  logic [3:0] real_Imem2proc_response;
  logic [3:0] sync_Imem2proc_response;

  logic [4:0]   fetch_index;
  logic [4:0]   fetch_index_next;
  logic [7:0]   fetch_tag;
  logic [7:0]   fetch_tag_next;

  logic [`XLEN-1:0] fetch_addr;
  logic [`XLEN-1:0] last_fetch_addr;

  // prefetch
  logic               give_way;
  logic [1:0]         prefetch_command;
  logic [`XLEN-1:0]   prefetch_addr;
  logic [4:0]         prefetch_index;
  logic [7:0]         prefetch_tag;
  logic               prefetch_wr_enable;
  logic               already_fetched;

  logic [7:0]                 pref_count_display;
  logic [`PREF-1:0][3:0]      mem_tag_display;
  logic [`PREF-1:0][4:0]      store_prefetch_index_display;
  logic [`PREF-1:0][7:0]      store_prefetch_tag_display;

  assign real_Imem2proc_response = d_request ? 4'd0 : Imem2proc_response;

  assign {current_tag[2], current_index[2]} = proc2Icache_addr[2][`XLEN-1:3];
  assign {current_tag[1], current_index[1]} = proc2Icache_addr[1][`XLEN-1:3];
  assign {current_tag[0], current_index[0]} = proc2Icache_addr[0][`XLEN-1:3];

  assign {fetch_tag_next, fetch_index_next} = fetch_addr[`XLEN-1:3];

  wire changed_addr = (current_index[2] != fetch_index) || (current_tag[2] != fetch_tag); // still needed for "update_mem_tag"
  wire cache_miss = ~cachemem_valid[2] | ~cachemem_valid[1] | ~cachemem_valid[0];

  //wire send_request = miss_outstanding && !changed_addr;

  assign Icache_data_out[2] = proc2Icache_addr[2][2] ? cachemem_data[2][63:32] : cachemem_data[2][31:0];
  assign Icache_data_out[1] = proc2Icache_addr[1][2] ? cachemem_data[1][63:32] : cachemem_data[1][31:0];
  assign Icache_data_out[0] = proc2Icache_addr[0][2] ? cachemem_data[0][63:32] : cachemem_data[0][31:0];

  assign Icache_valid_out[2] = cachemem_valid[2];
  assign Icache_valid_out[1] = cachemem_valid[1];
  assign Icache_valid_out[0] = cachemem_valid[0];

  assign fetch_wr_enable =  (current_mem_tag == Imem2proc_tag) &&
                            (current_mem_tag != 0);

  wire new_read = fetch_addr != last_fetch_addr;

  wire last_miss = miss_outstanding && (sync_Imem2proc_response == 0);

  wire unanswered_miss = take_branch  ? cache_miss :
                         changed_addr ? cache_miss :
                         new_read     ? cache_miss :
                         last_miss;

  wire want_to_fetch = ~reset & unanswered_miss & ~hit_but_stall;

  wire require_load = want_to_fetch & ~already_fetched;

  wire update_mem_tag = (changed_addr && require_load) || (unanswered_miss && require_load) || fetch_wr_enable;

  wire prefetch_require = !require_load && prefetch_command == BUS_LOAD;

  assign proc2Imem_command = reset            ? BUS_NONE :
                             require_load     ? BUS_LOAD : 
                             prefetch_require ? BUS_LOAD : 
                             BUS_NONE;

  assign give_way = require_load;

  assign proc2Imem_addr = require_load     ? fetch_addr :
                          prefetch_require ? prefetch_addr :
                          0;

  assign data_write_enable = fetch_wr_enable | prefetch_wr_enable;

  assign wr_index = fetch_wr_enable    ? fetch_index :
                    prefetch_wr_enable ? prefetch_index : 0;

  assign wr_tag = fetch_wr_enable    ? fetch_tag :
                  prefetch_wr_enable ? prefetch_tag : 0;

  prefetch pf (
    .clock(clock),
    .reset(reset),
    .Imem2pref_response(real_Imem2proc_response),    // <- (inside icache).real_Imem2proc_response
    .Imem2pref_tag(Imem2proc_tag),              // <- (inside icache).Imem2proc_tag

    .give_way(give_way),                        // <- (inside icache).give_way
    .branch(take_branch),                       // <- (inside icache).take_branch
    .proc2Icache_addr(proc2Icache_addr),        // <- (inside icache).proc2Icache_addr
    .cachemem_valid(cachemem_valid),            // <- (inside icache).cachemem_valid

    .want_to_fetch(want_to_fetch),              // <- (inside icache).want_to_fetch

    .already_fetched(already_fetched),          // -> (inside icache).already_fetched

    .prefetch_command(prefetch_command),        // -> (inside icache).prefetch_command
    .prefetch_addr(prefetch_addr),              // -> (inside icache).prefetch_addr
    .prefetch_index(prefetch_index),            // -> (inside icache).prefetch_index
    .prefetch_tag(prefetch_tag),                // -> (inside icache).prefetch_tag
    .prefetch_wr_enable(prefetch_wr_enable)     // -> (inside icache).prefetch_wr_enable

    `ifdef TEST_MODE
    , .pref_count_display(pref_count_display)
    , .mem_tag_display(mem_tag_display)
    , .store_prefetch_index_display(store_prefetch_index_display)
    , .store_prefetch_tag_display(store_prefetch_tag_display)
    `endif
  );

  always_comb begin
    if (shift == 2'd0) begin
      fetch_addr = {proc2Icache_addr[2][`XLEN-1:3],3'b0};
    end
    else if (shift == 2'd1) begin
      fetch_addr = {proc2Icache_addr[1][`XLEN-1:3],3'b0};
    end
    else if (shift == 2'd2) begin
      fetch_addr = {proc2Icache_addr[0][`XLEN-1:3],3'b0};
    end
    else begin
      fetch_addr = {proc2Icache_addr[2][`XLEN-1:3],3'b0};
    end
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if(reset) begin
      fetch_index       <= `SD -1;   // These are -1 to get ball rolling when
      fetch_tag         <= `SD -1;   // reset goes low because addr "changes"
      current_mem_tag  <= `SD 0;              
      miss_outstanding <= `SD 0;
      sync_Imem2proc_response <= `SD 0;
      last_fetch_addr <= `SD 0;
    end else begin
      fetch_index       <= `SD fetch_index_next;
      fetch_tag         <= `SD fetch_tag_next;
      miss_outstanding <= `SD unanswered_miss;
      sync_Imem2proc_response <= `SD real_Imem2proc_response;
      last_fetch_addr <= `SD fetch_addr;
      if(fetch_wr_enable || take_branch)
        current_mem_tag <= `SD 0;
      else if(update_mem_tag)
        current_mem_tag <= `SD real_Imem2proc_response;
    end
  end

endmodule
