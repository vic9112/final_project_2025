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
    output  reg  [(pDATA_WIDTH-1):0] ao,
    output  reg  [(pDATA_WIDTH-1):0] bo

);
//==================================================================================//

localparam NTT_MUL_LATENCY = 17;
localparam FFT_MUL_LATENCY = 20;

localparam NTT_LATENCY     = 22;
localparam iNTT_LATENCY    = 22;//?
localparam FFT_LATENCY     = 28;
localparam iFFT_LATENCY    = 28;//?


localparam mode_NTT        = 2'b10;
localparam mode_iNTT       = 2'b11;
localparam mode_FFT        = 2'b00;
localparam mode_iFFT       = 2'b01;

localparam FFT_WAIT  = 3'b000;
localparam iFFT_WAIT = 3'b001;
localparam NTT_WAIT  = 3'b010;
localparam iNTT_WAIT = 3'b011;
localparam READY     = 3'b111;
//==================================================================================//
localparam pFP_WIDTH            = 64 ;
localparam pNTT_WTDTH           = 16 ;
localparam pEXP_WIDTH           = 11 ;
//==================================================================================//
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
//==================================================================================//
reg  [4:0]                  count;
reg                         pass;
reg  [(pDATA_WIDTH-1):0]    a_reg[0:(FFT_MUL_LATENCY-1)];
wire [(pDATA_WIDTH-1):0]    a_result;
wire [(pDATA_WIDTH-1):0]    mul_result_int;
wire [(pDATA_WIDTH-1):0]    mul_result_com;
wire [(pDATA_WIDTH-1):0]    mul_result;
wire [(pFP_WIDTH-1):0]      mul_result_re_inv;
wire [(pFP_WIDTH-1):0]      mul_result_im_inv;
wire [(pDATA_WIDTH-1):0]    mul_result_inv;
wire                        mul_out_valid[0:1];
wire                        cmul_valid_i[0:1];
wire                        cmul_valid_o[0:1];
wire [(pDATA_WIDTH-1):0]    cmul_result[0:1];
wire [(pDATA_WIDTH-1):0]    cmul_result_ifft[0:1];
wire [(pEXP_WIDTH-1):0]     cmul_result_exp[0:1];
wire                        mont_add_valid_o0[0:7];
wire                        mont_add_valid_o1[0:7];
wire [(pDATA_WIDTH-1):0]    mont_add_result;
wire [(pDATA_WIDTH-1):0]    mont_sub_result;
reg  [(pNTT_WTDTH-1):0]     mont_add_intt[0:7];
reg  [(pNTT_WTDTH-1):0]     mont_sub_intt[0:7];
wire [(pDATA_WIDTH-1):0]    mont_add_intt_result;
wire [(pDATA_WIDTH-1):0]    mont_sub_intt_result;
//==================================================================================//


//==================================================================================//
//state control
//i_rdy controller
reg trans_en;
always @(*) begin
    if (i_vld && (mode_state != mode)) begin
        case (state)
        READY: begin
            trans_en = 1'b0;
            if (mode == mode_FFT) begin
                state_next = FFT_WAIT;
                buf_en = 1'b1;
                i_vld_en = 1'b0;
            end else if (mode == mode_iFFT) begin
                state_next = iFFT_WAIT;
                buf_en = 1'b1;
                i_vld_en = 1'b0;
            end else if (mode == mode_NTT) begin
                state_next = NTT_WAIT;
                buf_en = 1'b1;
                i_vld_en = 1'b0;
            end else if (mode == mode_iNTT) begin
                state_next = iNTT_WAIT;
                buf_en = 1'b1;
                i_vld_en = 1'b0;
            end else begin
                state_next = READY;
                buf_en = 1'b0;
                i_vld_en = 1'b1;
            end
        end
        FFT_WAIT: begin
          buf_en = 1'b0;
          i_vld_en = 1'b0;
          if (count == FFT_LATENCY - 1) begin
            state_next = READY;
            trans_en = 1'b1;
          end else begin
            state_next = state;
            trans_en = 1'b0;
          end
        end
        iFFT_WAIT: begin
          buf_en = 1'b0;
          i_vld_en = 1'b0;
          if (count == iFFT_LATENCY - 1) begin
            state_next = READY;
            trans_en = 1'b1;
          end else begin
            state_next = state;
            trans_en = 1'b0;
          end
        end
        NTT_WAIT: begin
          buf_en = 1'b0;
          i_vld_en = 1'b0;
          if (count == NTT_LATENCY - 1) begin
            state_next = READY;
            trans_en = 1'b1;
          end else begin
            state_next = state;
            trans_en = 1'b0;
          end
        end
        iNTT_WAIT: begin
          buf_en = 1'b0;
          i_vld_en = 1'b0;
          if (count == iNTT_LATENCY - 1) begin
            state_next = READY;
            trans_en = 1'b1;
          end else begin
            state_next = state;
            trans_en = 1'b0;
          end
        end 
        endcase
    end else begin
        state_next = state;
        trans_en = 1'b0;
        buf_en = (state == READY)? 1'b1:1'b0;
        i_vld_en = (state == READY)? 1'b1:1'b0;
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
      buf_ai <= {(pDATA_WIDTH){1'b0}};
      buf_bi <= {(pDATA_WIDTH){1'b0}};
      buf_gm <= {(pDATA_WIDTH){1'b0}};
      buf_i_vld <= 1'b0;
    end else if (buf_en) begin
      buf_ai <= ai;
      buf_bi <= bi;
      buf_gm <= gm;
      buf_i_vld <= i_vld & i_rdy;
    end else begin
      buf_ai <= buf_ai;
      buf_bi <= buf_bi;
      buf_gm <= buf_gm;
      buf_i_vld <= buf_i_vld;
    end
end

//==================================================================================//
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < FFT_MUL_LATENCY; i = i + 1) begin
          a_reg[i] <= {(pDATA_WIDTH){1'b0}};
        end
    end else begin
        a_reg[0] <= buf_ai;
        for (i = 1; i < FFT_MUL_LATENCY; i = i + 1) begin
          a_reg[i] <= a_reg[i-1];
        end
    end
end
//bi * gm
mul mul1(
    .in_A(buf_bi),
    .in_B(buf_gm),
    .mode(mode_state), // * set mode = 0 to do complex mul ， mode = 1 to do int mul
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(buf_i_vld & i_vld_en),
    .result_c(mul_result_com),  
    .result_int(mul_result_int),
    .out_valid(mul_out_valid[0])
);
assign mul_result = (mode_state[1] == 1'b0 )? mul_result_com:mul_result_int;


assign mul_result_re_inv = {~mul_result_com[(pFP_WIDTH*2-1)], mul_result_com[(pFP_WIDTH*2-2):pFP_WIDTH]};
assign mul_result_im_inv = {~mul_result_com[(pFP_WIDTH-1)]  , mul_result_com[(pFP_WIDTH-2):0]};
assign mul_result_inv = {mul_result_re_inv, mul_result_im_inv};

assign a_result = (mode_state[1] == 1'b0)? a_reg[(FFT_MUL_LATENCY-1)]:a_reg[(NTT_MUL_LATENCY-1)];

fp_add   fp_add_01( .in_A( a_result[(pFP_WIDTH-1):0] )             , .in_B( mul_result[(pFP_WIDTH-1)  :0] )               , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[0] )  , .result( cmul_result[0][(pFP_WIDTH-1):0] )             , .out_valid( cmul_valid_o[0] ));
fp_add   fp_add_02( .in_A( a_result[(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .in_B( mul_result[(pFP_WIDTH*2-1):(pFP_WIDTH)] )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[0] )  , .result( cmul_result[0][(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .out_valid( cmul_valid_o[1] ));
fp_add   fp_add_11( .in_A( a_result[(pFP_WIDTH-1):0] )             , .in_B( mul_result_inv[(pFP_WIDTH-1):0] )                 , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[0] )  , .result( cmul_result[1][(pFP_WIDTH-1):0] )             , .out_valid( cmul_valid_o[0] ));
fp_add   fp_add_12( .in_A( a_result[(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .in_B( mul_result_inv[(pFP_WIDTH*2-1):(pFP_WIDTH)] )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( mul_out_valid[0] )  , .result( cmul_result[1][(pFP_WIDTH*2-1):(pFP_WIDTH)] ) , .out_valid( cmul_valid_o[1] ));
assign cmul_result_exp[0] = cmul_result[0][(pFP_WIDTH-2):(pFP_WIDTH-1-pEXP_WIDTH)] - 1'b1;
assign cmul_result_exp[1] = cmul_result[1][(pFP_WIDTH-2):(pFP_WIDTH-1-pEXP_WIDTH)] - 1'b1;
assign  cmul_result_ifft[0] = {cmul_result[0][(pFP_WIDTH-1)], cmul_result_exp[0], cmul_result[0][(pFP_WIDTH-pEXP_WIDTH-2):0]};
assign  cmul_result_ifft[1] = {cmul_result[1][(pFP_WIDTH-1)], cmul_result_exp[1], cmul_result[1][(pFP_WIDTH-pEXP_WIDTH-2):0]};

mont_add mont_add_01(.in_A(mul_result[(pNTT_WTDTH-1):0])               , .in_B(a_result[(pNTT_WTDTH-1)  :0])             , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH-1)    :0])             , .out_valid(mont_add_valid_o0[0]));
mont_add mont_add_02(.in_A(mul_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .in_B(a_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH)])  , .out_valid(mont_add_valid_o0[1]));
mont_add mont_add_03(.in_A(mul_result[(pNTT_WTDTH*3-1):(2*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*3-1):(pNTT_WTDTH*2)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2)]), .out_valid(mont_add_valid_o0[2]));
mont_add mont_add_04(.in_A(mul_result[(pNTT_WTDTH*4-1):(3*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*4-1):(pNTT_WTDTH*3)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3)]), .out_valid(mont_add_valid_o0[3]));
mont_add mont_add_05(.in_A(mul_result[(pNTT_WTDTH*5-1):(4*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*5-1):(pNTT_WTDTH*4)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4)]), .out_valid(mont_add_valid_o0[4]));
mont_add mont_add_06(.in_A(mul_result[(pNTT_WTDTH*6-1):(5*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*6-1):(pNTT_WTDTH*5)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5)]), .out_valid(mont_add_valid_o0[5]));
mont_add mont_add_07(.in_A(mul_result[(pNTT_WTDTH*7-1):(6*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*7-1):(pNTT_WTDTH*6)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6)]), .out_valid(mont_add_valid_o0[6]));
mont_add mont_add_08(.in_A(mul_result[(pNTT_WTDTH*8-1):(7*pNTT_WTDTH)]), .in_B(a_result[(pNTT_WTDTH*8-1):(pNTT_WTDTH*7)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[0]), .result(mont_add_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7)]), .out_valid(mont_add_valid_o0[7]));

mont_sub mont_sub_11(.in_A(a_result[(pNTT_WTDTH-1)  :0])             , .in_B(mul_result[(pNTT_WTDTH-1):0])               , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH-1)    :0])             , .out_valid(mont_add_valid_o1[0]));
mont_sub mont_sub_12(.in_A(a_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .in_B(mul_result[(pNTT_WTDTH*2-1):(pNTT_WTDTH)])  , .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH)])  , .out_valid(mont_add_valid_o1[1]));
mont_sub mont_sub_13(.in_A(a_result[(pNTT_WTDTH*3-1):(pNTT_WTDTH*2)]), .in_B(mul_result[(pNTT_WTDTH*3-1):(2*pNTT_WTDTH)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2)]), .out_valid(mont_add_valid_o1[2]));
mont_sub mont_sub_14(.in_A(a_result[(pNTT_WTDTH*4-1):(pNTT_WTDTH*3)]), .in_B(mul_result[(pNTT_WTDTH*4-1):(3*pNTT_WTDTH)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3)]), .out_valid(mont_add_valid_o1[3]));
mont_sub mont_sub_15(.in_A(a_result[(pNTT_WTDTH*5-1):(pNTT_WTDTH*4)]), .in_B(mul_result[(pNTT_WTDTH*5-1):(4*pNTT_WTDTH)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4)]), .out_valid(mont_add_valid_o1[4]));
mont_sub mont_sub_16(.in_A(a_result[(pNTT_WTDTH*6-1):(pNTT_WTDTH*5)]), .in_B(mul_result[(pNTT_WTDTH*6-1):(5*pNTT_WTDTH)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5)]), .out_valid(mont_add_valid_o1[5]));
mont_sub mont_sub_17(.in_A(a_result[(pNTT_WTDTH*7-1):(pNTT_WTDTH*6)]), .in_B(mul_result[(pNTT_WTDTH*7-1):(6*pNTT_WTDTH)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6)]), .out_valid(mont_add_valid_o1[6]));
mont_sub mont_sub_18(.in_A(a_result[(pNTT_WTDTH*8-1):(pNTT_WTDTH*7)]), .in_B(mul_result[(pNTT_WTDTH*8-1):(7*pNTT_WTDTH)]), .clk(clk), .rst_n(rst_n), .in_valid(mul_out_valid[1]), .result(mont_sub_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7)]), .out_valid(mont_add_valid_o1[7]));

always @(*) begin
    mont_add_intt[0] = {1'b0, mont_add_result[(pNTT_WTDTH-1)    :1]};
    mont_add_intt[1] = {1'b0, mont_add_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH+1)]};
    mont_add_intt[2] = {1'b0, mont_add_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2+1)]};
    mont_add_intt[3] = {1'b0, mont_add_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3+1)]};
    mont_add_intt[4] = {1'b0, mont_add_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4+1)]};
    mont_add_intt[5] = {1'b0, mont_add_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5+1)]};
    mont_add_intt[6] = {1'b0, mont_add_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6+1)]};
    mont_add_intt[7] = {1'b0, mont_add_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7+1)]};
end
always @(*) begin
    mont_sub_intt[0] = {1'b0, mont_sub_result[(pNTT_WTDTH-1)    :1]};
    mont_sub_intt[1] = {1'b0, mont_sub_result[(pNTT_WTDTH*2-1)  :(pNTT_WTDTH+1)]};
    mont_sub_intt[2] = {1'b0, mont_sub_result[(pNTT_WTDTH*3-1)  :(pNTT_WTDTH*2+1)]};
    mont_sub_intt[3] = {1'b0, mont_sub_result[(pNTT_WTDTH*4-1)  :(pNTT_WTDTH*3+1)]};
    mont_sub_intt[4] = {1'b0, mont_sub_result[(pNTT_WTDTH*5-1)  :(pNTT_WTDTH*4+1)]};
    mont_sub_intt[5] = {1'b0, mont_sub_result[(pNTT_WTDTH*6-1)  :(pNTT_WTDTH*5+1)]};
    mont_sub_intt[6] = {1'b0, mont_sub_result[(pNTT_WTDTH*7-1)  :(pNTT_WTDTH*6+1)]};
    mont_sub_intt[7] = {1'b0, mont_sub_result[(pNTT_WTDTH*8-1)  :(pNTT_WTDTH*7+1)]};
end
assign mont_add_intt_result = {mont_add_intt[7], mont_add_intt[6], mont_add_intt[5], mont_add_intt[4], mont_add_intt[3], mont_add_intt[2], mont_add_intt[1], mont_add_intt[0]};
assign mont_sub_intt_result = {mont_sub_intt[7], mont_sub_intt[6], mont_sub_intt[5], mont_sub_intt[4], mont_sub_intt[3], mont_sub_intt[2], mont_sub_intt[1], mont_sub_intt[0]};

always @(*) begin
    case (mode_state) 
    mode_FFT: begin
        ao = cmul_result[0];
        bo = cmul_result[1];
    end
    mode_iFFT: begin //execute in exponent module?
        ao = cmul_result_ifft[0];
        bo = cmul_result_ifft[1];
    end
    mode_NTT: begin
        ao = mont_add_result;
        bo = mont_sub_result;
    end
    mode_iNTT: begin
        ao = mont_add_intt_result;
        bo = mont_sub_intt_result;
    end
    endcase
end

// assign ao = (mode_state[1] == 1'b0)? cmul_result[0] : mont_add_result;
// assign bo = (mode_state[1] == 1'b0)? cmul_result[1] : mont_sub_result;
assign o_vld = (mode_state[1] == 1'b0)? cmul_valid_o[0] & cmul_valid_o[1] : mont_add_valid_o0[0] ;
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

