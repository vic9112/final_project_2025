// `include "mul_16.v"

// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : mul16_array
// Author : Hsuan Jung,Lo
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
// * Waveform：    
//      clk       >|      |      |      |      |      |      |      |
//      in_valid  >________/-------------\______________________________ * input valid asserted high for data input
//      out_valid >____________________________________/-------------\_  * output valid asserted high for data output
//      result_xx >|                   xx             |  r0  |  r1  |    * set of  32bit result from mul_16
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

module mul16_array #(
    parameter pDi_WIDTH = 64 ,
    parameter pDo_WIDTH = 32 
)
( 
    input[(pDi_WIDTH-1):0]    in_A,  // * input 64bit data
    input[(pDi_WIDTH-1):0]    in_B,  // * input 64bit data
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
//============================================================================================//
    wire [(pMUL_WIDTH-1):0]  partA[0:3];
    wire [(pMUL_WIDTH-1):0]  partB[0:3];
    wire                     o_valid[0:15];

    wire [(pDo_WIDTH-1):0]   result_0[0:3];
    wire [(pDo_WIDTH-1):0]   result_1[0:3];
    wire [(pDo_WIDTH-1):0]   result_2[0:3];
    wire [(pDo_WIDTH-1):0]   result_3[0:3];
//============================================================================================//
genvar a;
generate
    for(a=0 ; a<4 ; a=a+1)begin : GEN_PART_DAT
        assign partA[a] = in_A[(a*pMUL_WIDTH + 15) :(a*pMUL_WIDTH)];
        assign partB[a] = in_B[(a*pMUL_WIDTH + 15) :(a*pMUL_WIDTH)];
    end
endgenerate


generate
    for(a=0 ; a<4 ; a=a+1)begin : GEN_MUL16
        mul_16 mul_16_0 (.in_a( partA[a] ), .in_b( partB[0] ), .in_valid( in_valid ), .out_valid( o_valid[a] ),    .result( result_0[a] ), .clk(clk), .rst_n(rst_n));
        mul_16 mul_16_1 (.in_a( partA[a] ), .in_b( partB[1] ), .in_valid( in_valid ), .out_valid( o_valid[a+4] ),  .result( result_1[a] ), .clk(clk), .rst_n(rst_n));
        mul_16 mul_16_2 (.in_a( partA[a] ), .in_b( partB[2] ), .in_valid( in_valid ), .out_valid( o_valid[a+8] ),  .result( result_2[a] ), .clk(clk), .rst_n(rst_n));
        mul_16 mul_16_3 (.in_a( partA[a] ), .in_b( partB[3] ), .in_valid( in_valid ), .out_valid( o_valid[a+12] ), .result( result_3[a] ), .clk(clk), .rst_n(rst_n));
    end
endgenerate

assign result_00 = result_0[0];
assign result_01 = result_0[1];
assign result_02 = result_0[2];
assign result_03 = result_0[3];

assign result_10 = result_1[0];
assign result_11 = result_1[1];
assign result_12 = result_1[2];
assign result_13 = result_1[3];

assign result_20 = result_2[0];
assign result_21 = result_2[1];
assign result_22 = result_2[2];
assign result_23 = result_2[3];

assign result_30 = result_3[0];
assign result_31 = result_3[1];
assign result_32 = result_3[2];
assign result_33 = result_3[3];

assign out_valid = o_valid[0];

endmodule