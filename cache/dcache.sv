
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
    input SQ_ENTRY_PACKET [2:0] sq_in,
    output sq_stall,

    /* with Load-FU/LQ */
    input [1:0] [`XLEN-1:0] ld_addr_in,   // This addr is word aligned !
    input [1:0] ld_start,
    output logic [1:0] is_hit,
    output logic [1:0] [`XLEN-1:0] ld_data,    //valid if hit
    output logic [3:0] broadcast_tag,
    output logic [`XLEN-1:0] broadcast_data,
    output [1:0] ld_stall

  );

  /* for dcache_mem */
  logic  [2:0] wr_en;                                    
  logic  [2:0][4:0] wr_idx;                                 
  logic  [2:0][7:0] wr_tag;                               
  logic  [2:0][63:0] wr_data;   
  logic  [2:0][7:0] used_bytes;                          

  logic  [1:0][4:0] rd_idx;                        
  logic  [1:0][7:0] rd_tag;

  logic  [1:0][63:0] rd_data;          
  logic  [1:0] rd_valid;                  

  logic  [2:0] need_write_mem;
  logic  [2:0][63:0]  wb_mem_data;

  logic  [2:0][`XLEN-1:0] wb_mem_addr;  //This can be directly calculated

  logic        wr2_en;        //For the miss load back
  logic  [4:0] wr2_idx;               
  logic  [7:0] wr2_tag;                    
  logic  [63:0] wr2_data;


  always_comb begin : SQ_input_processing
    for (int i = 2; i>= 0; i--) begin
      wr_en[i] = sq_in[i].ready;
      {wr_tag[i], wr_idx[i]} = sq_in[i].addr[`XLEN-1:3];
      wb_mem_addr[i] = {sq_in[i].addr[`XLEN-1:3], 3'b0};
      if (sq_in[i].addr[2]==1'b1) begin
        wr_data[i] = {sq_in[i].data, `XLEN'b0};
        used_bytes = {sq_in[i].usebytes, 4'b0};
      end
      else begin
        wr_data[i] = {`XLEN'b0, sq_in[i].data};
        used_bytes = {4'b0, sq_in[i].usebytes};
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
    .rd1_idx(rd_idx),
    .rd1_tag(rd_tag),
    .rd1_data(rd_data),
    .rd1_valid(rd_valid),
    .need_write_mem(need_write_mem),
    .wb_mem_data(wb_mem_data),
    .wr2_en(wr2_en),
    .wr2_idx(wr2_idx),
    .wr2_tag(wr2_tag),
    .wr2_data(wr2_data)
  );

  assign is_hit = rd_valid;  // no matter this load is started or not
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

  logic [`MHSRS-1:0] head, issue, tail;
  logic [`MHSRS-1:0] head_next, issue_next, tail_next;

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


  always_comb begin : head_logic
    head_next = head;
    broadcast_tag = 0;
    broadcast_data = 0;
    wr2_en = 0;
    wr2_idx = 0;
    wr2_tag = 0;
    wr2_data = 0;
    mshrs_table_next_after_retire = mshrs_table;
    if ((head!=tail) && (Ctlr2proc_tag==mshrs_table[head].mem_tag) && mshrs_table[head].issued) begin
      head_next = head + 1;
      mshrs_table_next_after_retire[head].issued = 1'b0;
      if (mshrs_table[head].command==BUS_LOAD) begin
        broadcast_tag = mshrs_table[head].mem_tag;
        broadcast_data = mshrs_table[head].left_or_right ? Ctlr2proc_data[63:32] : Ctlr2proc_data[31:0];
        wr2_en = 1'b1;
        //wr2_tag = mshrs_table[head].addr[15:8];
        //wr2_idx = mshrs_table[head].addr[7:3];
        {wr2_tag, wr2_idx} = mshrs_table[head].addr[`XLEN-1:3];
        wr2_data = Ctlr2proc_data;
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
    if (Ctlr2proc_response!=0) begin
      mshrs_table_next_after_issue[issue].mem_tag = Ctlr2proc_response;
      mshrs_table_next_after_issue[issue].issued = 1'b1;
      issue_next = issue+1;
    end
  end


  logic [2:0][`MHSRS-1:0] tail_after_ld;
  logic [3:0][`MHSRS-1:0] tail_after_wr;
  logic [2:0] full_after_ld;
  logic [3:0] full_after_wr;

  assign ld_stall = full_after_ld[2:1];
  assign sq_stall = full_after_wr[3:1];

  always_comb begin : tail_logic
    mshrs_table_next = mshrs_table_next_after_issue;
    tail_after_ld[2] = tail;
    full_after_ld[2] = (tail+1==head);
    for (int i = 1; i >= 0; i--) begin
      if (!full_after_ld[i+1] && !rd_valid[i] && ld_start[i]) begin   //need mem load
        //allocate
        mshrs_table_next[tail_after_ld[i+1]].addr = {ld_addr_in[i][`XLEN-1:3],3'b0};
        mshrs_table_next[tail_after_ld[i+1]].command = BUS_LOAD;
        mshrs_table_next[tail_after_ld[i+1]].mem_tag = 0;
        mshrs_table_next[tail_after_ld[i+1]].left_or_right = ld_addr_in[i][2] ? 1'b1 : 1'b0;
        mshrs_table_next[tail_after_ld[i+1]].data = 0;
        mshrs_table_next[tail_after_ld[i+1]].issued = 0;
        tail_after_ld[i] = tail_after_ld[i+1] + 1;
      end
      else begin
        tail_after_ld[i] = tail_after_ld[i+1];
      end
      full_after_ld[i] = (tail_after_ld[i]+1==head);
    end
    tail_after_wr[3] = tail_after_ld[0];
    full_after_wr[3] = full_after_ld[0];
    for (int i = 2; i >= 0; i--) begin
      if (!full_after_wr[i+1] && need_write_mem[i]) begin
        //allocate
        mshrs_table_next[tail_after_wr[i+1]].addr = wb_mem_addr[i];
        mshrs_table_next[tail_after_wr[i+1]].command = BUS_STORE;
        mshrs_table_next[tail_after_wr[i+1]].mem_tag = 0;
        mshrs_table_next[tail_after_wr[i+1]].left_or_right = 0;
        mshrs_table_next[tail_after_wr[i+1]].data = wb_mem_data[i];
        mshrs_table_next[tail_after_wr[i+1]].issued = 0;
        tail_after_wr[i] = tail_after_wr[i+1] + 1;
      end
      else begin
        tail_after_wr[i] = tail_after_wr[i+1];
      end
      full_after_wr[i] = (tail_after_wr[i]+1==head);
    end
    tail_next = tail_after_wr[0];
  end



endmodule