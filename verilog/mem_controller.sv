///////////////////////////////////////////////////////////////////////////////
//                                                                           //
//  Modulename : mem_controller.sv                                           //
//                                                                           //
//                                                                           // 
///////////////////////////////////////////////////////////////////////////////

`ifndef __MEM_CONTROLLER_SV__
`define __MEM_CONTROLLER_SV__

`timescale 1ns/100ps


module mem_controller (
    /* to mem */
    input [3:0] mem2ctlr_response,  // <- mem
	input [63:0] mem2ctlr_data,     // <- mem
	input [3:0] mem2ctlr_tag,       // <- mem

    output logic [1:0] ctlr2mem_command,  // -> mem
    output logic [`XLEN-1:0] ctlr2mem_addr, // ->mem
    output logic [63:0] ctlr2mem_data,

    /* to Icache */
    input [1:0] icache2ctlr_command,      
    input [`XLEN-1:0] icache2ctlr_addr,    

    output  logic [3:0] ctlr2icache_response,           
    output  logic [63:0] ctlr2icache_data,              
    output  logic [3:0] ctlr2icache_tag,   // directly assign
    output  logic d_request,             // if high, mem is assigned to Dcache

    /* to Dcache */
    input [1:0] dcache2ctlr_command,      
    input [`XLEN-1:0] dcache2ctlr_addr,  
    input [63:0] dcache2ctlr_data,

    output  logic [3:0] ctlr2dcache_response,           
    output  logic [63:0] ctlr2dcache_data,              
    output  logic [3:0] ctlr2dcache_tag

);

    logic i_request;
    assign i_request = icache2ctlr_command != BUS_NONE;
    assign d_request = dcache2ctlr_command != BUS_NONE;

    //pass through 
    assign  ctlr2icache_response = mem2ctlr_response;
    assign  ctlr2icache_data = mem2ctlr_data;
    assign  ctlr2icache_tag = mem2ctlr_tag;

    assign  ctlr2dcache_response = mem2ctlr_response;
    assign  ctlr2dcache_data = mem2ctlr_data;
    assign  ctlr2dcache_tag = mem2ctlr_tag;

    always_comb begin
        if (d_request) begin
            ctlr2mem_command = dcache2ctlr_command;
            ctlr2mem_addr = dcache2ctlr_addr;
            ctlr2mem_data = dcache2ctlr_data;
        end
        else if (i_request) begin
            ctlr2mem_command = icache2ctlr_command;
            ctlr2mem_addr = icache2ctlr_addr;
            ctlr2mem_data = 0;
        end
        else begin
            ctlr2mem_command = BUS_NONE;
            ctlr2mem_addr = 0;
            ctlr2mem_data = 0;
        end
    end


endmodule

`endif
