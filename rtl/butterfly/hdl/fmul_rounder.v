/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// `include "CLA_8.v"
// `include "add_13.v"
// `include "sub_13.v"
// `include "add_13_overflow.v"
// `include "add_53_overflow.v"
// `include "LOD_64.v"
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// =================================================================================================================================================================================
// Module Name : fmul_rounder
// Author : Hsuan Jung,Lo
// Create Date: 6/2025
// Features & Functions:
// . To round and normalize the floating point mul result into IEEE 754 double precision format. 
// .
// =================================================================================================================================================================================
// Revision History:
// Date         by              Version              Change Description
// 2025.6.5   hsuan_jung,lo       2.0       fix rounding position of lsb and fix pattern problem
// 2025.6.16  hsuan_jung,lo       3.0       modify the data process , we include subnormal case 
// 2025.6.18  hsuan_jung,lo       4.0       modfiy the rounding process to improve the precision
// 2025.7.2   hsuan_jung,lo       5.0       modify the operator alogrithm to follow IEEE 754 format
// 2025.7.6   hsuan_jung,lo       6.0       re-allocate the pipeline stage to improve the timming                                                                                                       
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//================================================================================================================================================================================//
// * As IEEE 754 double precision floating point format, fraction with hidden bit is 53 bit width, while doing mul operation , we need to mul 53bit fraction to 106bit width      //
// * This module is used to round the result of 53 bit mul operation and normalize to fit IEEE7754 format.                                                                        //
//                                                                                                                                                                                //
// * Asserted in_valid high to feed valid data ,and return valid result with out_valid                                                                                            //
//                                                                                                                                                                                //
// * Waveform：                                                                                                                                                                   //
//      clk       >|      |      |      |      |      |      |      |                                                                                                             //
//      in_valid  >________/-------------\_____________________________   * input valid asserted high for data input                                                              //
//      frac_i    >   xx  |  f0  |  f1  |           xx                    * input fraction(mul result from wallace tree)                                                          //
//      exp_i     >   xx  |  e0  |  e1  |           xx                    * input exponent(exponent result form fmul_exp) <= this will be the real value of exponent              //
//      inf_case  >_______________/------\_____________________________   * while input data contain infinite number ,asserted high.                                              //
//      out_valid >_____________________________/--------------\_______   * output valid asserted high for data output                                                            //
//      frac_o    >|         xx                |  F0  |  F1  |  xx  |     * output fraction (normalized into IEEE 754 format)                                                     //
//      exp_o     >|         xx                |  E0  |  INF |  xx  |     * output exponent (normalized into IEEE 754 format)                                                     //
//                                                                                                                                                                                //
//================================================================================================================================================================================//

//================================================================================================================================================================================//
//  * FLOW                                                                                                                                                                        //
//  *   step1 . round the fraction by nearest even rounding(with sticky)                                                                                                          //
//  *   step2 . detect whether there is overflow from rounding                                                                                                                    //
//  *   step3 . use LOD to count leading one's position and normalize the exponent and fraction (LOD width 64bit )                                                                //
//  *   step4 . Encode the fraction and exp into IEEE 754                                                                                                                         //
//                                                                                                                                                                                //
//                                                                                                                                                                                //
//                                     pip_stage1                                 pip_stage2                                pip_stage3                     pip_stage4             //
//                                        ___                                         ___                                       ___                           ___                 //
//                   ______________      |   |     ____________________________      |   |      __________________________     |   |      _____________      |   |                //
//                   |             |     |   |     |                          |      |   |      |                        |     |   |      |            |     |   |                //
//   data input  =>  |  rounding   |  => |   | =>  |   normalization part 0   |  =>  |   |  =>  |  normalization part 1  | =>  |   |  =>  |   Encode   |  => |   |  =>  Result    //
//                   |_____________|     |   |     |__________________________|      |   |      |________________________|     |   |      |____________|     |   |                //
//                                       |   |                                       |   |                                     |   |                         |   |                //
//                                       |___|                                       |___|                                     |___|                         |___|                //
//                                                                                                                                                                                //
//================================================================================================================================================================================//

//================================================================================================================================================================================//
//                                                                                                                                                                                //
// < First stage > : Rounding                                                                                                                                                     //
//                                                                                                                                                                                //
// * Step 1 . Detect whether there is  overflow from fraction mul                                                                                                                 //
//                                                                                                                                                                                //
//            106bit frac_i structure :  xx  . xxxxx                                                                                                                              //
//                                           ^                                                                                                                                    //
//                                     floating point                                                                                                                             //
//                                                                                                                                                                                //
//           If overflow :                                                                                                                                                        //
//                                       1bit      52bits      53bits                                                                                                             //
//                    frac structure : |   x   |    Frac   |  xxxxxxxxx  |                                                                                                        //  
//                                             ^                                                                                                                                  //
//                                        floating point                                                                                                                          //
//                    => exp = exp +1                                                                                                                                             //
//                                                                                                                                                                                //
//           If no overflow :                                                                                                                                                     //
//                                        1bit    1bit     52bits      52bits                                                                                                     //
//                    frac structure : |   0   |   x   |    Frac   |  xxxxxxxx  |                                                                                                 //
//                                                     ^                                                                                                                          //
//                                                  floating point                                                                                                                //
//                    => exp = exp                                                                                                                                                //
//                                                                                                                                                                                //  
// * Step 2.  get LSB 、 guard_bit 、 round_bit from  frac_i ( after the overflow detect ).                                                                                       //
//                                                                                                                                                                                //
//                           53bit         1bit      1bit      ...                                                                                                                //
//                      |     FRAC     |   GURAD  |  Round  |  sticky  |                                                                                                          //
//                                                                                                                                                                                //
// * Step 3.  rounding frac to nearest even  with sticky ( expand 1 bit for overflow )                                                                                            //
//                               | 1bit | 53bit fraction |                                                                                                                        //
//          frac_rounded  :      |   x  |   x . xxxxx~xx |                                                                                                                        //
//                                            ^                                                                                                                                   //
//                                      floating point                                                                                                                            //
//                                                                                                                                                                                //
// --------------------------------- pipeline stage --------------------------------------------------------                                                                      //
//================================================================================================================================================================================//

//================================================================================================================================================================================//
//  < Second stage > : normalization 0                                                                                                                                            //
//                                                                                                                                                                                //
// * Step 1. Check whether there is overflow in rounding stage                                                                                                                    //
//                                                                                                                                                                                //
//                               | 1bit | 53bit fraction |                                                                                                                        //
//          frac_rounded  :      |   x  |   x . xxxxx~xx |                                                                                                                        //
//                                   ^                                                                                                                                            //
//                                overflow                                                                                                                                        //
//                                                                                                                                                                                //
// * Step 2. shift FRAC 1bit rigth if there is overflow, and add one to exp .                                                                                                     //
//          (if no overflow , don't do anything )                                                                                                                                 //
//                                                                                                                                                                                //
// * Step 3. if sign bit of exp is 1 ( negative ) , calculate the absolute value of exp and then shfit the frac right                                                             //
//          (if exp is positive , don't do anything)                                                                                                                              //
//                                                                                                                                                                                //
//  **** After this stage we get positive exp ( or zero exp ) , and 53bits rounded frac *****                                                                                     //
//                                                                                                                                                                                //
// ----------------------------------- pipeline stage -------------------------------------------------------                                                                     //
//================================================================================================================================================================================//

//================================================================================================================================================================================//
//  < Third stage > : normalization 1                                                                                                                                             //
//                                                                                                                                                                                //
// * Step 1. expand fraction into 64 bits [ Leading one dector (LOD) is limit in 64bits 、 128bits ] .                                                                            //
//                                                                                                                                                                                //
// * Step 2. Use LOD_64 to detect the leading one's position of expanded fraction .                                                                                               //
//                                                                                                                                                                                //
//           => LOD_64 output shift as the number of zero in front of leading one                                                                                                 //
//                                                                                                                                                                                //
// * Step 3. Determine the shift amount :                                                                                                                                         //
//                                                                                                                                                                                //
//              If shift >= exp value :                                                                                                                                           //
//                                       shift_amount     = exp_value                                                                                                             //
//                                       exp_normalized_1 =  0                                                                                                                    //
//                                                                                                                                                                                //
//              If shift <  exp value :                                                                                                                                           //
//                                       shift_amount     = shift                                                                                                                 //
//                                       exp_normalized_1 = pip2_exp - shift                                                                                                      //
//                                                                                                                                                                                //
// * Step 4. Shift the fraction left as shift_amount                                                                                                                              //                                                  
//                                                                                                                                                                                //
// ----------------------------------- pipeline stage -------------------------------------------------------                                                                     //
//================================================================================================================================================================================//

//================================================================================================================================================================================//
// < Forth stage > : Encode into IEEE 754 format ( hid the leading bit of fraction )                                                                                              //
//                                                                                                                                                                                //
//         *************************************************************************                                                                                              //
//         *                      Subnormal Case of inf exp                        *                                                                                              //
//         *************************************************************************                                                                                              //
//                                                                                                                                                                                //
//                  Case A  :  inf = 1 , exp < 2047    , frac = 101..... ( binary )                                                                                               //
//        => transfer into  :            exp = 2047    , frac = 000...00 ( binary )                                                                                               //
//        => Encode IEEE754 :  exp_normalized_1 = 2047 , frac_normalized = 0000..00                                                                                               //
//                                 ( 11 bits )             ( 52 bits )                                                                                                            //
//                                                                                                                                                                                //
//                  Case B  :  inf = 0 , exp > 2047    , frac = 101..... ( binary )                                                                                               //
//        => transfer into  :            exp = 2047    , frac = 000...00 ( binary )                                                                                               //
//        => Encode IEEE754 :  exp_normalized_1 = 2047 , frac_normalized = 0000..00                                                                                               //
//                                 ( 11 bits )             ( 52 bits )                                                                                                            //
//                                                                                                                                                                                //
//         *************************************************************************                                                                                              //
//         *                     Subnormal Case of zero exp                        *                                                                                              //
//         *************************************************************************                                                                                              //
//                                                                                                                                                                                //
//                  Case C  :  inf = 0 , exp = 0    , frac = 10110... ( binary )                                                                                                  //
//        => transfer into  :            exp = 0    , frac = 010110.. ( binary )                                                                                                  //
//        => Enocde IEEE754 :  exp_normalized_1 = 0 ,  frac_normalized = 10110..                                                                                                  //
//                                 ( 11 bits )             ( 52 bits )                                                                                                            //
//                                                                                                                                                                                //
//         *************************************************************************                                                                                              //
//         *                            Normal Case                                *                                                                                              //
//         *************************************************************************                                                                                              //
//                  Case D  : inf = 0 , exp = 105    , frac = 101101... ( binary )                                                                                                //
//       =>  transfer into  :           exp = 105    , frac = 101101... ( binary )                                                                                                //
//       =>  Encode IEEE754 : exp_normalized_1 = 105 , frac_normalized = 01101                                                                                                    //
//                                 ( 11 bits )             ( 52 bits )                                                                                                            //
//                                                                                                                                                                                //
// ----------------------------------- pipeline stage -------------------------------------------------------                                                                     //
//================================================================================================================================================================================//

module fmul_rounder#(
    parameter pDIN_WIDTH   = 106 ,
    parameter pFRAC_WIDTH  = 52  ,
    parameter pEXP_WIDTH   = 11
)
(
    input [(pDIN_WIDTH-1) :0]    frac_i    ,
    input [(pEXP_WIDTH+1) :0]    exp_i     ,

    output[(pFRAC_WIDTH-1):0]    frac_o    ,
    output[(pEXP_WIDTH-1) :0]    exp_o     ,
    input                        inf_case  ,
    input                        in_valid  ,
    output                       out_valid ,
    input                        clk       ,
    input                        rst_n
);

localparam pLOD_WIDTH = 64 ;

//================================== Rounding ==============================================//
wire [(pEXP_WIDTH+1) :0]                exp          ;
wire [(pFRAC_WIDTH)  :0]                frac         ;
wire [(pFRAC_WIDTH+1):0]                frac_add     ;
wire [(pFRAC_WIDTH+1):0]                frac_rounded ;
wire [(pDIN_WIDTH-1) :0]                logic_one ;
wire [(pEXP_WIDTH+2) :0]                exp_add   ;
wire                                    lsb       ;
wire                                    guard_bit ;
wire                                    round_bit ;
wire                                    sticky    ;
//================================ Pipeline stage 1 ========================================//
reg [(pFRAC_WIDTH+1):0]                 pip1_frac ;
reg [(pEXP_WIDTH+1) :0]                 pip1_exp  ;
reg                                     pip1_v    ;
reg                                     pip1_inf  ;
//================================ Normalization 0 =========================================//
wire [(pFRAC_WIDTH) :0]                 frac_shift_0      ;
wire [(pFRAC_WIDTH) :0]                 frac_normalized_0 ;

wire [(pEXP_WIDTH+1):0]                 exp_norm          ;
wire [(pEXP_WIDTH+1):0]                 exp_abs           ;
wire [(pEXP_WIDTH+1):0]                 logic_norm_0      ;
wire [(pEXP_WIDTH  ):0]                 exp_normalized_0  ;
//================================ Pipeline stage 2 ========================================// 
reg                                     pip2_v     ;
reg                                     pip2_inf   ;
reg  [(pFRAC_WIDTH) :0]                 pip2_frac  ;
reg  [(pEXP_WIDTH)  :0]                 pip2_exp   ;
//================================ Normalization 1 =========================================//
wire [(pLOD_WIDTH-1):0]                 frac_expand       ;
wire [(pEXP_WIDTH+1):0]                 exp_expand        ;
wire [(pEXP_WIDTH  ):0]                 shift             ;
wire [(pEXP_WIDTH  ):0]                 shift_amount      ;
wire [(pEXP_WIDTH+1):0]                 shift_expand      ;
wire [(pEXP_WIDTH+1):0]                 exp_sub           ;
wire [(pEXP_WIDTH)  :0]                 exp_normalized_1  ;
wire [(pFRAC_WIDTH) :0]                 frac_normalized_1 ; 
//================================ Pipeline stage 3 ========================================// 
reg                                     pip3_v      ;
reg                                     pip3_inf    ;
reg  [(pEXP_WIDTH) :0]                  pip3_exp    ;
reg  [(pFRAC_WIDTH):0]                  pip3_frac   ;
//=============================== Encode into IEEE 754 ====================================//
reg  [(pFRAC_WIDTH-1):0]                frac_result ;
reg  [(pEXP_WIDTH-1) :0]                exp_result  ;
//================================ Pipeline stage 4 ========================================// 
reg                                     pip4_v      ;
reg [(pEXP_WIDTH-1): 0]                 pip4_exp    ;
reg [(pFRAC_WIDTH-1):0]                 pip4_frac   ;
//==========================================================================================//

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                          Leading bit check and Rounding                                                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign exp          = ( frac_i[pDIN_WIDTH-1] )?   exp_add[(pEXP_WIDTH+1):0] : exp_i ;
assign frac         = ( frac_i[pDIN_WIDTH-1] )?   frac_i[(pDIN_WIDTH-1) : (pDIN_WIDTH-pFRAC_WIDTH-1)]  :  frac_i[(pDIN_WIDTH-2) : (pDIN_WIDTH-pFRAC_WIDTH-2)] ;
assign lsb          = ( frac_i[pDIN_WIDTH-1] )?   frac_i[pDIN_WIDTH-pFRAC_WIDTH-1]         : frac_i[pDIN_WIDTH-pFRAC_WIDTH-2] ;
assign guard_bit    = ( frac_i[pDIN_WIDTH-1] )?   frac_i[pDIN_WIDTH-pFRAC_WIDTH-2]         : frac_i[pDIN_WIDTH-pFRAC_WIDTH-3] ;
assign round_bit    = ( frac_i[pDIN_WIDTH-1] )?   frac_i[pDIN_WIDTH-pFRAC_WIDTH-3]         : frac_i[pDIN_WIDTH-pFRAC_WIDTH-4] ;
assign sticky       = ( frac_i[pDIN_WIDTH-1] )?   (|frac_i[(pDIN_WIDTH-pFRAC_WIDTH-4):0])  : (|frac_i[(pDIN_WIDTH-pFRAC_WIDTH-5):0] );
assign frac_rounded = (guard_bit && (lsb | round_bit | sticky))?  frac_add : {1'b0 , frac}  ;
assign logic_one    = {{(pDIN_WIDTH-1){1'b0}} , 1'b1};


add_13_overflow add_13_00 ( .in_A( exp_i ) , .in_B( logic_one[(pEXP_WIDTH+1):0] ) , .result( exp_add  ) ) ;
add_53_overflow add_53_00 ( .in_A( frac  ) , .in_B( logic_one[(pFRAC_WIDTH) :0] ) , .result( frac_add ) ) ;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  Pipeline stage 1                                                                                    //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip1_v     <= 1'b0;
        pip1_inf   <= 1'b0;
        pip1_frac  <= {(pFRAC_WIDTH+2){1'b0}};
        pip1_exp   <= {(pEXP_WIDTH+2){1'b0}};
    end else begin
        pip1_v     <= in_valid ;
        pip1_inf   <= inf_case ;
        pip1_frac  <= frac_rounded ;
        pip1_exp   <= exp          ;
    end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                     Normalization 0                                                                                   //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign frac_shift_0      = ( pip1_frac[pFRAC_WIDTH+1] )? pip1_frac[(pFRAC_WIDTH+1):1] : pip1_frac[(pFRAC_WIDTH):0] ;

assign exp_normalized_0  = ( pip1_frac[pFRAC_WIDTH+1] )? (( exp_norm[pEXP_WIDTH+1] )? {(pEXP_WIDTH+1){1'b0}}   : exp_norm[(pEXP_WIDTH):0] ) : (( pip1_exp [pEXP_WIDTH+1]  )? {(pEXP_WIDTH+1){1'b0}} : pip1_exp[(pEXP_WIDTH):0]);
assign frac_normalized_0 = ( pip1_frac[pFRAC_WIDTH+1] )? (( exp_norm[pEXP_WIDTH+1] )? (frac_shift_0 >> exp_abs) : frac_shift_0 )            : (( pip1_exp [pEXP_WIDTH+1 ] )? ( frac_shift_0 >> exp_abs ) : frac_shift_0 );

assign logic_norm_0      = ( pip1_frac[pFRAC_WIDTH+1] )?  {(pEXP_WIDTH+2){1'b0}} : {{(pEXP_WIDTH+1){1'b0}} , 1'b1};  // if overflow , exp_abs = exp_abs + 1

add_13 add_13_01 ( .in_A( pip1_exp  ) , .in_B( logic_one   [(pEXP_WIDTH+1):0] ) , .result( exp_norm ) );
add_13 add_13_02 ( .in_A( ~pip1_exp ) , .in_B( logic_norm_0[(pEXP_WIDTH+1):0] ) , .result( exp_abs )  );


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  Pipeline stage 2                                                                                    //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip2_v     <= 1'b0;
        pip2_inf   <= 1'b0;
        pip2_frac  <= {(pFRAC_WIDTH+1){1'b0}};
        pip2_exp   <= {(pEXP_WIDTH+1){1'b0}};
    end else begin
        pip2_v     <= pip1_v   ;
        pip2_inf   <= pip1_inf ;
        pip2_frac  <= frac_normalized_0 ;
        pip2_exp   <= exp_normalized_0  ;
    end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                     Normalization 1                                                                                   //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign frac_expand       = { pip2_frac , {(pLOD_WIDTH-pFRAC_WIDTH-1){1'b1}} } ;
assign exp_expand        = { 1'b0      , pip2_exp } ;    // * add sign bit
assign shift_expand      = { 1'b0      , shift    } ;    // * add sign bit

assign shift_amount      = ( exp_sub[pEXP_WIDTH+1] )? pip2_exp : shift      ;

assign exp_normalized_1  = ( exp_sub[pEXP_WIDTH+1] )? {(pEXP_WIDTH+1){1'b0}} : exp_sub[(pEXP_WIDTH) : 0] ;
assign frac_normalized_1 = pip2_frac << shift_amount ;

LOD_64 LOD_00    ( .A( frac_expand   ) ,  .position( shift ));
sub_13 sub_13_00 ( .in_A( exp_expand ) ,  .in_B( shift_expand ) , .result( exp_sub )  );

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  Pipeline stage 3                                                                                    //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip3_v     <= 1'b0;
        pip3_inf   <= 1'b0;
        pip3_frac  <= {(pFRAC_WIDTH+1){1'b0}};
        pip3_exp   <= {(pEXP_WIDTH+1 ){1'b0}};
    end else begin
        pip3_v     <= pip2_v   ;
        pip3_inf   <= pip2_inf ;
        pip3_frac  <= frac_normalized_1 ;
        pip3_exp   <= exp_normalized_1  ;
    end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                    Encode into IEEE754                                                                                //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

localparam EXP_INF   = 11'd2047 ;
localparam FRAC_ZERO = 52'd0    ;


always @(*) begin
    if(pip3_exp[pEXP_WIDTH] || pip3_inf || (& pip3_exp[(pEXP_WIDTH-1):0]))begin
        frac_result = FRAC_ZERO ;
    end else if (|pip3_exp)  begin
        frac_result = pip3_frac[(pFRAC_WIDTH-1):0] ;
    end else begin
        frac_result = pip3_frac[(pFRAC_WIDTH) :1]  ;
    end
end

always @(*) begin
    if(pip3_exp[pEXP_WIDTH] || pip3_inf || (& pip3_exp[(pEXP_WIDTH-1):0]))begin
        exp_result = EXP_INF ;
    end else begin
        exp_result = pip3_exp[(pEXP_WIDTH-1):0] ;
    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  Pipeline stage 4                                                                                    //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip4_v     <= 1'b0                  ;
        pip4_frac  <= {(pFRAC_WIDTH){1'b0}} ;
        pip4_exp   <= {(pEXP_WIDTH ){1'b0}} ;
    end else begin
        pip4_v     <= pip3_v      ;
        pip4_frac  <= frac_result ;
        pip4_exp   <= exp_result  ;
    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  Output interface                                                                                    //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign exp_o     = pip4_exp  ;
assign frac_o    = pip4_frac ;
assign out_valid = pip4_v    ;   


endmodule