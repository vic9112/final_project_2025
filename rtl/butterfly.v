module butterfly
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers represent real & imaginary part
)
(
    input   wire clk,
    input   wire rst_n,

    input   wire [1:0] mode, // FFT(11)/iFFT(10)/NTT(01)/iNTT(00)

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
localparam mode_FFT  = 2'b11;
localparam mode_iFFT = 2'b10;
localparam mode_NTT  = 2'b01;
localparam mode_iNTT = 2'b00;

localparam NTT_MUL_LATENCY = 17;
localparam FFT_MUL_LATENCY = 22;
//==================================================================================//
localparam pFP_WIDTH            = 64 ;
localparam pNTT_WTDTH           = 16 ;
//==================================================================================//
wire [(pFP_WIDTH-1):0]      gre_inv;
wire [(pFP_WIDTH-1):0]      gim_inv;
wire [(pDATA_WIDTH-1):0]    gm_inv;
reg  [(pDATA_WIDTH-1):0]    a_reg[0:(FFT_MUL_LATENCY-1)];
wire [(pDATA_WIDTH-1):0]    a_result;
wire [(pDATA_WIDTH-1):0]    mul_result_int[0:1];
wire [(pDATA_WIDTH-1):0]    mul_result_com[0:1];
wire [(pDATA_WIDTH-1):0]    mul_result[0:1];
wire                        mul_out_valid[0:1];
wire                        cmul_valid_i[0:1];
wire                        cmul_valid_o[0:1];
wire [(pDATA_WIDTH-1):0]    cmul_result[0:1];
wire                        mont_add_valid_o0[0:7];
wire                        mont_add_valid_o1[0:7];
wire [(pDATA_WIDTH-1):0]    mont_add_result[0:1];
//==================================================================================//

assign gre_inv = {~gm[(pFP_WIDTH*2-1)], gm[(pFP_WIDTH*2-2):pFP_WIDTH]};
assign gim_inv = {~gm[(pFP_WIDTH-1)], gm[(pFP_WIDTH-2):0]};
assign gm_inv  = {gre_inv, gim_inv};


integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < FFT_MUL_LATENCY; i = i + 1) begin
          a_reg <= {(pDATA_WIDTH){1'b0}};
        end
    end else begin
        a_reg <= ai;
        for (i = 1; i < FFT_MUL_LATENCY; i = i + 1) begin
          a_reg[i] <= a_reg[i-1];
        end
    end
end
mul mul1(
    .in_A(bi),
    .in_B(gm),
    .mode(mode[1]), // * set mode = 0 to do complex mul ， mode = 1 to do int mul
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(i_vld),
    .result_c(mul_result_com[0]),  
    .result_int(mul_result_int[0]),
    .out_valid(mul_out_valid[0])
);
assign mul_result[0] = (mode[1] == mode_FFT )? mul_result_com[0]:mul_result_int[0];

mul mul2(
    .in_A(bi),
    .in_B(gm_inv),
    .mode(mode[1]), // * set mode = 0 to do complex mul ， mode = 1 to do int mul
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(i_vld),
    .result_c(mul_result_com[1]),  
    .result_int(mul_result_int[1]),
    .out_valid(mul_out_valid[1])
);
assign mul_result[1] = (mode[1] == 1'b1 )? mul_result_com[1]:mul_result_int[1];
assign a_result = (mode[1] == 1'b1)? a_reg[(FFT_MUL_LATENCY-1)]:a_reg[(NTT_MUL_LATENCY-1)];

fp_add   fp_add_01( .in_A( a_result ) , .in_B( mul_result[0][(pFP_WIDTH-1):0] )                 , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[0] )  , .result( cmul_result[0][(pFP_WIDTH-1):0] )             , .out_valid( cmul_valid_o[0] ));
fp_add   fp_add_02( .in_A( a_result ) , .in_B( mul_result[0][(pFP_WIDTH*2-1):(pFP_WIDTH)] )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[1] )  , .result( cmul_result[0][(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .out_valid( cmul_valid_o[1] ));
fp_add   fp_add_11( .in_A( a_result ) , .in_B( mul_result[1][(pFP_WIDTH-1):0] )                 , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[0] )  , .result( cmul_result[1][(pFP_WIDTH-1):0] )             , .out_valid( cmul_valid_o[0] ));
fp_add   fp_add_12( .in_A( a_result ) , .in_B( mul_result[1][(pFP_WIDTH*2-1):(pFP_WIDTH)] )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[1] )  , .result( cmul_result[1][(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .out_valid( cmul_valid_o[1] ));

mont_add mont_add_01(.in_A(mul_result[0][(pNTT_WTDTH-1):0])               , .in_B(a_result[(pNTT_WTDTH-1)  :0])             , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH-1)    :0])             , .out_valid(mont_add_valid_o0[0]));
mont_add mont_add_02(.in_A(mul_result[0][(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .in_B(a_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH*2-1)  :(pNTT_WTDTH)])  , .out_valid(mont_add_valid_o0[1]));
mont_add mont_add_03(.in_A(mul_result[0][(pNTT_WTDTH*3-1):(2*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*3-1):(pNTT_WTDTH*2)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2)]), .out_valid(mont_add_valid_o0[2]));
mont_add mont_add_04(.in_A(mul_result[0][(pNTT_WTDTH*4-1):(3*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*4-1):(pNTT_WTDTH*3)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3)]), .out_valid(mont_add_valid_o0[3]));
mont_add mont_add_05(.in_A(mul_result[0][(pNTT_WTDTH*5-1):(4*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*5-1):(pNTT_WTDTH*4)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4)]), .out_valid(mont_add_valid_o0[4]));
mont_add mont_add_06(.in_A(mul_result[0][(pNTT_WTDTH*6-1):(5*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*6-1):(pNTT_WTDTH*5)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5)]), .out_valid(mont_add_valid_o0[5]));
mont_add mont_add_07(.in_A(mul_result[0][(pNTT_WTDTH*7-1):(6*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*7-1):(pNTT_WTDTH*6)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6)]), .out_valid(mont_add_valid_o0[6]));
mont_add mont_add_08(.in_A(mul_result[0][(pNTT_WTDTH*8-1):(7*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*8-1):(pNTT_WTDTH*7)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[0][(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7)]), .out_valid(mont_add_valid_o0[7]));

mont_add mont_add_11(.in_A(mul_result[1][(pNTT_WTDTH-1):0])               , .in_B(a_result[(pNTT_WTDTH-1)  :0])             , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH-1)    :0])             , .out_valid(mont_add_valid_o1[0]));
mont_add mont_add_12(.in_A(mul_result[1][(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .in_B(a_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH*2-1)  :(pNTT_WTDTH)])  , .out_valid(mont_add_valid_o1[1]));
mont_add mont_add_13(.in_A(mul_result[1][(pNTT_WTDTH*3-1):(2*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*3-1):(pNTT_WTDTH*2)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2)]), .out_valid(mont_add_valid_o1[2]));
mont_add mont_add_14(.in_A(mul_result[1][(pNTT_WTDTH*4-1):(3*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*4-1):(pNTT_WTDTH*3)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3)]), .out_valid(mont_add_valid_o1[3]));
mont_add mont_add_15(.in_A(mul_result[1][(pNTT_WTDTH*5-1):(4*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*5-1):(pNTT_WTDTH*4)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4)]), .out_valid(mont_add_valid_o1[4]));
mont_add mont_add_16(.in_A(mul_result[1][(pNTT_WTDTH*6-1):(5*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*6-1):(pNTT_WTDTH*5)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5)]), .out_valid(mont_add_valid_o1[5]));
mont_add mont_add_17(.in_A(mul_result[1][(pNTT_WTDTH*7-1):(6*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*7-1):(pNTT_WTDTH*6)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6)]), .out_valid(mont_add_valid_o1[6]));
mont_add mont_add_18(.in_A(mul_result[1][(pNTT_WTDTH*8-1):(7*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*8-1):(pNTT_WTDTH*7)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_add_result[1][(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7)]), .out_valid(mont_add_valid_o1[7]));

assign ao = (mode == 1'b1)? cmul_result[0] : mont_add_result[0];
assign bo = (mode == 1'b1)? cmul_result[1] : mont_add_result[1];
assign o_vld = (mode == 1'b1)? mul_out_valid[0] & mul_out_valid[1] : mont_add_valid_o0[0] ;
    // complex mul & add & sub for FFT/iFFT

    // Complex Multiplication:
    // y_re = (a_re * b_re) - (a_im * b_im)
    // y_im = (a_re * b_im) + (a_im * b_re)
    // Rewrite as:
    // y_re = a_re * (b_re - b_im) + b_im * (a_re - a_im)
    // y_im = a_im * (b_re + b_im) + b_im * (a_re - a_im)
    // It will reduce the mul usage from 4 to 3 since we reuse [b_im * (a_re - a_im)]

    // montgomery mul & add & sub for NTT/iNTT

endmodule

