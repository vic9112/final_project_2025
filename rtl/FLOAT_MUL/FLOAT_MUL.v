//author: Jesse
//module: Double Precision Multiplier
//IEEE754 format
//64bit = 1bit |  11bit   | 52bit
//        Sign | Exponent | Mantissa
module FLOAT_MUL (
    input [(BIT-1):0] num1,
    input [(BIT-1):0] num2,
    input clk,
    input rstn,
    output [(BIT-1):0] result,
    input valid,
    output ready
);
localparam BIT = 64;
localparam BIAS = 1023;
localparam EXPONENT_LEN = 11;
localparam MANTISSA_LEN = 52;


//-----pipeline stage: 0-----//
reg [(BIT-1):0]pip0_num1;
reg [(BIT-1):0]pip0_num2;
reg pip0_valid;
always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    pip0_num1 <= 0;
    pip0_num2 <= 0;
    pip0_valid <= 0;
  end else begin
    pip0_num1 <= num1;
    pip0_num2 <= num2;
    pip0_valid <= valid;
  end
end
//---------------------------//

//-----pipeline stage: 1-----//
//this stage is input buffer
reg pip1_sign1;
reg pip1_sign2;
reg pip1_valid;
reg [(EXPONENT_LEN-1):0] pip1_exponent1;
reg [(EXPONENT_LEN-1):0] pip1_exponent2;
reg pip1_zero;
wire zero;
wire num1_zero;
wire num2_zero;
wire check_denor1;
wire check_denor2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip1_sign1 <= 0;
      pip1_sign2 <= 0;
      pip1_valid <= 0;
      pip1_exponent1 <= 0;
      pip1_exponent2 <= 0;
      pip1_zero <= 0;
    end else begin
      pip1_sign1 <= pip0_num1[63];
      pip1_sign2 <= pip0_num2[63];
      pip1_valid <= pip0_valid;
      if (check_denor1) begin   //for denormalize number
        pip1_exponent1 <= 11'd1; //1-BIAS = -1022
      end else begin
        pip1_exponent1 <= pip0_num1[62:52];
      end
      if (check_denor2) begin   //for denormalize number
        pip1_exponent2 <= 11'd1;  //1-BIAS = -1022
      end else begin
        pip1_exponent2 <= pip0_num2[62:52];
      end
      pip1_zero <= zero;
    end
end
assign zero = (num1_zero | num2_zero); //check zero
assign num1_zero = ~(|pip0_num1[62:0]); //check pip0_num1 zero
assign num2_zero = ~(|pip0_num2[62:0]); //check pip0_num2 zero
assign check_denor1 = ~(|pip0_num1[62:52]); //check denormalize number
assign check_denor2 = ~(|pip0_num2[62:52]); //check denormalize number
//53bit: 1bit(leading 1) + 52bit(mantissa)
reg [(MANTISSA_LEN):0] pip1_mantissa1 [(MANTISSA_LEN):0];
reg [(MANTISSA_LEN):0] pip1_mantissa2;
integer i;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      for (i = 0; i < 53; i=i+1) begin
        pip1_mantissa1[i][(MANTISSA_LEN):0] <= 0;
      end
      pip1_mantissa2[(MANTISSA_LEN):0] <= 0;
    end else begin
      for (i = 0; i <= 52; i=i+1) begin //0~51
        if (check_denor1) begin
          pip1_mantissa1[i][(MANTISSA_LEN):0] <= {1'b0, pip0_num1[51:0]};
        end else begin
          pip1_mantissa1[i][(MANTISSA_LEN):0] <= {1'b1, pip0_num1[51:0]};
        end
      end
      if (check_denor2) begin
        pip1_mantissa2[(MANTISSA_LEN):0] <= {1'b0, pip0_num2[51:0]};
      end else begin
        pip1_mantissa2[(MANTISSA_LEN):0] <= {1'b1, pip0_num2[51:0]};
      end
    end
end
//---------------------------//

//-----pipeline stage: 2-----//
//calculate sign, add exponent, anding num1 and num2
reg pip2_sign;
reg pip2_valid;
//1bit(check overflow) + 11bit(exponent)
reg [(EXPONENT_LEN):0] pip2_exponent;
reg pip2_zero;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip2_sign <= 0;
      pip2_exponent <= 0;
      pip2_zero <= 0;
      pip2_valid <= 0;
    end else begin
      pip2_sign <= pip1_sign1 ^ pip1_sign2;
      pip2_exponent <= pip1_exponent1 + pip1_exponent2;
      pip2_zero <= pip1_zero;
      pip2_valid <= pip1_valid;
    end
end
//AND num1 with each bit of num2
reg [(MANTISSA_LEN):0] pip2_mantissa [(MANTISSA_LEN):0];
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      for (i = 0; i < 53; i++) begin
        pip2_mantissa [i][(MANTISSA_LEN):0] <= 0;
      end 
    end else begin
      for (i = 0; i < 53; i++) begin
        pip2_mantissa [i][(MANTISSA_LEN):0] <= pip1_mantissa1[i] & {53{pip1_mantissa2[i]}};
      end
    end
end
//---------------------------//

//-----pipeline stage: 3-----//
reg pip3_sign;
reg pip3_valid;
reg [(EXPONENT_LEN):0]pip3_exponent;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip3_sign <= 0;
      pip3_exponent <= 0;
      pip3_valid <= 0;
    end else begin
      pip3_valid <= pip2_valid;
      if (pip2_zero) begin
        pip3_exponent <= 0;
        pip3_sign <= 0;
      end else begin
        pip3_exponent <= pip2_exponent - BIAS;
        pip3_sign <= pip2_sign;
      end
    end
end
//55bit = 54bit(pip2_mantissa1 shift 1bit) + 53bit(pip2_mantissa1)
//27number
reg [(MANTISSA_LEN+2):0]pip3_mantissa[(MANTISSA_LEN/2):0];
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      for (i = 0; i <= (MANTISSA_LEN/2); i++) begin
        pip3_mantissa[i] <= 0;
      end
    end else begin
      //Group A, B, C
      for (i = 0; i < (MANTISSA_LEN/2); i++) begin
        pip3_mantissa[i] <= pip2_mantissa[2*i] + {pip2_mantissa[2*i+1], 1'b0};
      end
      //Group D
      pip3_mantissa[(MANTISSA_LEN/2)] <= pip2_mantissa[MANTISSA_LEN];
    end
end 
//---------------------------//

//-----pipeline stage: 4-----//
reg pip4_sign;
reg pip4_valid;
reg [(EXPONENT_LEN):0]pip4_exponent;
reg [(MANTISSA_LEN + 4):0]pip4_mantissa[(MANTISSA_LEN/4):0];
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip4_sign <= 0;
      pip4_valid <= 0;
      pip4_exponent <= 0;
      for (i = 0; i <= (MANTISSA_LEN/4); i++) begin
        pip4_mantissa[i] <= 0;
      end
    end else begin
      pip4_sign <= pip3_sign;
      pip4_valid <= pip3_valid;
      pip4_exponent <= pip3_exponent;
      for (i = 0; i < (MANTISSA_LEN/4); i++) begin
        pip4_mantissa[i] <= pip3_mantissa[2*i] + {pip3_mantissa[2*i+1], 2'b00};
      end
      pip4_mantissa[(MANTISSA_LEN/4)] <= pip3_mantissa[(MANTISSA_LEN/2)];
    end
end
//14number
//---------------------------//

//-----pipeline stage: 5-----//
reg pip5_sign;
reg pip5_valid;
reg [(EXPONENT_LEN):0]pip5_exponent;
reg [(MANTISSA_LEN+8):0]pip5_mantissa[7:0];
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip5_sign <= 0;
      pip5_valid <= 0;
      pip5_exponent <= 0;
      for (i = 0; i <= 7; i++) begin
        pip5_mantissa[i] <= 0;
      end
    end else begin
      pip5_sign <= pip4_sign;
      pip5_valid <= pip4_valid;
      pip5_exponent <= pip4_exponent;
      for (i = 0; i <= 5; i++) begin
        pip5_mantissa[i] <= pip4_mantissa[2*i] + {pip4_mantissa[2*i+1], 4'b0000};
      end
      pip5_mantissa[6] <= pip4_mantissa[(MANTISSA_LEN/4)-1];
      pip5_mantissa[7] <= pip4_mantissa[(MANTISSA_LEN/4)];
    end
end
//61bit, 8number
//---------------------------//

//-----pipeline stage: 6-----//
reg pip6_sign;
reg pip6_valid;
reg [(EXPONENT_LEN):0]pip6_exponent;
reg [(MANTISSA_LEN+16):0]pip6_mantissa[4:0];
//69bit, 5number
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip6_sign <= 0;
      pip6_valid <= 0;
      pip6_exponent <= 0;
      for (i = 0; i <= 4; i++) begin
        pip6_mantissa[i] <= 0;
      end
    end else begin
      pip6_sign <= pip5_sign;
      pip6_valid <= pip5_valid;
      pip6_exponent <= pip5_exponent;
      for (i = 0; i <= 2; i++) begin
        pip6_mantissa[i] <= pip5_mantissa[2*i] + {pip5_mantissa[2*i+1], 8'h00};
      end
      pip6_mantissa[3] <= pip5_mantissa[6];
      pip6_mantissa[4] <= pip5_mantissa[7];
    end
end
//---------------------------//

//-----pipeline stage: 7-----//
reg pip7_sign;
reg pip7_valid;
reg [(EXPONENT_LEN):0]pip7_exponent;
reg [(MANTISSA_LEN+32):0]pip7_mantissa[3:0];
//85bit, 4number
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip7_sign <= 0;
      pip7_valid <= 0;
      pip7_exponent <= 0;
      for (i = 0; i <= 3; i++) begin
        pip7_mantissa[i] <= 0;
      end
    end else begin
      pip7_sign <= pip6_sign;
      pip7_valid <= pip6_valid;
      pip7_exponent <= pip6_exponent;
      //Group A
      pip7_mantissa[0] <= pip6_mantissa[0] + {pip6_mantissa[1], 16'h0000};
      //Group B
      pip7_mantissa[1] <= pip6_mantissa[2];
      //Group C
      pip7_mantissa[2] <= pip6_mantissa[3];
      //Group D
      pip7_mantissa[3] <= pip6_mantissa[4];
    end
end
//---------------------------//

//-----pipeline stage: 8-----//
reg pip8_sign;
reg pip8_valid;
reg [(EXPONENT_LEN):0]pip8_exponent;
reg [31:0] pip8_A_remain;
reg [3:0] pip8_C_remain;
reg [53:0]pip8_w; //1bit(carry) + 53bit
reg [16:0]pip8_x; //1bit(carry) + 16bit
reg [16:0]pip8_y; //1bit(carry) + 16bit
reg [37:0]pip8_z; //1bit(carry) + 37bit

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip8_sign <= 0;
      pip8_valid <= 0;
      pip8_exponent <= 0;
      pip8_A_remain <= 0;
      pip8_C_remain <= 0;
      pip8_w <= 0;
      pip8_x <= 0;
      pip8_y <= 0;
      pip8_z <= 0;
    end else begin
      pip8_sign <= pip7_sign;
      pip8_valid <= pip7_valid;
      pip8_exponent <= pip7_exponent;
      pip8_A_remain <= pip7_mantissa[0][31:0];
      pip8_C_remain <= pip7_mantissa[2][3:0];
      pip8_w <= pip7_mantissa[0][84:48] + pip7_mantissa[1][68:16];
      pip8_x <= pip7_mantissa[0][47:32] + pip7_mantissa[1][15:0];
      pip8_y <= pip7_mantissa[2][56:41] + pip7_mantissa[3][52:37];
      pip8_z <= pip7_mantissa[2][40:4] + pip7_mantissa[3][36:0];
    end
end
//---------------------------//

//-----pipeline stage: 9-----//
reg pip9_sign;
reg pip9_valid;
reg [(EXPONENT_LEN):0]pip9_exponent;
reg [101:0]pip9_AB;
reg [57:0]pip9_CD;
wire [53:0]pip9_w;
wire [16:0]pip9_y;
assign pip9_w = pip8_w + pip8_x[16];//add carry
assign pip9_y = pip8_y + pip8_z[37];//add carry
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip9_sign <= 0;
      pip9_valid <= 0;
      pip9_exponent <= 0;
      pip9_AB <= 0;
      pip9_CD <= 0;
    end else begin
      pip9_sign <= pip8_sign;
      pip9_valid <= pip8_valid;
      pip9_exponent <= pip8_exponent;
      pip9_AB <= {pip9_w, pip8_x[15:0], pip8_A_remain};
      pip9_CD <= {pip9_y, pip8_z[36:0], pip8_C_remain};
    end
end
//---------------------------//

//-----pipeline stage: 10----//
reg pip10_sign;
reg pip10_valid;
reg [(EXPONENT_LEN):0]pip10_exponent;
reg [47:0]pip10_AB_remain;
reg [31:0]pip10_n; //32bit = 1bit(carry)+31bit
reg [27:0]pip10_m; //28bit = 1bit(carry)+27bit
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip10_sign <= 0;
      pip10_valid <= 0;
      pip10_exponent <= 0;
      pip10_AB_remain <= 0;
      pip10_n <= 0;
      pip10_m <= 0;
    end else begin
      pip10_sign <= pip9_sign;
      pip10_valid <= pip9_valid;
      pip10_exponent <= pip9_exponent;
      pip10_AB_remain <= pip9_AB[47:0];
      pip10_n <= pip9_AB[78:48] + pip9_CD[30:0];
      pip10_m <= pip9_AB[101:79] + pip9_CD[57:31];
    end
end
//---------------------------//

//-----pipeline stage: 11----//
reg pip11_sign;
reg pip11_valid;
reg [(EXPONENT_LEN):0]pip11_exponent;
wire [26:0]pip11_mn;//27bit (need 1 bit carry?)
reg [105:0]pip11_mantissa;
assign pip11_mn = pip10_m + pip10_n[31];
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip11_sign <= 0;
      pip11_valid <= 0;
      pip11_exponent <= 0;
      pip11_mantissa <= 0;
    end else begin
      pip11_sign <= pip10_sign;
      pip11_valid <= pip10_valid;
      pip11_exponent <= pip10_exponent;
      pip11_mantissa <= {pip11_mn, pip10_n[30:0], pip10_AB_remain};
    end
end 
//---------------------------//

//-----pipeline stage: 12----//
reg pip12_sign;
reg pip12_valid;
reg [(EXPONENT_LEN-1):0]pip12_exponent;
reg [105:0]pip12_mantissa;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip12_sign <= 0;
      pip12_valid <= 0;
      pip12_exponent <= 0;
      pip12_mantissa <= 0;
    end else begin
      pip12_sign <= pip11_sign;
      pip12_valid <= pip11_valid;
      if (pip11_mantissa[105] == 1'b1) begin //normalize
        pip12_exponent <= pip11_exponent + 1'b1;
        pip12_mantissa <= pip11_mantissa >> 1; //shift right
      end else begin
        pip12_exponent <= pip11_exponent;
        pip12_mantissa <= pip11_mantissa;
      end
    end
end
//---------------------------//

//-----pipeline stage: 13----//
reg pip13_sign;
reg pip13_valid;
assign ready = pip13_valid;
reg [(EXPONENT_LEN-1):0]pip13_exponent;
reg [(MANTISSA_LEN-1):0]pip13_mantissa;
wire LSB = pip12_mantissa[52];
wire Guard = pip12_mantissa[51];
wire Round = pip12_mantissa[50];
wire Sticky = |pip12_mantissa[49:0];
wire round_up = Guard & (Round | Sticky | LSB);
always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    pip13_sign <= 0;
    pip13_valid <= 0;
    pip13_exponent <= 0;
    pip13_mantissa <= 0;
  end else begin
    pip13_sign <= pip12_sign;
    pip13_valid <= pip12_valid;
    pip13_exponent <= pip12_exponent;
    if (round_up) begin
      pip13_mantissa <= pip12_mantissa[103:52] + 1;
    end else begin
      pip13_mantissa <= pip12_mantissa[103:52];
    end
  end
end
assign result = {pip13_sign, pip13_exponent, pip13_mantissa};
//---------------------------//
endmodule //IEEE754_64bit_mul