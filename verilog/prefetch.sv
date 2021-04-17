//`define TEST_MODE

`timescale 1ns/100ps

module prefetch (
    input                       clock,
    input                       reset,
    input  [3:0]                Imem2pref_response,
    input  [3:0]                Imem2pref_tag,

    input                       give_way,           // it's high if the current load request is rejected when the fetch stage is also fetching
    input                       branch,             // it's high when the PC is not sequential
    input  [2:0][`XLEN-1:0]     proc2Icache_addr,   // current address the fetch stage is fetching
    input  [2:0]                cachemem_valid,

    input                       want_to_fetch,      // icache tells prefetch if it wants to send a new request

    output logic                already_fetched,     // tell icache if the request has already been sent

    output logic [1:0]          prefetch_command,
    output logic [`XLEN-1:0]    prefetch_addr,
    output logic [4:0]          prefetch_index,
    output logic [7:0]          prefetch_tag,
    output logic                prefetch_wr_enable

    `ifdef  TEST_MODE
    , output logic [7:0]                 pref_count_display
    , output logic [`PREF-1:0][3:0]      mem_tag_display
    , output logic [`PREF-1:0][4:0]      store_prefetch_index_display
    , output logic [`PREF-1:0][7:0]      store_prefetch_tag_display
    `endif
);

    logic [3:0]                 sync_Imem2pref_response;

    logic [`PREF-1:0][3:0]      mem_tag;           // default value is 0 if not valid
    logic [`PREF-1:0][3:0]      mem_tag_next;
    logic [`PREF-1:0][4:0]      store_prefetch_index;
    logic [`PREF-1:0][4:0]      store_prefetch_index_next;
    logic [`PREF-1:0][7:0]      store_prefetch_tag;
    logic [`PREF-1:0][7:0]      store_prefetch_tag_next;
    
    logic [7:0]                 pref_count;         // count how many lines have been prefetched (any length that is long enough is ok)
    logic [7:0]                 pref_count_last;
    logic [7:0]                 backward;
    logic [7:0]                 forward;

    logic                       store_new_tag;
    logic [`XLEN-1:0]           first_miss_addr;
    logic [`XLEN-1:0]           non_sync_prefetch_addr;

    logic                       found_a_loc;

    wire pref_enough = pref_count_last >= `PREF;

    wire pref_enable = ~pref_enough & ~branch;

    wire mem_reject = pref_enable && ~give_way && (Imem2pref_response == 0);

    wire response_valid = pref_enable & ~give_way & ~mem_reject;

    `ifdef TEST_MODE
    assign mem_tag_display = mem_tag;
    assign pref_count_display = pref_count;
    assign store_prefetch_index_display = store_prefetch_index;
    assign store_prefetch_tag_display = store_prefetch_tag;
    `endif


    assign prefetch_command = pref_enable ? BUS_LOAD : BUS_NONE;

    assign first_miss_addr = ~cachemem_valid[2] ? proc2Icache_addr[2] :
                             ~cachemem_valid[1] ? proc2Icache_addr[1] :
                             ~cachemem_valid[0] ? proc2Icache_addr[0] :
                             proc2Icache_addr[0] + 4;

    assign backward = ~cachemem_valid[2] ? 0 :
                      ~cachemem_valid[1] ? (proc2Icache_addr[1][3] == proc2Icache_addr[2][3]) :
                      ~cachemem_valid[0] && (proc2Icache_addr[1][3] == proc2Icache_addr[2][3]) ? 1 :
                      2;

    assign forward = pref_enough ? 0 :
                     give_way    ? 0 :
                     mem_reject  ? 0 :
                     1;

    wire start_zero = first_miss_addr[`XLEN-1:3] == 0;

    assign non_sync_prefetch_addr = start_zero ? ({first_miss_addr[`XLEN-1:3], 3'b000} + 8 * pref_count) :
                                    ({first_miss_addr[`XLEN-1:3], 3'b000} + 8 * pref_count - 8);


    wire pref_count_negative = (pref_count_last == 0 && backward > forward) || (pref_count_last == 1 && backward > forward + 1);

    assign pref_count = branch ? 7'd0 :
                        pref_count_negative ? 7'd0 :
                        pref_count_last - backward + forward;

    always_comb begin
        already_fetched = 0;
        if (want_to_fetch) begin
            for (int i = 0; i < `PREF; i++) begin
                if (mem_tag[i] != 0 && first_miss_addr[15:3] == {store_prefetch_tag[i], store_prefetch_index[i]})
                    already_fetched = 1;
            end
        end

        // whether to store the data from memory
        prefetch_index = 0;
        prefetch_tag = 0;
        prefetch_wr_enable = 1'b0;
        mem_tag_next = mem_tag;
        for (int i = 0; i < `PREF; i++) begin
            if (mem_tag[i] != 0 && mem_tag[i] == Imem2pref_tag) begin
                prefetch_index = store_prefetch_index[i];
                prefetch_tag = store_prefetch_tag[i];
                prefetch_wr_enable = 1'b1;
                mem_tag_next[i] = 0;
            end
        end

        found_a_loc = 0;
        store_prefetch_tag_next = store_prefetch_tag;
        store_prefetch_index_next = store_prefetch_index;
        if (response_valid) begin
            for (int i = 0; i < `PREF; i++) begin
                if (!found_a_loc && mem_tag[i] == 4'd0) begin
                    {store_prefetch_tag_next[i], store_prefetch_index_next[i]} = prefetch_addr[`XLEN-1:3];
                    mem_tag_next[i] = Imem2pref_response;
                    found_a_loc = 1'b1;
                end
            end
        end

    end

    always_ff @(posedge clock) begin
        if (reset) begin
            mem_tag <= `SD 0;
            store_prefetch_tag <= `SD 0;
            store_prefetch_index <= `SD 0;
            sync_Imem2pref_response <= `SD 0;
            pref_count_last <= `SD 0;
            prefetch_addr <= `SD 0;
        end
        else begin
            mem_tag <= `SD mem_tag_next;
            store_prefetch_tag <= `SD store_prefetch_tag_next;
            store_prefetch_index <= `SD store_prefetch_index_next;
            sync_Imem2pref_response <= `SD Imem2pref_response;
            pref_count_last <= `SD pref_count;
            prefetch_addr <= `SD non_sync_prefetch_addr;
        end
    end


endmodule