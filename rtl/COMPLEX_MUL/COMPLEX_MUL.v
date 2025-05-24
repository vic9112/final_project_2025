`include "FLOAT_ADD.v"
`include "FLOAT_MUL.v"
module COMPLEX_MUL #(
    parameter pDATA_WIDTH=128
)(
    input [(pDATA_WIDTH-1):0]num1,//Xr(64bit) + jXi(64bit)
    input [(pDATA_WIDTH-1):0]num2,//Yr(64bit) + jYi(64bit)
    input clk,
    input rstn,
    output [(pDATA_WIDTH-1):0]result,
    input valid,
    output ready
);
//num1 = Xr + jXi
//num2 = Yr + jYi
//-----stage 1-----//
//8 cycle
wire [63:0]negative_num1i = {~num1[63], num1[62:0]};
wire [63:0]negative_num2i = {~num2[63], num2[62:0]};
wire [63:0]stage1_add1_result;
wire [63:0]stage1_add2_result;
wire [63:0]stage1_add3_result;
wire stage1_add1_ready;
wire stage1_add2_ready;
wire stage1_add3_ready;
//Yr+Yi
FLOAT_ADD stage1_add1(
    .num1(num2[127:64]),
    .num2(num2[63:0]),
    .clk(clk),
    .rstn(rstn),
    .result(stage1_add1_result),
    .valid(valid),
    .ready(stage1_add1_ready)
);
//Xr-Xi
FLOAT_ADD stage1_add2(
    .num1(num1[127:64]),
    .num2(negative_num1i),
    .clk(clk),
    .rstn(rstn),
    .result(stage1_add2_result),
    .valid(valid),
    .ready(stage1_add2_ready)
);
//Yr-Yi
FLOAT_ADD stage1_add3(
    .num1(num2[127:64]),
    .num2(negative_num2i),
    .clk(clk),
    .rstn(rstn),
    .result(stage1_add3_result),
    .valid(valid),
    .ready(stage1_add3_ready)
);
//-----stage 1-----//

//-----stage 2-----//
//14 cycle
wire [63:0]stage2_mul1_result;
wire [63:0]stage2_mul2_result;
wire [63:0]stage2_mul3_result;
wire stage2_mul1_ready;
wire stage2_mul2_ready;
wire stage2_mul3_ready;
//Xi * (Yr + Yi)
FLOAT_MUL stage2_mul1(
    .num1(pip8_num1[63:0]),
    .num2(stage1_add1_result),
    .clk(clk),
    .rstn(rstn),
    .result(stage2_mul1_result),
    .valid(stage1_add1_ready),
    .ready(stage2_mul1_ready)
);
//Yi * (Xr - Xi)
FLOAT_MUL stage2_mul2(
    .num1(pip8_num2[63:0]),
    .num2(stage1_add2_result),
    .clk(clk),
    .rstn(rstn),
    .result(stage2_mul2_result),
    .valid(stage1_add2_ready),
    .ready(stage2_mul2_ready)
);
//Xr * (Yr - Yi)
FLOAT_MUL stage2_mul3(
    .num1(pip8_num1[127:64]),
    .num2(stage1_add3_result),
    .clk(clk),
    .rstn(rstn),
    .result(stage2_mul3_result),
    .valid(stage1_add3_ready),
    .ready(stage2_mul3_ready)
);
//-----stage 2-----//

//-----stage 3-----//
//8 cycle
wire stage3_add1_ready;
wire stage3_add2_ready;
wire stage2_1_ready = stage2_mul1_ready & stage2_mul2_ready;
wire stage2_2_ready = stage2_mul2_ready & stage2_mul3_ready;
assign ready = stage3_add1_ready & stage3_add2_ready;
//Zi = Xi * (Yr + Yi) + Yi * (Xr - Xi)
FLOAT_ADD stage3_add1(
    .num1(stage2_mul1_result),
    .num2(stage2_mul2_result),
    .clk(clk),
    .rstn(rstn),
    .result(result[63:0]),
    .valid(stage2_1_ready),
    .ready(stage3_add1_ready)
);
//Zr = Xr * (Yr - Yi) + Yi * (Xr - Xi)
FLOAT_ADD stage3_add2(
    .num1(stage2_mul3_result),
    .num2(stage2_mul2_result),
    .clk(clk),
    .rstn(rstn),
    .result(result[127:64]),
    .valid(stage2_2_ready),
    .ready(stage3_add2_ready)
);
//-----stage 3-----//

//-----pip-----//
//buffer for stage2 num1 & num2
reg [127:0]pip1_num1;
reg [63:0]pip1_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip1_num1 <= 0;
      pip1_num2 <= 0;
    end else begin
      pip1_num1 <= num1;
      pip1_num2 <= num2[63:0];
    end
end

reg [127:0]pip2_num1;
reg [63:0]pip2_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip2_num1 <= 0;
      pip2_num2 <= 0;
    end else begin
      pip2_num1 <= pip1_num1;
      pip2_num2 <= pip1_num2;
    end
end

reg [127:0]pip3_num1;
reg [63:0]pip3_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip3_num1 <= 0;
      pip3_num2 <= 0;
    end else begin
      pip3_num1 <= pip2_num1;
      pip3_num2 <= pip2_num2;
    end
end

reg [127:0]pip4_num1;
reg [63:0]pip4_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip4_num1 <= 0;
      pip4_num2 <= 0;
    end else begin
      pip4_num1 <= pip3_num1;
      pip4_num2 <= pip3_num2;
    end
end

reg [127:0]pip5_num1;
reg [63:0]pip5_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip5_num1 <= 0;
      pip5_num2 <= 0;
    end else begin
      pip5_num1 <= pip4_num1;
      pip5_num2 <= pip4_num2;
    end
end

reg [127:0]pip6_num1;
reg [63:0]pip6_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip6_num1 <= 0;
      pip6_num2 <= 0;
    end else begin
      pip6_num1 <= pip5_num1;
      pip6_num2 <= pip5_num2;
    end
end

reg [127:0]pip7_num1;
reg [63:0]pip7_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip7_num1 <= 0;
      pip7_num2 <= 0;
    end else begin
      pip7_num1 <= pip6_num1;
      pip7_num2 <= pip6_num2;
    end
end

reg [127:0]pip8_num1;
reg [63:0]pip8_num2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip8_num1 <= 0;
      pip8_num2 <= 0;
    end else begin
      pip8_num1 <= pip7_num1;
      pip8_num2 <= pip7_num2;
    end
end

//-----pip-----//

endmodule //COMPLEX_MUL