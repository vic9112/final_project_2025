
// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : mul
// Author : Hsuan Jung,Lo Jesse
// Create Date: 6/2025
// Features & Functions:
// . To do mul operation (can do complex multiplication and montgomery multiplication)
// .
// ============================================================================================================================================================================
// Revision History:
// Date         by      Version     Change Description
//  
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//==============================================================================================================================================================================
// 
//  * As IEEE754 format , we set NaN(not a number) = 64'h7FF0_0000_0000_0000 
//  *  + /- Inf case = 64'7FFF0_0000_0000_0000 / 64'hFFF0_0000_0000_0000  
//
//  * To make sure the FIFO of system , you need to wait 18 cycles to feed int data after last of fp data .
//  * After last int data feed , you need to wait 4 cycles to feed fp data immediately.
//
//  * Waveform：    
//                        wait 18 cycles                        wait 4 cycles   
//                    |<--------------------->|                 |<--------->|  
//      clk       >|  |  |  |  |  | .....  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  
//      in_valid  >----\_______________________/-----------------\___________/------------\________  * input valid asserted high for data input
//      mode      >____________________________/-----------------\_________________________________  * mode 0 for complex mul 、mode 1 for int mul.
//      out_valid >_______/--------------------\___________/---------------\_______________________  * 22 cycles to do cmul 、 4cycle to do int mul.
//      
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
//  * While doing int mul , result structure :
//
//     input : in_A = { a7 , a6 , a5 , a4 , a3 , a2 , a1 , a0 };
//     input : in_B = { b7 , b6 , b5 , b4 , b3 , b2 , b1 , b0 };
//
//     ==> result_int : { a7*b7 , a6*b6 , a5*b5 , a4*b4 , a3*b3 , a2*b2 , a1*b1 , a0*b0 };
//
//  *while doing complex mul , result structure :
//     
//     input : in_A = { a_re , a_im };
//     input : in_B = { b_re , b_im };
//
//     ==> result_c = { (a_re * b_re) - (a_im * b_im)  ,  (a_re * b_im) + (a_im * b_re) } ;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- 
module mul #(
    parameter pDATA_WIDTH = 128 
) (
    input [(pDATA_WIDTH-1) : 0]     in_A,
    input [(pDATA_WIDTH-1) : 0]     in_B,
    input [1:0]                     mode, 
    input                           clk ,
    input                           rst_n,
    input                           in_valid,
    output[(pDATA_WIDTH-1)  :0]     result_c,  
    output[(pDATA_WIDTH-1)  :0]   result_int,
    output                          out_valid
);
localparam NaN_num              = 64'h7FF0_0000_0000_0001;
//---------------------------------------------------------------------------------------------------------------------//
localparam pFP_WIDTH            = 64 ;
localparam pMANTISSA_WIDTH      = 52 ;
localparam pEXP_WIDTH           = 11 ;

localparam pNTT_WIDTH           = 16 ;
localparam pWALLACE_WIDTH       = 131;
//--------------------------------------------------------------------------------------------------------------------//
localparam pROUNDER_FRAC_WIDTH  = 106 ;
localparam pROUNDER_EXP_WIDTH   = 13  ;
//--------------------------------------- LATENCY OF STAGE -----------------------------------------------------------//

localparam CMUL_LATENCY         = 22;  //
localparam FP_ADD_LATENCY       = 5 ;  // * Latency of fp_add
localparam MUL16_ARRAY_LATENCY  = 4 ;  // * Latency of mul_16 array
localparam WALLACE_LATENCY      = 3 ;  // * Latency of wallace tree
localparam EXP_OP_LATENCY       = 7 ;
localparam ROUNDER_LATENCY      = 3 ;  // * Latency of rounder
localparam MOD_LATENCY          = 9 ;  // * Latency of mod operation(NTT)
localparam CLA_ADD_LATENCY       = 2 ;  // * Latency of CLA
//--------------------------------------------------------------------------------------------------------------------//
localparam Q01 = 16'h2FFF;
localparam Q = 16'h3001;
localparam Qn = 17'h1CFFF;              // * negative Q
//=====================================================================================================================//

//---------------------------------------- fp_add(first) operand -------------------------------------------------------//
// * input of fp_add
wire [(pFP_WIDTH-1) : 0]            a_re     ;
wire [(pFP_WIDTH-1) : 0]            a_im     ;
wire [(pFP_WIDTH-1) : 0]            b_re     ;
wire [(pFP_WIDTH-1) : 0]            b_im     ;
wire [(pFP_WIDTH-1) : 0]            a_im_neg ;
wire [(pFP_WIDTH-1) : 0]            b_im_neg ;
// * result of fp_add
wire [(pFP_WIDTH-1) : 0]            ar_sub_ai    ;
wire [(pFP_WIDTH-1) : 0]            br_add_bi    ;
wire [(pFP_WIDTH-1) : 0]            br_sub_bi    ;
wire [2             : 0]            fp_add_ready ;
// * other operand (store in shift reg)
reg  [(pDATA_WIDTH-1): 0]           a_reg           [0:(FP_ADD_LATENCY-1)];
reg  [(pFP_WIDTH-1)  : 0]           b_im_reg        [0:(FP_ADD_LATENCY-1)];
wire [(pFP_WIDTH-1)  : 0]           a_re_r;
wire [(pFP_WIDTH-1)  : 0]           a_im_r;
wire [(pFP_WIDTH-1)  : 0]           b_im_r;
//---------------------------------------- fmul_exp  ---------------------------------------------------------------------//
wire [(pEXP_WIDTH-1):0]             exp_A0;
wire [(pEXP_WIDTH-1):0]             exp_A1;
wire [(pEXP_WIDTH-1):0]             exp_B0;
wire [(pEXP_WIDTH-1):0]             exp_B1;
wire [(pEXP_WIDTH-1):0]             exp_C0;
wire [(pEXP_WIDTH-1):0]             exp_C1;
// * exp operator output
wire [(pROUNDER_EXP_WIDTH-1):0]     exp_A_out;
wire [(pROUNDER_EXP_WIDTH-1):0]     exp_B_out;
wire [(pROUNDER_EXP_WIDTH-1):0]     exp_C_out;
wire                                inf_A ;
wire                                inf_B ;
wire                                inf_C ;
wire                                exp_ready_A;
wire                                exp_ready_B;
wire                                exp_ready_C;
// * Other fp operand
wire                                sign_A ;
wire                                sign_B ;
wire                                sign_C ;
wire                                NaN_a;
wire                                NaN_b;
wire                                NaN_c;
reg                                 NaN_a_reg  [0 :(EXP_OP_LATENCY + ROUNDER_LATENCY-1)];
reg                                 NaN_b_reg  [0 :(EXP_OP_LATENCY + ROUNDER_LATENCY-1)];
reg                                 NaN_c_reg  [0 :(EXP_OP_LATENCY + ROUNDER_LATENCY-1)];
reg                                 sign_A_reg [0 :(EXP_OP_LATENCY + ROUNDER_LATENCY-1)];
reg                                 sign_B_reg [0 :(EXP_OP_LATENCY + ROUNDER_LATENCY-1)];
reg                                 sign_C_reg [0 :(EXP_OP_LATENCY + ROUNDER_LATENCY-1)];

//---------------------------------------- mul_16 array  ---------------------------------------------------------------//

wire[2:0]                           array_in_valid   ;
wire[2:0]                           array_out_valid  ;
// * hidden bit of fp_mul operand
wire                                hidden_br_add_bi ;
wire                                hidden_a_im      ;
wire                                hidden_ar_sub_ai ;
wire                                hidden_b_im ;
wire                                hidden_br_sub_bi ;
wire                                hidden_a_re      ;
// * mul_16 array input data ( A、 B 、 C array)
wire [(pFP_WIDTH-1)  : 0]           array_in_A0      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_A1      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_A2      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_B0      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_B1      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_C0      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_C1      ;
wire [(pNTT_WIDTH*4-1):0]           array_in_ntt1    ;
wire [(pNTT_WIDTH*4-1):0]           array_in_ntt2    ;

// * mul_16 array output result (A、 B 、 C array)
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a0[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a1[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a2[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a3[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b0[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b1[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b2[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b3[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c0[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c1[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c2[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c3[0:3];
reg  [(pNTT_WIDTH*16-1):0]          mul_16_reg[0 : (MOD_LATENCY-1)];
//--------------------------------------------- Wallace tree ------------------------------------------------------------//
wire                                wallace_mode;
wire [2:0]                          wallace_out_valid;
wire [(pWALLACE_WIDTH-1):0]         wallace_in;
// * wallace tree output result(A 、 B 、 C tree)
wire [(pWALLACE_WIDTH-1):0]         wallace_out_A;
wire [(pWALLACE_WIDTH-1):0]         wallace_out_B;
wire [(pWALLACE_WIDTH-1):0]         wallace_out_C;
//--------------------------------------- fraction rounder --------------------------------------------------------------//
wire [(pROUNDER_FRAC_WIDTH-1):0]    frac_A_i;
wire [(pROUNDER_FRAC_WIDTH-1):0]    frac_B_i;
wire [(pROUNDER_FRAC_WIDTH-1):0]    frac_C_i;
wire [(pMANTISSA_WIDTH-1):0]        frac_A_rounded;
wire [(pMANTISSA_WIDTH-1):0]        frac_B_rounded;
wire [(pMANTISSA_WIDTH-1):0]        frac_C_rounded;
wire [(pEXP_WIDTH-1):0]             exp_A_rounded;
wire [(pEXP_WIDTH-1):0]             exp_B_rounded;
wire [(pEXP_WIDTH-1):0]             exp_C_rounded;
wire                                rounder_ready_A;
wire                                rounder_ready_B;
wire                                rounder_ready_C;
//-------------------------------------- fp_add second (complex mul result) ---------------------------------------------//
wire [(pFP_WIDTH-1):0]              FP_num_A;
wire [(pFP_WIDTH-1):0]              FP_num_B;
wire [(pFP_WIDTH-1):0]              FP_num_c;
wire [(pFP_WIDTH-1):0]              y_re;
wire [(pFP_WIDTH-1):0]              y_im;
wire                                cmul_im_ready;
wire                                cmul_re_ready;
//-------------------------------------- mod (montgomery mul result) ---------------------------------------------//
wire [7:0]                          mont_add_valid;
wire [(pNTT_WIDTH*2+1):0]           mont_add_result[7:0];
wire [(pNTT_WIDTH-1):0]             mont_R_result[7:0];
wire [7:0]                          mont_n_valid;
wire [(pNTT_WIDTH+1):0]             mont_n_result[7:0];   // * bit17: carry bit16: sign, bit15~0: sum
reg  [(pNTT_WIDTH*8-1):0]           mont_add_reg[1:0];
wire [(pNTT_WIDTH-1):0]             result_int1;
wire [(pNTT_WIDTH-1):0]             result_int2;
wire [(pNTT_WIDTH-1):0]             result_int3;
wire [(pNTT_WIDTH-1):0]             result_int4;
wire [(pNTT_WIDTH-1):0]             result_int5;
wire [(pNTT_WIDTH-1):0]             result_int6;
wire [(pNTT_WIDTH-1):0]             result_int7;
wire [(pNTT_WIDTH-1):0]             result_int8;
wire [(pNTT_WIDTH):0]               mont_cla_in[7:0];
//======================================================================================================================//
localparam C_MUL   = 1'b0;
localparam INT_MUL = 1'b1;
localparam mode_iNTT       = 2'b11;
localparam mode_NTT        = 2'b10;
localparam mode_iFFT       = 2'b01;
localparam mode_FFT        = 2'b00;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                              FSM                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////


assign cmul_valid = (in_valid)?   ((mode[1] == C_MUL)? 1'b1 : 1'b0 ) : 1'b0;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                     floating point adder lv1                                              //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//----------------------------------------------------------------------------------------------------------//
// * In fp_add stage , we do following operation :                                                          //
//           1 .br_add_bi = (b_re + b_im)                                                                   //
//           2. ar_sub_ai = (a_re - a_im)                                                                   //
//           3. br_sub_bi = (b_re - b_im)                                                                   //
//                                                                                                          //
// * Because in next operation(mul) we need a_re 、 a_im 、 b_im .So  we store a_re 、 a_im 、b_im in shift  //
//   reg to store these data while fp_add is running.                                                       //                                                                                         //
//----------------------------------------------------------------------------------------------------------//

assign a_re       = in_A[(pDATA_WIDTH-1) : pFP_WIDTH];
assign a_im       = in_A[(pFP_WIDTH  -1) : 0];

assign b_re       = in_B[(pDATA_WIDTH-1) : pFP_WIDTH];
assign b_im       = in_B[(pFP_WIDTH  -1) : 0];

assign a_im_neg   = { ~in_A[pFP_WIDTH-1] , in_A[(pFP_WIDTH-2) : 0]};  // * inv the sign bit of a_im ( -a_im ).
assign b_im_neg   = { ~in_B[pFP_WIDTH-1] , in_B[(pFP_WIDTH-2) : 0]};  // * inv the sign bit of b_re ( -b_re ).



fp_add   fp_add_01( .in_A( b_re ) , .in_B( b_im )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( cmul_valid )  , .result( br_add_bi ) , .out_valid( fp_add_ready[0] ));
fp_add   fp_add_02( .in_A( a_re ) , .in_B( a_im_neg ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( cmul_valid )  , .result( ar_sub_ai ) , .out_valid( fp_add_ready[1] ));
fp_add   fp_add_03( .in_A( b_re ) , .in_B( b_im_neg ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( cmul_valid )  , .result( br_sub_bi ) , .out_valid( fp_add_ready[2] ));


integer i ;

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(i=0 ; i< FP_ADD_LATENCY ; i=i+1)begin        
            a_reg   [i]         <= {(pDATA_WIDTH){1'b0}} ;
            b_im_reg[i]         <= {(pFP_WIDTH){1'b0}}   ;
        end
    end else begin
        a_reg   [0]         <= in_A  ;
        b_im_reg[0]         <= b_im  ;
        for(i=1 ; i< FP_ADD_LATENCY ; i=i+1)begin        
            a_reg   [i]         <= a_reg   [i-1] ;
            b_im_reg[i]         <= b_im_reg[i-1] ;
        end

    end
end

// * specify a_re 、 a_im 、 b_re 、 b_im from last reg of a_reg、 b_reg
assign a_re_r = a_reg   [FP_ADD_LATENCY-1][(pFP_WIDTH*2-1) : pFP_WIDTH];
assign a_im_r = a_reg   [FP_ADD_LATENCY-1][(pFP_WIDTH-1)   : 0];
assign b_im_r = b_im_reg[FP_ADD_LATENCY-1][(pFP_WIDTH-1)   : 0];


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                           mul_16_array for both fp mul and int  mul                                      //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

//-----------------------------------------------------------------------------------------------------------//      
// * Use leading bit of mode to analyze operation type .                                                     //
//   If leading is "1" , we do FFT floating point operate.                                                   //
//   If leading is "0" , we do NTT integer operate.                                                          //
//                                                                                                           //
// * While doing FFT operation we feed data type { 11 , hidden_bit , mantissa} into mul_16 array.            //
//   (As IEEE 754 format : If exponent all zero ,hidden_bit will be 0 . Others will be 1 ).                  //
//                                                                                                           //
// * While doing NTT operation we feed data typr {a3 , a2 , a1 , a0} into mul_16 array.                      //
//-----------------------------------------------------------------------------------------------------------//





assign array_in_valid[0]  = (mode[1] == INT_MUL)? array_out_valid[1] : fp_add_ready[0]  ;
assign array_in_valid[1]  = (mode[1] == INT_MUL)? in_valid : fp_add_ready[1]  ;
assign array_in_valid[2]  = (mode[1] == INT_MUL)? in_valid : fp_add_ready[2]  ;

assign hidden_br_add_bi  = |(br_add_bi [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]) ;
assign hidden_a_im       = |(a_im_r    [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]); 
assign hidden_ar_sub_ai  = |(ar_sub_ai [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);
assign hidden_b_im       = |(b_im_r    [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);
assign hidden_br_sub_bi  = |(br_sub_bi [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);
assign hidden_a_re       = |(a_re_r    [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);       


//{mul_16_result_c3[3]  , mul_16_result_c2[2] ,  mul_16_result_c1[1] , mul_16_result_c0[0] , mul_16_result_b3[3] , mul_16_result_b2[2] , mul_16_result_b1[1] , mul_16_result_b0[0]};
assign array_in_ntt1     = {mul_16_result_b3[3][(pNTT_WIDTH-1):0] , mul_16_result_b2[2][(pNTT_WIDTH-1):0] , mul_16_result_b1[1][(pNTT_WIDTH-1):0] , mul_16_result_b0[0][(pNTT_WIDTH-1):0]};
assign array_in_ntt2     = {mul_16_result_c3[3][(pNTT_WIDTH-1):0] , mul_16_result_c2[2][(pNTT_WIDTH-1):0] , mul_16_result_c1[1][(pNTT_WIDTH-1):0] , mul_16_result_c0[0][(pNTT_WIDTH-1):0]};

assign array_in_A0       = {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_br_add_bi , br_add_bi [(pMANTISSA_WIDTH-1):0]} ;
assign array_in_A1       = (mode[1] == INT_MUL )? array_in_ntt1 : {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_a_im      , a_im_r    [(pMANTISSA_WIDTH-1):0]};
assign array_in_A2       = (mode[1] == INT_MUL )? array_in_ntt2 : {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_a_im      , a_im_r    [(pMANTISSA_WIDTH-1):0]};
assign array_in_B0       = (mode[1] == C_MUL )? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_ar_sub_ai , ar_sub_ai [(pMANTISSA_WIDTH-1):0]} : in_A[(pFP_WIDTH-1):0];                
assign array_in_B1       = (mode[1] == C_MUL )? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_b_im      , b_im_r    [(pMANTISSA_WIDTH-1):0]} : in_B[(pFP_WIDTH-1):0];                   
assign array_in_C0       = (mode[1] == C_MUL )? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_br_sub_bi , br_sub_bi [(pMANTISSA_WIDTH-1):0]} : in_A[(pDATA_WIDTH-1):pFP_WIDTH];
assign array_in_C1       = (mode[1] == C_MUL )? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_a_re      , a_re_r    [(pMANTISSA_WIDTH-1):0]} : in_B[(pDATA_WIDTH-1):pFP_WIDTH];
 

mul16_array_ntt mul16_array_a(
    //-------- input of mul_16_array(64bit data width)
    .in_A( array_in_A0 ),  .in_B0( array_in_A1 ),  .in_B1( array_in_A2 ),  .clk( clk ),  .rst_n( rst_n ),  .mode( mode[1] ),  .in_valid( array_in_valid[0] ),  .out_valid( array_out_valid[0] ),
    //-------- result from mul_16 ---------//
    .result_00( mul_16_result_a0[0] ) , .result_01( mul_16_result_a0[1] ) , .result_02( mul_16_result_a0[2] ) , .result_03( mul_16_result_a0[3] ), 
    .result_10( mul_16_result_a1[0] ) , .result_11( mul_16_result_a1[1] ) , .result_12( mul_16_result_a1[2] ) , .result_13( mul_16_result_a1[3] ),
    .result_20( mul_16_result_a2[0] ) , .result_21( mul_16_result_a2[1] ) , .result_22( mul_16_result_a2[2] ) , .result_23( mul_16_result_a2[3] ),
    .result_30( mul_16_result_a3[0] ) , .result_31( mul_16_result_a3[1] ) , .result_32( mul_16_result_a3[2] ) , .result_33( mul_16_result_a3[3] ));
    //-------- catch row 2 and row 3 32bit output for NTT --------//
    //row 2 output: result32(mul_16_result_a3[2]), result22(mul_16_result_a2[2]), result12(mul_16_result_a1[2]), result02(mul_16_result_a0[2])
    //row 3 output: result33(mul_16_result_a3[3]), result23(mul_16_result_a2[3]), result13(mul_16_result_a1[3]), result03(mul_16_result_a0[3])

mul16_array mul16_array_b(
    .in_A( array_in_B0 ),  .in_B( array_in_B1 ),  .clk( clk ),  .rst_n( rst_n ),  .in_valid( array_in_valid[1] ),  .out_valid( array_out_valid[1] ),
    .result_00( mul_16_result_b0[0] ) , .result_01( mul_16_result_b0[1] ) , .result_02( mul_16_result_b0[2] ) , .result_03( mul_16_result_b0[3] ), 
    .result_10( mul_16_result_b1[0] ) , .result_11( mul_16_result_b1[1] ) , .result_12( mul_16_result_b1[2] ) , .result_13( mul_16_result_b1[3] ),
    .result_20( mul_16_result_b2[0] ) , .result_21( mul_16_result_b2[1] ) , .result_22( mul_16_result_b2[2] ) , .result_23( mul_16_result_b2[3] ),
    .result_30( mul_16_result_b3[0] ) , .result_31( mul_16_result_b3[1] ) , .result_32( mul_16_result_b3[2] ) , .result_33( mul_16_result_b3[3] )
);

mul16_array mul16_array_c(
    .in_A( array_in_C0 ),  .in_B( array_in_C1 ),  .clk( clk ),  .rst_n( rst_n ),  .in_valid( array_in_valid[2] ),  .out_valid( array_out_valid[2] ),
    .result_00( mul_16_result_c0[0] ) , .result_01( mul_16_result_c0[1] ) , .result_02( mul_16_result_c0[2] ) , .result_03( mul_16_result_c0[3] ), 
    .result_10( mul_16_result_c1[0] ) , .result_11( mul_16_result_c1[1] ) , .result_12( mul_16_result_c1[2] ) , .result_13( mul_16_result_c1[3] ),
    .result_20( mul_16_result_c2[0] ) , .result_21( mul_16_result_c2[1] ) , .result_22( mul_16_result_c2[2] ) , .result_23( mul_16_result_c2[3] ),
    .result_30( mul_16_result_c3[0] ) , .result_31( mul_16_result_c3[1] ) , .result_32( mul_16_result_c3[2] ) , .result_33( mul_16_result_c3[3] )
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i<MOD_LATENCY; i=i+1) begin
            mul_16_reg[i] <= {(pNTT_WIDTH*16){1'b0}};
        end
    end else begin
        mul_16_reg[0] <= {mul_16_result_c3[3]  , mul_16_result_c2[2] ,  mul_16_result_c1[1] , mul_16_result_c0[0] , mul_16_result_b3[3] , mul_16_result_b2[2] , mul_16_result_b1[1] , mul_16_result_b0[0]};
        for (i = 1; i<MOD_LATENCY; i=i+1) begin
          mul_16_reg[i] <= mul_16_reg[i-1];
        end
    end
end
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                         mantissa mul operator   (Wallace tree for fp_mul out mantissa)                   //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign wallace_mode = 1'b0;
assign wallace_in   = {(pWALLACE_WIDTH){1'b0}};

wallace_131 Wallace_tree_a(
    .clk( clk )                           , .rst_n( rst_n )                       , .mode( wallace_mode ) ,     // * mode 0 for partial product adder , mode 1 for long operand adder
    .in_valid( array_out_valid[0] )       , .out_valid( wallace_out_valid[0]  )   , .result( wallace_out_A ),  
//----------------------------- data input of mul operation(from mul_16_array) -----------------------------------------//
    .mul_result_00( mul_16_result_a0[0] ) , .mul_result_01( mul_16_result_a0[1] ) , .mul_result_02( mul_16_result_a0[2] ) , .mul_result_03( mul_16_result_a0[3] ) ,    
    .mul_result_10( mul_16_result_a1[0] ) , .mul_result_11( mul_16_result_a1[1] ) , .mul_result_12( mul_16_result_a1[2] ) , .mul_result_13( mul_16_result_a1[3] ) ,    
    .mul_result_20( mul_16_result_a2[0] ) , .mul_result_21( mul_16_result_a2[1] ) , .mul_result_22( mul_16_result_a2[2] ) , .mul_result_23( mul_16_result_a2[3] ) ,
    .mul_result_30( mul_16_result_a3[0] ) , .mul_result_31( mul_16_result_a3[1] ) , .mul_result_32( mul_16_result_a3[2] ) , .mul_result_33( mul_16_result_a3[3] ) ,  
//------------------------------ data input of add operation(131bit add) -----------------------------------------------//
    .in_A( wallace_in )                  , .in_B( wallace_in )           
);

wallace_131 Wallace_tree_b(
    .clk( clk )                           , .rst_n( rst_n )                       , .mode( wallace_mode ) ,     
    .in_valid( array_out_valid[1] )       , .out_valid( wallace_out_valid[1] )    , .result( wallace_out_B ),  
    .mul_result_00( mul_16_result_b0[0] ) , .mul_result_01( mul_16_result_b0[1] ) , .mul_result_02( mul_16_result_b0[2] ) , .mul_result_03( mul_16_result_b0[3] ) ,    
    .mul_result_10( mul_16_result_b1[0] ) , .mul_result_11( mul_16_result_b1[1] ) , .mul_result_12( mul_16_result_b1[2] ) , .mul_result_13( mul_16_result_b1[3] ) ,    
    .mul_result_20( mul_16_result_b2[0] ) , .mul_result_21( mul_16_result_b2[1] ) , .mul_result_22( mul_16_result_b2[2] ) , .mul_result_23( mul_16_result_b2[3] ) ,
    .mul_result_30( mul_16_result_b3[0] ) , .mul_result_31( mul_16_result_b3[1] ) , .mul_result_32( mul_16_result_b3[2] ) , .mul_result_33( mul_16_result_b3[3] ) ,  
    .in_A( wallace_in )                  , .in_B( wallace_in )           
);

wallace_131 Wallace_tree_c(
    .clk( clk )                           , .rst_n( rst_n )                       , .mode( wallace_mode ) ,  
    .in_valid( array_out_valid[2] )       , .out_valid( wallace_out_valid[2] )    , .result( wallace_out_C ),  
    .mul_result_00( mul_16_result_c0[0] ) , .mul_result_01( mul_16_result_c0[1] ) , .mul_result_02( mul_16_result_c0[2] ) , .mul_result_03( mul_16_result_c0[3] ) ,    
    .mul_result_10( mul_16_result_c1[0] ) , .mul_result_11( mul_16_result_c1[1] ) , .mul_result_12( mul_16_result_c1[2] ) , .mul_result_13( mul_16_result_c1[3] ) ,    
    .mul_result_20( mul_16_result_c2[0] ) , .mul_result_21( mul_16_result_c2[1] ) , .mul_result_22( mul_16_result_c2[2] ) , .mul_result_23( mul_16_result_c2[3] ) ,
    .mul_result_30( mul_16_result_c3[0] ) , .mul_result_31( mul_16_result_c3[1] ) , .mul_result_32( mul_16_result_c3[2] ) , .mul_result_33( mul_16_result_c3[3] ) ,  
    .in_A( wallace_in )                  , .in_B( wallace_in )           
);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                        Exponent operator for cmul                                        //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign exp_A0 = br_add_bi [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * exp of (b_re + b_im)
assign exp_A1 = a_im_r    [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * exp of a_im
assign exp_B0 = ar_sub_ai [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * exp of (a_re - a_im)
assign exp_B1 = b_im_r    [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * exp of b_im              
assign exp_C0 = br_sub_bi [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * exp of (b_re - b_im)
assign exp_C1 = a_re_r    [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * exp of a_re

assign NaN_a  = (mode[1] == C_MUL)?  ( (& exp_A0) & (|br_add_bi [(pMANTISSA_WIDTH-1):0]) ) | ( (& exp_A1) & (|a_im_r [(pMANTISSA_WIDTH-1):0]) ) : 1'b0;  // * if exp == 2047 and mantissa != 0 , assert NaN
assign NaN_b  = (mode[1] == C_MUL)?  ( (& exp_B0) & (|ar_sub_ai [(pMANTISSA_WIDTH-1):0]) ) | ( (& exp_B1) & (|b_im_r [(pMANTISSA_WIDTH-1):0]) ) : 1'b0;  // * if exp == 2047 and mantissa != 0 , assert NaN
assign NaN_c  = (mode[1] == C_MUL)?  ( (& exp_C0) & (|br_sub_bi [(pMANTISSA_WIDTH-1):0]) ) | ( (& exp_C1) & (|a_re_r [(pMANTISSA_WIDTH-1):0]) ) : 1'b0;  // * if exp == 2047 and mantissa != 0 , assert NaN

fmul_exp  exponent_op_A( .clk( clk ) , .rst_n( rst_n ), .in_valid( fp_add_ready[0] ), .exp_A( exp_A0 ), .exp_B( exp_A1 ),  .exp_o( exp_A_out ), .out_inf( inf_A ) , .out_valid( exp_ready_A ));
fmul_exp  exponent_op_B( .clk( clk ) , .rst_n( rst_n ), .in_valid( fp_add_ready[1] ), .exp_A( exp_B0 ), .exp_B( exp_B1 ),  .exp_o( exp_B_out ), .out_inf( inf_B ) , .out_valid( exp_ready_B ));
fmul_exp  exponent_op_C( .clk( clk ) , .rst_n( rst_n ), .in_valid( fp_add_ready[2] ), .exp_A( exp_C0 ), .exp_B( exp_C1 ),  .exp_o( exp_C_out ), .out_inf( inf_C ) , .out_valid( exp_ready_C ));

assign sign_A = ((|array_in_A0) && (|array_in_A1))? (br_add_bi[pFP_WIDTH-1] ^ a_im_r[pFP_WIDTH-1]) : 1'b0;  // * zero case while doing fp_mul
assign sign_B = ((|array_in_B0) && (|array_in_B1))? (ar_sub_ai[pFP_WIDTH-1] ^ b_im_r[pFP_WIDTH-1]) : 1'b0;  // * zero case while doing fp_mul
assign sign_C = ((|array_in_C0) && (|array_in_C1))? (br_sub_bi[pFP_WIDTH-1] ^ a_re_r[pFP_WIDTH-1]) : 1'b0;  // * zero case while doing fp_mul

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        for(i=0 ; i< (EXP_OP_LATENCY + ROUNDER_LATENCY ); i=i+1)begin
            sign_A_reg[i] <= 1'b0;
            sign_B_reg[i] <= 1'b0;
            sign_C_reg[i] <= 1'b0;
            NaN_a_reg [i] <= 1'b0;
            NaN_b_reg [i] <= 1'b0;
            NaN_c_reg [i] <= 1'b0;
        end
    end else begin
        sign_A_reg[0] <= sign_A; 
        sign_B_reg[0] <= sign_B;
        sign_C_reg[0] <= sign_C;
        NaN_a_reg [0] <= NaN_a;
        NaN_b_reg [0] <= NaN_b;
        NaN_c_reg [0] <= NaN_c;
        for(i=1 ; i< (EXP_OP_LATENCY + ROUNDER_LATENCY ) ; i=i+1)begin
            sign_A_reg[i] <= sign_A_reg[i-1];
            sign_B_reg[i] <= sign_B_reg[i-1];
            sign_C_reg[i] <= sign_C_reg[i-1];
            NaN_a_reg [i] <= NaN_a_reg [i-1];
            NaN_b_reg [i] <= NaN_b_reg [i-1];
            NaN_c_reg [i] <= NaN_c_reg [i-1];
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                    Rounding operator for cmul                                            //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign frac_A_i =  wallace_out_A[(pROUNDER_FRAC_WIDTH-1) :0] ;
assign frac_B_i =  wallace_out_B[(pROUNDER_FRAC_WIDTH-1) :0] ;
assign frac_C_i =  wallace_out_C[(pROUNDER_FRAC_WIDTH-1) :0] ; 

fmul_rounder rounder_A ( .frac_i( frac_A_i ) , .exp_i( exp_A_out ) , .frac_o( frac_A_rounded ) , .exp_o( exp_A_rounded ) , .inf_case( inf_A ) , .in_valid( exp_ready_A ) , .out_valid( rounder_ready_A ) , .clk( clk ) , .rst_n( rst_n ));
fmul_rounder rounder_B ( .frac_i( frac_B_i ) , .exp_i( exp_B_out ) , .frac_o( frac_B_rounded ) , .exp_o( exp_B_rounded ) , .inf_case( inf_B ) , .in_valid( exp_ready_B ) , .out_valid( rounder_ready_B ) , .clk( clk ) , .rst_n( rst_n ));
fmul_rounder rounder_C ( .frac_i( frac_C_i ) , .exp_i( exp_C_out ) , .frac_o( frac_C_rounded ) , .exp_o( exp_C_rounded ) , .inf_case( inf_C ) , .in_valid( exp_ready_C ) , .out_valid( rounder_ready_C ) , .clk( clk ) , .rst_n( rst_n ));

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                       floating point adder 2                                              //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign FP_num_A = (NaN_a_reg[EXP_OP_LATENCY + ROUNDER_LATENCY -1])? {NaN_num} : {sign_A_reg[EXP_OP_LATENCY + ROUNDER_LATENCY -1] , exp_A_rounded , frac_A_rounded };  // num_A = a_im * (b_re + b_im)
assign FP_num_B = (NaN_b_reg[EXP_OP_LATENCY + ROUNDER_LATENCY -1])? {NaN_num} : {sign_B_reg[EXP_OP_LATENCY + ROUNDER_LATENCY -1] , exp_B_rounded , frac_B_rounded };  // num_B = b_im * (a_re - a_im)
assign FP_num_c = (NaN_c_reg[EXP_OP_LATENCY + ROUNDER_LATENCY -1])? {NaN_num} : {sign_C_reg[EXP_OP_LATENCY + ROUNDER_LATENCY -1] , exp_C_rounded , frac_C_rounded };  // num_C = a_re * (b_re - b_im)


fp_add   fp_add_04( .in_A( FP_num_A ) , .in_B( FP_num_B )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( rounder_ready_A )  , .result( y_im ) , .out_valid( cmul_im_ready ));
fp_add   fp_add_05( .in_A( FP_num_B ) , .in_B( FP_num_c )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( rounder_ready_C )  , .result( y_re ) , .out_valid( cmul_re_ready ));


///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                       NTT: step2                                                            //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

CLA33 CLA33_1(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a0[2]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*2-1):0]}),                .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[0]), .result(mont_add_result[0]));
CLA33 CLA33_2(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a1[2]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*4-1):(pNTT_WIDTH*2)]}),   .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[1]), .result(mont_add_result[1]));
CLA33 CLA33_3(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a2[2]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*6-1):(pNTT_WIDTH*4)]}),   .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[2]), .result(mont_add_result[2]));
CLA33 CLA33_4(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a3[2]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*8-1):(pNTT_WIDTH*6)]}),   .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[3]), .result(mont_add_result[3]));
CLA33 CLA33_5(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a0[3]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*10-1):(pNTT_WIDTH*8)]}),  .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[4]), .result(mont_add_result[4]));
CLA33 CLA33_6(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a1[3]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*12-1):(pNTT_WIDTH*10)]}), .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[5]), .result(mont_add_result[5]));
CLA33 CLA33_7(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a2[3]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*14-1):(pNTT_WIDTH*12)]}), .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[6]), .result(mont_add_result[6]));
CLA33 CLA33_8(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A({1'b0, mul_16_result_a3[3]}), .B({1'b0, mul_16_reg[8][(pNTT_WIDTH*16-1):(pNTT_WIDTH*14)]}), .in_valid(array_out_valid[0]), .out_valid(mont_add_valid[7]), .result(mont_add_result[7]));
// In montgomery mul, will bit33 of result=(T+W)/R=z always 0?
// I have prove that z <= 2Q(32bit), but this needs the assumption that all of the input data is montgomery representation.
assign mont_R_result[0] = mont_add_result[0][(pNTT_WIDTH*2-1):pNTT_WIDTH];
assign mont_R_result[1] = mont_add_result[1][(pNTT_WIDTH*2-1):pNTT_WIDTH];
assign mont_R_result[2] = mont_add_result[2][(pNTT_WIDTH*2-1):pNTT_WIDTH];
assign mont_R_result[3] = mont_add_result[3][(pNTT_WIDTH*2-1):pNTT_WIDTH];
assign mont_R_result[4] = mont_add_result[4][(pNTT_WIDTH*2-1):pNTT_WIDTH];
assign mont_R_result[5] = mont_add_result[5][(pNTT_WIDTH*2-1):pNTT_WIDTH];
assign mont_R_result[6] = mont_add_result[6][(pNTT_WIDTH*2-1):pNTT_WIDTH];
assign mont_R_result[7] = mont_add_result[7][(pNTT_WIDTH*2-1):pNTT_WIDTH];

assign mont_cla_in[0] = {1'b0, mont_R_result[0]};
assign mont_cla_in[1] = {1'b0, mont_R_result[1]};
assign mont_cla_in[2] = {1'b0, mont_R_result[2]};
assign mont_cla_in[3] = {1'b0, mont_R_result[3]};
assign mont_cla_in[4] = {1'b0, mont_R_result[4]};
assign mont_cla_in[5] = {1'b0, mont_R_result[5]};
assign mont_cla_in[6] = {1'b0, mont_R_result[6]};
assign mont_cla_in[7] = {1'b0, mont_R_result[7]};
// 16bit sign add needs 17 bit CLA
CLA17 CLA17_1(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[0]), .B(Qn), .in_valid(mont_add_valid[0]), .out_valid(mont_n_valid[0]), .result(mont_n_result[0]));
CLA17 CLA17_2(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[1]), .B(Qn), .in_valid(mont_add_valid[1]), .out_valid(mont_n_valid[1]), .result(mont_n_result[1]));
CLA17 CLA17_3(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[2]), .B(Qn), .in_valid(mont_add_valid[2]), .out_valid(mont_n_valid[2]), .result(mont_n_result[2]));
CLA17 CLA17_4(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[3]), .B(Qn), .in_valid(mont_add_valid[3]), .out_valid(mont_n_valid[3]), .result(mont_n_result[3]));
CLA17 CLA17_5(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[4]), .B(Qn), .in_valid(mont_add_valid[4]), .out_valid(mont_n_valid[4]), .result(mont_n_result[4]));
CLA17 CLA17_6(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[5]), .B(Qn), .in_valid(mont_add_valid[5]), .out_valid(mont_n_valid[5]), .result(mont_n_result[5]));
CLA17 CLA17_7(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[6]), .B(Qn), .in_valid(mont_add_valid[6]), .out_valid(mont_n_valid[6]), .result(mont_n_result[6]));
CLA17 CLA17_8(.clk(clk), .rst_n(rst_n), .Cin(1'b0), .A(mont_cla_in[7]), .B(Qn), .in_valid(mont_add_valid[7]), .out_valid(mont_n_valid[7]), .result(mont_n_result[7]));

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mont_add_reg[0] <= {(pNTT_WIDTH*8){1'b0}};
        mont_add_reg[1] <= {(pNTT_WIDTH*8){1'b0}};
    end else begin
        mont_add_reg[0] <= {mont_R_result[7], mont_R_result[6], mont_R_result[5], mont_R_result[4], mont_R_result[3], mont_R_result[2], mont_R_result[1], mont_R_result[0]};
        mont_add_reg[1] <= mont_add_reg[0];
    end
end

// mod Q
assign result_int1 = (mont_n_result[0][(pNTT_WIDTH)] == 1'b0)? mont_n_result[0][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH-1):0];
assign result_int2 = (mont_n_result[1][(pNTT_WIDTH)] == 1'b0)? mont_n_result[1][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH*2-1):(pNTT_WIDTH)];
assign result_int3 = (mont_n_result[2][(pNTT_WIDTH)] == 1'b0)? mont_n_result[2][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH*3-1):(pNTT_WIDTH*2)];
assign result_int4 = (mont_n_result[3][(pNTT_WIDTH)] == 1'b0)? mont_n_result[3][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH*4-1):(pNTT_WIDTH*3)];
assign result_int5 = (mont_n_result[4][(pNTT_WIDTH)] == 1'b0)? mont_n_result[4][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH*5-1):(pNTT_WIDTH*4)];
assign result_int6 = (mont_n_result[5][(pNTT_WIDTH)] == 1'b0)? mont_n_result[5][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH*6-1):(pNTT_WIDTH*5)];
assign result_int7 = (mont_n_result[6][(pNTT_WIDTH)] == 1'b0)? mont_n_result[6][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH*7-1):(pNTT_WIDTH*6)];
assign result_int8 = (mont_n_result[7][(pNTT_WIDTH)] == 1'b0)? mont_n_result[7][(pNTT_WIDTH-1):0] : mont_add_reg[1][(pNTT_WIDTH*8-1):(pNTT_WIDTH*7)];

assign result_c     = { y_re , y_im} ; 
assign result_int   = {result_int8, result_int7, result_int6, result_int5, result_int4, result_int3, result_int2, result_int1};
assign out_valid    = (mode[1] == C_MUL)?   (cmul_im_ready & cmul_re_ready) : (mont_n_valid[0]);


endmodule