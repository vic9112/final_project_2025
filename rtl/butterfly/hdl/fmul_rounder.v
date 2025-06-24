///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//   `include "CLA_8.v"
//   `include "add_13_overflow.v"
//   `include "add_53_overflow.v"
//   `include "LOD_64.v"
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : fmul_rounder
// Author : Hsuan Jung,Lo
// Create Date: 6/2025
// Features & Functions:
// . To round and normalize the floating point mul result into IEEE 754 double precision format. 
// .
// ============================================================================================================================================================================
// Revision History:
// Date         by              Version              Change Description
// 2025.6.5   hsuan_jung,lo       2.0       fix rounding position of lsb and fix pattern problem
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//==================================================================================================================================================================================
// * As IEEE 754 double precision floating point format, fraction with hidden bit is 53 bit width, while doing mul operation , we need to mul 53bit fraction to 106bit width
// * This module is used to round the result of 53 bit mul operation and normalize to fit IEEE7754 format.
//
// * Asserted in_valid high to feed valid data ,and return valid result with out_valid
//
// * Waveform：    
//      clk       >|      |      |      |      |      |      |      |
//      in_valid  >________/-------------\_____________________________   * input valid asserted high for data input
//      frac_i    >   xx  |  f0  |  f1  |           xx                    * input fraction(mul result from wallace tree)
//      exp_i     >   xx  |  e0  |  e1  |           xx                    * input exponent(exponent result form fmul_exp)
//      inf_case  >_______________/------\____________________________    * while input data contain infinite number ,asserted high.
//      out_valid >_____________________________/--------------\_______   * output valid asserted high for data output
//      frac_o    >|         xx                |  F0  |  F1  |   xx  |    * output fraction (normalized into IEEE 754 format)
//      exp_o     >|         xx                |  E0  |  INF |   xx  |    * output exponent (normalized into IEEE 754 format)
//
//===================================================================================================================================================================================


//===================================================================================================================================================================================
//  * FLOW 
//  *   step1 . round the rraction by nearest even rounding(with sticky)
//  *   step2 . use LOD to count leading one's position add normalize the exponent and fraction (LOD width 64bit )
//    
//
//                                                 pip_stage0                                  pip_stage1
//                                                     ___                                         ___
//                     __________________________     |   |        _________________________      |   |
//                    |                         |     |   |       |                        |      |   |
//   data input  =>   |        rounding         |  => |   | =>    |      normalization     |  =>  |   |  ==> Result  
//                    |_________________________|     |   |       |________________________|      |   |
//                                                    |   |                                       |   |
//                                                    |___|                                       |___|
//====================================================================================================================================================================================

//=====================================================================================================================================================================================-//
//  First we normalize fraction and exponent ,and then round the fraction .
// * Step 1.  first time normalize the exponent       
//                               2bit  104bit
//    106bit frac_i structure :  xx  . xxxxx
//                                   ^
//                                 float point
//
// * so if leading of frac_i = 1 , we normalize exp into exp_i - 1 
// * others don't change.
//
// 
// * Step 2.  get LSB 、 guard_bit 、 round_bit from frac_i.
//
//           53bit         1bit      1bit      ...
//     |     FRAC     |   GURAD  |  Round  |  sticky  | 
//
// * Step 3.  rounding frac to nearest even (with sticky)
//                              53bit
//          frac_rounded  :  |  FRAC  |    
//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
//  Second we normalize the rounded result and exponent
//
// * Step 1. find leading one position of fraction(extense the frac into 64bit to fit LOD_width)
//          
//        53bit          53bit    11bit
//     |  FRAC  |  =>  |  FRAC  |  000... |
//
//  *Step 2. shift FRAC (maximun shift is value of exponent + 1023) 
//
//
// * Step 3. normaliztion into IEEE 754 foramt 52bit fraction(1 bit hidden)
//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------/

//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// At the end we check the denormal case (infinite number or zero number)
//
//    output structure :
//                         FRAC  :    |  52 bit  |  one bit hidden , as IEEE 754 double precision floating point format.
//                      EXPONENT :    |  11 bit  |
//================================================================================================================================================================================//
module fmul_rounder#(
    parameter pDIN_WIDTH = 106,
    parameter pDo_WIDTH  = 52,
    parameter pEXP_WIDTH = 11
)
(
    input [(pDIN_WIDTH-1):0]    frac_i ,
    input [(pEXP_WIDTH+1):0]    exp_i,

    output[(pDo_WIDTH-1) :0]    frac_o,
    output[(pEXP_WIDTH-1):0]    exp_o,
    input                       inf_case,
    input                       in_valid,
    output                      out_valid,
    input                       clk,
    input                       rst_n
);
    localparam pLOD_WIDTH  = 64;
    localparam pFRAC_WIDTH = 53;
    localparam EXP_BIAS   = 13'd1023;
    localparam EXP_MAX    = 12'b0111_1111_1110;
    localparam EXP_INF    = 11'b111_1111_1111;
    localparam EXP_ZERO   = 11'b000_0000_0000;
    localparam FRAC_ZERO  = 52'd0;
//========================================================================================================================//

//----------------------------------------- First normalize & rounding----------------------------------------------------//
    wire                            lsb ;
    wire                            sticky_bit ;
    wire                            guard_bit  ;
    wire                            round_bit  ;
    wire [(pFRAC_WIDTH-1):0]        frac;
    wire [(pFRAC_WIDTH-1):0]        frac_logic_one;
    wire [(pFRAC_WIDTH  ):0]        frac_add;
    wire [(pFRAC_WIDTH-1):0]        frac_rounded;

    wire [(pEXP_WIDTH+2):0]         exp_add;
    wire [(pEXP_WIDTH+1):0]         exp_logic_one;
    wire [(pEXP_WIDTH+1):0]         exp_normalized_0;
    wire                            zero_case;
//------------------------------------------ pipeline stage 0 ------------------------------------------------------------//
    reg                             stage_0_v;
    reg                             stage_0_inf ;
    reg                             stage_0_zero;
    reg  [(pFRAC_WIDTH-1):0]        frac_stage_0;
    reg signed [(pEXP_WIDTH+1) :0]  exp_stage_0;
//----------------------------------------- Second normalize(part1) -------------------------------------------------------//
    wire [(pLOD_WIDTH-1):0]         frac_expand;
    wire [(pEXP_WIDTH):0]           shift;
    wire [(pEXP_WIDTH):0]           shift_amount;
    wire [(pFRAC_WIDTH-1):0]        frac_normalized_1;
    wire [(pEXP_WIDTH):0]           exp_normalized_1;
//------------------------------------------ pipeline stage 1 ------------------------------------------------------------//
    reg                             stage_1_v;
    reg                             stage_1_inf; 
    reg  [(pDo_WIDTH-1):0]          frac_stage_1;
    reg  [(pEXP_WIDTH) :0]          exp_stage_1;
//------------------------------------------ Second normalize -------------------------------------------------------------//
    wire                            zero_result;
    wire [(pEXP_WIDTH-1):0]         exp_normalized_2;
    wire [(pDo_WIDTH-1):0]          frac_normalized_2;

//------------------------------------------ pipeline stage 2 -----------------------------------------------------//
    reg                             stage_2_v;
    reg [(pDo_WIDTH-1):0]           frac_stage_2;
    reg [(pEXP_WIDTH-1):0]          exp_stage_2;

//------------------------------------------------------------------------------------------------------------------------//




//=======================================================================================================================//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                         First Normalize and rounding                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign zero_case        = ~ (|frac_i);
//------------------------------------------ first normalize  & rounding --------------------------------------------------//
    assign frac             = (frac_i[pDIN_WIDTH-1]) ? frac_i[(pDIN_WIDTH-1):(pDIN_WIDTH - pFRAC_WIDTH)] : frac_i[(pDIN_WIDTH-2) : (pDIN_WIDTH - pFRAC_WIDTH - 1) ]; 
    assign sticky_bit       = (frac_i[pDIN_WIDTH-1]) ? |(frac_i[(pDIN_WIDTH - pFRAC_WIDTH -3) :0 ])      : |(frac_i[(pDIN_WIDTH- pFRAC_WIDTH -4) :0]);
    assign lsb              = (frac_i[pDIN_WIDTH-1]) ? frac_i[pDIN_WIDTH - pFRAC_WIDTH]                  : frac_i[pDIN_WIDTH - pFRAC_WIDTH -1];
    assign guard_bit        = (frac_i[pDIN_WIDTH-1]) ? frac_i[pDIN_WIDTH - pFRAC_WIDTH-1]                : frac_i[pDIN_WIDTH - pFRAC_WIDTH -2];
    assign round_bit        = (frac_i[pDIN_WIDTH-1]) ? frac_i[pDIN_WIDTH - pFRAC_WIDTH-2]                : frac_i[pDIN_WIDTH - pFRAC_WIDTH -3];
    
    assign exp_normalized_0 = (frac_i[pDIN_WIDTH-1]) ? exp_add[(pEXP_WIDTH+1):0] : exp_i ;


    assign frac_rounded     = (guard_bit && (lsb | round_bit | sticky_bit))?   frac_add[(pFRAC_WIDTH-1):0] :  frac ;
    assign frac_logic_one   = {{(pFRAC_WIDTH-1){1'b0}}  , 1'b1};

    add_53_overflow adder_0(
        .in_A(frac),
        .in_B(frac_logic_one),
        .result(frac_add)
    );

    add_13_overflow adder_1(
        .in_A( exp_i ),
        .in_B( frac_logic_one[(pEXP_WIDTH+1):0] ),
        .result( exp_add )
    );

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            pipeline stage 0                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_0_v     <= 1'b0;
        stage_0_inf   <= 1'b0;
        stage_0_zero  <= 1'b0;
        frac_stage_0  <= {(pFRAC_WIDTH){1'b0}};
        exp_stage_0   <= {(pEXP_WIDTH+2){1'b0}};
    end else begin
        stage_0_v     <= in_valid;
        stage_0_inf   <= inf_case;
        stage_0_zero  <= zero_case;
        frac_stage_0  <= frac_rounded[(pFRAC_WIDTH-1):0] ;
        exp_stage_0   <= exp_normalized_0[(pEXP_WIDTH+1):0];
    end
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            Second Normalize (part 1)                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////




assign frac_expand = {  frac_stage_0 , {(pLOD_WIDTH-pFRAC_WIDTH){1'b0}} };

    LOD_64 LOD_00(
        .A(frac_expand) ,
        .position(shift)
    );

    
assign shift_amount       = (shift > exp_stage_0)?                           exp_stage_0[(pEXP_WIDTH):0] : shift ; 
assign exp_normalized_1   = (stage_0_zero || exp_stage_0[pEXP_WIDTH+1])?     {(pEXP_WIDTH+1){1'b0}}      : (exp_stage_0 - shift_amount); 
assign frac_normalized_1  = (stage_0_zero || exp_stage_0[pEXP_WIDTH+1])?     {(pFRAC_WIDTH){1'b0}}       : (frac_stage_0 << shift_amount);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            pipeline stage 1                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_1_v     <= 1'b0;
        stage_1_inf   <= 1'b0;
        frac_stage_1  <= {(pDo_WIDTH){1'b0}};
        exp_stage_1   <= {(pEXP_WIDTH+1){1'b0}};
    end else begin
        stage_1_v     <= stage_0_v;
        stage_1_inf   <= stage_0_inf;
        frac_stage_1  <= frac_normalized_1[(pDo_WIDTH-1):0];
        exp_stage_1   <= exp_normalized_1;

    end
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            Second Normalize (part 2)                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


assign zero_result       = ! (  (|(frac_stage_1)) | (|(exp_stage_1)) );

assign exp_normalized_2  = (zero_result)? EXP_ZERO  :   ( ((exp_stage_1 > EXP_MAX)|| stage_1_inf )? EXP_INF   :  exp_stage_1[(pEXP_WIDTH-1):0]);
assign frac_normalized_2 = (zero_result)? FRAC_ZERO :   ( ((exp_stage_1 > EXP_MAX)|| stage_1_inf )? FRAC_ZERO :  frac_stage_1 );

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            pipeline stage 2                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_2_v     <= 1'b0;
        frac_stage_2  <= {(pDo_WIDTH){1'b0}};
        exp_stage_2   <= {(pEXP_WIDTH){1'b0}};
    end else begin
        stage_2_v     <= stage_1_v;
        frac_stage_2  <= frac_normalized_2;
        exp_stage_2   <= exp_normalized_2;

    end
end
    
    assign frac_o     = frac_stage_2 ;
    assign exp_o      = exp_stage_2;
    assign out_valid  = stage_2_v;

endmodule


