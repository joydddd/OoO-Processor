`timescale 1ns/100ps
`ifndef __PIPE_TEST_SV__
`define __PIPE_TEST_SV__

`define TEST_MODE 
`define DIS_DEBUG

/* import freelist simulator */
import "DPI-C" function void fl_init();
import "DPI-C" function int fl_new_pr_valid();
import "DPI-C" function int fl_new_pr2();
import "DPI-C" function int fl_new_pr1();
import "DPI-C" function int fl_new_pr0();
import "DPI-C" function int fl_pop(int new_pr_en);

/* import map table simulator */ 
import "DPI-C" function void mt_init();
import "DPI-C" function int look_up(int i);
import "DPI-C" function int map(int ar, int pr);


module testbench;
logic clock, reset;

`ifdef TEST_MODE
IF_ID_PACKET                if_d_packet_debug;
logic [2:0]                 dis_new_pr_en_out;
/* free list simulation */
logic [2:0]                 free_pr_valid_debug;
logic [2:0][`PR-1:0]        free_pr_debug;

/* maptable simulation */
logic [2:0] [4:0]           maptable_lookup_reg1_ar_out;
logic [2:0] [4:0]           maptable_lookup_reg2_ar_out;
logic [2:0] [4:0]           maptable_allocate_ar_out;
logic [2:0] [`PR-1:0]       maptable_allocate_pr_out;
logic [2:0][`PR-1:0]        maptable_old_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg1_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg2_pr_debug;
logic [2:0][`PR-1:0]        maptable_reg1_ready_debug;
logic [2:0][`PR-1:0]        maptable_reg2_ready_debug;
`endif

endmodule


`endif // __PIPE_TEST_SV__