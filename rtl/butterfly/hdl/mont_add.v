//`include "CLA17.v"
module mont_add #(
    parameter pNTT_WIDTH = 16
)(
    input [(pNTT_WIDTH-1):0]in_A,
    input [(pNTT_WIDTH-1):0]in_B,
    input clk,
    input rst_n,
    input in_valid,
    output [(pNTT_WIDTH-1):0]result,
    output out_valid
);
localparam Q = 16'h3001;
localparam Qn = 17'h1CFFF;              // * negative Q
localparam zero = 1'b0;

wire cla_out_valid;
wire [(pNTT_WIDTH+1):0] cla1_result;
wire [(pNTT_WIDTH-1):0] cla1_result_tmp;
wire [(pNTT_WIDTH+1):0] cla2_result;
reg  [(pNTT_WIDTH-1):0] mont_add_reg[0:1];
CLA17 CLA17_1(
    .clk(clk),
    .rst_n(rst_n),
    .Cin(zero),
    .A({1'b0, in_A}),
    .B({1'b0, in_B}),
    .in_valid(in_valid),
    .out_valid(cla_out_valid),
    .result(cla1_result)
);
assign cla1_result_tmp = cla1_result[(pNTT_WIDTH-1):0];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mont_add_reg[0] <= {(pNTT_WIDTH){1'b0}};
        mont_add_reg[1] <= {(pNTT_WIDTH){1'b0}};
    end else begin
        mont_add_reg[0] <= cla1_result_tmp;
        mont_add_reg[1] <= mont_add_reg[0];
    end
end
CLA17 CLA17_2(
    .clk(clk),
    .rst_n(rst_n),
    .Cin(zero),
    .A({1'b0, cla1_result_tmp}),
    .B(Qn),
    .in_valid(cla_out_valid),
    .out_valid(out_valid),
    .result(cla2_result)
);
assign result = (cla2_result[(pNTT_WIDTH)] == 1'b1)? mont_add_reg[1]:cla2_result[(pNTT_WIDTH-1):0];


endmodule //mont_add