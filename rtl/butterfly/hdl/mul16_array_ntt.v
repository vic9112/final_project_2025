// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : mul16_array_ntt
// Author : Hsuan Jung,Lo Jesse
// Create Date: 5/2025
// Features & Functions:
// . Combine 16bit multiplier as 2 dimension array (4*4 array) 
// . Output every mul_16's result(32bit * 16)
// ============================================================================================================================================================================
// Revision History:
// Date         by      Version     Change Description
//  
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//==================================================================================================================================================================================
//
// * Asserted in_valid high to feed valid data ,and return valid result with out_valid
//
// * Waveform(FFT)：    
//      clk       >|      |      |      |      |      |      |      |
//      in_valid  >________/-------------\______________________________ * input valid asserted high for data input
//      out_valid >____________________________________/-------------\_  * output valid asserted high for data output
//      result_xx >|                   xx             |  r0  |  r1  |    * set of  32bit result from mul_16
// * Waveform(NTT)：    
//      clk       >|      |      |      |      |      |      |      |      |      |      |      |      |      |      
//      in_valid  >________/-------------\______________________________________________________________________  * input valid for row 0 and 1
//      i_valid   >___________________________________________/-------------\___________________________________  * input valid for row 2 and 3
//      out_valid >_______________________________________________________________________/-------------\_______  * output valid asserted high for data output
//      result_xx >|                   xx                                                 |  r0  |  r1  |         * set of  32bit result from mul_16
//    
//  * Structure :
//   
//      (0,0) : partA[0] * partB[0]
//      (0,1) : partA[0] * partB[1]
//      (1,0) : partA[1] * partB[0]
//        .        .          .
//        .        .          .
//        .        .          .
//
//                      ___________________________________________________________________________
//                     /                   /                 /                  /                 /
//                    /   mul_16(0,3)     /  mul_16(0,2)    /   mul_16(0,1)    /  mul_16(0,0)    /
//                   /                   /                 /                  /                 /
//                  /___________________/_________________/__________________/_________________/
//                 /                   /                 /                  /                 /
//                /    mul_16(1,3)    /   mul_16(1,2)   /   mul_16(1,1)    /  mul_16(1,0)    /
//               /                   /                 /                  /                 /
//              /___________________/ ________________/__________________/_________________/
//             /                   /                 /                  /                 /
//            /   mul_16(2,3)     /  mul_16(2,2)    /   mul_16(2,1)    /   mul_16(2,0)   /
//           /                   /                 /                  /                 /
//          /___________________/_________________/__________________/_________________/     
//         /                   /                 /                  /                 /
//        /    mul_16(3,3)    /   mul_16(3,2)   /    mul_16(3,1)   /   mul_16(3,0)   /
//       /                   /                 /                  /                 /
//      /___________________/_________________/__________________/_________________/
//
//
//
//  * Output Data rule :
//     result_00 = in_A[15:0]  * in_B[15:0]
//     result_01 = in_A[31:16] * in_B[15:0] 
//     result_02 = in_A[47:32] * in_B[15:0] 
//     result_03 = in_A[63:48] * in_B[15:0] 
//
//     result_10 = in_A[15:0]  * in_B[31:16]
//     result_11 = in_A[31:16] * in_B[31:16] 
//     result_12 = in_A[47:32] * in_B[31:16] 
//     result_13 = in_A[63:48] * in_B[31:16] 
//
//     result_20 = in_A[15:0]  * in_B[47:32]
//     result_21 = in_A[31:16] * in_B[47:32] 
//     result_22 = in_A[47:32] * in_B[47:32] 
//     result_23 = in_A[63:48] * in_B[47:32] 
//
//     result_30 = in_A[15:0]  * in_B[63:48]
//     result_31 = in_A[31:16] * in_B[63:48] 
//     result_32 = in_A[47:32] * in_B[63:48] 
//     result_33 = in_A[63:48] * in_B[63:48] 
//===================================================================================================================================================================================

module mul16_array_ntt #(
    parameter pDi_WIDTH = 64 ,
    parameter pDo_WIDTH = 32 
)
( 
    input[(pDi_WIDTH-1):0]    in_A,  // * input 64bit data
    input[(pDi_WIDTH-1):0]    in_B0,  // * input 64bit data
    input[(pDi_WIDTH-1):0]    in_B1,  // FFT: in_B1 = in_B2, NTT in_B1 != in_B2
    input                     clk,
    input                     rst_n,
    input                     mode,
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
wire [(pMUL_WIDTH-1):0]  partA[0:3];
wire [(pMUL_WIDTH-1):0]  partB[0:3];
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
assign partA[0] = in_A[15:0];
assign partA[1] = in_A[31:16];
assign partA[2] = in_A[47:32];
assign partA[3] = in_A[63:48];

assign partB[0] = in_B0[15:0];
assign partB[1] = in_B0[31:16];
assign partB[2] = in_B0[47:32];
assign partB[3] = in_B0[63:48];



//For FFT in_B0 = in B1 = array_in_A0 
//For NTT in_B0 = mul_16_result_b3[3][15:0] , mul_16_result_b2[2][15:0] , mul_16_result_b1[1][15:0] , mul_16_result_b0[0][15:0]
//For NTT in_B1 = mul_16_result_c3[3][15:0] , mul_16_result_c2[2][15:0] , mul_16_result_c1[1][15:0] , mul_16_result_c0[0][15:0]
// a = 0(row)
assign in_a00 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH-1):0];
assign in_a01 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH-1):0];
assign in_a02 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH-1):0];
assign in_a03 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH-1):0];
// a = 1(row)
assign in_a10 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_a11 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_a12 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_a13 = (mode == INT_MUL)? Q01:in_A[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
// a = 2(row)
assign in_a20 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_a21 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_a22 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_a23 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
// a = 3(row)
assign in_a30 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_a31 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_a32 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_a33 = (mode == INT_MUL)? Q:in_A[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
// b = 0(column)
assign in_b00 = (mode == INT_MUL)? in_B0[(pMUL_WIDTH-1):0]:in_B0[(pMUL_WIDTH-1):0];
assign in_b10 = (mode == INT_MUL)? in_B1[(pMUL_WIDTH-1):0]:in_B0[(pMUL_WIDTH-1):0];
assign in_b20 = (mode == INT_MUL)? in_buf[0]              :in_B0[(pMUL_WIDTH-1):0];
assign in_b30 = (mode == INT_MUL)? in_buf[1]              :in_B0[(pMUL_WIDTH-1):0];
// b = 1(column)
assign in_b01 = (mode == INT_MUL)? in_B0[(pMUL_WIDTH*2-1):(pMUL_WIDTH)]:in_B0[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_b11 = (mode == INT_MUL)? in_B1[(pMUL_WIDTH*2-1):(pMUL_WIDTH)]:in_B0[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_b21 = (mode == INT_MUL)? in_buf[2]                           :in_B0[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
assign in_b31 = (mode == INT_MUL)? in_buf[3]                           :in_B0[(pMUL_WIDTH*2-1):(pMUL_WIDTH)];
// b = 2(column)
assign in_b02 = (mode == INT_MUL)? in_B0[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)]:in_B0[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_b12 = (mode == INT_MUL)? in_B1[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)]:in_B0[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_b22 = (mode == INT_MUL)? in_buf[4]                             :in_B0[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
assign in_b32 = (mode == INT_MUL)? in_buf[5]                             :in_B0[(pMUL_WIDTH*3-1):(pMUL_WIDTH*2)];
// b = 3(column)
assign in_b03 = (mode == INT_MUL)? in_B0[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)]:in_B0[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_b13 = (mode == INT_MUL)? in_B1[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)]:in_B0[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_b23 = (mode == INT_MUL)? in_buf[6]                             :in_B0[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];
assign in_b33 = (mode == INT_MUL)? in_buf[7]                             :in_B0[(pMUL_WIDTH*4-1):(pMUL_WIDTH*3)];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_buf[0] = 0;
      in_buf[1] = 0;
      in_buf[2] = 0;
      in_buf[3] = 0;
      in_buf[4] = 0;
      in_buf[5] = 0;
      in_buf[6] = 0;
      in_buf[7] = 0;
      o_valid_buf[0] = 0;
      o_valid_buf[1] = 0;
      o_valid_buf[2] = 0;
      o_valid_buf[3] = 0;
      o_valid_buf[4] = 0;
      o_valid_buf[5] = 0;
      o_valid_buf[6] = 0;
      o_valid_buf[7] = 0;
    end else begin
      in_buf[0] = result_0[0][(pMUL_WIDTH-1):0];//Structure output: (0, 0)
      in_buf[1] = result_0[1][(pMUL_WIDTH-1):0];//Structure output: (1, 0)
      in_buf[2] = result_1[0][(pMUL_WIDTH-1):0];//Structure output: (0, 1)
      in_buf[3] = result_1[1][(pMUL_WIDTH-1):0];//Structure output: (1, 1)
      in_buf[4] = result_2[0][(pMUL_WIDTH-1):0];//Structure output: (0, 2)
      in_buf[5] = result_2[1][(pMUL_WIDTH-1):0];//Structure output: (1, 2)
      in_buf[6] = result_3[0][(pMUL_WIDTH-1):0];//Structure output: (0, 3)
      in_buf[7] = result_3[1][(pMUL_WIDTH-1):0];//Structure output: (1, 3)
      o_valid_buf[0] = o_valid[0] ;//Structure valid: (0, 0)
      o_valid_buf[1] = o_valid[4] ;//Structure valid: (0, 1)
      o_valid_buf[2] = o_valid[8] ;//Structure valid: (0, 2)
      o_valid_buf[3] = o_valid[12];//Structure valid: (0, 3)
      o_valid_buf[4] = o_valid[1] ;//Structure valid: (1, 0)
      o_valid_buf[5] = o_valid[5] ;//Structure valid: (1, 1)
      o_valid_buf[6] = o_valid[9] ;//Structure valid: (1, 2)
      o_valid_buf[7] = o_valid[13];//Structure valid: (1, 3)
    end
end

assign i_valid[0] = (mode == INT_MUL)? o_valid_buf[0] :in_valid;
assign i_valid[1] = (mode == INT_MUL)? o_valid_buf[1] :in_valid;
assign i_valid[2] = (mode == INT_MUL)? o_valid_buf[2] :in_valid;
assign i_valid[3] = (mode == INT_MUL)? o_valid_buf[3] :in_valid;
assign i_valid[4] = (mode == INT_MUL)? o_valid_buf[4] :in_valid;
assign i_valid[5] = (mode == INT_MUL)? o_valid_buf[5] :in_valid;
assign i_valid[6] = (mode == INT_MUL)? o_valid_buf[6] :in_valid;
assign i_valid[7] = (mode == INT_MUL)? o_valid_buf[7] :in_valid;
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


// generate
//     for(a=0 ; a<4 ; a=a+1)begin : GEN_MUL16
//         mul_16 mul_16_0 (.in_a( partA[a] ), .in_b( partB[0] ), .in_valid( in_valid ), .out_valid( o_valid[a] ),    .result( result_0[a] ), .clk(clk), .rst_n(rst_n));
//         mul_16 mul_16_1 (.in_a( partA[a] ), .in_b( partB[1] ), .in_valid( in_valid ), .out_valid( o_valid[a+4] ),  .result( result_1[a] ), .clk(clk), .rst_n(rst_n));
//         mul_16 mul_16_2 (.in_a( partA[a] ), .in_b( partB[2] ), .in_valid( in_valid ), .out_valid( o_valid[a+8] ),  .result( result_2[a] ), .clk(clk), .rst_n(rst_n));
//         mul_16 mul_16_3 (.in_a( partA[a] ), .in_b( partB[3] ), .in_valid( in_valid ), .out_valid( o_valid[a+12] ), .result( result_3[a] ), .clk(clk), .rst_n(rst_n));
//     end
// endgenerate

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

assign out_valid = o_valid[2];//use o_valid of row 2 or 3 for NTT path

endmodule