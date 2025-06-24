///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//    `include "CLA_8.v"
//    `include "add_11_overflow.v"
//    `include "add_13_overflow.v"
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : fmul_exp
// Author : Hsuan Jung,Lo
// Create Date: 5/2025
// Features & Functions:
// . To calculate the exp while doing fp_mul's mul operation.
// . * Add Latency to alignment the timing of mul operation.
// ============================================================================================================================================================================
// Revision History:
// Date           by          Version         Change Description
// 2025.6.16   hsuanjung,lo     2.0        solve subnormal case problem
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//==================================================================================================================================================================================
//      
// * As IEEE 754 format , if the one of operand's exponent is exceed 111_1111_1111 , we regard it as infinite number,and return out_inf=1 ,to tell rounder the infinite number occur. 
// 
// * To make sure that the timing exponent operation and fraction_mul operatiom will finish at the same time, we add latency to this module.
//
// * Asserted in_valid high to feed valid data ,and return valid result with out_valid
//
// * Waveform：    
//      clk       >|      |      |      |      |      |      |      |      |      |      |      |
//      in_valid  >________/-------------\________________________________________________________   * input valid asserted high for data input
//      exp_A     >|  xx  |  a0  |  a1  |           xx                                               * input exponent A
//      exp_B     >|  xx  |  b0  |  b1  |           xx                                               * input exponent B
//      out_valid >_________________________________________________________/-------------\_______   * output valid asserted high for data output
//      exp_o     >|                         xx                            |  e0  |  e1  |  xx  |    * output exponent as 13bit signed  value
//      out_inf   >________________________________________________________________/------\_______   * while the input data contain denormal case(infinite case), asserted high.
//===================================================================================================================================================================================

//===================================================================================================================================================================================
//  * FLOW 
//  *   step1 . add exponent A and B 、 check whether there is infinite number.
//  *   step2 . subtract the bias of IEEE 754 double precision floating pint(1023) to get the real value of result exponent(siggned)
//  *   step3 . use group of pipline stage to make sure the timing  
//    
//              pip_stage1                                               pip_stage2                                                              pip_stage3-->7
//                  __                                                       ___                                                                 ___          ___
//                 |  |    ___________________________________________      |   |      ___________________________________________________      |   |        |   |
//                 |  |    |                                          |     |   |     |                                                   |     |   |        |   |
//   data input  =>|  | => |   add exponent 、 detect infinite case   | =>  |   |  => |   substract bias to get real value of exp result  |  => |   | => ... |   |   => Result output  
//                 |  |    |__________________________________________|     |   |     |___________________________________________________|     |   |        |   |
//                 |  |                                                     |   |                                                               |   |        |   | 
//                 |__|                                                     |___|                                                               |___|        |___|
//
//  * Output exp_o sturcture :
//        signed    value
//      |  1bit  |  12bit  |
//          
//====================================================================================================================================================================================

module fmul_exp #(
    parameter pEXP_WIDTH = 11
)(
    input                      clk,
    input                      rst_n,
    input                      in_valid,
    input  [(pEXP_WIDTH-1):0]  exp_A,
    input  [(pEXP_WIDTH-1):0]  exp_B,

    output [(pEXP_WIDTH+1):0]  exp_o,
    output                     out_inf,   // * out_inf =1 while infinite case.
    output                     out_valid
);
//===========================================================================================================================//
    localparam LATENCY      = 7;    //* Adujust the Latency to align the mul operation timing

//---------------------------------------------------------------------------------------------------------------------------//
    localparam  INF_EXP     = 11'b111_1111_1111 ;      // * Denormal of infinite     while exponent = 111_1111_1111
    localparam EXP_BIAS     = 12'd1023;                // * Bias of exponent by IEEE double precision floating point format.
    localparam EXP_BIAS_sub = 13'b1_1100_0000_0001;    // * Use for substraction Bias.
//===========================================================================================================================//

//----------------------- pipeline stage 1 ----------------------------------------------------------------------------------//
    reg                                     pip1_v;
//    reg                                     pip1_zero_case;
    reg [(pEXP_WIDTH-1):0]                  pip1_exp_a;
    reg [(pEXP_WIDTH-1):0]                  pip1_exp_b;
//----------------------- pipeline stage 2 -----------------------------------------------------------------------------------//
    reg                                     pip2_v;
    reg                                     pip2_inf;
//    reg                                     pip2_zero_case;
    reg [(pEXP_WIDTH):0]                    pip2_exp;
    reg [1:0]                               pip2_sub_norm ;
//-------------------- EXP add & subnormal detect ------------------------------------------------------------------------------//
    wire                                    zero_a;
    wire                                    zero_b;
    wire                                    inf_a;
    wire                                    inf_b;
    wire[1:0]                               subnorm_add;
    wire[(pEXP_WIDTH):0]                    exp_add;
    wire[(pEXP_WIDTH):0]                    exp_result;
//----------------------- EXP normalize ---------------------------------------------------------------------------------------//
    wire[(pEXP_WIDTH+2):0]                  exp_real;
    wire[(pEXP_WIDTH+1):0]                  exp_expand;
    wire[(pEXP_WIDTH+1):0]                  exp_real_value;

//--------------------- pipline stage 3-LATENCY ------------------------------------------------------------------------------//
    reg                                     pip3_v ;
    reg [1:0]                               pip3_sub_norm;  
    reg                                     pip3_inf;
    reg [(pEXP_WIDTH+1):0]                  pip3_exp;
//---------------------------------------------------------------------------------------------------------------------------// 
    reg                                     pip_v  [0:LATENCY];
    reg                                     pip_inf[0:LATENCY];
    reg [(pEXP_WIDTH+1):0]                  pip_exp[0:LATENCY];
//===========================================================================================================================//

///////////////////////////////////////////////////////////////////////////////////////////////////
//                             pipline stage 1                                                   //
///////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip1_v         <= 1'b0;
//        pip1_zero_case <= 1'b0;
        pip1_exp_a     <= {(pEXP_WIDTH){1'b0}};
        pip1_exp_b     <= {(pEXP_WIDTH){1'b0}};
    end else begin
        pip1_v         <= in_valid;
//        pip1_zero_case <= zero_case;
        pip1_exp_a     <= exp_A;
        pip1_exp_b     <= exp_B;
    end
end

////////////////////////////////////////////////////////////////////////////////////////////////////
//                               EXP add &　 subnormal detect                                      //
////////////////////////////////////////////////////////////////////////////////////////////////////


assign inf_a       = &(pip1_exp_a);
assign inf_b       = &(pip1_exp_b);
assign zero_a      = ~(|pip1_exp_a) ;
assign zero_b      = ~(|pip1_exp_b) ;
assign subnorm_add = zero_a + zero_b;

add_11_overflow add_11_0( .in_A( pip1_exp_a ) , .in_B( pip1_exp_b ) , .result( exp_add ));


///////////////////////////////////////////////////////////////////////////////////////////////////
//                                   pipline stage 2                                             //
///////////////////////////////////////////////////////////////////////////////////////////////////


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip2_v          <= 1'b0;
//        pip2_zero_case  <= 1'b0;
        pip2_inf        <= 1'b0;
        pip2_exp        <= {(pEXP_WIDTH+1){1'b0}};
        pip2_sub_norm   <= 2'd0 ;
    end else begin
        pip2_v          <= pip1_v;
        pip2_inf        <= (inf_a | inf_b);
//        pip2_zero_case  <= pip1_zero_case;
        pip2_exp        <= exp_add[(pEXP_WIDTH):0];
        pip2_sub_norm   <= subnorm_add ;
    end
end

////////////////////////////////////////////////////////////////////////////////////////////////////
//                                        EXP normalize                                           //
////////////////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------------------------------------
// * can't directly add the exp result , weknow that real value of exponent is exp - bias
// * so we need to sub the bias hehre.
//
// * step1. sign extension exp_expand   
//                   sign   exp_value
//    exp_expand > |  0  |   12bit    |    
//
// * step2. 
//        exp_real = exp_expand - 1023 ;
//      
//      structure of exp_real :
//                    don't care    sign    signed value
//       exp_real > |    1bit     | 1bit |     12bit     |
//
// * step3. elininate 1 bit of value(we know that maximum value is 12bit)
//                           sign    value
//     exp_real_value  >   | 1bit |  12bit   |
//
//--------------------------------------------------------------------------------------------------------------------

assign exp_expand      = {1'b0 , pip2_exp}; // *sign extension of exp(positive)
assign exp_real_value  =  exp_real[(pEXP_WIDTH+1): 0];


add_13_overflow add_13_0( .in_A( exp_expand ) , .in_B( EXP_BIAS_sub ) , .result( exp_real ));


///////////////////////////////////////////////////////////////////////////////////////////////////
//                                   pipline stage 3-> LATENCY                                    //
///////////////////////////////////////////////////////////////////////////////////////////////////


integer i;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip3_v          <= 1'b0 ;
        pip3_inf        <= 1'b0 ;
        pip3_exp        <= {(pEXP_WIDTH+2){1'b0}};
        pip3_sub_norm   <= 2'd0;
    end else begin 
        pip3_v          <= pip2_v ;
        pip3_inf        <= pip2_inf ;
        pip3_exp        <= exp_real_value ;
        pip3_sub_norm   <= pip2_sub_norm ;
    end
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        for(i=4 ; i<=LATENCY ; i=i+1)begin
            pip_v[i]   <= 1'b0;
            pip_inf[i] <= 1'b0;
            pip_exp[i] <= {(pEXP_WIDTH+1){1'b0}};
        end
    end else begin
        pip_v  [4] <= pip3_v;
        pip_inf[4] <= pip3_inf;
        pip_exp[4] <= (pip3_exp + { {(pEXP_WIDTH){1'b0}} , pip3_sub_norm });
        for(i=5 ; i<=LATENCY ; i=i+1)begin
            pip_v[i]   <= pip_v[i-1];
            pip_inf[i] <= pip_inf[i-1];
            pip_exp[i] <= pip_exp[i-1];
        end
    end
end

assign exp_o     = pip_exp[LATENCY];
assign out_valid = pip_v  [LATENCY];
assign out_inf   = pip_inf[LATENCY];




endmodule


