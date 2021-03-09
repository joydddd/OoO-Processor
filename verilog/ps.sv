module ps2(
    input        [1:0] req,
    input              en,
    output logic [1:0] gnt,
    output logic       req_up
);
    always_comb begin
        if(~en)
            gnt = 2'b00;
        else if (req[1])
            gnt = 2'b10;
        else if (req[0])
            gnt = 2'b01;
        else 
            gnt = 2'b00;
    end

    always_comb begin
        if(req[1]|req[0])
            req_up = 1'b1;
        else
            req_up = 1'b0;
    end

endmodule

module ps4(
    input           [3:0] req,
    input                 en,
    output logic    [3:0] gnt,
    output logic          req_up
);
    wire [1:0]tmp;
    wire [1:0]sel;
    ps2 psl(.req(req[3:2]), .en(sel[1]), .gnt(gnt[3:2]), .req_up(tmp[1]));
    ps2 psr(.req(req[1:0]), .en(sel[0]), .gnt(gnt[1:0]), .req_up(tmp[0]));
    ps2 p2top(.req(tmp[1:0]), .en(en), .gnt(sel[1:0]), .req_up(req_up));
    

endmodule

module ps8(
    input       [7:0]   req,
    input               en,
    output logic [7:0] gnt,
    output logic        req_up
);
    wire [1:0]tmp;
    wire [1:0]sel;
    ps4 psl(.req(req[7:4]), .en(sel[1]), .gnt(gnt[7:4]), .req_up(tmp[1]));
    ps4 psr(.req(req[3:0]), .en(sel[0]), .gnt(gnt[3:0]), .req_up(tmp[0]));
    ps2 pstop(.req(tmp), .en(en), .gnt(sel), .req_up(req_up));

endmodule

module ps16(
    input        [15:0] req,
    input               en,
    output logic [15:0] gnt,
    output logic        req_up
);
    wire [3:0]tmp;
    wire [3:0]sel;
    ps4 ps_3(.req(req[15:12]), .en(sel[3]), .gnt(gnt[15:12]), .req_up(tmp[3]));
    ps4 ps_2 (.req(req[11:8]), .en(sel[2]), .gnt(gnt[11:8]), .req_up(tmp[2]));
    ps4 ps_1(.req(req[7:4]), .en(sel[1]), .gnt(gnt[7:4]), .req_up(tmp[1]));
    ps4 ps_0(.req(req[3:0]), .en(sel[0]), .gnt(gnt[3:0]), .req_up(tmp[0]));
    ps4 pstop(.req(tmp), .en(en), .gnt(sel), .req_up(req_up));

endmodule
