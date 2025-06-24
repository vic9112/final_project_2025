// `include "CLA_8.v"
// `include "FA.v"
// `include "HA.v"

// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : wallace_131
// Author : Hsuan Jung,Lo
// Create Date: 5/2025
// Features & Functions:
// . To calculate sum of partial product or long bit-width add. 
// .
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
//      in_valid  >________/-------------\______________________________  * input valid asserted high for data input
//      mode      >________/------\_____________________________________  * mode=0 for partial product adder , mode=1 for long operand adder
//      out_valid >_____________________________/--------------\________  * output valid asserted high for data output
//      result    >|             xx             |  r0  |  r1  |    xx  |  *  
//
//===================================================================================================================================================================================

//===================================================================================================================================================================================
//  * FLOW 
//  *   step1 . use wallace tree to process input data thickness(7=> 2)
//  *   step2 . use carry lookahead adder to do add operation(with both carryin with 0 and 1 )
//  *   step3 . select the CLA output as result by last CLA output's leading bit(bit[8])  
//
//               pip_stage0                                pip_stage1                                  pip_stage2
//                  ___                                       ___                                         ___
//                 |   |     __________________________      |   |        _________________________      |   |
//                 |   |     |                         |     |   |       |                        |      |   |
//   data input => |   | =>  |  wallace tree (4 level) |  => |   | =>    |  set of  CLA_8  & MUX  |  =>  |   |  ==> Result  
//                 |   |     |_________________________|     |   |       |________________________|      |   |
//                 |   |                                     |   |                                       |   |
//                 |___|                                     |___|                                       |___|
//====================================================================================================================================================================================

module wallace_131 
(
    input                       clk,
    input                       rst_n,
    input                       mode ,     // * mode 0 for partial product adder , mode 1 for long operand adder
    input                       in_valid,
    output                      out_valid,
    output[130:0]               result,  
//----------------------------- data of partial product ---------------------------------------------------//
    input[31 : 0]  mul_result_00 ,
    
    input[31 : 0]  mul_result_01 ,
    input[31 : 0]  mul_result_10 ,

    input[31 : 0]  mul_result_02 ,
    input[31 : 0]  mul_result_20 ,
    input[31 : 0]  mul_result_11 ,
    
    input[31 : 0]  mul_result_03 ,
    input[31 : 0]  mul_result_30 ,
    input[31 : 0]  mul_result_21 ,
    input[31 : 0]  mul_result_12 ,

    input[31 : 0]  mul_result_31 ,
    input[31 : 0]  mul_result_22 ,
    input[31 : 0]  mul_result_13 ,

    input[31 : 0]  mul_result_32 ,
    input[31 : 0]  mul_result_23 ,  

    input[31 : 0]  mul_result_33 ,  
//------------------------------ data of add operation ---------------------------------------------------//
    input[130 : 0]  in_A,            
    input[130 : 0]  in_B           
);
//========================================================================================================//
    localparam pMUL_WIDTH = 32 ;
    localparam pADD_WIDTH = 131;
//========================================================================================================//
    wire[(pADD_WIDTH-1):0]      wallace_lv0[0:6];    
//------------------------------------- pipeline stage 0 --------------------------------------------------//
    reg                         stage_0_v;
    reg [(pADD_WIDTH-1):0]      stage_0_0 ;
    reg [(pADD_WIDTH-1):0]      stage_0_1 ;
    reg [95:0]                  stage_0_2 ;
    reg [63:0]                  stage_0_3 ;
    reg [63:0]                  stage_0_4 ;
    reg [31:0]                  stage_0_5 ;
    reg [31:0]                  stage_0_6 ;
    wire[(pADD_WIDTH-1): 0]     stage_0[0:6];
//------------------------------------- pipeline stage 1  --------------------------------------------------//
    reg                         stage_1_v;
    reg                         stage_1_0;
    reg                         stage_1_1;
    reg                         stage_1_2;
    reg                         stage_1_3;
    reg [1:0]                   stage_1[4:(pADD_WIDTH-1)];    
//------------------------------------ wallace tree(1~4) ---------------------------------------------------//      
    wire[4:0]                   wallace_lv1[0 : pADD_WIDTH];
    wire[3:0]                   wallace_lv2[0 : pADD_WIDTH];
    wire[2:0]                   wallace_lv3[0 : pADD_WIDTH];
    wire[1:0]                   wallace_lv4[0 : pADD_WIDTH];
//------------------------------------ CLA calculate & predict ----------------------------------------------//  
    wire[(pADD_WIDTH):0]        last_lv_A;
    wire[(pADD_WIDTH):0]        last_lv_B;
    wire[15:0]                  logic_one;
    wire[15:0]                  logic_zero;
    wire[8:0]                   CLA_result_one [0:15];
    wire[8:0]                   CLA_result_zero[0:15];
//-------------------------------------- result select ------------------------------------------------------//  
    wire[8:0]                   sel_result[0:15];
    wire[pADD_WIDTH:0]          last_result;
//------------------------------------- pipeline stage 2  --------------------------------------------------//
    reg                         stage_2_v;
    reg [(pADD_WIDTH-1):0]      stage_2;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                  Input data load into wallace lv0                                      //
////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign wallace_lv0[0]  = (!mode)? {3'd0 , mul_result_33 , mul_result_31 , mul_result_02 , mul_result_00}          : in_A ;
    assign wallace_lv0[1]  = (!mode)? {3'd0 , 16'd0         , mul_result_32 , mul_result_03 , mul_result_01 , 16'd0 } : in_B ;
    assign wallace_lv0[2]  = (!mode)? {3'd0 , 16'd0         , mul_result_23 , mul_result_30 , mul_result_10 , 16'd0 } : 131'd0;
    assign wallace_lv0[3]  = (!mode)? {3'd0 , 32'd0         , mul_result_22 , mul_result_20 ,  32'd0 }                : 131'd0 ;
    assign wallace_lv0[4]  = (!mode)? {3'd0 , 32'd0         , mul_result_13 , mul_result_11 ,  32'd0 }                : 131'd0 ;
    assign wallace_lv0[5]  = (!mode)? {3'd0 , 48'd0         , mul_result_21 ,  48'd0 }                                : 131'd0;
    assign wallace_lv0[6]  = (!mode)? {3'd0 , 48'd0         , mul_result_12 ,  48'd0 }                                : 131'd0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          pipeline stage 0                                               //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            stage_0_v  <= 1'b0;
            stage_0_0  <= {(pADD_WIDTH){1'b0}};
            stage_0_1  <= {(pADD_WIDTH){1'b0}};
            stage_0_2  <= 96'd0;
            stage_0_3  <= 64'd0;
            stage_0_4  <= 64'd0;
            stage_0_5  <= 32'd0;
            stage_0_6  <= 32'd0;
        end else begin
            stage_0_v  <= in_valid;
            stage_0_0  <= wallace_lv0[0];
            stage_0_1  <= wallace_lv0[1];
            stage_0_2  <= wallace_lv0[2][111:16];
            stage_0_3  <= wallace_lv0[3][95:32] ;
            stage_0_4  <= wallace_lv0[4][95:32] ;
            stage_0_5  <= wallace_lv0[5][79:48] ;
            stage_0_6  <= wallace_lv0[6][79:48] ;
        end
    end

    assign stage_0[0]           = stage_0_0;
    assign stage_0[1]           = stage_0_1;
    assign stage_0[2][111: 16]  = stage_0_2;
    assign stage_0[3][95 : 32]  = stage_0_3;
    assign stage_0[4][95 : 32]  = stage_0_4;
    assign stage_0[5][79 : 48]  = stage_0_5;
    assign stage_0[6][79 : 48]  = stage_0_6;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                           wallace lv1                                                   //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

genvar a;
//----------------------------------------- first floor ---------------------------------------------------//
generate
    for(a=1 ; a < 16 ; a = a+1)begin : GEN_WALLACE_LV1_HA0
        HA HA_lv1_0( .A(stage_0[0][a] ) , .B( stage_0[1][a] ) , .Cout( wallace_lv1[a+1][0] ) , .Sum( wallace_lv1[a][1]));
    end
endgenerate

generate
    for(a=16 ; a < 112 ; a = a+1)begin : GEN_WALLACE_LV1_FA0
        FA FA_lv1_0( .A( stage_0[0][a] ) , .B( stage_0[1][a] ) , .Cin( stage_0[2][a] ) , .Cout( wallace_lv1[a+1][0] ) , .Sum( wallace_lv1[a][1] ));
    end
endgenerate

generate
    for (a =112 ; a < 131 ; a = a+1) begin : GEN_WALLACE_LV1_HA1
        HA HA_lv1_1 ( .A(stage_0[0][a] ) , .B( stage_0[1][a] ) , .Cout( wallace_lv1[a+1][0] ) , .Sum( wallace_lv1[a][1]));
    end
endgenerate
//----------------------------------------- second floor ---------------------------------------------------//
generate
    for (a =33 ; a < 48 ; a = a+1) begin : GEN_WALLACE_LV1_HA2
        HA HA_lv1_2 ( .A(stage_0[3][a] ) , .B( stage_0[4][a] ) , .Cout( wallace_lv1[a+1][2] ) , .Sum( wallace_lv1[a][3]));
    end
endgenerate

generate
    for (a =80 ; a < 96 ; a = a+1) begin : GEN_WALLACE_LV1_HA3
        HA HA_lv1_3 ( .A(stage_0[3][a] ) , .B( stage_0[4][a] ) , .Cout( wallace_lv1[a+1][2] ) , .Sum( wallace_lv1[a][3]));
    end
endgenerate

generate
    for(a=48 ; a < 80 ; a = a+1)begin : GEN_WALLACE_LV1_FA1
        FA FA_lv1_1( .A( stage_0[3][a] ) , .B( stage_0[4][a] ) , .Cin( stage_0[5][a] ) , .Cout( wallace_lv1[a+1][2] ) , .Sum( wallace_lv1[a][3] ));
        // ------- pass element ----- //
        assign wallace_lv1[a][4] = stage_0[6][a] ;
    end

endgenerate

HA HA_lv1_4( .A(stage_0[0][0] ) , .B( stage_0[1][0] ) , .Cout( wallace_lv1[1][0] ) , .Sum( wallace_lv1[0][0] ));
HA HA_lv1_5( .A(stage_0[3][32] ) , .B( stage_0[4][32] ) , .Cout( wallace_lv1[33][2] ) , .Sum( wallace_lv1[32][2]));

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                           wallace lv2                                                   //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////


//----------------------------------------- first floor ---------------------------------------------------//
generate
    for(a=2 ; a < 32 ; a = a+1)begin : GEN_WALLACE_LV2_HA0
        HA HA_lv2_0( .A( wallace_lv1[a][0] ) , .B( wallace_lv1[a][1] ) , .Cout( wallace_lv2[a+1][0] ) , .Sum( wallace_lv2[a][1] ));
    end
endgenerate

generate
    for(a=32 ; a < 97 ; a = a+1)begin : GEN_WALLACE_LV2_FA0
        FA FA_lv2_0( .A( wallace_lv1[a][0] ) , .B( wallace_lv1[a][1] ) , .Cin( wallace_lv1[a][2] ) , .Cout( wallace_lv2[a+1][0] ) , .Sum( wallace_lv2[a][1] ));
    end
endgenerate

generate
    for(a=97 ; a < 131 ; a = a+1)begin : GEN_WALLACE_LV2_HA1
        HA HA_lv2_1( .A( wallace_lv1[a][0] ) , .B( wallace_lv1[a][1] ) , .Cout( wallace_lv2[a+1][0] ) , .Sum( wallace_lv2[a][1] ));
    end
endgenerate
//----------------------------------------- second floor ---------------------------------------------------//
generate
    for(a=49 ; a < 80 ; a = a+1)begin : GEN_WALLACE_LV2_HA2
        HA HA_lv2_2( .A( wallace_lv1[a][3] ) , .B( wallace_lv1[a][4] ) , .Cout( wallace_lv2[a+1][2] ) , .Sum( wallace_lv2[a][3] ));
    end
endgenerate

HA HA_lv2_3( .A( wallace_lv1[1][0] )  , .B( wallace_lv1[1][1] )  , .Cout( wallace_lv2[2][0] )  , .Sum( wallace_lv2[1][0] ));
HA HA_lv2_4( .A( wallace_lv1[48][3] ) , .B( wallace_lv1[48][4] ) , .Cout( wallace_lv2[49][2] ) , .Sum( wallace_lv2[48][2] ));
//----------------------------------------- pass element ---------------------------------------------------//
generate
    for (a = 81 ; a<96 ; a=a+1) begin : GEN_WALLACE_LV2_PASS0
        assign wallace_lv2[a][2] = wallace_lv1[a][3];
    end
endgenerate

generate
    for(a=33 ; a<48 ; a=a+1)begin : GEN_WALLACE_LV2_PASS0
        assign wallace_lv2[a][2] = wallace_lv1[a][3];
    end
endgenerate

assign wallace_lv2[0][0]  =  wallace_lv1[0][0];
assign wallace_lv2[80][3] =  wallace_lv1[80][3];

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                           wallace lv3                                                   //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

generate
    for(a=3 ; a<33 ; a=a+1)begin : GEN_WALLACE_LV3_HA0
        HA HA_lv3_0( .A( wallace_lv2[a][0] ) , .B( wallace_lv2[a][1] ) , .Cout( wallace_lv3[a+1][0] ) , .Sum( wallace_lv3[a][1] ));
    end
endgenerate

generate
    for(a=33 ; a<96 ; a=a+1)begin : GEN_WALLACE_LV3_FA0
        FA FA_lv3_0( .A( wallace_lv2[a][0] ) , .B( wallace_lv2[a][1] ) , .Cin( wallace_lv2[a][2] ) , .Cout( wallace_lv3[a+1][0] ) , .Sum( wallace_lv3[a][1] ));
    end
endgenerate

generate
    for(a=96 ; a<131 ; a=a+1)begin: GEN_WALLACE_LV3_HA1
        HA HA_lv3_0( .A( wallace_lv2[a][0] ) , .B( wallace_lv2[a][1] ) , .Cout( wallace_lv3[a+1][0] ) , .Sum( wallace_lv3[a][1] ));
    end
endgenerate
HA HA_lv3_2( .A( wallace_lv2[2][0] ) , .B( wallace_lv2[2][1] ) , .Cout( wallace_lv3[3][0] ) , .Sum( wallace_lv3[2][0] ));
//----------------------------------------- pass element ---------------------------------------------------//
generate
    for(a=49 ; a<81 ; a=a+1)begin : GEN_WALLACE_LV3_PASS
        assign wallace_lv3[a][2] = wallace_lv2[a][3];
    end
endgenerate

assign wallace_lv3[0][0] = wallace_lv2[0][0];
assign wallace_lv3[1][0] = wallace_lv2[1][0];

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                           wallace lv4                                                   //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

generate
    for(a=4 ; a<49 ; a=a+1)begin : GEN_WALLACE_LV4_HA0
        HA HA_lv4_0( .A( wallace_lv3[a][0] ) , .B( wallace_lv3[a][1] ) , .Cout( wallace_lv4[a+1][0] ) , .Sum( wallace_lv4[a][1] ));
    end
endgenerate

generate
    for(a=81 ; a<131 ; a=a+1)begin : GEN_WALLACE_LV4_HA1
        HA HA_lv4_1( .A( wallace_lv3[a][0] ) , .B( wallace_lv3[a][1] ) , .Cout( wallace_lv4[a+1][0] ) , .Sum( wallace_lv4[a][1] ));
    end
endgenerate

generate
    for(a=49 ; a<81 ; a=a+1)begin : GEN_WALLACE_LV4_FA0
        FA FA_lv4_0( .A( wallace_lv3[a][0] ) , .B( wallace_lv3[a][1] ) , .Cin( wallace_lv3[a][2] ) , .Cout( wallace_lv4[a+1][0] ) , .Sum( wallace_lv4[a][1] ));
    end
endgenerate

HA HA_lv4_2( .A( wallace_lv3[3][0] ) , .B( wallace_lv3[3][1] ) , .Cout( wallace_lv4[4][0] ) , .Sum( wallace_lv4[3][0] ));

assign wallace_lv4[0][0] = wallace_lv3[0][0];
assign wallace_lv4[1][0] = wallace_lv3[1][0];
assign wallace_lv4[2][0] = wallace_lv3[2][0];

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          pipeline stage 1                                               //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

integer i;

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        stage_1_v  <= 1'b0;
        stage_1_0  <= 1'b0;
        stage_1_1  <= 1'b0;
        stage_1_2  <= 1'b0;
        stage_1_3  <= 1'b0;
        for(i=4 ; i<pADD_WIDTH ; i=i+1)begin
            stage_1[i] <= 2'd0;
        end
    end else begin
        stage_1_v  <= stage_0_v ;
        stage_1_0  <= wallace_lv4[0][0];
        stage_1_1  <= wallace_lv4[1][0];
        stage_1_2  <= wallace_lv4[2][0];
        stage_1_3  <= wallace_lv4[3][0];
        for(i=4 ; i<pADD_WIDTH ; i=i+1)begin
            stage_1[i] <= wallace_lv4[i][1:0];
        end
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                  CLA to calculate &  predict                                            //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////


assign last_lv_A[3:0]        = {stage_1_3 , stage_1_2 , stage_1_1 , stage_1_0}; 
assign last_lv_A[pADD_WIDTH] = 1'b0;
assign last_lv_B[3:0]        = 3'd0; 
assign last_lv_B[pADD_WIDTH] = 1'b0;
assign logic_one             = 16'b1111_1111_1111_1111;      
assign logic_zero            = 16'd0;

generate
    for(a=4 ; a<pADD_WIDTH ; a=a+1)begin : GEN_LAST_LV
       assign last_lv_A[a] = stage_1[a][0];
       assign last_lv_B[a] = stage_1[a][1];
    end
endgenerate

generate
    for(a=1 ; a<16 ; a=a+1)begin : GEN_CLA8
        CLA_8 CLA_one  (.A( last_lv_A[ a*8+11 : a*8+4 ] ) , .B( last_lv_B[a*8+11 : a*8+4] ) , .Cin( logic_one [a]  ) , .result( CLA_result_one [a] ));
        CLA_8 CLA_zero (.A( last_lv_A[ a*8+11 : a*8+4 ] ) , .B( last_lv_B[a*8+11 : a*8+4] ) , .Cin( logic_zero[a]  ) , .result( CLA_result_zero[a] ));
    end
endgenerate

CLA_8 CLA_0 (.A( last_lv_A[ 11 : 4 ] ) , .B( last_lv_B[ 11 : 4] ) , .Cin( logic_zero[0]  ) , .result( CLA_result_zero[0] ));

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                        result select                                                    //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign sel_result[0]      = CLA_result_zero[0];
assign last_result[3:0]   = last_lv_A[3:0];


generate
    for(a=1 ; a<16 ; a=a+1)begin : GEN_RESULT_SEL
        assign sel_result[a] = (sel_result[a-1][8])? CLA_result_one[a] : CLA_result_zero[a] ;
    end
endgenerate

generate
    for(a=0 ; a<16 ; a=a+1)begin : GEN_RESULT_LAST
        assign last_result[a*8+11 : a*8+4] = sel_result[a][7:0];
    end
endgenerate

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          pipeline stage 2                                               //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_2_v <= 1'b0;
        stage_2   <= 131'd0;
    end else begin
        stage_2_v <= stage_1_v;
        stage_2   <= last_result[(pADD_WIDTH-1):0];
    end
end

assign result       = stage_2;
assign out_valid    = stage_2_v;

endmodule






