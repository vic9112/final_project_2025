///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // `include "CLA_8.v"
    // `include "add_13_overflow.v"
    // `include "add_53_overflow.v"
    // `include "LOD_64.v"
    // `include "LOD_128.v"
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
// 2025.6.16  hsuan_jung,lo       3.0       modify the data process , we include subnormal case 
// 2025.6.18  hsuan_jung,lo       4.0       modfiy the rounding process to improve the precision
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
//      exp_i     >   xx  |  e0  |  e1  |           xx                    * input exponent(exponent result form fmul_exp) <= this will be the real value of exponent
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
//                                                 pip_stage0                                     pip_stage1                               pip_stage2
//                                                     ___                                           ___                                       ___
//                     __________________________     |   |      ____________________________       |   |      __________________________     |   |
//                    |                         |     |   |      |                          |       |   |      |                        |     |   |
//   data input  =>   |        rounding         |  => |   | =>   |   normalization part 1   |  =>   |   |  =>  |  normalization part 2  | =>  |   |  ==> Result  
//                    |_________________________|     |   |      |__________________________|       |   |      |________________________|     |   |
//                                                    |   |                                         |   |                                     |   |
//                                                    |___|                                         |___|                                     |___|
//====================================================================================================================================================================================

//=====================================================================================================================================================================================-//
//
//  First , in rounding block ,  we normalize the fraction position and exponent before rounding .
// * Step 1.  first time normalization       
//                               2bit  104bit
//    106bit frac_i structure :  xx  . xxxxx
//                                   ^
//                               floating point
//
// * Then extension frac_i into 128bit width by zero to detect the leading one position (because the LOD logic we used is limit in width of 128、64) .
// * If leading of frac_i = 1 , we normalize exp into exp_i + 1 , keep the frac = fraci 
// *    else we shift left the frac_i to satisfy the following structure :
//
//                                      1bit   105bit
//        =>  106 bits frac structure :  x  .  xxxxxx
//                                          ^
//                                     floating point
//
// * Step 2.  get LSB 、 guard_bit 、 round_bit from frac.
//
//           53bit         1bit      1bit      ...
//     |     FRAC     |   GURAD  |  Round  |  sticky  | 
//
// * Step 3.  rounding frac to nearest even  with sticky ( expand 1 bit for overflow )
//                                1bit | 53bit fraction |
//          frac_rounded  :         x     x . xxxxx    
//                                          ^
//                                     floating point 
//
//         ------------------------- pipeline stage ----------------------------------   
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
//  Second , in normaliztion block , we normalize the rounded result and exponent
//
// * Step 1. find leading one position of fraction(extense the frac into 64bit to fit LOD_width)
//          
//        53bit          53bit    11bit
//     |  FRAC  |  =>  |  FRAC  |  000... |
//
//  *Step 2. shift FRAC to let the leading bits is one  
//          (if all zero , we shift frac 64bits by value of LOD detected)
//
// ----------------------------------- pipeline stage -------------------------------------------------------
//  
// * Step 3. normaliztion into IEEE 754 foramt 52bit fraction(1 bit hidden)
//         if real value of exponent < -1022 here , we normalize the exponent and fraction into the value we can transfer into IEEE754.
//         for example :
//                    Case A  :     exp_value = -1025 (decimal) , frac = 1.01.... (binary)
//          =>  transfer into :     exp_value = -1022 (decimal) , frac = 0.00101..(binary)
//          =>  normalization :   exp_IEEE754 =     0 (decimal) , frac = 52'b00101...
//
//                             
//                    Case B  :     exp_value = -1000 (decimal) , frac = 1.0111... (binary)
//          =>  normalization :   exp_IEEE754 =   23  (decimal) , frac = 0111....  (binary) 
//
//
//                    Case C  :     exp_value = -1023 (decimal) , frac = 1.0111... (binary)
//          =>  transfer into :     exp_value = -1022 (decimal) , frac = 0.10111.. (binary)            
//          =>  normalization :   exp_IEEE754 =    0  (decimal) , frac = 010111....  (binary) 
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
    localparam pLOD_WIDTH2 = 128;
    localparam pFRAC_WIDTH = 53;
    localparam EXP_BIAS    = 13'd1023;
    localparam EXP_MAX     = 12'b0111_1111_1110;
    localparam EXP_MIN     = 13'b1_1100_0000_0010; // * -1022
    localparam EXP_INF     = 11'b111_1111_1111;
    localparam EXP_ZERO    = 11'b000_0000_0000;
    localparam FRAC_ZERO   = 53'd0;
//========================================================================================================================//

//----------------------------------------- First normalize & rounding----------------------------------------------------//
    wire                                    lsb ;
    wire                                    sticky_bit ;
    wire                                    guard_bit  ;
    wire                                    ound_bit  ;
    wire [(pDIN_WIDTH-1) :0]                frac;
    wire [(pFRAC_WIDTH-1):0]                frac_logic_one;
    wire [(pFRAC_WIDTH  ):0]                frac_add;
    wire [(pFRAC_WIDTH  ):0]                frac_rounded;
    wire [(pLOD_WIDTH2-1):0]                frac_i_expand;
    wire [(pEXP_WIDTH+2):0]                 exp_add;
    wire [(pEXP_WIDTH+1):0]                 exp_logic_one;
    wire signed[(pEXP_WIDTH+1):0]           exp_normalized_0;
    wire signed[(pEXP_WIDTH+1) :0]          shift_fi ; 
    wire                                    zero_case;
//------------------------------------------ pipeline stage 0 ------------------------------------------------------------//
    reg                                     stage_0_v;
    reg                                     stage_0_inf ;
    reg                                     stage_0_zero;
    reg  [(pFRAC_WIDTH  ):0]                frac_stage_0;
    reg signed [(pEXP_WIDTH+1) :0]          exp_stage_0;
//----------------------------------------- Second normalize(part1) -------------------------------------------------------//
    wire [(pLOD_WIDTH-1):0]                 frac_shifted;
    wire [(pLOD_WIDTH-1):0]                 frac_expand;
    wire [(pEXP_WIDTH):0]                   shift;
    wire [(pEXP_WIDTH):0]                   shift_amount;
    wire [(pFRAC_WIDTH-1):0]                frac_normalized_1;
    wire signed[(pEXP_WIDTH+1):0]           exp_normalized_1;
    wire signed[(pEXP_WIDTH+1) :0]          exp_0;
//------------------------------------------ pipeline stage 1 ------------------------------------------------------------//
    reg                                     stage_1_v;
    reg                                     stage_1_inf; 
    reg                                     stage_1_zero;
    reg  [(pFRAC_WIDTH-1):0]                frac_stage_1;
    reg signed[(pEXP_WIDTH+1) :0]           exp_stage_1;
//------------------------------------------ Second normalize -------------------------------------------------------------//
    wire                                    zero_result;
    wire [(pEXP_WIDTH+1):0]                 shift_2 ;
    wire [(pFRAC_WIDTH-1):0]                frac_normalized_2;
    wire signed[(pEXP_WIDTH+1) :0]          exp_normalized_2;
    wire signed[(pEXP_WIDTH+1) :0]          exp_min;
    wire signed[(pEXP_WIDTH+1) :0]          exp_less;

//------------------------------------------ pipeline stage 2 -----------------------------------------------------//
    wire                                    inf_o;
    reg                                     stage_2_v;
    reg [(pFRAC_WIDTH-1):0]                 frac_stage_2;
    reg [(pEXP_WIDTH):0]                    exp_stage_2;

//------------------------------------------------------------------------------------------------------------------------//




//=======================================================================================================================//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                         First Normalize and rounding                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assign frac_i_expand                       = {frac_i , {(pLOD_WIDTH2 - pDIN_WIDTH){1'b0}}};
    assign shift_fi[(pEXP_WIDTH+1):pEXP_WIDTH] = 2'b00;
    assign zero_case                           = ~ (|frac_i);

//------------------------------------------ first normalize  & rounding --------------------------------------------------//

    LOD_128 LOD_01(
        .A(frac_i_expand) ,
        .position(shift_fi[(pEXP_WIDTH-1):0])
    );
    
    assign frac             = frac_i << shift_fi ;    
    assign sticky_bit       = |(frac[(pDIN_WIDTH - pFRAC_WIDTH -3) : 0]);
    assign lsb              = frac[pDIN_WIDTH - pFRAC_WIDTH];
    assign guard_bit        = frac[pDIN_WIDTH - pFRAC_WIDTH-1];
    assign round_bit        = frac[pDIN_WIDTH - pFRAC_WIDTH-2];
    assign exp_normalized_0 = exp_i - shift_fi + frac_logic_one[(pEXP_WIDTH+1):0];
    assign frac_add         = frac[(pDIN_WIDTH-1):(pDIN_WIDTH - pFRAC_WIDTH)] + {{(pFRAC_WIDTH){1'b0}} , 1'b1 };
    
    
    // assign frac             = (frac_i[pDIN_WIDTH-1]) ? frac_i[(pDIN_WIDTH-1):(pDIN_WIDTH - pFRAC_WIDTH)] : frac_i[(pDIN_WIDTH-2) : (pDIN_WIDTH - pFRAC_WIDTH - 1) ]; 
    // assign sticky_bit       = (frac_i[pDIN_WIDTH-1]) ? |(frac_i[(pDIN_WIDTH - pFRAC_WIDTH -3) : 1])      : |(frac_i[(pDIN_WIDTH- pFRAC_WIDTH -4) :0]);
    // assign lsb              = (frac_i[pDIN_WIDTH-1]) ? frac_i[pDIN_WIDTH - pFRAC_WIDTH]                  : frac_i[pDIN_WIDTH - pFRAC_WIDTH -1];
    // assign guard_bit        = (frac_i[pDIN_WIDTH-1]) ? frac_i[pDIN_WIDTH - pFRAC_WIDTH-1]                : frac_i[pDIN_WIDTH - pFRAC_WIDTH -2];
    // assign round_bit        = (frac_i[pDIN_WIDTH-1]) ? frac_i[pDIN_WIDTH - pFRAC_WIDTH-2]                : frac_i[pDIN_WIDTH - pFRAC_WIDTH -3];


    // assign exp_normalized_0 = (frac_i[pDIN_WIDTH-1]  ) ? exp_add[(pEXP_WIDTH+1):0] : exp_i ;
     assign frac_rounded     = (guard_bit && (lsb | round_bit | sticky_bit))?   frac_add : {1'b0 , frac[(pDIN_WIDTH-1):(pDIN_WIDTH - pFRAC_WIDTH)]};
     assign frac_logic_one   = {{(pFRAC_WIDTH-1){1'b0}}  , 1'b1};

    // add_53_overflow adder_0(
    //     .in_A(frac),
    //     .in_B(frac_logic_one),
    //     .result(frac_add)
    // );

    // add_13_overflow adder_1(
    //     .in_A( exp_i ),
    //     .in_B( frac_logic_one[(pEXP_WIDTH+1):0] ),
    //     .result( exp_add )
    // );

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            pipeline stage 0                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_0_v     <= 1'b0;
        stage_0_inf   <= 1'b0;
        stage_0_zero  <= 1'b0;
        frac_stage_0  <= {(pFRAC_WIDTH+1){1'b0}};
        exp_stage_0   <= {(pEXP_WIDTH+2){1'b0}};
    end else begin
        stage_0_v     <= in_valid;
        stage_0_inf   <= inf_case;
        stage_0_zero  <= zero_case;
        frac_stage_0  <= frac_rounded[(pFRAC_WIDTH):0] ;
        exp_stage_0   <= exp_normalized_0[(pEXP_WIDTH+1):0];
    end
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            Second Normalize (part 1)                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign frac_expand = (frac_stage_0[pFRAC_WIDTH])? {frac_stage_0 , {(pLOD_WIDTH-pFRAC_WIDTH-1){1'b0}} } : {frac_stage_0[(pFRAC_WIDTH-1):0] , {(pLOD_WIDTH-pFRAC_WIDTH){1'b0}}};
assign exp_0       = (frac_stage_0[pFRAC_WIDTH])?      (exp_stage_0 + {{(pEXP_WIDTH+1){1'b0}} , 1'b1}) : exp_stage_0 ;

    LOD_64 LOD_02(
        .A(frac_expand) ,
        .position(shift)
    );

assign frac_shifted = frac_expand << shift ;

assign exp_normalized_1   = (stage_0_zero)?     (EXP_MIN - {{(pEXP_WIDTH){1'b1}} , 2'b10} )       : (exp_0 - shift); 
assign frac_normalized_1  = (stage_0_zero)?     {(pFRAC_WIDTH){1'b0}} : (frac_shifted[(pLOD_WIDTH-1):(pLOD_WIDTH - pFRAC_WIDTH )]);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            pipeline stage 1                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_1_v     <= 1'b0;
        stage_1_inf   <= 1'b0;
        stage_1_zero  <= 1'b0;
        frac_stage_1  <= {(pFRAC_WIDTH){1'b0}};
        exp_stage_1   <= {(pEXP_WIDTH+2){1'b0}};
    end else begin
        stage_1_v     <= stage_0_v;
        stage_1_inf   <= stage_0_inf;
        stage_1_zero  <= stage_0_zero;
        frac_stage_1  <= frac_normalized_1[(pFRAC_WIDTH-1):0];
        exp_stage_1   <= exp_normalized_1;

    end
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            Second Normalize (part 2)                                                   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign shift_2             = - exp_less;
assign exp_min             = EXP_MIN  ;
assign exp_less            = exp_stage_1 - exp_min ;
assign exp_normalized_2    = (stage_1_inf && (~stage_1_zero))?  EXP_INF   : ((exp_less[pEXP_WIDTH+1])?            {(pEXP_WIDTH+2){1'b0}}  : ( exp_stage_1 + EXP_BIAS ) );  
assign frac_normalized_2   = (stage_1_inf && (~stage_1_zero))?  FRAC_ZERO : ((exp_less[pEXP_WIDTH+1])? ((frac_stage_1  ) >> shift_2)   : frac_stage_1 );




//assign exp_normalized_2  = (zero_result)? EXP_ZERO  :   ( ((exp_stage_1 > EXP_MAX)|| stage_1_inf )? EXP_INF   :  exp_stage_1[(pEXP_WIDTH-1):0]);
//assign frac_normalized_2 = (zero_result)? FRAC_ZERO :   ( ((exp_stage_1 > EXP_MAX)|| stage_1_inf )? FRAC_ZERO :  frac_stage_1 );

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                            pipeline stage 2                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_2_v     <= 1'b0;
        frac_stage_2  <= {(pFRAC_WIDTH){1'b0}};
        exp_stage_2   <= {(pEXP_WIDTH+1){1'b0}};
    end else begin
        stage_2_v     <= stage_1_v;
        frac_stage_2  <= frac_normalized_2[(pFRAC_WIDTH-1):0];
        exp_stage_2   <= exp_normalized_2 [(pEXP_WIDTH):0];

    end
end
    assign inf_o        = (exp_stage_2 > EXP_MAX )? 1'b1 : 1'b0 ;
    assign frac_o       =  (inf_o)?   {(pDo_WIDTH){1'b0}} : frac_stage_2[(pDo_WIDTH-1):0];
    assign exp_o        =  (inf_o)?              EXP_INF  : exp_stage_2 [(pEXP_WIDTH-1):0];
    assign out_valid    = stage_2_v;

endmodule


