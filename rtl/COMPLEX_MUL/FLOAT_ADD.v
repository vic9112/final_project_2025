//author: Jesse
//module: Double Precision Adder
//IEEE754 format
//64bit = 1bit |  11bit   | 52bit
//        Sign | Exponent | Mantissa
module FLOAT_ADD (
    input [63:0] num1,
    input [63:0] num2,
    input clk,
    input rstn,
    input valid,
    output [63:0] result,
    output ready
);
localparam BIT = 64;
localparam BIAS = 1023;
localparam EXPONENT_LEN = 11;
localparam MANTISSA_LEN = 52;

//-----pipeline stage: 1-----//
//input buffer
reg pip1_sign1;
reg pip1_sign2;
reg pip1_valid;
reg [(EXPONENT_LEN-1):0] pip1_exponent1;
reg [(EXPONENT_LEN-1):0] pip1_exponent2;
reg [(MANTISSA_LEN-1):0] pip1_mantissa1;
reg [(MANTISSA_LEN-1):0] pip1_mantissa2;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip1_sign1 <= 0;
      pip1_sign2 <= 0;
      pip1_exponent1 <= 0;
      pip1_exponent2 <= 0;
      pip1_mantissa1 <= 0;
      pip1_mantissa2 <= 0;
      pip1_valid <= 0;
    end else begin
      pip1_sign1 <= num1[63];
      pip1_sign2 <= num2[63];
      pip1_exponent1 <= num1[62:52];
      pip1_exponent2 <= num2[62:52];
      pip1_mantissa1 <= num1[51:0];
      pip1_mantissa2 <= num2[51:0];
      pip1_valid <= valid;
    end
end
//---------------------------//

//-----pipeline stage: 2-----//
reg pip2_sign1;
reg pip2_sign2;
reg pip2_valid;
reg [(EXPONENT_LEN-1):0]pip2_exponent1;
reg [(EXPONENT_LEN-1):0]pip2_exponent2;
reg signed [(EXPONENT_LEN):0]pip2_exponent_diff;
reg [(MANTISSA_LEN):0]pip2_mantissa1;
reg [(MANTISSA_LEN):0]pip2_mantissa2;
wire check_denor1;
wire check_denor2;
assign check_denor1 = ~(|pip1_exponent1); //check denormalize number
assign check_denor2 = ~(|pip1_exponent2); //check denormalize number
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip2_sign1 <= 0;
      pip2_sign2 <= 0;
      pip2_valid <= 0;
      pip2_exponent1 <= 0;
      pip2_exponent2 <= 0;
      pip2_mantissa1 <= 0;
      pip2_mantissa2 <= 0;
      pip2_exponent_diff <= 0;
    end else begin
      pip2_sign1 <= pip1_sign1;
      pip2_sign2 <= pip1_sign2;
      pip2_valid <= pip1_valid;
      pip2_exponent1 <= pip1_exponent1;
      pip2_exponent2 <= pip1_exponent2;
      pip2_exponent_diff <= pip1_exponent1 - pip1_exponent2;
      if (check_denor1) begin
        pip2_mantissa1 <= {1'b0, pip1_mantissa1};
      end else begin
        pip2_mantissa1 <= {1'b1, pip1_mantissa1};
      end
      if (check_denor2) begin
        pip2_mantissa2 <= {1'b0, pip1_mantissa2};
      end else begin
        pip2_mantissa2 <= {1'b1, pip1_mantissa2};
      end
    end
end
//---------------------------//

//-----pipeline stage: 3-----//
//align binary point, rounding
reg pip3_sign1;
reg pip3_sign2;
reg pip3_valid;
reg [(EXPONENT_LEN-1):0]pip3_exponent1;
reg [(EXPONENT_LEN-1):0]pip3_exponent2;
reg [(MANTISSA_LEN):0]pip3_mantissa1;
reg [(MANTISSA_LEN):0]pip3_mantissa2;
wire [(MANTISSA_LEN+52):0]pip2_mantissa1_shift;
wire [(MANTISSA_LEN+52):0]pip2_mantissa2_shift;
wire [(MANTISSA_LEN+52):0]pip2_mantissa1_shifted;
wire [(MANTISSA_LEN+52):0]pip2_mantissa2_shifted;
wire [(MANTISSA_LEN):0]pip3_mantissa1_tmp;
wire [(MANTISSA_LEN):0]pip3_mantissa2_tmp;
reg [(MANTISSA_LEN):0]pip3_mantissa1_next;
reg [(MANTISSA_LEN):0]pip3_mantissa2_next;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip3_sign1 <= 0;
      pip3_sign2 <= 0;
      pip3_exponent1 <= 0;
      pip3_exponent2 <= 0;
      pip3_mantissa1 <= 0;
      pip3_mantissa2 <= 0;
      pip3_valid <= 0;
    end else begin
      pip3_sign1 <= pip2_sign1;
      pip3_sign2 <= pip2_sign2;
      pip3_valid <= pip2_valid;
      if (pip2_exponent_diff >= 0) begin //exponent1>exponent2
        pip3_exponent1 <= pip2_exponent1;
        pip3_exponent2 <= pip2_exponent1;
        pip3_mantissa1 <= pip2_mantissa1;
        //pip3_mantissa2 <= pip2_mantissa2 >> pip2_exponent_diff;
        pip3_mantissa2 <= pip3_mantissa2_next;
      end else begin //exponent1<exponent2
        pip3_exponent1 <= pip2_exponent2;
        pip3_exponent2 <= pip2_exponent2;
        //pip3_mantissa1 <= pip2_mantissa1 >> -pip2_exponent_diff;
        pip3_mantissa1 <= pip3_mantissa1_next;
        pip3_mantissa2 <= pip2_mantissa2;
      end
    end
end

assign pip2_mantissa1_shift = {pip2_mantissa1, 52'b0};
assign pip2_mantissa2_shift = {pip2_mantissa2, 52'b0};
assign pip2_mantissa1_shifted = pip2_mantissa1_shift >> -pip2_exponent_diff;
assign pip2_mantissa2_shifted = pip2_mantissa2_shift >> pip2_exponent_diff;
assign pip3_mantissa1_tmp = pip2_mantissa1_shifted[(MANTISSA_LEN+52):52];
assign pip3_mantissa2_tmp = pip2_mantissa2_shifted[(MANTISSA_LEN+52):52];
wire LSB_1 = pip2_mantissa1_shifted[52];
wire Guard_1 = pip2_mantissa1_shifted[51];
wire Round_1 = pip2_mantissa1_shifted[50];
wire Sticky_1 = |pip2_mantissa1_shifted[49:0];
wire LSB_2 = pip2_mantissa2_shifted[52];
wire Guard_2 = pip2_mantissa2_shifted[51];
wire Round_2 = pip2_mantissa2_shifted[50];
wire Sticky_2 = |pip2_mantissa2_shifted[49:0];
wire round_up1 = Guard_1 & (Round_1 | Sticky_1 | LSB_1);
wire round_up2 = Guard_2 & (Round_2 | Sticky_2 | LSB_2);
always @(*) begin
  if (round_up1) begin
    pip3_mantissa1_next = pip3_mantissa1_tmp + 1;
  end else begin
    pip3_mantissa1_next = pip3_mantissa1_tmp;
  end
  if (round_up2) begin
    pip3_mantissa2_next = pip3_mantissa2_tmp + 1;
  end else begin
    pip3_mantissa2_next = pip3_mantissa2_tmp;
  end
end
//---------------------------//

//-----pipeline stage: 4-----//
reg pip4_sign1;
reg pip4_sign2;
reg [(EXPONENT_LEN-1):0]pip4_exponent1;
reg [(EXPONENT_LEN-1):0]pip4_exponent2;
reg [(MANTISSA_LEN):0]pip4_mantissaA;
reg [(MANTISSA_LEN):0]pip4_mantissaB;
reg pip4_compare; //compare mantissa1 and mantissa2
reg pip4_valid;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pip4_sign1 <= 0;
      pip4_sign2 <= 0;
      pip4_exponent1 <= 0;
      pip4_exponent2 <= 0;
      pip4_mantissaA <= 0;
      pip4_mantissaB <= 0;
      pip4_compare <= 0;
      pip4_valid <= 0;
    end else begin
      pip4_sign1 <= pip3_sign1;
      pip4_sign2 <= pip3_sign2;
      pip4_exponent1 <= pip3_exponent1;
      pip4_exponent2 <= pip3_exponent2;
      pip4_valid <= pip3_valid;
      case ({pip3_sign1, pip3_sign2})
        2'b00: begin
          pip4_mantissaA <= pip3_mantissa1;
          pip4_mantissaB <= pip3_mantissa2;
        end
        2'b01: begin
          pip4_mantissaA <= pip3_mantissa1;
          pip4_mantissaB <= pip3_mantissa2;
        end
        2'b10: begin
          pip4_mantissaA <= pip3_mantissa2;
          pip4_mantissaB <= pip3_mantissa1;
        end
        2'b11: begin
          pip4_mantissaA <= pip3_mantissa1;
          pip4_mantissaB <= pip3_mantissa2;
        end
        default: begin
          pip4_mantissaA <= pip3_mantissa1;
          pip4_mantissaB <= pip3_mantissa2;
        end
      endcase
      pip4_compare <= (pip3_mantissa1 > pip3_mantissa2)? 1:0;
    end
end
//---------------------------//

//-----pipeline stage: 5-----//
reg pip5_sign;
reg pip5_valid;
reg [(EXPONENT_LEN-1):0]pip5_exponent;
reg signed [(MANTISSA_LEN+1):0]pip5_mantissa;//2bit(integer)+52bit(float point)
reg pip5_complement;
reg signed [(MANTISSA_LEN+1):0]pip5_add;
reg signed [(MANTISSA_LEN+1):0]pip5_sub;
reg pip5_sign_tmp;
reg pip5_complement_tmp;

always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    pip5_sign <= 0;
    pip5_exponent <= 0;
    pip5_complement <= 0;
    pip5_mantissa <= 0; 
    pip5_valid <= 0;
  end else begin
    pip5_valid <= pip4_valid;
    if (~|pip5_sub && (pip4_sign1 ^ pip4_sign2)) begin //2.0 - 2.0 = zero
      pip5_sign <= 0;
      pip5_exponent <= 0;
    end else begin
      pip5_sign <= pip5_sign_tmp;
    pip5_exponent <= pip4_exponent1 & pip4_exponent2;
    end
    pip5_complement <= pip5_complement_tmp;
    if (pip4_sign1 ^ pip4_sign2) begin
      pip5_mantissa <= pip5_sub;
    end else begin
      pip5_mantissa <= pip5_add;
    end
  end
end
always @(*) begin
  pip5_add = pip4_mantissaA + pip4_mantissaB;
  pip5_sub = pip4_mantissaA - pip4_mantissaB;
  if (pip4_compare) begin
    pip5_sign_tmp = pip4_sign1;
  end else begin
    pip5_sign_tmp = pip4_sign2;
  end
  case ({pip4_sign1, pip4_sign2})
    2'b00: begin //A=mantissa1 B=mantissa2, A+B
      //pip5_sign_tmp = 0;
      pip5_complement_tmp = 0;
    end
    2'b01: begin //A=mantissa1 B=mantissa2, A-B
      if (~pip4_compare) begin //mantissa2 > mantissa1 => B>A
        //pip5_sign_tmp = 1;
        pip5_complement_tmp = 1;
      end else begin
        //pip5_sign_tmp = 0;
        pip5_complement_tmp = 0;
      end
    end
    2'b10: begin //A=mantissa2 B=mantissa1, A-B
      if (pip4_compare) begin //mantissa1 > mantissa2 => B>A
        //pip5_sign_tmp = 1;
        pip5_complement_tmp = 1;
      end else begin
        //pip5_sign_tmp = 0;
        pip5_complement_tmp = 0;
      end
    end
    2'b11: begin //A=mantissa1 B=mantissa2, -(A+B)
      //pip5_sign_tmp = 1;
      pip5_complement_tmp = 0;
    end
  endcase
end
//---------------------------//

//-----pipeline stage: 6-----//
reg pip6_sign;
reg pip6_valid;
reg [(EXPONENT_LEN-1):0]pip6_exponent;
reg [(MANTISSA_LEN+1):0]pip6_mantissa;
always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    pip6_sign <= 0;
    pip6_exponent <= 0;
    pip6_mantissa <= 0;
    pip6_valid <= 0;
  end else begin
    pip6_valid <= pip5_valid;
    pip6_sign <= pip5_sign;
    pip6_exponent <= pip5_exponent;
    if (pip5_complement) begin
      pip6_mantissa <= ~pip5_mantissa+1;
    end else begin
      pip6_mantissa <= pip5_mantissa;
    end
  end
end
//---------------------------//

//-----pipeline stage: 7-----//
//normalize, large num
reg pip7_sign;
reg pip7_valid;
reg [(EXPONENT_LEN-1):0]pip7_exponent;
reg [(MANTISSA_LEN+1):0]pip7_mantissa; //54bit = 2bit interger + 52bit float
always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    pip7_sign <= 0;
    pip7_exponent <= 0;
    pip7_mantissa <= 0;
    pip7_valid <= 0;
  end else begin
    pip7_valid <= pip6_valid;
    pip7_sign <= pip6_sign;
    if (pip6_mantissa[MANTISSA_LEN+1] == 1) begin
      pip7_exponent <= pip6_exponent + 1;
      if (pip6_mantissa[0] & pip6_mantissa[1]) begin
        pip7_mantissa <= {1'b0, pip6_mantissa[(MANTISSA_LEN+1):1]} + 1;
      end else begin
        pip7_mantissa <= {1'b0, pip6_mantissa[(MANTISSA_LEN+1):1]};
      end
    end else begin
      pip7_exponent <= pip6_exponent;
      pip7_mantissa <= pip6_mantissa;
    end
  end
end
//---------------------------//


//-----pipeline stage: 8-----//
// normalize using leading-one detection (pure RTL style)
reg pip8_sign;
reg pip8_valid;
reg [(EXPONENT_LEN-1):0] pip8_exponent;
reg [(MANTISSA_LEN-1):0] pip8_mantissa;

assign ready = pip8_valid;

reg [MANTISSA_LEN:0] pip8_mantissa_shift;
reg signed [5:0] shift;

integer i;

always @(*) begin
  shift = 0;
  for (i = MANTISSA_LEN - 1; i >= 0; i = i - 1) begin
    if (pip7_mantissa[i] && shift == 0)
      shift = MANTISSA_LEN - i;
  end
  pip8_mantissa_shift = pip7_mantissa << shift;
end

always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    pip8_sign     <= 0;
    pip8_valid    <= 0;
    pip8_exponent <= 0;
    pip8_mantissa <= 0;
  end else begin
    pip8_sign  <= pip7_sign;
    pip8_valid <= pip7_valid;

    if (pip7_mantissa[MANTISSA_LEN] == 1'b1) begin
      // Already normalized
      pip8_exponent <= pip7_exponent;
      pip8_mantissa <= pip7_mantissa[MANTISSA_LEN-1:0];
    end else begin
      // Subnormal: align to leading one
      pip8_exponent <= pip7_exponent - shift;
      pip8_mantissa <= pip8_mantissa_shift[MANTISSA_LEN-1:0];
    end
  end
end

// //-----pipeline stage: 8-----//
// //binary tree find leading one
// reg pip8_sign;
// reg pip8_valid;
// reg [(EXPONENT_LEN-1):0]pip8_exponent;
// reg [(MANTISSA_LEN-1):0]pip8_mantissa;
// assign ready = pip8_valid;
// reg [5:0]lod_pos; //position of leading one
// //mask first 12 bit, only check mantissa part's loading one
// wire [63:0]pip7_result = {1'b0, 11'b0, pip7_mantissa[(MANTISSA_LEN-1):0]};
// reg [(MANTISSA_LEN+1):0]pip8_mantissa_shift;
// reg signed [5:0]shift;
// //search leading one
// always @(posedge clk or negedge rstn) begin
//   if (!rstn) begin
//     pip8_sign <= 0;
//     pip8_exponent <= 0;
//     pip8_mantissa <= 0;
//     pip8_valid <= 0;
//   end else begin
//     pip8_sign <= pip7_sign;
//     pip8_valid <= pip7_valid;
//     if (pip7_mantissa[MANTISSA_LEN] == 1'b1) begin
//       pip8_exponent <= pip7_exponent;
//       pip8_mantissa <= pip7_mantissa;
//     end else begin
//       pip8_exponent <= pip7_exponent - shift;
//       pip8_mantissa <= pip8_mantissa_shift;
//     end
    
//   end
// end

// always @(*) begin
//   if (|pip7_result[63:32]) begin
//     lod_pos[5] = 1;
//     if (|pip7_result[63:48]) begin
//       lod_pos[4] = 1;
//       if (|pip7_result[63:56]) begin
//         lod_pos[3] = 1;
//         if (|pip7_result[63:60]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[63] ? 2'd3 :
//                           pip7_result[62] ? 2'd2 :
//                           pip7_result[61] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[59] ? 2'd3 :
//                           pip7_result[58] ? 2'd2 :
//                           pip7_result[57] ? 2'd1 : 2'd0);
//         end
//       end else begin
//         lod_pos[3] = 0;
//         if (|pip7_result[55:52]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[55] ? 2'd3 :
//                           pip7_result[54] ? 2'd2 :
//                           pip7_result[53] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[51] ? 2'd3 :
//                           pip7_result[50] ? 2'd2 :
//                           pip7_result[49] ? 2'd1 : 2'd0);
//         end
//       end
//     end else begin
//       lod_pos[4] = 0;
//       if (|pip7_result[47:40]) begin
//         lod_pos[3] = 1;
//         if (|pip7_result[47:44]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[47] ? 2'd3 :
//                           pip7_result[46] ? 2'd2 :
//                           pip7_result[45] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[43] ? 2'd3 :
//                           pip7_result[42] ? 2'd2 :
//                           pip7_result[41] ? 2'd1 : 2'd0);
//         end
//       end else begin
//         lod_pos[3] = 0;
//         if (|pip7_result[39:36]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[39] ? 2'd3 :
//                           pip7_result[38] ? 2'd2 :
//                           pip7_result[37] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[35] ? 2'd3 :
//                           pip7_result[34] ? 2'd2 :
//                           pip7_result[33] ? 2'd1 : 2'd0);
//         end
//       end
//     end
//   end else begin
//     lod_pos[5] = 0;
//     if (|pip7_result[31:16]) begin
//       lod_pos[4] = 1;
//       if (|pip7_result[31:24]) begin
//         lod_pos[3] = 1;
//         if (|pip7_result[31:28]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[31] ? 2'd3 :
//                           pip7_result[30] ? 2'd2 :
//                           pip7_result[29] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[27] ? 2'd3 :
//                           pip7_result[26] ? 2'd2 :
//                           pip7_result[25] ? 2'd1 : 2'd0);
//         end
//       end else begin
//         lod_pos[3] = 0;
//         if (|pip7_result[23:20]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[23] ? 2'd3 :
//                           pip7_result[22] ? 2'd2 :
//                           pip7_result[21] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[19] ? 2'd3 :
//                           pip7_result[18] ? 2'd2 :
//                           pip7_result[17] ? 2'd1 : 2'd0);
//         end
//       end
//     end else begin
//       lod_pos[4] = 0;
//       if (|pip7_result[15:8]) begin
//         lod_pos[3] = 1;
//         if (|pip7_result[15:12]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[15] ? 2'd3 :
//                           pip7_result[14] ? 2'd2 :
//                           pip7_result[13] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[11] ? 2'd3 :
//                           pip7_result[10] ? 2'd2 :
//                           pip7_result[9]  ? 2'd1 : 2'd0);
//         end
//       end else begin
//         lod_pos[3] = 0;
//         if (|pip7_result[7:4]) begin
//           lod_pos[2] = 1;
//           lod_pos[1:0] = (pip7_result[7] ? 2'd3 :
//                           pip7_result[6] ? 2'd2 :
//                           pip7_result[5] ? 2'd1 : 2'd0);
//         end else begin
//           lod_pos[2] = 0;
//           lod_pos[1:0] = (pip7_result[3] ? 2'd3 :
//                           pip7_result[2] ? 2'd2 :
//                           pip7_result[1] ? 2'd1 :
//                           pip7_result[0] ? 2'd0 : 2'd0);
//         end
//       end
//     end
//   end
//   shift = MANTISSA_LEN - lod_pos;
//   pip8_mantissa_shift = pip7_mantissa << shift;
// end


//---------------------------//
//assign result = {pip7_sign, pip7_exponent, pip7_mantissa[(MANTISSA_LEN-1):0]};
assign result = {pip8_sign, pip8_exponent, pip8_mantissa[(MANTISSA_LEN-1):0]};
endmodule //IEEE754_64bit_adder