// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : fmul_exp
// Author : Jeese
// Create Date: 6/2025
// Features & Functions:
// . Butterfly process element
// .
// ============================================================================================================================================================================
// Revision History:
// Date          by         Version       Change Description
// 2025.7.23    hsuanjung      x          change ifft's operation to follow falcon ifft
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

module butterfly
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers represent real & imaginary part
)
(
    input   wire clk,
    input   wire rst_n,

    input   wire [1:0] mode, // /iNTT(11)/NTT(10)/iFFT(01)/FFT(00)

    input   wire i_vld,
    output  wire i_rdy,
    
    output  wire o_vld,
    input   wire o_rdy,

    input   wire [(pDATA_WIDTH-1):0] ai, // are(64bit)+aim(64bit)
    input   wire [(pDATA_WIDTH-1):0] bi, // bre(64bit)+bim(64bit)
    input   wire [(pDATA_WIDTH-1):0] gm, // gre(64bit)+gim(64bit)
    output  wire [(pDATA_WIDTH-1):0] ao,
    output  wire [(pDATA_WIDTH-1):0] bo

);
//==================================================================================//

localparam NTT_MUL_LATENCY = 17;
localparam FFT_MUL_LATENCY = 21;
localparam FP_ADD_LATENCY  = 5 ;

localparam NTT_LATENCY     = 22;
localparam iNTT_LATENCY    = 22;//?
localparam FFT_LATENCY     = 28;
localparam iFFT_LATENCY    = 28;//?

localparam mode_FFT        = 2'b00;
localparam mode_iFFT       = 2'b01;
localparam mode_NTT        = 2'b10;
localparam mode_iNTT       = 2'b11;


localparam FFT_WAIT  = 3'b000;
localparam iFFT_WAIT = 3'b001;
localparam NTT_WAIT  = 3'b010;
localparam iNTT_WAIT = 3'b011;
localparam READY     = 3'b111;
//==================================================================================//
localparam pFP_WIDTH       = 64 ;
localparam pNTT_WTDTH      = 16 ;
localparam pEXP_WIDTH      = 11 ;
localparam pFRAC_WIDTH     = 52 ;
//==================================================================================//
localparam pEXP_DENOR      = 11'b000_0000_0000;
localparam pEXP_INF        = 11'b111_1111_1111;
//==================================================================================//
//-------------------- Input interface and mode control ----------------------------//
reg  [2:0]                  state;
reg  [2:0]                  state_next;
reg  [1:0]                  mode_state ; //control datapath
reg  [1:0]                  mode_state_next;

reg                         buf_en;
reg  [(pDATA_WIDTH-1):0]    buf_ai;
reg  [(pDATA_WIDTH-1):0]    buf_bi;
reg  [(pDATA_WIDTH-1):0]    buf_gm;
reg                         buf_i_vld;
reg                         i_vld_en;
reg                         trans_en;
reg  [4:0]                  count;
//----------------------------- MUL & ADD FIFO ------------------------------------//
reg  [(pDATA_WIDTH-1):0]    MUL_FIFO[0:(FFT_MUL_LATENCY-1)];
reg  [(pDATA_WIDTH-1):0]    ADD_FIFO[0:(FP_ADD_LATENCY-1)] ;
//-------------------------- Multiplier operand & result  -------------------------//
wire [(pDATA_WIDTH-1):0]    a_result;
wire [(pFP_WIDTH*2-1):0]    mul_in1 ;
wire [(pFP_WIDTH*2-1):0]    mul_in2 ;
wire                        mul_in_valid ;
wire [(pDATA_WIDTH-1):0]    mul_result_int;
wire [(pDATA_WIDTH-1):0]    mul_result_com;
wire [(pDATA_WIDTH-1):0]    mul_result;
wire [(pFP_WIDTH-1):0]      mul_result_re_inv;
wire [(pFP_WIDTH-1):0]      mul_result_im_inv;
wire [(pDATA_WIDTH-1):0]    mul_result_inv;
wire                        mul_out_valid[0:1];
wire                        cmul_valid_i[0:1];
wire                        cmul_valid_o[0:3];
wire                        mont_add_valid_o0[0:7];
wire                        mont_add_valid_o1[0:7];
wire [(pDATA_WIDTH-1):0]    mont_add_result;
wire [(pDATA_WIDTH-1):0]    mont_sub_result;
reg  [(pNTT_WTDTH-1):0]     mont_add_intt[0:7];
reg  [(pNTT_WTDTH-1):0]     mont_sub_intt[0:7];
wire [(pDATA_WIDTH-1):0]    mont_add_intt_result;
wire [(pDATA_WIDTH-1):0]    mont_sub_intt_result;
//----------------------------- fp_add operand -------------------------------------//
wire [(pFP_WIDTH-1):0]      fp_add_in_01[0:1] ;
wire [(pFP_WIDTH-1):0]      fp_add_in_02[0:1] ;
wire [(pFP_WIDTH-1):0]      fp_add_in_11[0:1] ;
wire [(pFP_WIDTH-1):0]      fp_add_in_12[0:1] ;
wire                        fp_add_in_valid   ;
wire [3:0]                  fp_add_out_valid  ;
wire [(pFP_WIDTH*2-1):0]    fp_add_result[0:1];
//------------------------------ ifft result ---------------------------------------//
wire [(pEXP_WIDTH-1):0]     IFFT_result_exp_im [0:1] ;
wire [(pEXP_WIDTH-1):0]     IFFT_result_exp_re [0:1] ;
wire [(pFRAC_WIDTH-1):0]    IFFT_result_frac_im[0:1] ;
wire [(pFRAC_WIDTH-1):0]    IFFT_result_frac_re[0:1] ;
wire [(pDATA_WIDTH-1):0]    cmul_result_ifft   [0:1] ;
//----------------------------- output buffer --------------------------------------//
reg  [(pDATA_WIDTH-1):0]    ao_buf   [0:1];
reg  [(pDATA_WIDTH-1):0]    bo_buf   [0:1];
reg                         o_vld_buf[0:1];

//==================================================================================//

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                       Input interface and mode control                                                                              //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// state control
// i_rdy controller
always @(*) begin
    if (i_vld && (mode_state != mode)) begin
        case (state)
        READY: begin
            trans_en = 1'b0;
            if (mode_state == mode_FFT) begin
                state_next = FFT_WAIT;
                buf_en     = 1'b1;
                i_vld_en   = 1'b0;
            end else if (mode_state == mode_iFFT) begin
                state_next = iFFT_WAIT;
                buf_en     = 1'b1;
                i_vld_en   = 1'b0;
            end else if (mode_state == mode_NTT) begin
                state_next = NTT_WAIT;
                buf_en     = 1'b1;
                i_vld_en   = 1'b0;
            end else if (mode_state == mode_iNTT) begin
                state_next = iNTT_WAIT;
                buf_en     = 1'b1;
                i_vld_en   = 1'b0;
            end else begin
                state_next = READY;
                buf_en     = 1'b0;
                i_vld_en   = 1'b1;
            end
        end
        FFT_WAIT: begin
          buf_en   = 1'b0;
          i_vld_en = 1'b0;
          if (count == FFT_LATENCY - 1) begin
            state_next = READY;
            trans_en   = 1'b1;
          end else begin
            state_next = state;
            trans_en   = 1'b0;
          end
        end
        iFFT_WAIT: begin
          buf_en   = 1'b0;
          i_vld_en = 1'b0;
          if (count == iFFT_LATENCY - 1) begin
            state_next = READY;
            trans_en   = 1'b1;
          end else begin
            state_next = state;
            trans_en   = 1'b0;
          end
        end
        NTT_WAIT: begin
          buf_en   = 1'b0;
          i_vld_en = 1'b0;
          if (count == NTT_LATENCY - 1) begin
            state_next = READY;
            trans_en   = 1'b1;
          end else begin
            state_next = state;
            trans_en   = 1'b0;
          end
        end
        iNTT_WAIT: begin
          buf_en   = 1'b0;
          i_vld_en = 1'b0;
          if (count == iNTT_LATENCY - 1) begin
            state_next = READY;
            trans_en   = 1'b1;
          end else begin
            state_next = state;
            trans_en   = 1'b0;
          end
        end 
        endcase
    end else begin
        state_next  = state;
        trans_en    = 1'b0;
        buf_en      = (state == READY)? 1'b1:1'b0;
        i_vld_en    = (state == READY)? 1'b1:1'b0;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= READY;
    end else begin
        state <= state_next;
    end
end
//counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
    end else if (i_vld & i_rdy) begin
      count <= 0;
    end else begin
      count <= count + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mode_state <= mode_FFT;
    end else if (trans_en) begin
      mode_state <= mode;
    end else begin
      mode_state <= mode_state;
    end
end
assign i_rdy = (state == READY)? 1'b1:1'b0;

//==================================================================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buf_ai    <= {(pDATA_WIDTH){1'b0}};
      buf_bi    <= {(pDATA_WIDTH){1'b0}};
      buf_gm    <= {(pDATA_WIDTH){1'b0}};
      buf_i_vld <= 1'b0;
    end else if (buf_en) begin
      buf_ai    <= ai;
      buf_bi    <= bi;
      buf_gm    <= gm;
      buf_i_vld <= i_vld & i_rdy;
    end else begin
      buf_ai    <= buf_ai;
      buf_bi    <= buf_bi;
      buf_gm    <= buf_gm;
      buf_i_vld <= buf_i_vld;
    end
end
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  MUL/ADD FIFO                                                                                       //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//=====================================================================================================================================================================//
// In this data path , use group of reg as FIFO to store some data while others are being operated :                                                                   //
//                                                                                                                                                                     //
// 1. MUL_FIFO :                                                                                                                                                       //
//    * Use to store the ain while doing FFT's complex mul .                                                                                                           //
//    * Use to store the (ain+bin) from fp_add while doing iFFT's complex mul .                                                                                        //
//    * Use to store the ain while doing NTT's operation .                                                                                                             //
//                                                                                                                                                                     //
// 2. ADD_FIFO :                                                                                                                                                       //
//    * Use to store the twiddle factor while doing iFFT's  floating point add .                                                                                       //
//                                                                                                                                                                     //
//=====================================================================================================================================================================//
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < FFT_MUL_LATENCY; i = i + 1) begin
          MUL_FIFO[i] <= {(pDATA_WIDTH){1'b0}};
        end
    end else begin
        MUL_FIFO[0] <= (mode_state ==  mode_iFFT)? fp_add_result[0] : buf_ai;
        for (i = 1; i < FFT_MUL_LATENCY; i = i + 1) begin
          MUL_FIFO[i] <= MUL_FIFO[i-1];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < FP_ADD_LATENCY; i = i + 1) begin
          ADD_FIFO[i] <= {(pDATA_WIDTH){1'b0}};
        end
    end else begin
        // * CONJ (W)
        ADD_FIFO[0] <=  {buf_gm[(pFP_WIDTH*2-1) : pFP_WIDTH]  , (~buf_gm[pFP_WIDTH-1]) , buf_gm[(pFP_WIDTH-2):0]};
        for (i = 1; i < FP_ADD_LATENCY; i = i + 1) begin
          ADD_FIFO[i] <= ADD_FIFO[i-1];
        end
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  Multiplier operand & result                                                                        //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//=====================================================================================================================================================================//
// * If  FFT mode , do bi * gm .                                                                                                                                       //
// * If IFFT mode , do (ao-bi)*gm                                                                                                                                      //
//=====================================================================================================================================================================//
assign mul_in1       = (mode_state == mode_iFFT )?          fp_add_result[1]     : buf_bi ;
assign mul_in2       = (mode_state == mode_iFFT )?    ADD_FIFO[FP_ADD_LATENCY-1] : buf_gm ;
assign mul_in_valid  = (mode_state == mode_iFFT )?       fp_add_out_valid[0]     : (buf_i_vld & i_vld_en);

mul mul1(
    .in_A(mul_in1),
    .in_B(mul_in2),
    .mode(mode_state), // * set mode = 0 to do complex mul ， mode = 1 to do int mul
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(mul_in_valid),
    .result_c(mul_result_com),  
    .result_int(mul_result_int),
    .out_valid(mul_out_valid[0])
);
assign mul_result        = (mode_state[1] == 1'b0 )? mul_result_com : mul_result_int;

assign mul_result_re_inv = {~mul_result_com[(pFP_WIDTH*2-1)], mul_result_com[(pFP_WIDTH*2-2):pFP_WIDTH]};
assign mul_result_im_inv = {~mul_result_com[(pFP_WIDTH-1)]  , mul_result_com[(pFP_WIDTH-2):0]};
assign mul_result_inv    = {mul_result_re_inv, mul_result_im_inv} ;

assign a_result          = (mode_state[1] == 1'b0)? MUL_FIFO[(FFT_MUL_LATENCY-1)] : MUL_FIFO[(NTT_MUL_LATENCY-1)];

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  FP_ADD operand & result                                                                            //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// select operand OF FP_ADD in FFT 、 iFFT
assign fp_add_in_01[0] = (mode_state == mode_iFFT)?   buf_ai[(pFP_WIDTH-1) : 0]   : a_result  [(pFP_WIDTH-1):0]       ;
assign fp_add_in_01[1] = (mode_state == mode_iFFT)?   buf_bi[(pFP_WIDTH-1) : 0]   : mul_result[(pFP_WIDTH-1):0]       ;

assign fp_add_in_02[0] = (mode_state == mode_iFFT)?   buf_ai[(pFP_WIDTH*2-1) : (pFP_WIDTH)] : a_result  [(pFP_WIDTH*2-1) : (pFP_WIDTH)]      ;
assign fp_add_in_02[1] = (mode_state == mode_iFFT)?   buf_bi[(pFP_WIDTH*2-1) : (pFP_WIDTH)] : mul_result[(pFP_WIDTH*2-1) : (pFP_WIDTH)]    ;

assign fp_add_in_11[0] = (mode_state == mode_iFFT)?                              buf_ai[(pFP_WIDTH-1) : 0] : a_result[(pFP_WIDTH-1):0]         ;
assign fp_add_in_11[1] = (mode_state == mode_iFFT)?   {(~buf_bi[pFP_WIDTH-1]) , buf_bi[(pFP_WIDTH-2) : 0]} : mul_result_inv[(pFP_WIDTH-1):0]   ;

assign fp_add_in_12[0] = (mode_state == mode_iFFT)?                              buf_ai[(pFP_WIDTH*2-1) : pFP_WIDTH]  : a_result[(pFP_WIDTH*2-1):(pFP_WIDTH)]       ;
assign fp_add_in_12[1] = (mode_state == mode_iFFT)?  {(~buf_bi[pFP_WIDTH*2-1]) , buf_bi[(pFP_WIDTH*2-2) : pFP_WIDTH]} : mul_result_inv[(pFP_WIDTH*2-1):(pFP_WIDTH)] ;

assign fp_add_in_valid = (mode_state == mode_iFFT)?  (buf_i_vld & i_vld_en) : mul_out_valid[0] ;

//* In FFT  mode these two fp_add do (  ain + b_in*g  ) 
//* In IFFT mode these two fp_add do (  ain + bin     )
fp_add   fp_add_01( .in_A( fp_add_in_01[0] ) , .in_B( fp_add_in_01[1] ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( fp_add_in_valid )  , .result( fp_add_result[0][(pFP_WIDTH-1):0] )             , .out_valid( fp_add_out_valid[0] ));
fp_add   fp_add_02( .in_A( fp_add_in_02[0] ) , .in_B( fp_add_in_02[1] ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( fp_add_in_valid )  , .result( fp_add_result[0][(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .out_valid( fp_add_out_valid[1] ));

//* In FFT  mode these two fp_add do (  ain - bin*g  )
//* In IFFT mode these two fp_add do (  ain - bin    )
fp_add   fp_add_11( .in_A( fp_add_in_11[0] ) , .in_B( fp_add_in_11[1] ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( fp_add_in_valid )  , .result( fp_add_result[1][(pFP_WIDTH-1):0] )             , .out_valid( fp_add_out_valid[2] ));
fp_add   fp_add_12( .in_A( fp_add_in_12[0] ) , .in_B( fp_add_in_12[1] ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( fp_add_in_valid )  , .result( fp_add_result[1][(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .out_valid( fp_add_out_valid[3] ));


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  iFFT's div operation                                                                               //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//=====================================================================================================================================================================//
//  * IFFT_result[1] = ((ai+bi)*conj(w))/2                                                                                                                             //
//  * IFFT_result[0] = (ai+bi)/2                                                                                                                                       //
//=====================================================================================================================================================================//
// * exponent of complex (ain + bin)/2
assign IFFT_result_exp_im [0] = ( (~(|MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]))   || (&MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]  ))?  MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]   : (MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]   - 1'b1 );
assign IFFT_result_exp_re [0] = ( (~(|MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)])) || (&MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)]))?  MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)] : (MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)] - 1'b1 );
// * exponent of complex (ain - bin) * conj(w)/2
assign IFFT_result_exp_im [1] = ( (~(|mul_result[(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]))   || (&mul_result[(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]   ))?   mul_result[(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]   : (mul_result[(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]   - 1'b1);
assign IFFT_result_exp_re [1] = ( (~(|mul_result[(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)])) || (&mul_result[(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)] ))?   mul_result[(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)] : (mul_result[(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)] - 1'b1);
// * fraction of complex (ain + bin)/2
assign IFFT_result_frac_im[0] = (|MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]  )?  ((|MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-2):(pFP_WIDTH-pEXP_WIDTH)])?      MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-pEXP_WIDTH-2):0]            : {1'b1 , MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-pEXP_WIDTH-2):1]}                ) : {1'b0 , MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-pEXP_WIDTH-2):1] };
assign IFFT_result_frac_re[0] = (|MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)])?  ((|MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH)])?  MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-pEXP_WIDTH-2): pFP_WIDTH] : {1'b1 , MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-pEXP_WIDTH-2): (pFP_WIDTH+1) ]}) : {1'b0 , MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-pEXP_WIDTH-2): (pFP_WIDTH+1)]};
// * fraction of complex (ain - bin) * conj(w)/2
assign IFFT_result_frac_im[1] = (|mul_result[(pFP_WIDTH-2)  :(pFP_WIDTH-pEXP_WIDTH-1)]  )?     ((|mul_result[(pFP_WIDTH-2):(pFP_WIDTH-pEXP_WIDTH)]    )?  mul_result[(pFP_WIDTH-pEXP_WIDTH-2):0]            : {1'b1 , mul_result[(pFP_WIDTH-pEXP_WIDTH-2):1]} )                : {1'b0 , mul_result[(pFP_WIDTH-pEXP_WIDTH-2):1]} ;
assign IFFT_result_frac_re[1] = (|mul_result[(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH-1)])?     ((|mul_result[(pFP_WIDTH*2-2):(pFP_WIDTH*2-pEXP_WIDTH)])?  mul_result[(pFP_WIDTH*2-pEXP_WIDTH-2): pFP_WIDTH] : {1'b1 , mul_result[(pFP_WIDTH*2-pEXP_WIDTH-2): (pFP_WIDTH+1) ]}) : {1'b0 , mul_result[(pFP_WIDTH*2-pEXP_WIDTH-2): (pFP_WIDTH+1) ]};
// * combine into complex format {real , img}
assign cmul_result_ifft[0]    = {MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH*2-1)] , IFFT_result_exp_re[0] , IFFT_result_frac_re[0] , MUL_FIFO[FFT_MUL_LATENCY-1][(pFP_WIDTH-1)] , IFFT_result_exp_im[0] , IFFT_result_frac_im[0] };
assign cmul_result_ifft[1]    = {mul_result[(pFP_WIDTH*2-1)]                  , IFFT_result_exp_re[1] , IFFT_result_frac_re[1] , mul_result[(pFP_WIDTH-1)]                  , IFFT_result_exp_im[1] , IFFT_result_frac_im[1] };


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                  MONT_ADD in NTT/iNTT                                                                               //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
mont_add mont_add_01(.in_A(mul_result[(pNTT_WTDTH-1):0])               , .in_B(a_result[(pNTT_WTDTH-1)  :0])                , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH-1)    :0])             , .out_valid(mont_add_valid_o0[0]));
mont_add mont_add_02(.in_A(mul_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .in_B(a_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])     , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH)])  , .out_valid(mont_add_valid_o0[1]));
mont_add mont_add_03(.in_A(mul_result[(pNTT_WTDTH*3-1):(2*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*3-1):(pNTT_WTDTH*2)])   , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2)]), .out_valid(mont_add_valid_o0[2]));
mont_add mont_add_04(.in_A(mul_result[(pNTT_WTDTH*4-1):(3*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*4-1):(pNTT_WTDTH*3)])   , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3)]), .out_valid(mont_add_valid_o0[3]));
mont_add mont_add_05(.in_A(mul_result[(pNTT_WTDTH*5-1):(4*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*5-1):(pNTT_WTDTH*4)])   , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4)]), .out_valid(mont_add_valid_o0[4]));
mont_add mont_add_06(.in_A(mul_result[(pNTT_WTDTH*6-1):(5*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*6-1):(pNTT_WTDTH*5)])   , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5)]), .out_valid(mont_add_valid_o0[5]));
mont_add mont_add_07(.in_A(mul_result[(pNTT_WTDTH*7-1):(6*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*7-1):(pNTT_WTDTH*6)])   , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6)]), .out_valid(mont_add_valid_o0[6]));
mont_add mont_add_08(.in_A(mul_result[(pNTT_WTDTH*8-1):(7*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*8-1):(pNTT_WTDTH*7)])   , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7)]), .out_valid(mont_add_valid_o0[7]));

mont_sub mont_sub_11(.in_A(a_result[(pNTT_WTDTH-1)  :0])               , .in_B(mul_result[(pNTT_WTDTH-1):0])                , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH-1)    :0])             , .out_valid(mont_add_valid_o1[0]));
mont_sub mont_sub_12(.in_A(a_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])    , .in_B(mul_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])   , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH)])  , .out_valid(mont_add_valid_o1[1]));
mont_sub mont_sub_13(.in_A(a_result[(pNTT_WTDTH*3-1):(pNTT_WTDTH*2)])  , .in_B(mul_result[(pNTT_WTDTH*3-1):(2*pNTT_WTDTH)]) , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2)]), .out_valid(mont_add_valid_o1[2]));
mont_sub mont_sub_14(.in_A(a_result[(pNTT_WTDTH*4-1):(pNTT_WTDTH*3)])  , .in_B(mul_result[(pNTT_WTDTH*4-1):(3*pNTT_WTDTH)]) , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3)]), .out_valid(mont_add_valid_o1[3]));
mont_sub mont_sub_15(.in_A(a_result[(pNTT_WTDTH*5-1):(pNTT_WTDTH*4)])  , .in_B(mul_result[(pNTT_WTDTH*5-1):(4*pNTT_WTDTH)]) , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4)]), .out_valid(mont_add_valid_o1[4]));
mont_sub mont_sub_16(.in_A(a_result[(pNTT_WTDTH*6-1):(pNTT_WTDTH*5)])  , .in_B(mul_result[(pNTT_WTDTH*6-1):(5*pNTT_WTDTH)]) , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5)]), .out_valid(mont_add_valid_o1[5]));
mont_sub mont_sub_17(.in_A(a_result[(pNTT_WTDTH*7-1):(pNTT_WTDTH*6)])  , .in_B(mul_result[(pNTT_WTDTH*7-1):(6*pNTT_WTDTH)]) , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6)]), .out_valid(mont_add_valid_o1[6]));
mont_sub mont_sub_18(.in_A(a_result[(pNTT_WTDTH*8-1):(pNTT_WTDTH*7)])  , .in_B(mul_result[(pNTT_WTDTH*8-1):(7*pNTT_WTDTH)]) , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7)]), .out_valid(mont_add_valid_o1[7]));

// always @(*) begin
//     mont_add_intt[0] = {1'b0, mont_add_result[(pNTT_WTDTH-1)    :1]};
//     mont_add_intt[1] = {1'b0, mont_add_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH+1)]};
//     mont_add_intt[2] = {1'b0, mont_add_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2+1)]};
//     mont_add_intt[3] = {1'b0, mont_add_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3+1)]};
//     mont_add_intt[4] = {1'b0, mont_add_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4+1)]};
//     mont_add_intt[5] = {1'b0, mont_add_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5+1)]};
//     mont_add_intt[6] = {1'b0, mont_add_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6+1)]};
//     mont_add_intt[7] = {1'b0, mont_add_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7+1)]};
// end
// always @(*) begin
//     mont_sub_intt[0] = {1'b0, mont_sub_result[(pNTT_WTDTH-1)    :1]};
//     mont_sub_intt[1] = {1'b0, mont_sub_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH+1)]};
//     mont_sub_intt[2] = {1'b0, mont_sub_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2+1)]};
//     mont_sub_intt[3] = {1'b0, mont_sub_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3+1)]};
//     mont_sub_intt[4] = {1'b0, mont_sub_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4+1)]};
//     mont_sub_intt[5] = {1'b0, mont_sub_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5+1)]};
//     mont_sub_intt[6] = {1'b0, mont_sub_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6+1)]};
//     mont_sub_intt[7] = {1'b0, mont_sub_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7+1)]};
// end
// assign mont_add_intt_result = {mont_add_intt[7], mont_add_intt[6], mont_add_intt[5], mont_add_intt[4], mont_add_intt[3], mont_add_intt[2], mont_add_intt[1], mont_add_intt[0]};
// assign mont_sub_intt_result = {mont_sub_intt[7], mont_sub_intt[6], mont_sub_intt[5], mont_sub_intt[4], mont_sub_intt[3], mont_sub_intt[2], mont_sub_intt[1], mont_sub_intt[0]};

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      Output interface                                                                               //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(*) begin
    case (mode_state) 
    mode_FFT: begin //div 2 in each stage
        ao_buf[0] = fp_add_result[0];
        bo_buf[0] = fp_add_result[1];
    end
    mode_iFFT: begin //execute in exponent module?
        ao_buf[0] = cmul_result_ifft[0];
        bo_buf[0] = cmul_result_ifft[1];
    end
    mode_NTT: begin
        ao_buf[0] = mont_add_result;
        bo_buf[0] = mont_sub_result;
    end
    mode_iNTT: begin //div N in the last stage
        ao_buf[0] = mont_add_result;
        bo_buf[0] = mont_sub_result;
    end
    endcase
    o_vld_buf[0] = (mode_state[1] == 1'b0)? ((mode_state[0])?   mul_out_valid[0] : (fp_add_out_valid[0])) : mont_add_valid_o0[0] ;
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    ao_buf[1]    <= {(pDATA_WIDTH){1'b0}};
    bo_buf[1]    <= {(pDATA_WIDTH){1'b0}};
    o_vld_buf[1] <= 1'b0;
    // ao_buf[2]    <= {(pDATA_WIDTH){1'b0}};
    // bo_buf[2]    <= {(pDATA_WIDTH){1'b0}};
    // o_vld_buf[2] <= 1'b0;
  end else begin
    ao_buf[1]    <= ao_buf[0];
    bo_buf[1]    <= bo_buf[0];
    o_vld_buf[1] <= o_vld_buf[0];
    // ao_buf[2]    <= ao_buf[1];
    // bo_buf[2]    <= bo_buf[1];
    // o_vld_buf[2] <= o_vld_buf[1];
  end
end
assign ao    = ao_buf[1];
assign bo    = bo_buf[1];
assign o_vld = o_vld_buf[1];


// assign ao = (mode_state[1] == 1'b0)? cmul_result[0] : mont_add_result;
// assign bo = (mode_state[1] == 1'b0)? cmul_result[1] : mont_sub_result;


endmodule

