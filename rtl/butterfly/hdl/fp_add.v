// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : fp_add
// Author : Jesse 、hsuanjung,Lo
// Create Date: 5/2025
// Features & Functions:
// . To do add operation of IEEE754 double precisoin floating point. 
// . 
// ============================================================================================================================================================================
// Revision History:
// Date           by            Version       Change Description
// 2025.5.26    hsuanjung,Lo      2.0         fix rounding bug
// 2025.5.26    hsuanjung,Lo      3.0         fix exponent bug in first normalization
// 2025.6.1     hsuanjung,lo      4.0         change the included module name "LOD" => "LOD_128"
// 2025.6.13    hsuanjung,lo      5.0         solve inf input case and NaN case
// 2025.6.15    hsuanjung,lo      6.0         solve subnormal bias mistake
// 2025.6.19    hsuanjung,lo      7.0         solve the error of fraction in pip4、pip5(modify flip flop width)
// 2025.6.26    hsuanjung,lo      8.0         re-allocate pipeline stage and operator to optomize area and freq(clk period)
// 2025.8.15    hsuanjung,lo      9.0         reduce pipeline to improve area
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//==================================================================================================================================================================================
//
//
//
//  IEEE 754 double precision floating point form(64bit width)
//     1bit     11bit       52bit
//   | sign |  exponent | fraction |  
//
//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// * Asserted in_valid high to feed valid data ,and return valid result with out_valid
//
// * Waveform：    
//      clk       >|      |      |      |      |      |      |      |       |       |
//      in_valid  >________/-------------\______________________________________________ * input valid asserted high for data input
//      in_A      >  XX   |  A1  |  A2  |           - XX -                               * data input(with IEEE754 double precision floating point format )
//      in_B      >  XX   |  B1  |  B2  |           - XX -                               * data input(with IEEE754 double precision floating point format )
//      out_valid >______________________/--------------\_____________________________   * output valid asserted high for data output
//      result    >|         xx         |  r0  |  r1   |             xx             |    *  
//
//===================================================================================================================================================================================


//===================================================================================================================================================================================//
// < First stage >                                                                                                                                                                   //
//                                                                                                                                                                                   //
// * Subnormal case follow IEEE 754 double precision format :                                                                                                                        //
//      1. while exp = 0 , bias must be -1022 (normal case has bias of -1023) , and the hidden bit will be zero .                                                                    //
//          =>  shift the fraction one bit left in exp = 0 case , as followinng structure                                                                                            //
//                                 1bit          52bits                                                                                                                              //
//           normal frac    : |   1(hid)    |   mantissa  |                                                                                                                          //
//                                                                                                                                                                                   //
//                                52bits       1bit                                                                                                                                  //
//           subnormal frac : |  mantissa   |   0   |                                                                                                                                //
//                                                                                                                                                                                   //
//       2. while exp = 2047  with all zero mantissa, the valuse must be infinite  => assert inf_A / inf_B high.                                                                     //
//                                                                                                                                                                                   //
//       3. while exp = 2047 with nonzero mantissa , the operand becomes NaN   =>  assert NaN high .                                                                                 //
//                                                                                                                                                                                   //
//       4. while the both operand are infinite , but they have different sign (one + , one -) , the result must become NaN => assert NaN high .                                     //
//                                                                                                                                                                                   //
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// * In this stage , it also compute the diff of exponent and which operand has larger exponent ( exp_compare ) before alignment .                                                   //
//===================================================================================================================================================================================//

//===================================================================================================================================================================================//
//  < Second stage >                                                                                                                                                                 //
//  * Align the exponent  :                                                                                                                                                          //
//     1. expand the fraction before shift to avoid data loss                                                                                                                        //
//                        53bits          53bits                                                                                                                                     //
//       frac_expand  |  pip1_frac |   0000000...000  |                                                                                                                              //
//                                                                                                                                                                                   //
//     2. shift the expanded fraction to align the exponent diff (shift the fraction that has smaller exponent)                                                                      //
//         exp : exp_A > exp_B , with exp_diff = 3                                                                                                                                   //
//                                                                                                                                                                                   //
//                                        53bits         53bits                                                                                                                      //
//               frac_A_shifted  :  |    fraction   |   0000....00 |                                                                                                                 //
//                                                                                                                                                                                   //
//                                    3bits     53bits     50bits                                                                                                                    //
//               frac_B_shifted  :  |  000  |  fraction  | 00...00 |                                                                                                                 //
//                                                                                                                                                                                   //
//  * operand selsect :                                                                                                                                                              //
//      To reduce the use of adder in next stage , select the operand_1 、 operand_2 , op command , and sign predict predict here.                                                   //
//                                                                                                                                                                                   //
//      sign_ab(sign_A/sign_B) |   0/0   |   0/1   |  1/0  |  1/1  |                                                                                                                 //
//      op(pip1_op_nxt)        |   ADD   |   SUB   |  SUB  |  ADD  |                                                                                                                 //
//      operation(op)          |   A+B   |   A-B   |  B-A  |  A+B  |                                                                                                                 //
//      operand_1              |    A    |    A    |   B   |   A   |                                                                                                                 //
//      operand_2              |    B    |    B    |   A   |   B   |                                                                                                                 //
//      sign predict (op1>op2) |   pos   |   pos   |  pos  |  neg  |                                                                                                                 //
//                                                                                                                                                                                   //
//                                                                                                                                                                                   //
//    => To reduce cost I modify the op to detect only B_sub_A  to swith the operand1、operand2 here                                                                                 //
//                                                                                                                                                                                   //
//      And extract the GRS from operand_2 (these GRS will combine with the operand_2 before add & sub ):                                                                            //
//                                  53bits      1bit      1bit     51bits                                                                                                            //
//                              |  fraction  |  Guard |  Round |   ......  |                                                                                                         //
//                                                              \  sticky  /                                                                                                         //
//      Next stage will only do :                                                                                                                                                    //
//                                operand_1 + operand_2                                                                                                                              //
//                                operand_2 - operand_1   .... then select the result by pip1_op                                                                                     //
//                                                                                                                                                                                   //
//                *** predict the operand_1 is larger than the operand_2 ***                                                                                                         //
//   *** if there is/are inf case , the perdictopn of sign may follow the inf number  **                                                                                             //
//===================================================================================================================================================================================//

//===================================================================================================================================================================================//
// < Third stage >                                                                                                                                                                   //
//   * Do add and sub of fraction , and then select the result fraction by cmd ( pip2_op )                                                                                           //
//   * Before add/sub expand the fraction into 58bit as following structure (1bit sign and 1bit overflow for result ) :                                                              //
//                            2bits    53bits      3bits                                                                                                                             //
//              operand1  : |  00  |  fraction  |   000  |                                                                                                                           //
//              operand2  : |  00  |  fraction  |   GRS  |  (G: Guard , R: Round , S: Sticky)                                                                                        //
//   * As above stage , adjust the sign bit by result of frac after operation .                                                                                                      // 
//   * If sign bit of  operated frac is 1 , and the prediction is positive => negative result 
//
//===================================================================================================================================================================================//

//===================================================================================================================================================================================//
// < Forth stage >                                                                                                                                                                   //
//   * Rounding the operated fraction (pip1_frac) to nearest even with sticky.                                                                                                       //
//   * operated frac has two condition ( overflow / no overflow ) :                                                                                                                  //
//      -----------------------------------------------------------------------------------------------------                                                                        //
//     | if overflow :                                                                                      |                                                                        //
//     |                        |<--- 53bit frac --->|                                                      |                                                                        //   
//     |                           1bit      52bits     1bit       1bit      2bits                          |                                                                        //
//     |           pip1_frac :  |   1     |   FRAC   |  Guard  |  Round  |   Sticky   |                     |                                                                        //
//     |                                                                                                    |                                                                        //
//     |           => exp = exp + 1 ;                                                                       |                                                                        //
//     |----------------------------------------------------------------------------------------------------|                                                                        //
//     | if no overflow :                                                                                   |                                                                        //
//     |                                1bit       |<- 53bits ->|   1bit      1bit        1bit              |                                                                        //
//     |           pip1_frac :  |   0 (don't care) |    FRAC    |  Guard  |   Round   |   Sticky   |        |                                                                        //
//     |----------------------------------------------------------------------------------------------------|                                                                        //
//   * As the conditon of overflow to sel the range of FRAC and GRS                                                                                                                  //
//                                                                                                                                                                                   //
//   * After rounding , if frac_rounded has overflow , shift 1 bit of frac , and then add 1 to exp                                                                                   //
//===================================================================================================================================================================================//

//===================================================================================================================================================================================//
// < Fifth stage >                                                                                                                                                                   //
//   * Normalization :                                                                                                                                                               //
//          1 . expand the rounded frac into the 64bit before feed into LOD_64                                                                                                       //
//                                  53bits      11bits                                                                                                                               //
//              frac_expand :    |   frac   |  0000...00  |                                                                                                                          //
//                                                                                                                                                                                   //
//          2. Detect the leading one position of rounded frac by LOD_64                                                                                                             //
//                                                                                                                                                                                   //
//          3. Shift the fraction and adjust the exponent to follow IEEE754 format                                                                                                   //
//                                                                                                                                                                                   //
//          * Maximum shift is the value of exp.If exceed the maximum value , set exp = 0 and shift the frac as maximum value .                                                      //
//          * After all ,,check the subnormal case :                                                                                                                                 //
//                                   1. if exp = 0 , shift the frac 1bit right (because the zero exp has bias of -1022 )                                                             //
//                                   2. if exp >= 2047 , set the exp=2047 , frac = 0 .(infinite case)                                                                                //
//                                   3. if input A、B has infinte value and the result is exist, set infinite value output                                                           //
//                                   4. if the result is Not A Number , set sign = 0 / exp = 2047 / frac = 1 /                                                                       //
//===================================================================================================================================================================================//

module fp_add#(
    parameter pDATA_WIDTH = 64,
    parameter pEXP_WIDTH  = 11, 
    parameter pFRAC_WIDTH = 52
)
(
    in_A,
    in_B,
    clk,
    rst_n,
    in_valid,
    result,
    out_valid
);
//============================================================================//
input  [(pDATA_WIDTH-1):0]          in_A ;
input  [(pDATA_WIDTH-1):0]          in_B ;
input                               clk  ;
input                               rst_n ;
input                               in_valid ;
output [(pDATA_WIDTH-1):0]          result;
output                              out_valid ;   
//============================================================================//
localparam pLOD_WIDTH   = 64;

//------------- sign detect -----------//
localparam postive   = 0;
localparam negative  = 1;
localparam posA_posB = 2'b00;
localparam negA_negB = 2'b11;
localparam negA_posB = 2'b10;
localparam posA_negB = 2'b01;
//-------- op from pip1 <-> pip2 ------//
localparam ADD       = 1;
localparam SUB       = 0;
//-------- op from pip1 <-> pip2 ------//
localparam OTHERS_OP = 1'b1;
//localparam A_ADD_B   = 2'b00;
//localparam A_SUB_B   = 2'b01;
localparam B_SUB_A   = 1'b0;

//=============================== Decode ======================================//
wire[(pFRAC_WIDTH)  :0]             frac_a        ;
wire[(pFRAC_WIDTH)  :0]             frac_b        ;

wire[(pEXP_WIDTH-1) :0]             exp_a         ;
wire[(pEXP_WIDTH-1) :0]             exp_b         ;
wire[(pEXP_WIDTH)   :0]             exp_A         ;
wire[(pEXP_WIDTH)   :0]             exp_B         ;
wire[(pEXP_WIDTH)   :0]             exp_diff_ab   ;
wire[(pEXP_WIDTH)   :0]             exp_diff_ba   ;
wire[(pEXP_WIDTH-1) :0]             exp_larger    ;
wire[(pEXP_WIDTH-1) :0]             align_amount  ;
wire                                exp_compare   ;
wire                                sign_a;
wire                                sign_b;
wire                                hid_a ;
wire                                hid_b ;
wire                                inf_a ; 
wire                                inf_b ;
wire                                NaN   ;
wire                                mantissa_nonzero_a;
wire                                mantissa_nonzero_b;
//============================= Align exponent ================================//
wire [(pFRAC_WIDTH*2+1) :0]         frac_a_shifted ;
wire [(pFRAC_WIDTH*2+1) :0]         frac_a_expand  ;
wire [(pFRAC_WIDTH*2+1) :0]         frac_b_shifted ;
wire [(pFRAC_WIDTH*2+1) :0]         frac_b_expand  ;
wire [(pFRAC_WIDTH*2+1) :0]         operand_1    ;
wire [(pFRAC_WIDTH*2+1) :0]         operand_2    ;
wire                                inf          ;
wire [1:0]                          sign_ab      ;
wire                                op           ;
wire                                sub_operation ;
reg                                 sign_predict  ;
wire                                operand_1_sticky ;
wire                                operand_2_sticky ;
//============================ frac operation ================================//
wire [(pFRAC_WIDTH+5) :0]           operand1 ;
wire [(pFRAC_WIDTH+5) :0]           operand2 ;
wire [(pFRAC_WIDTH+5) :0]           adder_op1 ;
wire [(pFRAC_WIDTH+5) :0]           adder_op2 ;
wire [(pFRAC_WIDTH+5) :0]           op1_add_op2 ;
wire [(pFRAC_WIDTH+5) :0]           op1_sub_op2 ;
wire [(pFRAC_WIDTH+5) :0]           adder_out   ; 
wire [(pFRAC_WIDTH+5) :0]           frac_result ;
wire [(pFRAC_WIDTH+5) :0]           logic_one ;
wire [(pFRAC_WIDTH+5) :0]           op1_sub_op2_abs ;
wire [(pFRAC_WIDTH+5) :0]           op1_sub_op2_inv ;
wire                                sign_result ;
//=========================== Pipline stage 1 =================================//
reg  [(pEXP_WIDTH-1)  :0]           pip1_exp  ;
reg  [(pFRAC_WIDTH+4) :0]           pip1_frac ;
reg                                 pip1_NaN  ;
reg                                 pip1_inf  ;
reg                                 pip1_sign ;
reg                                 pip1_v    ;
//============================== rounding =====================================//
wire [(pEXP_WIDTH)    :0]           exp_add1 ;
wire [(pEXP_WIDTH)    :0]           exp_add2 ;
wire [(pEXP_WIDTH)    :0]           exp_normal_0 ;
wire [(pFRAC_WIDTH)   :0]           frac     ;
wire [(pFRAC_WIDTH+1) :0]           frac_add ;
wire [(pFRAC_WIDTH+1) :0]           frac_rounded ;
wire [(pEXP_WIDTH-1)  :0]           logic_two ;
wire                                guard_bit  ;
wire                                round_bit  ;
wire                                sticky_bit ;
wire                                lsb        ;
//============================ Normalization ==================================//
wire [(pLOD_WIDTH-1):0]             frac_expand  ;
wire [(pEXP_WIDTH  ):0]             shift        ;
wire [(pEXP_WIDTH  ):0]             shift_amount ;
wire [(pEXP_WIDTH  ):0]             exp_normal_1 ;
wire [(pFRAC_WIDTH ):0]             frac_shifted ;
wire [(pEXP_WIDTH-1) :0]            exp_final    ;
reg  [(pFRAC_WIDTH-1):0]            frac_final   ;
//=========================== Pipline stage 2 =================================//
reg  [(pEXP_WIDTH-1) :0]            pip2_exp  ;
reg  [(pFRAC_WIDTH-1):0]            pip2_frac ;
reg                                 pip2_sign ;
reg                                 pip2_v    ;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  Decode                                                                                 //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign NaN    = (in_A[pDATA_WIDTH-1] != in_B[pDATA_WIDTH-1])? ((inf_a & inf_b) | ( ((inf_a & mantissa_nonzero_a) | (inf_b & mantissa_nonzero_b)) )) : ((inf_a & mantissa_nonzero_a) | (inf_b & mantissa_nonzero_b));
assign sign_a = in_A[pDATA_WIDTH-1];
assign sign_b = in_B[pDATA_WIDTH-1];

assign exp_a  = in_A[(pDATA_WIDTH-2) : pFRAC_WIDTH]; 
assign exp_b  = in_B[(pDATA_WIDTH-2) : pFRAC_WIDTH];

assign hid_a  = |exp_a;
assign hid_b  = |exp_b;

assign inf_a  = &(exp_a);
assign inf_b  = &(exp_b);

assign frac_a = (hid_a)?  {hid_a , in_A[(pFRAC_WIDTH-1) : 0] } : {in_A[(pFRAC_WIDTH-1) : 0] , 1'b0};     //*  expand hidden bit of fraction and shift subnormal case
assign frac_b = (hid_b)?  {hid_b , in_B[(pFRAC_WIDTH-1) : 0] } : {in_B[(pFRAC_WIDTH-1) : 0] , 1'b0};     //*  expand hidden bit of fraction and shift subnormal case

assign mantissa_nonzero_a  = (| (in_A[(pFRAC_WIDTH-1):0]));
assign mantissa_nonzero_b  = (| (in_B[(pFRAC_WIDTH-1):0]));

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                             EXP compare and select                                                                   //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


localparam a_bigger = 1'b1;
localparam b_bigger = 1'b0;

assign exp_A = { 1'b0 , exp_a } ;
assign exp_B = { 1'b0 , exp_b } ; 

sub_12 sub_12_00( .in_A( exp_A ) , .in_B( exp_B ) , .result( exp_diff_ab ));
sub_12 sub_12_01( .in_A( exp_B ) , .in_B( exp_A ) , .result( exp_diff_ba ));
// assign exp_diff_ab     = exp_a - exp_b ;
// assign exp_diff_ba     = exp_b - exp_a ;

// use sign bit to compare the bigger one.
assign align_amount    = ( exp_diff_ba[pEXP_WIDTH] )?   exp_diff_ab[(pEXP_WIDTH-1):0] : exp_diff_ba[(pEXP_WIDTH-1):0] ;
assign exp_larger      = ( exp_diff_ba[pEXP_WIDTH] )?   exp_a                         : exp_b    ;
//assign exp_compare     = ( exp_diff_ba[pEXP_WIDTH] )?   a_bigger                      : b_bigger ;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                 PIPELINE stage 1                                                                     //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// always @(posedge clk or negedge rst_n) begin
//     if(!rst_n)begin
//         pip1_NaN         <= 1'b0 ;
//         pip1_inf_a       <= 1'b0 ;
//         pip1_inf_b       <= 1'b0 ;
//         pip1_sign_a      <= 1'b0 ;
//         pip1_sign_b      <= 1'b0 ;
//         pip1_frac_a      <= {(pFRAC_WIDTH+1){1'b0}} ;
//         pip1_frac_b      <= {(pFRAC_WIDTH+1){1'b0}} ;
//         pip1_exp         <= {(pEXP_WIDTH){1'b0}} ;
//         pip1_shift       <= {(pEXP_WIDTH){1'b0}} ;
//         pip1_exp_compare <= 1'b0 ;
//         pip1_v           <= 1'b0;
//     end else begin
//         pip1_NaN         <= NaN    ;
//         pip1_inf_a       <= inf_a  ;
//         pip1_inf_b       <= inf_b  ; 
//         pip1_sign_a      <= sign_a ;
//         pip1_sign_b      <= sign_b ;
//         pip1_frac_a      <= frac_a ;
//         pip1_frac_b      <= frac_b ;
//         pip1_exp         <= pip1_exp_nxt  ;
//         pip1_shift       <= pip1_shift_nxt;
//         pip1_exp_compare <= exp_compare ;
//         pip1_v           <= in_valid;
//     end
// end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                          Align fraction before add & sub                                                            //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign sign_ab          = {sign_a , sign_b};
assign frac_a_expand    = {frac_a , {(pFRAC_WIDTH+1){1'b0}}};
assign frac_b_expand    = {frac_b , {(pFRAC_WIDTH+1){1'b0}}};
assign frac_a_shifted   = (exp_diff_ba[pEXP_WIDTH])?  frac_a_expand : (frac_a_expand >> align_amount); 
assign frac_b_shifted   = (exp_diff_ba[pEXP_WIDTH])?  (frac_b_expand >> align_amount) : frac_b_expand ;


assign operand_1        = (op == B_SUB_A)?  frac_b_shifted : frac_a_shifted ;
assign operand_2        = (op == B_SUB_A)?  frac_a_shifted : frac_b_shifted ;
assign operand_1_sticky = |(operand_1[(pFRAC_WIDTH-2) : 0]);
assign operand_2_sticky = |(operand_2[(pFRAC_WIDTH-2) : 0]);
assign inf              = inf_a | inf_b ;
assign op               = (sign_ab == negA_posB)?  B_SUB_A : OTHERS_OP ;

// always @(*) begin
//     case(sign_ab)
//         posA_posB : op =  A_ADD_B ;
//         negA_negB : op =  A_ADD_B ;
//         negA_posB : op =  B_SUB_A ;
//         posA_negB : op =  A_SUB_B ;
//     endcase
// end

always @(*) begin
    case(sign_ab)
        posA_posB : sign_predict =  postive ;
        negA_negB : sign_predict =  negative ;
        negA_posB : sign_predict =  (inf_a)? negative : postive ;
        posA_negB : sign_predict =  (inf_b)? negative : postive ;
    endcase
end

// always @(*) begin
//     case(sign_ab)
//         posA_posB : op_nxt =  ADD ;
//         negA_negB : op_nxt =  ADD ;
//         negA_posB : op_nxt =  SUB ;
//         posA_negB : op_nxt =  SUB ;
//     endcase
// end

assign sub_operation = (sign_a ^ sign_b); 

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                 PIPELINE stage 2                                                                     //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// always @(posedge clk or negedge rst_n) begin
//     if(!rst_n)begin
//         pip2_NaN         <= 1'b0 ;
//         pip2_inf         <= 1'b0 ;
//         pip2_sign        <= 1'b0 ;
//         pip2_op          <= 1'b0 ;

//         pip2_operand_1   <= {(pFRAC_WIDTH+1){1'b0}} ;
//         pip2_operand_2   <= {(pFRAC_WIDTH+1){1'b0}} ;
//         pip2_exp         <= {(pEXP_WIDTH){1'b0}} ;
        
//         pip2_guard1      <= 1'b0 ;
//         pip2_round1      <= 1'b0 ;
//         pip2_sticky1     <= 1'b0 ;

//         pip2_guard2      <= 1'b0 ;
//         pip2_round2      <= 1'b0 ;
//         pip2_sticky2     <= 1'b0 ;
        
//         pip2_v           <= 1'b0 ;
//     end else begin
//         pip2_NaN         <= pip1_NaN  ;
//         pip2_inf         <= inf  ;
//         pip2_sign        <= sign_predict ;
//         pip2_op          <= pip2_op_nxt  ;

//         pip2_operand_1   <= operand_1[(pFRAC_WIDTH*2+1):(pFRAC_WIDTH+1)] ;
//         pip2_operand_2   <= operand_2[(pFRAC_WIDTH*2+1):(pFRAC_WIDTH+1)] ;
        
//         pip2_guard1      <= operand_1[pFRAC_WIDTH]   ;
//         pip2_round1      <= operand_1[pFRAC_WIDTH-1] ;
//         pip2_sticky1     <= operand_1_sticky         ;

//         pip2_guard2      <= operand_2[pFRAC_WIDTH]   ;
//         pip2_round2      <= operand_2[pFRAC_WIDTH-1] ;
//         pip2_sticky2     <= operand_2_sticky         ;

//         pip2_exp         <= pip1_exp  ;

//         pip2_v           <= pip1_v;
//     end
// end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                           fraction operation                                                                            //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign logic_one       = {{(pFRAC_WIDTH+5){1'b0}} , 1'b1}   ;
assign operand1        = { 2'b00 , operand_1[(pFRAC_WIDTH*2+1):(pFRAC_WIDTH+1)] , operand_1[pFRAC_WIDTH] , operand_1[pFRAC_WIDTH-1] , operand_1_sticky };
assign operand2        = { 2'b00 , operand_2[(pFRAC_WIDTH*2+1):(pFRAC_WIDTH+1)] , operand_2[pFRAC_WIDTH] , operand_2[pFRAC_WIDTH-1] , operand_2_sticky};

assign op1_sub_op2_inv = ~op1_sub_op2 ;

assign frac_result     = (sub_operation)?    ((op1_sub_op2[pFRAC_WIDTH+5])?  op1_sub_op2_abs : op1_sub_op2) : op1_add_op2  ;
assign sign_result     = (inf )?         sign_predict   : ((sub_operation)?   ( sign_predict ^ op1_sub_op2[pFRAC_WIDTH+5] ) :  sign_predict ) ;

assign adder_op1        = (sub_operation)?    op1_sub_op2_inv : operand1 ;
assign adder_op2        = (sub_operation)?    logic_one : operand2   ;

assign op1_add_op2      = adder_out ;
assign op1_sub_op2_abs  = adder_out ;

add_58 add_58_00 (.in_A( adder_op1       ), .in_B( adder_op2  ), .result( adder_out       ));
sub_58 sub_58_00 (.in_A( operand1        ), .in_B( operand2   ), .result( op1_sub_op2     ));
// add_58 add_58_01 (.in_A( op1_sub_op2_inv ), .in_B( logic_one  ), .result( op1_sub_op2_abs ));

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                              PIPELINE stage 3                                                                          //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip1_NaN         <= 1'b0 ;
        pip1_inf         <= 1'b0 ;
        pip1_sign        <= 1'b0 ;
        pip1_exp         <= {(pEXP_WIDTH){1'b0}} ;
        pip1_frac        <= {(pFRAC_WIDTH+5){1'b0}};
        pip1_v           <= 1'b0 ;
    end else begin
        pip1_NaN         <= NaN  ;
        pip1_inf         <= inf  ;
        pip1_sign        <= sign_result ;
        pip1_exp         <= exp_larger  ;
        pip1_frac        <= frac_result[(pFRAC_WIDTH+4):0] ;
        pip1_v           <= in_valid ;
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                               ROUNDING                                                                                  //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



assign logic_two    = { {(pEXP_WIDTH-2){1'b0}}  , 2'b10 } ;


assign exp_normal_0 = ( pip1_frac[pFRAC_WIDTH+4] )? ((frac_rounded[pFRAC_WIDTH+1])?  exp_add2 : exp_add1 ) : ((frac_rounded[pFRAC_WIDTH+1])? exp_add1 : ({1'b0 , pip1_exp }));
assign lsb          = ( pip1_frac[pFRAC_WIDTH+4] )? pip1_frac[4]      : pip1_frac[3] ;
assign guard_bit    = ( pip1_frac[pFRAC_WIDTH+4] )? pip1_frac[3]      : pip1_frac[2] ;
assign round_bit    = ( pip1_frac[pFRAC_WIDTH+4] )? pip1_frac[2]      : pip1_frac[1] ;
assign sticky_bit   = ( pip1_frac[pFRAC_WIDTH+4] )? |(pip1_frac[1:0]) : pip1_frac[0] ;
assign frac         = ( pip1_frac[pFRAC_WIDTH+4] )? pip1_frac[(pFRAC_WIDTH+4):4] : pip1_frac[(pFRAC_WIDTH+3):3];
assign frac_rounded = ( guard_bit && (round_bit | lsb | sticky_bit) )?  frac_add : {1'b0 , frac} ;

add_11_overflow add_11_00( .in_A( pip1_exp ) , .in_B( logic_one[(pEXP_WIDTH-1):0] ) , .result( exp_add1  ));
add_11_overflow add_11_01( .in_A( pip1_exp ) , .in_B( logic_two[(pEXP_WIDTH-1):0] ) , .result( exp_add2  ));

add_53_overflow add_53_02( .in_A( frac )     , .in_B( logic_one[(pFRAC_WIDTH):0]  ) , .result( frac_add ));


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                               Normalization                                                                             //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
localparam EXP_MAX      = 11'd2047 ;
localparam EXP_MIN      = 11'd0    ;
localparam FRAC_ZERO    = 52'd0    ;
localparam FRAC_ONE     = 52'd1    ;

wire [pFRAC_WIDTH:0] frac_rounded_unnorm ;

assign frac_rounded_unnorm = (frac_rounded[pFRAC_WIDTH+1])? frac_rounded[(pFRAC_WIDTH+1):1] : frac_rounded [pFRAC_WIDTH:0] ;

assign frac_expand   = {frac_rounded_unnorm , {(pLOD_WIDTH-pFRAC_WIDTH-1){1'b0}}};

assign frac_shifted  =  frac_rounded_unnorm << shift_amount;

assign shift_amount  = (shift > exp_normal_0)?      exp_normal_0 : shift ;
assign exp_normal_1  = ((shift > exp_normal_0)||(~(|frac_rounded_unnorm)))?  {(pEXP_WIDTH+1){1'b0}} : (exp_normal_0 - shift);  

assign exp_final     = (pip1_inf || pip1_NaN)?  EXP_MAX :(( exp_normal_1[pEXP_WIDTH] )?  EXP_MAX  : exp_normal_1[(pEXP_WIDTH-1) : 0]) ;

always @(*) begin
    if(pip1_NaN)begin
        frac_final = FRAC_ONE ;
    end else if ( pip1_inf )begin
        frac_final = FRAC_ZERO ;
    end else if ( exp_normal_1[pEXP_WIDTH] )begin
        frac_final = FRAC_ZERO ;
    end else if ( &(exp_normal_1[(pEXP_WIDTH-1):0])  )begin
        frac_final = FRAC_ZERO ;
    end else if ( |(exp_normal_1[(pEXP_WIDTH)  :0]) )begin
        frac_final = frac_shifted[(pFRAC_WIDTH-1) :0];
    end else begin
        frac_final = frac_shifted[(pFRAC_WIDTH)   :1];
    end
end            


LOD_64 LOD_02  ( .A(frac_expand) , .position(shift));



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                              PIPELINE stage 5                                                                          //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire sign_final ;

assign sign_final = ((~(| exp_final)) && (~(| frac_final)))?  1'b0 : ((pip1_NaN)? 1'b0 : pip1_sign ) ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip2_sign        <= 1'b0 ;
        pip2_exp         <= {(pEXP_WIDTH){1'b0}} ;
        pip2_frac        <= {(pFRAC_WIDTH){1'b0}};
        pip2_v           <= 1'b0 ;
    end else begin
        pip2_sign        <= sign_final ;
        pip2_exp         <= exp_final  ;
        pip2_frac        <= frac_final ;
        pip2_v           <= pip1_v     ;
    end
end

assign out_valid  = pip2_v ;
assign result     = { pip2_sign , pip2_exp , pip2_frac};

endmodule




