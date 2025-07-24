module mul16_array_intt #(
    parameter pDi_WIDTH = 64 ,
    parameter pDo_WIDTH = 32 
)
( 
    input[(pDi_WIDTH-1):0]    in_B0,  // * input 64bit data
    input[(pDi_WIDTH-1):0]    in_B1,  // FFT: in_B1 = in_B2, NTT in_B1 != in_B2
    input                     clk,
    input                     rst_n,
    input                     in_valid,
    output                    out_valid,
    
    //-------- result from mul_16 ---------//
    output[(pDo_WIDTH-1):0]     result_00,
    output[(pDo_WIDTH-1):0]     result_01,
    output[(pDo_WIDTH-1):0]     result_02,
    output[(pDo_WIDTH-1):0]     result_03,
    
    output[(pDo_WIDTH-1):0]     result_10,
    output[(pDo_WIDTH-1):0]     result_11,
    output[(pDo_WIDTH-1):0]     result_12,
    output[(pDo_WIDTH-1):0]     result_13,
    
    output[(pDo_WIDTH-1):0]     result_20,
    output[(pDo_WIDTH-1):0]     result_21,
    output[(pDo_WIDTH-1):0]     result_22,
    output[(pDo_WIDTH-1):0]     result_23,

    output[(pDo_WIDTH-1):0]     result_30,
    output[(pDo_WIDTH-1):0]     result_31,
    output[(pDo_WIDTH-1):0]     result_32,
    output[(pDo_WIDTH-1):0]     result_33

);
//============================================================================================//
localparam pMUL_WIDTH = 16;
localparam C_MUL   = 1'b0;
localparam INT_MUL = 1'b1;
localparam Q01 = 16'h2FFF;
localparam Q = 16'h3001;
//============================================================================================//

wire                     o_valid[0:15];
reg                      o_valid_buf[0:7];
wire                     i_valid[0:7];

wire [(pDo_WIDTH-1):0]   result_0[0:3];
wire [(pDo_WIDTH-1):0]   result_1[0:3];
wire [(pDo_WIDTH-1):0]   result_2[0:3];
wire [(pDo_WIDTH-1):0]   result_3[0:3];

wire [(pMUL_WIDTH-1):0]in_a00;
wire [(pMUL_WIDTH-1):0]in_a01;
wire [(pMUL_WIDTH-1):0]in_a02;
wire [(pMUL_WIDTH-1):0]in_a03;
wire [(pMUL_WIDTH-1):0]in_a10;
wire [(pMUL_WIDTH-1):0]in_a11;
wire [(pMUL_WIDTH-1):0]in_a12;
wire [(pMUL_WIDTH-1):0]in_a13;
wire [(pMUL_WIDTH-1):0]in_a20;
wire [(pMUL_WIDTH-1):0]in_a21;
wire [(pMUL_WIDTH-1):0]in_a22;
wire [(pMUL_WIDTH-1):0]in_a23;
wire [(pMUL_WIDTH-1):0]in_a30;
wire [(pMUL_WIDTH-1):0]in_a31;
wire [(pMUL_WIDTH-1):0]in_a32;
wire [(pMUL_WIDTH-1):0]in_a33;

wire [(pMUL_WIDTH-1):0]in_b00;
wire [(pMUL_WIDTH-1):0]in_b01;
wire [(pMUL_WIDTH-1):0]in_b02;
wire [(pMUL_WIDTH-1):0]in_b03;
wire [(pMUL_WIDTH-1):0]in_b10;
wire [(pMUL_WIDTH-1):0]in_b11;
wire [(pMUL_WIDTH-1):0]in_b12;
wire [(pMUL_WIDTH-1):0]in_b13;
wire [(pMUL_WIDTH-1):0]in_b20;
wire [(pMUL_WIDTH-1):0]in_b21;
wire [(pMUL_WIDTH-1):0]in_b22;
wire [(pMUL_WIDTH-1):0]in_b23;
wire [(pMUL_WIDTH-1):0]in_b30;
wire [(pMUL_WIDTH-1):0]in_b31;
wire [(pMUL_WIDTH-1):0]in_b32;
wire [(pMUL_WIDTH-1):0]in_b33;
reg  [(pMUL_WIDTH-1):0]in_buf[7:0];
//============================================================================================//

//For FFT in_B0 = in B1 = array_in_A0 
//For NTT in_B0 = mul_16_result_b3[3][15:0] , mul_16_result_b2[2][15:0] , mul_16_result_b1[1][15:0] , mul_16_result_b0[0][15:0]
//For NTT in_B1 = mul_16_result_c3[3][15:0] , mul_16_result_c2[2][15:0] , mul_16_result_c1[1][15:0] , mul_16_result_c0[0][15:0]
// a = 0(row)
assign in_a00 = Q01;
assign in_a01 = Q01;
assign in_a02 = Q01;
assign in_a03 = Q01;
// a = 1(row)
assign in_a10 = Q01;
assign in_a11 = Q01;
assign in_a12 = Q01;
assign in_a13 = Q01;
// a = 2(row)
assign in_a20 = Q;
assign in_a21 = Q;
assign in_a22 = Q;
assign in_a23 = Q;
// a = 3(row)
assign in_a30 = Q;
assign in_a31 = Q;
assign in_a32 = Q;
assign in_a33 = Q;
// b = 0(column)
assign in_b00 = in_B0[(pMUL_WIDTH-1):0];
assign in_b10 = in_B1[(pMUL_WIDTH-1):0];
assign in_b20 = in_buf[0];
assign in_b30 = in_buf[1];
// b = 1(column)
assign in_b01 = in_B0[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_b11 = in_B1[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_b21 = in_buf[2];
assign in_b31 = in_buf[3];
// b = 2(column)
assign in_b02 = in_B0[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_b12 = in_B1[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_b22 = in_buf[4];
assign in_b32 = in_buf[5];
// b = 3(column)
assign in_b03 = in_B0[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_b13 = in_B1[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_b23 = in_buf[6];
assign in_b33 = in_buf[7];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_buf[0] <= 0;
      in_buf[1] <= 0;
      in_buf[2] <= 0;
      in_buf[3] <= 0;
      in_buf[4] <= 0;
      in_buf[5] <= 0;
      in_buf[6] <= 0;
      in_buf[7] <= 0;
      o_valid_buf[0] <= 0;
      o_valid_buf[1] <= 0;
      o_valid_buf[2] <= 0;
      o_valid_buf[3] <= 0;
      o_valid_buf[4] <= 0;
      o_valid_buf[5] <= 0;
      o_valid_buf[6] <= 0;
      o_valid_buf[7] <= 0;
    end else begin
      in_buf[0] <= result_0[0][(pMUL_WIDTH-1):0];//Structure output: (0, 0)
      in_buf[1] <= result_0[1][(pMUL_WIDTH-1):0];//Structure output: (1, 0)
      in_buf[2] <= result_1[0][(pMUL_WIDTH-1):0];//Structure output: (0, 1)
      in_buf[3] <= result_1[1][(pMUL_WIDTH-1):0];//Structure output: (1, 1)
      in_buf[4] <= result_2[0][(pMUL_WIDTH-1):0];//Structure output: (0, 2)
      in_buf[5] <= result_2[1][(pMUL_WIDTH-1):0];//Structure output: (1, 2)
      in_buf[6] <= result_3[0][(pMUL_WIDTH-1):0];//Structure output: (0, 3)
      in_buf[7] <= result_3[1][(pMUL_WIDTH-1):0];//Structure output: (1, 3)
      o_valid_buf[0] <= o_valid[0] ;//Structure valid: (0, 0)
      o_valid_buf[1] <= o_valid[4] ;//Structure valid: (0, 1)
      o_valid_buf[2] <= o_valid[8] ;//Structure valid: (0, 2)
      o_valid_buf[3] <= o_valid[12];//Structure valid: (0, 3)
      o_valid_buf[4] <= o_valid[1] ;//Structure valid: (1, 0)
      o_valid_buf[5] <= o_valid[5] ;//Structure valid: (1, 1)
      o_valid_buf[6] <= o_valid[9] ;//Structure valid: (1, 2)
      o_valid_buf[7] <= o_valid[13];//Structure valid: (1, 3)
    end
end

assign i_valid[0] = o_valid_buf[0];
assign i_valid[1] = o_valid_buf[1];
assign i_valid[2] = o_valid_buf[2];
assign i_valid[3] = o_valid_buf[3];
assign i_valid[4] = o_valid_buf[4];
assign i_valid[5] = o_valid_buf[5];
assign i_valid[6] = o_valid_buf[6];
assign i_valid[7] = o_valid_buf[7];
//a = 0(row)
mul_16 mul_16_00 (.in_a(in_a00), .in_b(in_b00), .in_valid(in_valid), .out_valid(o_valid[0]),  .result(result_0[0]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_01 (.in_a(in_a01), .in_b(in_b01), .in_valid(in_valid), .out_valid(o_valid[4]),  .result(result_1[0]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_02 (.in_a(in_a02), .in_b(in_b02), .in_valid(in_valid), .out_valid(o_valid[8]),  .result(result_2[0]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_03 (.in_a(in_a03), .in_b(in_b03), .in_valid(in_valid), .out_valid(o_valid[12]), .result(result_3[0]), .clk(clk), .rst_n(rst_n));

// a = 1(row)
mul_16 mul_16_10 (.in_a(in_a10), .in_b(in_b10), .in_valid(in_valid), .out_valid(o_valid[1]),  .result(result_0[1]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_11 (.in_a(in_a11), .in_b(in_b11), .in_valid(in_valid), .out_valid(o_valid[5]),  .result(result_1[1]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_12 (.in_a(in_a12), .in_b(in_b12), .in_valid(in_valid), .out_valid(o_valid[9]),  .result(result_2[1]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_13 (.in_a(in_a13), .in_b(in_b13), .in_valid(in_valid), .out_valid(o_valid[13]), .result(result_3[1]), .clk(clk), .rst_n(rst_n));

// a = 2(row)
mul_16 mul_16_20 (.in_a(in_a20), .in_b(in_b20), .in_valid(i_valid[0]), .out_valid(o_valid[2]),  .result(result_0[2]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_21 (.in_a(in_a21), .in_b(in_b21), .in_valid(i_valid[1]), .out_valid(o_valid[6]),  .result(result_1[2]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_22 (.in_a(in_a22), .in_b(in_b22), .in_valid(i_valid[2]), .out_valid(o_valid[10]), .result(result_2[2]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_23 (.in_a(in_a23), .in_b(in_b23), .in_valid(i_valid[3]), .out_valid(o_valid[14]), .result(result_3[2]), .clk(clk), .rst_n(rst_n));

// a = 3(row)
mul_16 mul_16_30 (.in_a(in_a30), .in_b(in_b30), .in_valid(i_valid[4]), .out_valid(o_valid[3]),  .result(result_0[3]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_31 (.in_a(in_a31), .in_b(in_b31), .in_valid(i_valid[5]), .out_valid(o_valid[7]),  .result(result_1[3]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_32 (.in_a(in_a32), .in_b(in_b32), .in_valid(i_valid[6]), .out_valid(o_valid[11]), .result(result_2[3]), .clk(clk), .rst_n(rst_n));
mul_16 mul_16_33 (.in_a(in_a33), .in_b(in_b33), .in_valid(i_valid[7]), .out_valid(o_valid[15]), .result(result_3[3]), .clk(clk), .rst_n(rst_n));



assign result_00 = result_0[0];//Structure: (0, 0)
assign result_01 = result_0[1];//Structure: (1, 0)
assign result_02 = result_0[2];//Structure: (2, 0)
assign result_03 = result_0[3];//Structure: (3, 0)

assign result_10 = result_1[0];//Structure: (0, 1)
assign result_11 = result_1[1];//Structure: (1, 1)
assign result_12 = result_1[2];//Structure: (2, 1)
assign result_13 = result_1[3];//Structure: (3, 1)

assign result_20 = result_2[0];//Structure: (0, 2)
assign result_21 = result_2[1];//Structure: (1, 2)
assign result_22 = result_2[2];//Structure: (2, 2)
assign result_23 = result_2[3];//Structure: (3, 2)

assign result_30 = result_3[0];//Structure: (0, 3)
assign result_31 = result_3[1];//Structure: (1, 3)
assign result_32 = result_3[2];//Structure: (2, 3)
assign result_33 = result_3[3];//Structure: (3, 3)

assign out_valid = o_valid[2];//use o_valid of row 2 or 3 for iNTT path

endmodule