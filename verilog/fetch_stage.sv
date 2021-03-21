/*
Just for reference
typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
} IF_ID_PACKET;
*/

/**************Fake Cache**************/
/************For Debug Only************/
`timescale 1ns/100ps
module fake_cache (
    //input   [3:0]       Imem2proc_response, 
    //input  [63:0]       Imem2proc_data,
    //input   [3:0]       Imem2proc_tag,      

    input  [2:0][`XLEN-1:0]    pc,   
    //input  [63:0]       cachemem_data,
    //input               cachemem_valid,
    
    output logic [2:0]        cache_miss,
    output logic [2:0][31:0]  cache_rd_data
);

    logic [3:0] [63:0] data;
    logic [3:0] [26:0] tags;

    wire [2:0][1:0]     idx;
    wire [2:0][26:0]    pc_tag;

    assign idx[2] = pc[2][4:3];
    assign idx[1] = pc[1][4:3];
    assign idx[0] = pc[0][4:3];

    assign pc_tag[2] = pc[2][31:5];
    assign pc_tag[1] = pc[1][31:5];
    assign pc_tag[0] = pc[0][31:5];

    assign data[3] = 64'h123456789abcde12;
    assign data[2] = 64'h12415eb1561eba01;
    assign data[1] = 64'h157eb0a24183fc91;
    assign data[0] = 64'hfc8157e4a8701f9b;

    assign tags[3] = 0;
    assign tags[2] = 0;
    assign tags[1] = 0;
    assign tags[0] = 0;

    always_comb begin
        for (int i = 0; i < 3; i++) begin
            if (tags[idx[i]] == pc_tag[i]) begin
                if (pc[i][2])
                    cache_rd_data[i] = data[idx[i]][63:32];
                else
                    cache_rd_data[i] = data[idx[i]][31:0];
                cache_miss[i] = 1'b0;
            end
            else begin
                cache_rd_data[i] = 0;
                cache_miss[i] = 1'b1;
            end
        end
    end

endmodule

`timescale 1ns/100ps

module fetch_stage (
    input                       clock,
    input                       reset,
    input   [3:0]               Imem2proc_response, // icache input, 
    input  [63:0]               Imem2proc_data,     // icache input, the new data read from memory
    input   [3:0]               Imem2proc_tag,      // icache input, currently not used

    input  [63:0]               proc2Icache_addr,   // icache input, 
    input  [63:0]               cachemem_data,      // icache input, 
    input                       cachemem_valid,     // icache input, 

    input                       mem_busy,           // won't read new data if this is high
                                                    // mem_busy = reading_mem | writing_mem

    input                       take_branch,        // taken-branch signal
	input  [`XLEN-1:0]          target_pc,          // target pc: use if take_branch is TRUE


    output logic [`XLEN-1:0]    proc2Imem_addr,     // Address sent to Instruction memory
    output IF_ID_PACKET[2:0] 	if_packet_out       // output data from fetch stage to dispatch stage
);

    logic   [2:0][`XLEN-1:0]    PC_reg;             // the three PC we are currently fetching
    logic   [2:0][`XLEN-1:0]    next_PC;            // the next three PC we are gonna fetch

    logic   [2:0][7:0]  mem_count_down;
    logic   [2:0][7:0]  mem_count_down_next;
    logic   [1:0]       count_down_shift;
    wire    [2:0]       data_ready;

    logic   read_mem2, read_mem1;

    wire    [2:0]       cache_miss;
    wire    [2:0][31:0] cache_rd_data;
    // TODO: the registers that are needed to write cache
    //logic         wr1_en;
    //logic [63:0]  wr1_data;

    /**************For Debug**************/
    fake_cache fc(
        .pc(PC_reg),
        .cache_miss(cache_miss),
        .cache_rd_data(cache_rd_data)
    );
    /*****************end*****************/

    // data_ready indicate whether the data is available, either read from memory or in the cache
    assign  data_ready[2] = ~cache_miss[2] | mem_count_down[2] == 0;
    assign  data_ready[1] = ~cache_miss[1] | mem_count_down[1] == 0 | (mem_count_down[2] == 0 & PC_reg[1][`XLEN-1:3] == PC_reg[2][`XLEN-1:3]);
    assign  data_ready[0] = ~cache_miss[0] | mem_count_down[0] == 0 | (mem_count_down[1] == 0 & PC_reg[0][`XLEN-1:3] == PC_reg[1][`XLEN-1:3]) | (mem_count_down[2] == 0 & PC_reg[0][`XLEN-1:3] == PC_reg[2][`XLEN-1:3]);

	// the next_PC[2] (smallest PC) is:
    //  1. target_PC, if take branch
    //  2. PC_reg[2], if no branch and the current PC_reg[2] is not ready
	//  3. PC_reg[1], if no branch and the current PC_reg[1] is not ready
    //  4. PC_reg[0], if no branch and the current PC_reg[0] is not ready
    //  5. PC_reg[0] + 4 = PC_reg[2] + 12, if no branch and all three PCs are ready
	assign next_PC[2] = take_branch    ? target_pc :     // if take_branch, go to the target PC
                        ~data_ready[2] ? PC_reg[2] :     // if the first inst isn't ready, wait until finish reading from memory
                        ~data_ready[1] ? PC_reg[1] :     // same for the second inst
                        ~data_ready[0] ? PC_reg[0] :     // and the third inst
                        PC_reg[0] + 4;
    assign next_PC[1] = next_PC[2] + 4;
    assign next_PC[0] = next_PC[1] + 4;

    assign count_down_shift = take_branch    ? 2'd0 :
                              ~data_ready[2] ? 2'd0 :
                              ~data_ready[1] ? 2'd1 :
                              ~data_ready[0] ? 2'd2 :
                              2'd0;

    // Pass PC and NPC down pipeline w/instruction
	assign if_packet_out[2].NPC = PC_reg[2] + 4;
	assign if_packet_out[2].PC  = PC_reg[2];
    assign if_packet_out[1].NPC = PC_reg[1] + 4;
	assign if_packet_out[1].PC  = PC_reg[1];
    assign if_packet_out[0].NPC = PC_reg[0] + 4;
	assign if_packet_out[0].PC  = PC_reg[0];

    // Assign the valid bits of output
    assign if_packet_out[2].valid = data_ready[2] ? 1'b1 : 1'b0;
    assign if_packet_out[1].valid = ~if_packet_out[2].valid ? 1'b0 :
                                    data_ready[1] ? 1'b1 : 1'b0;
    assign if_packet_out[0].valid = ~if_packet_out[1].valid ? 1'b0 :
                                    data_ready[0] ? 1'b1 : 1'b0;

    // Assign the inst part of output
    assign if_packet_out[2].inst  = ~data_ready[2] ? 32'b0 : 
                                    ~cache_miss[2] ? cache_rd_data[2] :
                                    PC_reg[2][2]   ? Imem2proc_data[63:32] : 
                                    Imem2proc_data[31:0];
    assign if_packet_out[1].inst  = ~data_ready[1] ? 32'b0 : 
                                    ~cache_miss[1] ? cache_rd_data[1] :
                                    PC_reg[1][2]   ? Imem2proc_data[63:32] : 
                                    Imem2proc_data[31:0];
    assign if_packet_out[0].inst  = ~data_ready[0] ? 32'b0 : 
                                    ~cache_miss[0] ? cache_rd_data[0] :
                                    PC_reg[0][2]   ? Imem2proc_data[63:32] : 
                                    Imem2proc_data[31:0];

    always_comb begin
        proc2Imem_addr = {PC_reg[2][`XLEN-1:3], 3'b0};  // dummy initialization
        read_mem2 = 1'b0;
        read_mem1 = 1'b0;

        for (int i = 0; i < 3; i++) begin
            if (mem_count_down[i] == 0 || mem_count_down[i] > `MEM_LATENCY_IN_CYCLES)
                mem_count_down_next[i] = {8{1'b1}};
            else
                mem_count_down_next[i] = mem_count_down[i] - 1;
        end

        // initiate the reading from memory
        // do nothing if the reading has already begun
        if (!data_ready[2] && mem_count_down[2] > `MEM_LATENCY_IN_CYCLES && !mem_busy) begin
            proc2Imem_addr = {PC_reg[2][`XLEN-1:3], 3'b0};
            mem_count_down_next[2] = `MEM_LATENCY_IN_CYCLES - 1;
            read_mem2 = 1'b1;
        end
        if (!data_ready[1] && mem_count_down[1] > `MEM_LATENCY_IN_CYCLES && !mem_busy) begin
            if (!read_mem2 || PC_reg[2][`XLEN-1:3] == PC_reg[1][`XLEN-1:3]) begin
                proc2Imem_addr = {PC_reg[1][`XLEN-1:3], 3'b0};
                mem_count_down_next[1] = `MEM_LATENCY_IN_CYCLES - 1;
                read_mem1 = 1'b1;
            end
        end
        if (!data_ready[0] && mem_count_down[0] > `MEM_LATENCY_IN_CYCLES && !mem_busy) begin
            if ((!read_mem2 && !read_mem1) || 
                (read_mem2 && PC_reg[2][`XLEN-1:3] == PC_reg[0][`XLEN-1:3]) ||
                (read_mem1 && PC_reg[1][`XLEN-1:3] == PC_reg[0][`XLEN-1:3])) begin
                proc2Imem_addr = {PC_reg[0][`XLEN-1:3], 3'b0};
                mem_count_down_next[0] = `MEM_LATENCY_IN_CYCLES - 1;
            end
        end

        if (count_down_shift == 2'd1) begin
            mem_count_down_next[2] = mem_count_down_next[1];
            mem_count_down_next[1] = mem_count_down_next[0];
            mem_count_down_next[0] = {8{1'b1}};
        end
        else if (count_down_shift == 2'd2) begin
            mem_count_down_next[2] = mem_count_down_next[0];
            mem_count_down_next[1] = {8{1'b1}};
            mem_count_down_next[0] = {8{1'b1}};
        end

        // TODO: update the cache when finishing reading from memory
        /*
        if (mem_count_down[2] == 0) begin
            wr1_en = 1'b1;
        end
        */
        
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
			PC_reg <= `SD {`XLEN'd0, `XLEN'd4, `XLEN'd8};       // initial PC value
            mem_count_down <= `SD {24{1'b1}};
        end
		else begin
			PC_reg <= `SD next_PC; // transition to next PC
            mem_count_down <= `SD mem_count_down_next;
        end
    end


endmodule
