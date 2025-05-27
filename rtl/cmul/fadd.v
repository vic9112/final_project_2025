`include "LOD.v"
module fadd#(
    parameter pDATA_WIDTH = 64,
    parameter pEXP_WIDTH  = 11, 
    parameter pFRAC_WIDTH = 52
)
(
    num1,
    num2,
    clk,
    rstn,
    valid,
    result,
    ready
);
//============================================================================//
input  [(pDATA_WIDTH-1):0]          num1 ;
input  [(pDATA_WIDTH-1):0]          num2 ;
input                               clk  ;
input                               rstn ;
input                               valid ;
output [(pDATA_WIDTH-1):0]          result;
output                              ready ;   
//============================================================================//
localparam pADDER_WIDTH = pFRAC_WIDTH*2+3;
localparam LOD_WIDTH    = 11'd128;

//=============================== Decode ======================================//

wire[(pFRAC_WIDTH):0]               frac_a;
wire[(pFRAC_WIDTH):0]               frac_b;
wire                                sign_a;
wire                                sign_b;
wire                                hid_a;
wire                                hid_b;
wire[(pEXP_WIDTH-1):0]              exp_a;
wire[(pEXP_WIDTH-1):0]              exp_b;
wire[(pEXP_WIDTH-1):0]              exp_diff_ab;
wire[(pEXP_WIDTH-1):0]              exp_diff_ba;
wire                                exp_compare;
//============================== Pipline stage 1 ==============================//
reg [(pEXP_WIDTH-1):0]              pip1_exp_diff_ab ;
reg [(pEXP_WIDTH-1):0]              pip1_exp_diff_ba ;

reg [(pEXP_WIDTH-1):0]              pip1_exp_a  ;     
reg [(pEXP_WIDTH-1):0]              pip1_exp_b  ;        

reg [(pFRAC_WIDTH):0]               pip1_frac_a ;     
reg [(pFRAC_WIDTH):0]               pip1_frac_b ;

reg                                 pip1_sign_a ;     
reg                                 pip1_sign_b ;    
reg                                 pip1_exp_compare ;
reg                                 pip1_v; 
//============================ exponent align =================================//
wire[(pADDER_WIDTH-1):0]            frac_a_expand;      
wire[(pADDER_WIDTH-1):0]            frac_b_expand;
wire[(pADDER_WIDTH-1):0]            frac_a_shifted;      
wire[(pADDER_WIDTH-1):0]            frac_b_shifted;  
wire[(pEXP_WIDTH-1):0]              exp_diff; 
//============================== OP analyze ===================================//
reg [1:0]                           op;
wire[1:0]                           sign_ab;
//============================= pipeline stage2 ==============================//
reg [(pADDER_WIDTH-1):0]            pip2_frac_a;
reg [(pADDER_WIDTH-1):0]            pip2_frac_b;
reg [1:0]                           pip2_op;
reg [1:0]                           pip2_sign_ab;
reg [(pEXP_WIDTH-1):0]              pip2_exp ;
reg                                 pip2_v;
//* wire                                frac_compare;
//* reg                                 pip2_frac_compare;
//============================ fraction operate ==============================//
wire signed[(pADDER_WIDTH-1):0]     frac_a_add_b;
wire signed[(pADDER_WIDTH-1):0]     frac_a_sub_b;
wire signed[(pADDER_WIDTH-1):0]     frac_b_sub_a;
reg  signed[(pADDER_WIDTH-1):0]     frac_result ;
//============================ pipeline stage3 ==============================//
reg [1:0]                           pip3_op;
reg [(pADDER_WIDTH-1):0]            pip3_frac_result;
reg [(pEXP_WIDTH-1):0]              pip3_exp;
reg                                 pip3_v;
reg [1:0]                           pip3_sign_ab ;
//============================ first normalizeation ==========================//
wire                                lsb         ;
wire                                guard_bit   ;
wire                                round_bit   ;
wire                                sticky_bit  ;
reg                                 result_sign ;
wire[(pADDER_WIDTH-1):0]            frac_abs    ;
wire[(LOD_WIDTH-1):0]               frac_abs_expand;
wire[(pADDER_WIDTH-1):0]            frac_normal_0;
wire[(pEXP_WIDTH-1)  :0]            exp_normal_0 ;
wire                                frac_sign;
wire signed[(pEXP_WIDTH-1):0]       shift;
wire signed[(pEXP_WIDTH-1):0]       shift_amount;
wire signed[(pEXP_WIDTH-1):0]       maximum_shift;
//============================= pipeline stage4 ==============================//
reg                                 pip4_lsb;
reg                                 pip4_sticky;
reg                                 pip4_guard;
reg                                 pip4_round;
reg                                 pip4_result_sign;
reg [(pEXP_WIDTH-1)  :0]            pip4_exp ;
reg [(pFRAC_WIDTH-1):0]             pip4_frac;
reg                                 pip4_v;
//====================== rounding and second normalization ===================//
wire[(pFRAC_WIDTH) :0]              frac_normal_0_expand;
wire[(pFRAC_WIDTH) :0]              frac_rounded;
reg                                 round_op;

wire[(pFRAC_WIDTH) :0]              frac_normal_1;
wire[(pEXP_WIDTH-1):0]              exp_normal_1;
//============================ pipeline stage5 ===============================//
reg                                 pip5_result_sign;
reg [(pEXP_WIDTH-1):0]              pip5_exp;
reg [(pFRAC_WIDTH-1):0]             pip5_frac;
reg                                 pip5_v;

/////////////////////////////////////////////////////////////////////////////////////////
//                                  Decode                                             //
/////////////////////////////////////////////////////////////////////////////////////////

assign exp_a  = num1[(pDATA_WIDTH-2) : pFRAC_WIDTH]; 
assign exp_b  = num2[(pDATA_WIDTH-2) : pFRAC_WIDTH];

assign hid_a  = |exp_a;
assign hid_b  = |exp_b;


assign frac_a = {hid_a , num1[(pFRAC_WIDTH-1) : 0]};    //*  expand hidden bit of fraction
assign frac_b = {hid_b , num2[(pFRAC_WIDTH-1) : 0]};    //*  expand hidden bit of fraction

assign sign_a = num1[pDATA_WIDTH-1];
assign sign_b = num2[pDATA_WIDTH-1];

/////////////////////////////////////////////////////////////////////////////////////////
//                       EXP COMPARE and complement generate                           //
/////////////////////////////////////////////////////////////////////////////////////////

assign exp_compare = (exp_a > exp_b)? 1'b1 : 1'b0;
assign exp_diff_ab = exp_a - exp_b ;
assign exp_diff_ba = exp_b - exp_a ;

///////////////////////////////////////////////////////////////////////////////////////
//                              PIPELINE stage1                                      //
///////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        pip1_exp_compare <= 1'b0;
        pip1_exp_diff_ab <= {(pEXP_WIDTH){1'b0}}; 
        pip1_exp_diff_ba <= {(pEXP_WIDTH){1'b0}}; 
        
        pip1_frac_a      <= {(pFRAC_WIDTH+1){1'b0}} ;
        pip1_frac_b      <= {(pFRAC_WIDTH+1){1'b0}} ;
        pip1_sign_a      <= 1'b0;
        pip1_sign_b      <= 1'b0;
        pip1_exp_a       <= {(pEXP_WIDTH){1'b0}};
        pip1_exp_b       <= {(pEXP_WIDTH){1'b0}};
        pip1_v           <= 1'b0;
    end else begin
        pip1_exp_compare <= exp_compare;
        pip1_exp_diff_ab <= exp_diff_ab;
        pip1_exp_diff_ba <= exp_diff_ba;

        pip1_frac_a      <= frac_a ;
        pip1_frac_b      <= frac_b ;
        pip1_sign_a      <= sign_a;
        pip1_sign_b      <= sign_b;
        pip1_exp_a       <= exp_a ;
        pip1_exp_b       <= exp_b ;
        pip1_v           <= valid;
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////
//                                EXP align                                                //
/////////////////////////////////////////////////////////////////////////////////////////////
///========================================================================================//
// * To make sure add or sub can tolarant overflow or negative,and can be shifted.
// * We expand the data width.
// * frac_expand structure 
//      2bits     53bits(contain hidden)     49bits
//    |  00  |        FRACTION          |    0000..     |
//
//=========================================================================================//
assign exp_diff       = (pip1_exp_compare)?   pip1_exp_diff_ab : pip1_exp_diff_ba;

assign frac_a_expand  = {2'b00 ,pip1_frac_a , {(pADDER_WIDTH-pFRAC_WIDTH-3){1'b0}}};
assign frac_b_expand  = {2'b00 ,pip1_frac_b , {(pADDER_WIDTH-pFRAC_WIDTH-3){1'b0}}};

assign frac_a_shifted = (pip1_exp_compare)?              frac_a_expand  : (frac_a_expand >> exp_diff);
assign frac_b_shifted = (pip1_exp_compare)? (frac_b_expand >> exp_diff) : frac_b_expand;

//////////////////////////////////////////////////////////////////////////////////////////////
//                              OP analyze                                                  //
//////////////////////////////////////////////////////////////////////////////////////////////
localparam negA_negB = 2'b11;
localparam negA_posB = 2'b10;
localparam posA_negB = 2'b01;
localparam posA_posB = 2'b00;

localparam A_SUB_B = 2'd1 ;
localparam B_SUB_A = 2'd2 ;
localparam A_ADD_B = 2'd3 ;

assign sign_ab      = {pip1_sign_a , pip1_sign_b};
//* assign frac_compare = (frac_a_shifted > frac_b_shifted)? 1'b1 : 1'b0;

always @(*) begin
    case(sign_ab)
        negA_negB : op = A_ADD_B;
        negA_posB : op = B_SUB_A;
        posA_negB : op = A_SUB_B;
        posA_posB : op = A_ADD_B;
        default   : op = 2'd0;
    endcase
end

/////////////////////////////////////////////////////////////////////////////////////////////
//                              PIPELINE stage2                                           //
/////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rstn)begin
    if(!rstn)begin
        pip2_op           <= 2'd0;

        pip2_sign_ab      <= 2'd0;

        pip2_frac_a       <= {(pADDER_WIDTH){1'b0}};
        pip2_frac_b       <= {(pADDER_WIDTH){1'b0}};

        pip2_exp          <= {(pEXP_WIDTH){1'b0}};
        pip2_v            <= 1'b0;
    end else begin
        pip2_op           <= op;
        pip2_sign_ab      <= sign_ab;

        pip2_frac_a       <= frac_a_shifted ;
        pip2_frac_b       <= frac_b_shifted ;

        pip2_exp          <= (pip1_exp_compare)? pip1_exp_a : pip1_exp_b ;
        pip2_v            <= pip1_v;
    end
end

////////////////////////////////////////////////////////////////////////////////
//                              FRACTION ADD                                  //  
////////////////////////////////////////////////////////////////////////////////


assign frac_a_add_b = pip2_frac_a + pip2_frac_b;
assign frac_a_sub_b = pip2_frac_a - pip2_frac_b;
assign frac_b_sub_a = pip2_frac_b - pip2_frac_a;


always @(*)begin
    case(pip2_op)
            A_ADD_B : frac_result = frac_a_add_b;
            A_SUB_B : frac_result = frac_a_sub_b;
            B_SUB_A : frac_result = frac_b_sub_a;
            default : frac_result = frac_a_add_b;
    endcase
end

////////////////////////////////////////////////////////////////////////////////
//                            Pipeline stage 3                                //
////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        pip3_frac_result <= {(pADDER_WIDTH){1'b0}};
        pip3_exp         <= {(pEXP_WIDTH){1'b0}};
        pip3_sign_ab     <= 2'd0;
        pip3_v           <= 1'b0;
    end else begin
        pip3_frac_result <= frac_result;
        pip3_exp         <= pip2_exp;
        pip3_sign_ab     <= pip2_sign_ab;
        pip3_v           <= pip2_v;
    end
end
/////////////////////////////////////////////////////////////////////////////////
//                 first  normalization  and result_sign analyze               //
/////////////////////////////////////////////////////////////////////////////////

//==================================================================================================================//
// * frac_result is  result of fraction operation 
//
// * frac_result Structure:
//        1bit     1bit        53bits           49bits
//      | sign | overflow | fraction add  | shifted fraction  |
//
// * First we transfer signed value into absolute value (frac_abs)
// * And calculate the shift amount by LOD.
// * Final we normalize the frac into following structure(frac_normal_0)
//        2bit        53bits           49bits
//      |  00  |   fraction(valid) |  G R S .. |
//
//  * And extract LSB 、guard_bit 、 round_bit 、sticky_bit from frac_normal_0.
//  * Only transfer valid fraction part to next pipeline stage! 
// 
//  * If fraction is all zero , set exp=0 , frac=0
//  * If exp value is smaller than number of zero in fromt of leading one ,set exp =0 and shift as exp value. 
//  * Others shift to eliminate zero in front of leading one,and sub the exp value by shift amount.
//==================================================================================================================//
localparam  postive      = 1'b0;
localparam  negative     = 1'b1;

//---------------------------------------------------------- normalization ----------------------------------------------------------------------------------------------------------------------//
assign frac_sign     = pip3_frac_result[pADDER_WIDTH-1];                                                                        // * pip3_frac_result is signed we need to collect its sign bit to calculate
assign frac_abs      = (frac_sign)?  (((~ pip3_frac_result) + {{(pADDER_WIDTH-1){1'b0}} , 1'b1})) : (pip3_frac_result );          // * pip3_frac_result is signed we need to transfer it to absolute value !


assign frac_normal_0 = (frac_abs[(pADDER_WIDTH-1):0] << shift_amount) >>1 ;                                                                             // * fisrt time normalize
assign exp_normal_0  = (shift_amount <= maximum_shift)? (pip3_exp - shift_amount+1) : {(pEXP_WIDTH){1'b0}};                       // * first time normalize .If all zero ,replace exp = 0000(denormal type).

assign maximum_shift = pADDER_WIDTH-2;                                                                                          


assign shift_amount  = (shift >= pip3_exp)? pip3_exp + 1: shift -1;


assign frac_abs_expand = {frac_abs , {(LOD_WIDTH-pADDER_WIDTH){1'b0}}};

LOD #(LOD_WIDTH , pEXP_WIDTH) compute_zero_num(.A(frac_abs_expand) , .position(shift));

//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
assign lsb           = frac_normal_0[(pADDER_WIDTH-pFRAC_WIDTH-3)];
assign guard_bit     = frac_normal_0[(pADDER_WIDTH-pFRAC_WIDTH-4)];
assign round_bit     = frac_normal_0[(pADDER_WIDTH-pFRAC_WIDTH-5)];
assign sticky_bit    = | frac_normal_0[(pADDER_WIDTH-pFRAC_WIDTH-6) : 0];

always @(*) begin
    case(pip3_sign_ab)
        posA_negB : result_sign = (frac_sign)?  negative : postive;
        posA_posB : result_sign = postive ;
        negA_negB : result_sign = negative;
        negA_posB : result_sign = (frac_sign)?  negative : postive;
    endcase
end

////////////////////////////////////////////////////////////////////////////////
//                            Pipeline stage4                                 //
////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        pip4_lsb         <= 1'b0;
        pip4_sticky      <= 1'b0;
        pip4_guard       <= 1'b0;
        pip4_round       <= 1'b0;
    
        pip4_exp         <= {(pEXP_WIDTH){1'b0}};
        pip4_frac        <= {(pFRAC_WIDTH){1'b0}};
        pip4_result_sign <= 1'b0;
        pip4_v           <= 1'b0;
    end else begin
        pip4_lsb         <= lsb;
        pip4_sticky      <= sticky_bit;
        pip4_guard       <= guard_bit;
        pip4_round       <= round_bit;

        pip4_exp         <= exp_normal_0;
        pip4_frac        <= frac_normal_0[(pADDER_WIDTH-4):(pADDER_WIDTH-pFRAC_WIDTH-3)];
        pip4_result_sign <= result_sign;
        pip4_v           <= pip3_v;
    end
end


/////////////////////////////////////////////////////////////////////////////////
//                  rounding and second normalization                          //
/////////////////////////////////////////////////////////////////////////////////

//=========================================================================================================//
//
// * Before rounding operation,we first expand 1bit of zero in front of fraction from last 
// * pipeline stage.(to tolarant overflow while rounding)
//  
//  frac_normal_0_expand structure
//    1bit         53bit
//  |   0   | fraction(valid) |
//
// * Then we do nearest even rounding(with sticky).
//   frac_rounded structure
//      1bit         53bit
//  | overflow? | fraction(valid) |
//
// * Final we normalize the fraction into 53bit.
//=========================================================================================================//
localparam  ROUNDING        = 1'b0;
localparam  NO_ROUNDING     = 1'b1;

assign frac_normal_0_expand = {1'b0 , pip4_frac};
assign frac_rounded         = (round_op == ROUNDING)?  (frac_normal_0_expand + {{(pFRAC_WIDTH){1'b0}} , 1'b1}) : frac_normal_0_expand ;


assign frac_normal_1        = (frac_rounded[pFRAC_WIDTH])?  ( frac_rounded >> 1) : frac_rounded  ;
assign exp_normal_1         = (frac_rounded[pFRAC_WIDTH])?  (pip4_exp + {{(pEXP_WIDTH-1){1'b0}} , 1'b1})  : pip4_exp;

always @(*) begin
    if(pip4_guard)begin
        round_op = (! pip4_lsb)?  ((pip4_round | pip4_sticky )? ROUNDING : NO_ROUNDING ) : ROUNDING;
    end else begin
        round_op = NO_ROUNDING;
    end
end


////////////////////////////////////////////////////////////////////////////////
//                            Pipeline stage5                                 //
////////////////////////////////////////////////////////////////////////////////


always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        pip5_result_sign <= 1'b0;
        pip5_exp         <= {(pEXP_WIDTH){1'b0}};
        pip5_frac        <= {(pFRAC_WIDTH){1'b0}};
        pip5_v           <= 1'b0;
    end else begin
        pip5_result_sign <= pip4_result_sign ;
        pip5_exp         <= exp_normal_1;
        pip5_frac        <= frac_normal_1[(pFRAC_WIDTH-1): 0];
        pip5_v           <= pip4_v;
    end
end

assign result     = {pip5_result_sign , pip5_exp , pip5_frac};
assign ready  = pip5_v;


endmodule

