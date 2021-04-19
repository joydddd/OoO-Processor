`define TEST_MODE

module dcache(
    input   clock,
    input   reset,
    /* with mem_controller */
    input   [3:0] Ctlr2proc_response,
    input  [63:0] Ctlr2proc_data,
    input   [3:0] Ctlr2proc_tag,

    output logic [1:0] dcache2ctlr_command,      
    output logic [`XLEN-1:0] dcache2ctlr_addr,  
    output logic [63:0] dcache2ctlr_data,
  

    /* with SQ */
    input SQ_ENTRY_PACKET [2:0] sq_in,   // <- cache_wb
    input SQ_ENTRY_PACKET [2:0] sq_head,
    output [2:0] sq_stall,

    /* with Load-FU/LQ */                 // <- cache_read_addr
    input [1:0] [`XLEN-1:0] ld_addr_in,   // This addr is word aligned !
    input [1:0] ld_start,                 // <- cache_read_start
    output logic [1:0] is_hit,
    output logic [1:0] [`XLEN-1:0] ld_data,    //valid if hit
    output logic [1:0] broadcast_fu,
    output logic [`XLEN-1:0] broadcast_data


    `ifdef TEST_MODE
      , output logic [31:0] [63:0] cache_data_disp
      , output logic [31:0] [7:0] cache_tags_disp
      , output logic [31:0]       valids_disp
      , output MHSRS_ENTRY_PACKET [`MHSRS_W-1:0] MHSRS_disp
      , output logic [`MHSRS-1:0] head_pointer
      , output logic [`MHSRS-1:0] issue_pointer
      , output logic [`MHSRS-1:0] tail_pointer
    `endif
  );

  /* for dcache_mem */
  logic  [2:0] wr_en;                                    
  logic  [2:0][4:0] wr_idx;                                 
  logic  [2:0][7:0] wr_tag;                               
  logic  [2:0][63:0] wr_data;   
  logic  [2:0][7:0] used_bytes;
  logic  [2:0]      wr_hit;      

  logic  [1:0][4:0] rd_idx;                        
  logic  [1:0][7:0] rd_tag;

  logic  [1:0][63:0] rd_data;          
  logic  [1:0] rd_valid;                  

  logic  need_write_mem;
  logic  [63:0]  wb_mem_data;
  logic  [`XLEN-1:0] wb_mem_addr;

  logic  [2:0][`XLEN-1:0] ld_new_mem_addr;  //This can be directly calculated

  logic        wr2_en;        //For the miss load back
  logic  [4:0] wr2_idx;               
  logic  [7:0] wr2_tag;                    
  logic  [63:0] wr2_data;
  logic  [7:0]  wr2_usebytes;
  logic         wr2_dirty;


  logic [2:0] sq_head_stall;
  logic [2:0] sq_head_hit;
  logic [2:0][7:0] wrh_tag;
  logic [2:0][4:0] wrh_idx;

  always_comb begin
    case(sq_head_hit)
      3'b000: sq_head_stall = 3'b011;
      3'b001: sq_head_stall = 3'b011;
      3'b010: sq_head_stall = 3'b011;
      3'b011: sq_head_stall = 3'b011;
      3'b100: sq_head_stall = 3'b001;
      3'b101: sq_head_stall = 3'b001;
      3'b110: sq_head_stall = 3'b000;
      3'b111: sq_head_stall = 3'b000;
    endcase
  end
  // assign sq_head_stall[2] = 1'b0;
  // assign sq_head_stall[1] = sq_head_hit[2] ? 1'b0 : 1'b1; 
  // assign sq_head_stall[0] = sq_head_stall[1] ? 1'b1 : (sq_head_hit[1] ? 1'b0 : 1'b1);
  always_comb begin
    for(int i=0; i<3; i++)
      wr_hit[i] = sq_in[i].ready & sq_head_hit[i];
  end



  assign {wrh_tag[2], wrh_idx[2]} = sq_head[2].addr[`XLEN-1:3];
  assign {wrh_tag[1], wrh_idx[1]} = sq_head[1].addr[`XLEN-1:3];
  assign {wrh_tag[0], wrh_idx[0]} = sq_head[0].addr[`XLEN-1:3];

  always_comb begin : SQ_input_processing
    for (int i = 2; i>= 0; i--) begin
      wr_en[i] = sq_in[i].ready;
      {wr_tag[i], wr_idx[i]} = sq_in[i].addr[`XLEN-1:3];
      ld_new_mem_addr[i] = {sq_in[i].addr[`XLEN-1:3], 3'b0};
      if (sq_in[i].addr[2]==1'b1) begin
        wr_data[i] = {sq_in[i].data, `XLEN'b0};
        used_bytes[i] = {sq_in[i].usebytes, 4'b0};
      end
      else begin
        wr_data[i] = {`XLEN'b0, sq_in[i].data};
        used_bytes[i] = {4'b0, sq_in[i].usebytes};
      end
    end
  end

  always_comb begin : LQ_input_processing
    for (int i = 1; i >=0 ; i--) begin
      {rd_tag[i], rd_idx[i]} = ld_addr_in[i][`XLEN-1:3];
    end
  end

  dcache_mem ram(
    .clock(clock),
    .reset(reset),
    .wr1_en(wr_en),
    .wr1_idx(wr_idx),
    .wr1_tag(wr_tag),
    .wr1_data(wr_data),
    .used_bytes(used_bytes),
    .wr1_hit(wr_hit),
    .wrh_idx(wrh_idx),
    .wrh_tag(wrh_tag),
    .wrh_hit(sq_head_hit),
    .rd1_idx(rd_idx),
    .rd1_tag(rd_tag),
    .rd1_data(rd_data),
    .rd1_valid(rd_valid),
    .need_write_mem(need_write_mem),
    .wb_mem_data(wb_mem_data),
    .wb_mem_addr(wb_mem_addr),
    .wr2_en(wr2_en),
    .wr2_idx(wr2_idx),
    .wr2_tag(wr2_tag),
    .wr2_data(wr2_data),
    .wr2_usebytes(wr2_usebytes),
    .wr2_dirty(wr2_dirty)

    `ifdef TEST_MODE
      , .cache_data_disp(cache_data_disp)
      , .cache_tags_disp(cache_tags_disp)
      , .valids_disp(valids_disp)
    `endif
  );

  always_comb begin : send_hit_data
    ld_data = 0;
    for (int i = 1; i >= 0; i--) begin
      if (ld_addr_in[i][2]==1'b1) begin
        ld_data[i] = rd_data[i][63:32];
      end
      else begin
        ld_data[i] = rd_data[i][31:0];
      end
    end
  end

  
  // MHSRS: 
  /* For MHSRS */
  MHSRS_ENTRY_PACKET [`MHSRS_W-1:0] mshrs_table;
  MHSRS_ENTRY_PACKET [`MHSRS_W-1:0] mshrs_table_next;

  logic [`MHSRS-1:0] head;
  logic [`MHSRS-1:0] issue;
  logic [`MHSRS-1:0] tail;
  logic [`MHSRS-1:0] head_next;
  logic [`MHSRS-1:0] issue_next;
  logic [`MHSRS-1:0] tail_next;

  `ifdef TEST_MODE
    assign MHSRS_disp = mshrs_table;
    assign head_pointer = head;
    assign issue_pointer = issue;
    assign tail_pointer = tail;
  `endif

  always_ff @( posedge clock ) begin : MSHRS_reg
    if (reset) begin
      mshrs_table <= `SD 0;
      head <= `SD 0;
      issue <= `SD 0;
      tail <= `SD 0;
    end
    else begin
      mshrs_table <= `SD mshrs_table_next;
      head <= `SD head_next;
      issue <= `SD issue_next;
      tail <= `SD tail_next;
    end
  end

  MHSRS_ENTRY_PACKET [`MHSRS_W-1:0] mshrs_table_next_after_retire;

  assign   broadcast_fu = 0;
  assign  broadcast_data = 0;


  always_comb begin : head_logic
    head_next = head;
    wr2_en = 0;
    wr2_idx = 0;
    wr2_tag = 0;
    wr2_data = 0;
    wr2_dirty = 0;
    wr2_usebytes = 0;
    mshrs_table_next_after_retire = mshrs_table;
    if ((head!=tail) && mshrs_table[head].issued &&(mshrs_table[head].command==BUS_STORE || (mshrs_table[head].command==BUS_LOAD && (Ctlr2proc_tag==mshrs_table[head].mem_tag)))) begin
      head_next = head + 1;
      mshrs_table_next_after_retire[head] = 0;
      if (mshrs_table[head].command==BUS_LOAD) begin
        wr2_en = 1'b1;
        {wr2_tag, wr2_idx} = mshrs_table[head].addr[`XLEN-1:3];
        wr2_data = Ctlr2proc_data;
        wr2_dirty = mshrs_table[head].dirty;
        wr2_usebytes = mshrs_table[head].usebytes;

        if (mshrs_table[head].dirty==1'b1) begin
          for ( int j = 7; j >= 0 ; j--) begin
            if (mshrs_table[head].usebytes[j]) begin
              wr2_data[8*j+7] = mshrs_table[head].data[8*j+7];
              wr2_data[8*j+6] = mshrs_table[head].data[8*j+6];
              wr2_data[8*j+5] = mshrs_table[head].data[8*j+5];
              wr2_data[8*j+4] = mshrs_table[head].data[8*j+4];
              wr2_data[8*j+3] = mshrs_table[head].data[8*j+3];
              wr2_data[8*j+2] = mshrs_table[head].data[8*j+2];
              wr2_data[8*j+1] = mshrs_table[head].data[8*j+1];
              wr2_data[8*j+0] = mshrs_table[head].data[8*j+0];
            end
          end
        end
      end
    end
  end

  MHSRS_ENTRY_PACKET [`MHSRS_W-1:0] mshrs_table_next_after_issue;

  always_comb begin : issue_logic
    issue_next = issue;
    dcache2ctlr_command = BUS_NONE;     
    dcache2ctlr_addr = 0;
    dcache2ctlr_data = 0;
    mshrs_table_next_after_issue = mshrs_table_next_after_retire;
    if ((issue!=tail) && mshrs_table[issue].issued==1'b0) begin
      dcache2ctlr_command = mshrs_table[issue].command;     
      dcache2ctlr_addr = mshrs_table[issue].addr;
      dcache2ctlr_data = mshrs_table[issue].data;
    end
    if (mshrs_table[issue].command!= BUS_NONE && Ctlr2proc_response!=4'b0) begin
      mshrs_table_next_after_issue[issue].mem_tag = Ctlr2proc_response;
      mshrs_table_next_after_issue[issue].issued = 1'b1;
      issue_next = issue+1;
    end
  end


  logic [2:0][`MHSRS-1:0] tail_after_ld;
  logic [3:0][`MHSRS-1:0] tail_after_wr;
  logic [2:0] full_after_ld;
  logic [3:0] full_after_wr;
  logic [`MHSRS-1:0] h_t_distance;


  logic [1:0] ld_request;
  logic [1:0] ld_request_next;

  //assign ld_request_next[1] = ld_stall[1] && !rd_valid[1] && ld_start[1];
  //assign ld_request_next[0] = ld_stall[0] && !rd_valid[0] && ld_start[0];

  always_ff @( posedge clock ) begin
    if (reset) begin
      ld_request <= `SD 0;
    end
    else begin
      ld_request <= ld_request_next;
    end
  end


  logic is_there_store_miss;
  logic [1:0] is_there_load_hazard;
  logic [1:0][7:0] load_hazard, load_hazard_next;
  always_comb begin
    for(int i=0; i<8; i++) begin
      load_hazard_next[0][i] = mshrs_table[i].dirty && (mshrs_table[i].addr[`XLEN-1:3]==ld_addr_in[0][`XLEN-1:3]);
      load_hazard_next[1][i] = mshrs_table[i].dirty && (mshrs_table[i].addr[`XLEN-1:3]==ld_addr_in[1][`XLEN-1:3]);
    end
  end
always_ff @(posedge clock) begin
  if (reset) load_hazard <= `SD 0;
  else begin
    if (ld_start[0]) load_hazard[0] <= `SD load_hazard_next[0];
    else load_hazard[0] <= `SD load_hazard[0] & load_hazard_next[0];
    if (ld_start[1]) load_hazard[1] <= `SD load_hazard_next[1];
    else load_hazard[1] <= `SD load_hazard[1] & load_hazard_next[1];
  end
end

  assign is_there_load_hazard[0] = ld_start[0] ? |load_hazard_next[0] : |load_hazard[0];
  assign is_there_load_hazard[1] = ld_start[1] ? |load_hazard_next[1] : |load_hazard[1];

  assign is_there_store_miss = 0;
  //mshrs_table[7].dirty | mshrs_table[6].dirty | mshrs_table[5].dirty | mshrs_table[4].dirty
  //| mshrs_table[3].dirty | mshrs_table[2].dirty | mshrs_table[1].dirty | mshrs_table[0].dirty;



  //assign is_hit[1] =  rd_valid[1];  // no matter this load is started or not
 // assign is_hit[0] =  rd_valid[0]; 

  assign is_hit[1] = is_there_load_hazard[1] ? 0 : rd_valid[1];  // no matter this load is started or not
  assign is_hit[0] = is_there_load_hazard[0] ? 0 : rd_valid[0];  // no matter this load is started or not
  

  //assign ld_stall = full_after_ld[2:1];
  assign h_t_distance = head - tail;

  assign sq_stall[2] = sq_head_stall[2] | (is_there_store_miss ? 1'b1 : (h_t_distance==`MHSRS'd4));
  assign sq_stall[1] = sq_head_stall[1] | (is_there_store_miss ? 1'b1 : (h_t_distance==`MHSRS'd5));
  assign sq_stall[0] = sq_head_stall[0] | (is_there_store_miss ? 1'b1 : (h_t_distance==`MHSRS'd6));

  // assign sq_stall[2] = (is_there_store_miss ? 1'b1 : (h_t_distance==`MHSRS'd2));
  // assign sq_stall[1] = (is_there_store_miss ? 1'b1 : (h_t_distance==`MHSRS'd3));
  // assign sq_stall[0] = (is_there_store_miss ? 1'b1 : (h_t_distance==`MHSRS'd4));

  always_comb begin : tail_logic
    mshrs_table_next = mshrs_table_next_after_issue;
    ld_request_next = ld_request;
    tail_after_ld[2] = tail;
    full_after_ld[2] = (tail+2==head);   // +2 because reserve a seat for final possible STORE
    for (int i = 1; i >= 0; i--) begin
      if (!full_after_ld[i+1]  && ((!rd_valid[i] && ld_start[i])||ld_request)) begin   //need mem load
        //allocate i
        mshrs_table_next[tail_after_ld[i+1]].addr = {ld_addr_in[i][`XLEN-1:3],3'b0};
        mshrs_table_next[tail_after_ld[i+1]].command = BUS_LOAD;
        mshrs_table_next[tail_after_ld[i+1]].mem_tag = 0;
        mshrs_table_next[tail_after_ld[i+1]].left_or_right = ld_addr_in[i][2] ? 1'b1 : 1'b0;
        mshrs_table_next[tail_after_ld[i+1]].data = 0;
        mshrs_table_next[tail_after_ld[i+1]].issued = 0;
        mshrs_table_next[tail_after_ld[i+1]].broadcast_fu = (i==1) ? 2'b10 : 2'b01;
        mshrs_table_next[tail_after_ld[i+1]].usebytes = 8'b0;
        mshrs_table_next[tail_after_ld[i+1]].dirty = 0;
        tail_after_ld[i] = tail_after_ld[i+1] + 1;
        ld_request_next[i] = 1'b0;
      end
      else if ((full_after_ld[i+1]) && !rd_valid[i] && ld_start[i]) begin
        tail_after_ld[i] = tail_after_ld[i+1];
        ld_request_next[i] = 1'b1;
      end
      else begin
        tail_after_ld[i] = tail_after_ld[i+1];
      end
      full_after_ld[i] = (tail_after_ld[i]+2==head);
    end
    tail_after_wr[3] = tail_after_ld[0];
    for (int i = 2; i >= 0; i--) begin
      if (wr_en[i] && !wr_hit[i]) begin
        //allocate
        mshrs_table_next[tail_after_wr[i+1]].addr = ld_new_mem_addr[i];
        mshrs_table_next[tail_after_wr[i+1]].command = BUS_LOAD;
        mshrs_table_next[tail_after_wr[i+1]].mem_tag = 0;
        mshrs_table_next[tail_after_wr[i+1]].left_or_right = 0;
        mshrs_table_next[tail_after_wr[i+1]].data = wr_data[i];
        mshrs_table_next[tail_after_wr[i+1]].issued = 0;
        mshrs_table_next[tail_after_wr[i+1]].broadcast_fu = 0;
        mshrs_table_next[tail_after_wr[i+1]].usebytes = used_bytes[i];
        mshrs_table_next[tail_after_wr[i+1]].dirty = 1'b1;
        tail_after_wr[i] = tail_after_wr[i+1] + 1;
      end
      else begin
        tail_after_wr[i] = tail_after_wr[i+1];
      end
    end

    tail_next = tail_after_wr[0];
    if (need_write_mem) begin
        mshrs_table_next[tail_after_wr[0]].addr = wb_mem_addr;
        mshrs_table_next[tail_after_wr[0]].command = BUS_STORE;
        mshrs_table_next[tail_after_wr[0]].mem_tag = 0;
        mshrs_table_next[tail_after_wr[0]].left_or_right = 0;
        mshrs_table_next[tail_after_wr[0]].data = wb_mem_data;
        mshrs_table_next[tail_after_wr[0]].issued = 0;
        mshrs_table_next[tail_after_wr[0]].broadcast_fu = 0;
        mshrs_table_next[tail_after_wr[0]].usebytes = 0;
        mshrs_table_next[tail_after_wr[0]].dirty = 0;
        tail_next = tail_after_wr[0] + 1;
    end
  end

endmodule