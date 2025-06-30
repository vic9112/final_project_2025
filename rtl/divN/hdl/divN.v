
module divN #(
    parameter pDATA_WIDTH = 128 
) (
    input [(pDATA_WIDTH-1) : 0]     in_A,
    input                           clk ,
    input                           rst_n,
    input                           in_valid,
    output[(pDATA_WIDTH-1)  :0]     result_int,
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

localparam MUL16_ARRAY_LATENCY  = 4 ;  // * Latency of mul_16 array
localparam MOD_LATENCY          = 9 ;  // * Latency of mod operation(NTT)
localparam CLA_ADD_LATENCY       = 2 ;  // * Latency of CLA
//--------------------------------------------------------------------------------------------------------------------//
localparam Q01 = 16'h2FFF;
localparam Q = 16'h3001;
localparam Qn = 17'h1CFFF;              // * negative Q
localparam N01 = 16'h2FF5;              // * N^-1
//=====================================================================================================================//
wire [(pDATA_WIDTH-1):0]            in_B = {8{N01}};
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


assign array_in_valid[0]  = array_out_valid[1];
assign array_in_valid[1]  = in_valid;
assign array_in_valid[2]  = in_valid;

//{mul_16_result_c3[3]  , mul_16_result_c2[2] ,  mul_16_result_c1[1] , mul_16_result_c0[0] , mul_16_result_b3[3] , mul_16_result_b2[2] , mul_16_result_b1[1] , mul_16_result_b0[0]};
assign array_in_ntt1     = {mul_16_result_b3[3][(pNTT_WIDTH-1):0] , mul_16_result_b2[2][(pNTT_WIDTH-1):0] , mul_16_result_b1[1][(pNTT_WIDTH-1):0] , mul_16_result_b0[0][(pNTT_WIDTH-1):0]};
assign array_in_ntt2     = {mul_16_result_c3[3][(pNTT_WIDTH-1):0] , mul_16_result_c2[2][(pNTT_WIDTH-1):0] , mul_16_result_c1[1][(pNTT_WIDTH-1):0] , mul_16_result_c0[0][(pNTT_WIDTH-1):0]};

assign array_in_A0       = array_in_ntt1;
assign array_in_A1       = array_in_ntt1;
assign array_in_A2       = array_in_ntt2;
assign array_in_B0       = in_A[(pFP_WIDTH-1):0];                
assign array_in_B1       = in_B[(pFP_WIDTH-1):0];                   
assign array_in_C0       = in_A[(pDATA_WIDTH-1):pFP_WIDTH];
assign array_in_C1       = in_B[(pDATA_WIDTH-1):pFP_WIDTH];
 

mul16_array_intt mul16_array_a(
    //-------- input of mul_16_array(64bit data width)
    .in_B0( array_in_A1 ),  .in_B1( array_in_A2 ),  .clk( clk ),  .rst_n( rst_n ),  .in_valid( array_in_valid[0] ),  .out_valid( array_out_valid[0] ),
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

integer i;
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

assign result_int   = {result_int8, result_int7, result_int6, result_int5, result_int4, result_int3, result_int2, result_int1};
assign out_valid    = (mont_n_valid[0]);


endmodule