//  `include "CLA_8.v"
//  `include "FA.v"
//  `include "HA.v"

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
//      out_valid >_______________/--------------\______________________  * output valid asserted high for data output
//      result    >|     xx      |  r0  |  r1  |          xx           |  *  
//
//===================================================================================================================================================================================

//===================================================================================================================================================================================
//  * FLOW 
//  *   step1 . use wallace tree to process input data thickness(7=> 2)
//  *   step2 . use carry lookahead adder to do add operation(with both carryin with 0 and 1 )
//  *   step3 . select the CLA output as result by last CLA output's leading bit(bit[8])  
//
//                                                                                   pipeline stage 1
//                                                                                         ___
//                    __________________________           _________________________      |   |
//                    |                         |         |                        |      |   |
//   data input   =>  |  wallace tree (4 level) |   =>    |  set of  CLA_8  & MUX  |  =>  |   |  ==> Result  
//                    |_________________________|         |________________________|      |   |
//                                                                                        |   |
//                                                                                        |___|
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
//------------------------------------ operand alignment -------------------------------------------------//
    wire[(pADD_WIDTH-1):0]      wallace_lv0[0:6];    
//--------------------------------------- add result ----------------------------------------------------//  
    wire[(pADD_WIDTH-1):0]      last_result ;
//------------------------------------ pipeline stage 1  --------------------------------------------------//
    reg                         pip1_v      ;
    reg [(pADD_WIDTH-1):0]      pip1_result ;

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

assign last_result = wallace_lv0[0] + wallace_lv0[1] + wallace_lv0[2] + wallace_lv0[3] + wallace_lv0[4] + wallace_lv0[5] + wallace_lv0[6] ;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          pipeline stage 1                                               //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip1_v       <= 1'b0;
        pip1_result  <= 131'd0;
    end else begin
        pip1_v       <= in_valid;
        pip1_result  <= last_result[(pADD_WIDTH-1):0];
    end
end

assign result       = pip1_result;
assign out_valid    = pip1_v;

endmodule

