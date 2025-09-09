module stage_top
#(
  parameter pDATA_WIDTH = 128, // two 64-bit numbers
  parameter pSS_WIDTH   = 32   // one 32-bit SS lane
)
(
  input  wire                     clk,
  input  wire                     clk_s,
  input  wire                     rstn,

  //input wire                [1:0] in1_sw,  // not used for now
  output wire               [31:0] ap_ctrl,
  //output wire              [31:0] coef_ctrl,
  input  wire                     ap_read,

  // SS/SM interface:
  // FFT/iFFT SS: concat 4x32-bit to 128-bit
  // FFT/iFFT SM: split 128-bit to 32-bit
  input  wire                     ss_vld,
  input  wire [(pSS_WIDTH-1):0]   ss_dat,
  input  wire                     ss_lst,     // not used for now
  output wire                     ss_rdy,
  input  wire                     sm_rdy,
  output wire                     sm_vld,
  output reg  [(pSS_WIDTH-1):0]   sm_dat,
  output wire                     sm_lst,     // not used for now
  output wire                     sm_mode
);

  // ------------------------------------------------------------
  // Localparams / States / Modes
  // ------------------------------------------------------------
  localparam [1:0] ST_INPUT  = 2'd0;
  localparam [1:0] ST_DECODE = 2'd1;
  localparam [1:0] ST_OUTPUT = 2'd2;

  localparam [7:0] COEF_FFT   = 8'b00010100;
  localparam [7:0] COEF_iFFT  = 8'b00010101;
  localparam [7:0] COEF_NTT   = 8'b00010110;
  localparam [7:0] COEF_iNTT  = 8'b00010111;
  localparam [7:0] MODE_FFT   = 8'b00000100;
  localparam [7:0] MODE_iFFT  = 8'b00000101;
  localparam [7:0] MODE_NTT   = 8'b00000110;
  localparam [7:0] MODE_iNTT  = 8'b00000111;

  // ------------------------------------------------------------
  // Registers / Wires
  // ------------------------------------------------------------
  reg  [11:0] meta_cnt;
  reg  [ 2:0] pack_cnt;
  reg  [ 7:0] mode;
  reg  [15:0] length;
  reg  [ 7:0] destination;

  reg  [15:0] ss_buffer1, ss_buffer2, ss_buffer3, ss_buffer4;
  reg  [15:0] ss_buffer5, ss_buffer6, ss_buffer7, ss_buffer8;
  wire [127:0] ss_buffer;

  reg  [ 1:0] state;
  reg  [11:0] output_cnt;

  reg  [11:0] coef_addr_cnt_fft;
  reg  [11:0] coef_addr_cnt_ntt;

  wire [ 3:0] fft_coef_ram_we;
  wire [12:0] fft_coef_ram_a;
  reg  [ 3:0] fft_coef_ram_we_r;

  wire [ 3:0] ntt_coef_ram_we;
  wire [12:0] ntt_coef_ram_a;
  reg  [ 3:0] ntt_coef_ram_we_r;

  wire [ 3:0] intt_coef_ram_we;
  wire [12:0] intt_coef_ram_a;
  reg  [ 3:0] intt_coef_ram_we_r;

  wire [ 3:0]  ram1_we;
  wire [12:0]  ram1_a;
  reg  [127:0] ram1_di;
  wire [12:0]  ram1_a_fft, ram1_a_ifft, ram1_a_ntt, ram1_a_intt;
  wire [ 3:0]  ram1_we_fft, ram1_we_ntt, ram1_we_intt;

  reg          phase;
  reg  [11:0]  length_old;

  // ========= kernel IO wires =========
  wire [1:0] mode_k = mode[1:0];
  wire       sw_lst;

  // ============ data RAM ============
  /* SRAM1 512x128 */
  wire [ 3:0] WE_512_1;
  wire        sram_en_512_1;
  wire [127:0] sram_din_512_1;
  wire [127:0] sram_dout_512_1;
  wire [12:0]  sram_addr_512_1;

  /* SRAM2 512x128 */
  wire [ 3:0] WE_512_2;
  wire        sram_en_512_2;
  wire [127:0] sram_din_512_2;
  wire [127:0] sram_dout_512_2;
  wire [12:0]  sram_addr_512_2;

  // ============ coef RAM ============
  /* fft/ifft 512x128 */
  wire [ 3:0]  coef_WE_512;
  wire         coef_sram_en_512;
  wire [127:0] coef_sram_din_512;
  wire [127:0] coef_sram_dout_512;
  wire [12:0]  coef_sram_addr_512;

  /* ntt 128x128 */
  wire [ 3:0]  coef_WE_ntt;
  wire         coef_sram_en_ntt;
  wire [127:0] coef_sram_din_ntt;
  wire [127:0] coef_sram_dout_ntt;
  wire [12:0]  coef_sram_addr_ntt;

  /* intt 128x128 */
  wire [ 3:0]  coef_WE_intt;
  wire         coef_sram_en_intt;
  wire [127:0] coef_sram_din_intt;
  wire [127:0] coef_sram_dout_intt;
  wire [12:0]  coef_sram_addr_intt;

  wire clk_mux_sel = (state == ST_DECODE);
  wire clk_mux;

  // ------------------------------------------------------------
  // Decode meta data
  // ------------------------------------------------------------
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) mode <= 8'd0;
    else if (ss_rdy && ss_vld && (meta_cnt == 12'd0)) mode <= ss_dat[23:16];
  end

  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) length <= 16'hffff;
    else if (ss_rdy && ss_vld && (meta_cnt == 12'd0)) length <= ss_dat[15:0];
  end

  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) destination <= 8'd0;
    else if (ss_rdy && ss_vld && (meta_cnt == 12'd0)) destination <= ss_dat[31:24];
  end

  // ------------------------------------------------------------
  // meta counter
  // ------------------------------------------------------------
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) meta_cnt <= 12'd0;
    else if (ss_rdy && ss_vld) meta_cnt <= (meta_cnt == length) ? 12'd0 : (meta_cnt + 12'd1);
  end

  // ------------------------------------------------------------
  // pack counter
  // ------------------------------------------------------------
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) pack_cnt <= 3'd0;
    else if (ss_rdy && ss_vld) begin
      if ((meta_cnt == 12'd0) || (pack_cnt == 3'd7)) pack_cnt <= 3'd0;
      else pack_cnt <= pack_cnt + 3'd1;
    end
  end

  // ------------------------------------------------------------
  // coef addr counter
  // ------------------------------------------------------------
  // fft
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) coef_addr_cnt_fft <= 12'd0;
    else if (ss_rdy && ss_vld) begin
      if (meta_cnt == 12'd0) coef_addr_cnt_fft <= 12'd0;
      else if ((pack_cnt == 3'd3) || (pack_cnt == 3'd7)) coef_addr_cnt_fft <= coef_addr_cnt_fft + 12'd1;
    end
  end

  // ntt
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) coef_addr_cnt_ntt <= 12'd0;
    else if (ss_rdy && ss_vld) begin
      if (meta_cnt == 12'd0) coef_addr_cnt_ntt <= 12'd0;
      else if (pack_cnt == 3'd7) coef_addr_cnt_ntt <= coef_addr_cnt_ntt + 12'd1;
    end
  end

  // ------------------------------------------------------------
  // ss buffer
  // ------------------------------------------------------------
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) begin
      ss_buffer1 <= 16'd0; ss_buffer2 <= 16'd0; ss_buffer3 <= 16'd0; ss_buffer4 <= 16'd0;
      ss_buffer5 <= 16'd0; ss_buffer6 <= 16'd0; ss_buffer7 <= 16'd0; ss_buffer8 <= 16'd0;
    end else if (ss_rdy && ss_vld) begin
      if (mode[2:1] == 2'b10) begin
        ss_buffer7 <= ((pack_cnt == 3'd0) || (pack_cnt == 3'd4)) ? ss_dat[15: 0] : ss_buffer7;
        ss_buffer8 <= ((pack_cnt == 3'd0) || (pack_cnt == 3'd4)) ? ss_dat[31:16] : ss_buffer8;
        ss_buffer5 <= ((pack_cnt == 3'd1) || (pack_cnt == 3'd5)) ? ss_dat[15: 0] : ss_buffer5;
        ss_buffer6 <= ((pack_cnt == 3'd1) || (pack_cnt == 3'd5)) ? ss_dat[31:16] : ss_buffer6;
        ss_buffer3 <= ((pack_cnt == 3'd2) || (pack_cnt == 3'd6)) ? ss_dat[15: 0] : ss_buffer3;
        ss_buffer4 <= ((pack_cnt == 3'd2) || (pack_cnt == 3'd6)) ? ss_dat[31:16] : ss_buffer4;
        ss_buffer1 <= ((pack_cnt == 3'd3) || (pack_cnt == 3'd7)) ? ss_dat[15: 0] : ss_buffer1;
        ss_buffer2 <= ((pack_cnt == 3'd3) || (pack_cnt == 3'd7)) ? ss_dat[31:16] : ss_buffer2;
      end else if (mode[2:1] == 2'b11) begin
        ss_buffer1 <= (pack_cnt == 3'd0) ? ss_dat[15:0] : ss_buffer1;
        ss_buffer2 <= (pack_cnt == 3'd1) ? ss_dat[15:0] : ss_buffer2;
        ss_buffer3 <= (pack_cnt == 3'd2) ? ss_dat[15:0] : ss_buffer3;
        ss_buffer4 <= (pack_cnt == 3'd3) ? ss_dat[15:0] : ss_buffer4;
        ss_buffer5 <= (pack_cnt == 3'd4) ? ss_dat[15:0] : ss_buffer5;
        ss_buffer6 <= (pack_cnt == 3'd5) ? ss_dat[15:0] : ss_buffer6;
        ss_buffer7 <= (pack_cnt == 3'd6) ? ss_dat[15:0] : ss_buffer7;
        ss_buffer8 <= (pack_cnt == 3'd7) ? ss_dat[15:0] : ss_buffer8;
      end
    end
  end

  assign ss_buffer = { ss_buffer8, ss_buffer7, ss_buffer6, ss_buffer5
                     , ss_buffer4, ss_buffer3, ss_buffer2, ss_buffer1 };

  // clocked one (registered-1 to avoid combinational 1'b1 before first clk)
  reg l;
  always @(posedge clk_s) begin
    l <= 1'b1;
  end

  // ------------------------------------------------------------
  // coef input (fft / ifft / ntt / intt)
  // ------------------------------------------------------------
  assign fft_coef_ram_we = {4{ ((pack_cnt == 3'd3) || (pack_cnt == 3'd7))
                               && ss_vld && ss_rdy
                               && (destination == COEF_FFT || destination == COEF_iFFT)}};
  always @(posedge clk_s) fft_coef_ram_we_r <= fft_coef_ram_we;
  assign fft_coef_ram_a = { (coef_addr_cnt_fft), 2'b00 };

  assign ntt_coef_ram_we = {4{ (pack_cnt == 3'd7) && ss_vld && ss_rdy
                               && (destination == COEF_NTT)}};
  always @(posedge clk_s) ntt_coef_ram_we_r <= ntt_coef_ram_we;
  assign ntt_coef_ram_a = { (coef_addr_cnt_ntt - 12'd1), 2'b00 };

  assign intt_coef_ram_we = {4{ (pack_cnt == 3'd7) && ss_vld && ss_rdy
                                && (destination == COEF_iNTT)}};
  always @(posedge clk_s) intt_coef_ram_we_r <= intt_coef_ram_we;
  assign intt_coef_ram_a = { (coef_addr_cnt_ntt - 12'd1), 2'b00 };

  // ------------------------------------------------------------
  // ss_tready
  // ------------------------------------------------------------
  reg ss_rdy_i;
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) ss_rdy_i <= 1'b0;
    else ss_rdy_i <= (mode == MODE_iNTT) ? ((ss_vld && ss_rdy_i) ? 1'b0 : 1'b1) : 1'b0;
  end

  assign ss_rdy =
      ((state == ST_INPUT) || ((state == ST_OUTPUT) && (meta_cnt < length)))
        ? ((mode == MODE_iNTT) ? ss_rdy_i : l)
        : 1'b0;

  // ------------------------------------------------------------
  // data input
  // ------------------------------------------------------------
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) phase <= 1'b0;
    else if ((mode == MODE_FFT) || (mode == MODE_NTT)) phase <= 1'b0;
    else if (mode == MODE_iNTT) phase <= (ss_rdy && ss_vld && (meta_cnt != 12'd0)) ? 1'b1 : 1'b0;
  end

  reg [3:0] ram1_we_fft_r, ram1_we_ntt_r, ram1_we_intt_r;
  always @(posedge clk_s) ram1_we_fft_r  <= ram1_we_fft;
  always @(posedge clk_s) ram1_we_ntt_r  <= ram1_we_ntt;
  always @(posedge clk_s) ram1_we_intt_r <= ram1_we_intt;

  assign ram1_we_fft  = {4{ ((pack_cnt == 3'd3) || (pack_cnt == 3'd7))
                            && ss_vld && ss_rdy
                            && (mode == MODE_FFT || mode == MODE_iFFT)}};
  assign ram1_we_ntt  = {4{ (pack_cnt == 3'd7) && ss_vld && ss_rdy && (mode == MODE_NTT)}};
  assign ram1_we_intt = {4{ phase }};

  assign ram1_we = (mode == MODE_FFT  || mode == MODE_iFFT) ? ram1_we_fft_r  :
                   (mode == MODE_NTT)                      ? ram1_we_ntt_r  :
                   (mode == MODE_iNTT)                     ? ram1_we_intt   :
                                                             4'b0000;

  reg  [12:0]  latch_a;
  wire [127:0] ram1_do;
  reg  [ 2:0]  latch_ro;
  wire [12:0]  ram1_a_intt_no;
  wire [ 9:0]  ram1_a_intt_ro; // widened to real 10-bit (lint clean), only [2:0] used.

  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) latch_a <= 13'd0;
    else if (ss_rdy && ss_vld && (meta_cnt != 12'd0) && (mode == MODE_iNTT)) latch_a <= ram1_a_intt;
  end

  assign ram1_a_fft  = { (coef_addr_cnt_fft - 12'd1), 2'b00 };
  assign ram1_a_ntt  = { (coef_addr_cnt_ntt - 12'd1), 2'b00 };
  // bit-wise reversal of address bits for iFFT
  assign ram1_a_ifft = { ram1_a_fft[0],  ram1_a_fft[1],  ram1_a_fft[2],  ram1_a_fft[3],  ram1_a_fft[4],
                         ram1_a_fft[5],  ram1_a_fft[6],  ram1_a_fft[7],  ram1_a_fft[8],  ram1_a_fft[9],
                         ram1_a_fft[10], ram1_a_fft[11], ram1_a_fft[12] };

  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) latch_ro <= 3'd0;
    else if (ss_rdy && ss_vld && (meta_cnt != 12'd0) && (mode == MODE_iNTT)) latch_ro <= ram1_a_intt_ro[2:0];
  end

  assign ram1_a_intt_no = meta_cnt - 12'd1;
  assign ram1_a_intt_ro = { ram1_a_intt_no[0], ram1_a_intt_no[1], ram1_a_intt_no[2], ram1_a_intt_no[3], ram1_a_intt_no[4],
                            ram1_a_intt_no[5], ram1_a_intt_no[6], ram1_a_intt_no[7], ram1_a_intt_no[8], ram1_a_intt_no[9] };
  assign ram1_a_intt    = { ram1_a_intt_no[0], ram1_a_intt_no[1], ram1_a_intt_no[2], ram1_a_intt_no[3], ram1_a_intt_no[4],
                            ram1_a_intt_no[5], ram1_a_intt_no[6], ram1_a_intt_no[7], ram1_a_intt_no[8], ram1_a_intt_no[9] } >> 3;

  assign ram1_a = (mode == MODE_FFT ) ? ram1_a_fft  :
                  (mode == MODE_NTT ) ? ram1_a_ntt  :
                  (mode == MODE_iFFT) ? ram1_a_ifft :
                  (mode == MODE_iNTT) ? (phase ? {latch_a, 2'b00} : {ram1_a_intt, 2'b00}) :
                                        13'b0;

  always @* begin
    if (mode == MODE_FFT || mode == MODE_iFFT || mode == MODE_NTT) begin
      ram1_di = ss_buffer;
    end else if (mode == MODE_iNTT) begin
      case (latch_ro[2:0])
        3'd0: ram1_di = {ram1_do[127:16],  ss_dat[15:0]};
        3'd1: ram1_di = {ram1_do[127:32],  ss_dat[15:0], ram1_do[15:0]};
        3'd2: ram1_di = {ram1_do[127:48],  ss_dat[15:0], ram1_do[31:0]};
        3'd3: ram1_di = {ram1_do[127:64],  ss_dat[15:0], ram1_do[47:0]};
        3'd4: ram1_di = {ram1_do[127:80],  ss_dat[15:0], ram1_do[63:0]};
        3'd5: ram1_di = {ram1_do[127:96],  ss_dat[15:0], ram1_do[79:0]};
        3'd6: ram1_di = {ram1_do[127:112], ss_dat[15:0], ram1_do[95:0]};
        3'd7: ram1_di = {ss_dat[15:0],     ram1_do[111:0]};
        default: ram1_di = 128'b0;
      endcase
    end else begin
      ram1_di = ss_buffer;
    end
  end

  // ------------------------------------------------------------
  // state: input, process, output
  // ------------------------------------------------------------
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) state <= ST_INPUT;
    else if ((state == ST_INPUT)  && ss_vld && ss_rdy && (meta_cnt == length) && (destination[4] == 1'b0)) state <= ST_DECODE;
    else if ((state == ST_DECODE) && sw_lst)                                                    state <= ST_OUTPUT;
    else if ((state == ST_OUTPUT) && (output_cnt == (length_old - 12'd1)))                      state <= ST_INPUT;
  end

  // ------------------------------------------------------------
  // decode (clk_s domain)
  // ------------------------------------------------------------
  reg  decode;
  wire decode_q;
  reg [1:0] decode_cnt;

  assign decode_q = (state == ST_DECODE) && (ram1_we == 4'hF);

  always @(posedge clk_s) begin
    if (!rstn) begin
      decode <= 0;
    end else begin
      decode <= decode_q;
    end
  end

  // ------------------------------------------------------------
  // output
  // ------------------------------------------------------------
  wire sm_vld_a = (state == ST_OUTPUT);
  reg  sm_vld_r;

  // output addr counter
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) output_cnt <= 12'd0;
    else if ((state == ST_OUTPUT) && sm_rdy && sm_vld_a) begin
      if (output_cnt == length_old) output_cnt <= 12'd0;
      else                           output_cnt <= output_cnt + 12'd1;
    end else begin
      output_cnt <= 12'd0;
    end
  end

  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) length_old <= 12'd0;
    else if (decode) length_old <= length;
  end

  reg [1:0] mode_latch;
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) mode_latch <= 2'd0;
    else if (decode) mode_latch <= mode[1:0];
  end

  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) sm_vld_r <= 1'b0;
    else       sm_vld_r <= (state == ST_OUTPUT);
  end

  assign sm_vld = sm_vld_r;

  // ------------------------------------------------------------
  // output addr
  // ------------------------------------------------------------
  wire [11:0] output_cnt_ro_ifft;
  wire [11:0] output_cnt_ro_intt;
  wire [12:0] output_addr_fft;
  wire [12:0] output_addr_ifft;
  wire [12:0] output_addr_intt;
  wire [12:0] output_addr_ntt;

  wire [12:0]  output_a;
  wire [127:0] ram_2_do;

  assign output_cnt_ro_ifft = { output_addr_fft[0],  output_addr_fft[1],  output_addr_fft[2],
                                output_addr_fft[3],  output_addr_fft[4],  output_addr_fft[5],
                                output_addr_fft[6],  output_addr_fft[7],  output_addr_fft[8],
                                output_addr_fft[9],  output_addr_fft[10] };

  assign output_cnt_ro_intt = { output_cnt[0], output_cnt[1], output_cnt[2], output_cnt[3], output_cnt[4],
                                output_cnt[5], output_cnt[6], output_cnt[7], output_cnt[8], output_cnt[9] };

  assign output_addr_fft  = { (output_cnt >> 2),         2'b00 };
  assign output_addr_ifft = { output_cnt_ro_ifft,        2'b00 };
  assign output_addr_intt = { (output_cnt_ro_intt >> 3), 2'b00 };
  assign output_addr_ntt  = { (output_cnt >> 3),         2'b00 };

  assign output_a = (mode_latch == 2'd0) ? output_addr_fft  :
                    (mode_latch == 2'd1) ? output_addr_ifft :
                    (mode_latch == 2'd2) ? output_addr_ntt  :
                    (mode_latch == 2'd3) ? output_addr_intt :
                                           13'b0;

  reg [2:0] intt_a_latch;
  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) intt_a_latch <= 3'd0;
    else       intt_a_latch <= output_cnt_ro_intt[2:0];
  end

  always @* begin
    if (mode_latch == 2'b00 || mode_latch == 2'b01) begin
      case (output_cnt[2:0])
        3'd4: sm_dat = ram_2_do[31:0];
        3'd3: sm_dat = ram_2_do[63:32];
        3'd2: sm_dat = ram_2_do[95:64];
        3'd1: sm_dat = ram_2_do[127:96];
        3'd0: sm_dat = ram_2_do[31:0];
        3'd7: sm_dat = ram_2_do[63:32];
        3'd6: sm_dat = ram_2_do[95:64];
        3'd5: sm_dat = ram_2_do[127:96];
        default: sm_dat = 32'b0;
      endcase
    end else if (mode_latch == 2'b10) begin
      case (output_cnt[2:0])
        3'd1: sm_dat = ram_2_do[15:0];
        3'd2: sm_dat = ram_2_do[31:16];
        3'd3: sm_dat = ram_2_do[47:32];
        3'd4: sm_dat = ram_2_do[63:48];
        3'd5: sm_dat = ram_2_do[79:64];
        3'd6: sm_dat = ram_2_do[95:80];
        3'd7: sm_dat = ram_2_do[111:96];
        3'd0: sm_dat = ram_2_do[127:112];
        default: sm_dat = 32'b0;
      endcase
    end else if (mode_latch == 2'b11) begin
      case (intt_a_latch)
        3'd0: sm_dat = ram_2_do[15:0];
        3'd1: sm_dat = ram_2_do[31:16];
        3'd2: sm_dat = ram_2_do[47:32];
        3'd3: sm_dat = ram_2_do[63:48];
        3'd4: sm_dat = ram_2_do[79:64];
        3'd5: sm_dat = ram_2_do[95:80];
        3'd6: sm_dat = ram_2_do[111:96];
        3'd7: sm_dat = ram_2_do[127:112];
        default: sm_dat = 32'b0;
      endcase
    end else begin
      sm_dat = 32'b0;
    end
  end

  ////////////////////////////////////////////////////////////////
  // state == 0: input data
  // state == 1: decode impulse and kernel processes the data
  // state == 2: output data
  ////////////////////////////////////////////////////////////////

  // ------------------------------------------------------------
  // RAM instance (mux to kernel during DECODE)
  // ------------------------------------------------------------
  wire [ 3:0]  ram1_we_mux  = ((state == ST_DECODE) && !decode_q) ? WE_512_1         : ram1_we;
  wire         ram1_en_mux  = ((state == ST_DECODE) && !decode_q) ? sram_en_512_1    : l;
  wire [127:0] ram1_di_mux  = ((state == ST_DECODE) && !decode_q) ? sram_din_512_1   : ram1_di;
  wire [12:0]  ram1_a_mux   = ((state == ST_DECODE) && !decode_q) ? sram_addr_512_1  : ram1_a;

  wire         ram2_en_mux  = ((state == ST_DECODE) && !decode_q) ? sram_en_512_2    : l;
  wire [12:0]  ram2_a_mux   = ((state == ST_DECODE) && !decode_q) ? sram_addr_512_2  : output_a;

  wire         fft_coef_ram_en_mux = ((state == ST_DECODE) && !decode_q) ? coef_sram_en_512   : l;
  wire [12:0]  fft_coef_ram_a_mux  = ((state == ST_DECODE) && !decode_q) ? coef_sram_addr_512 : fft_coef_ram_a;

  wire         ntt_coef_ram_en_mux = ((state == ST_DECODE) && !decode_q) ? coef_sram_en_ntt   : l;
  wire [12:0]  ntt_coef_ram_a_mux  = ((state == ST_DECODE) && !decode_q) ? coef_sram_addr_ntt : ntt_coef_ram_a;

  wire         intt_coef_ram_en_mux = ((state == ST_DECODE) && !decode_q) ? coef_sram_en_intt   : l;
  wire [12:0]  intt_coef_ram_a_mux  = ((state == ST_DECODE) && !decode_q) ? coef_sram_addr_intt : intt_coef_ram_a;

  ///////////////////////////////
  // clk sel
  ///////////////////////////////



  clk_mux clk_mux_inst (
    .clk_fast(clk_s),
    .clk_slow(clk),
    .rstn(rstn),
    .sel (clk_mux_sel),
    .clk_out(clk_mux)
  );

  //------------------------------------------------
  // ap_ctrl
  //------------------------------------------------
  reg ap_done;

  assign ap_ctrl[3:0] = {3'b0, {ap_done}};
  assign ap_ctrl[7:4] = {3'b0, {state != ST_DECODE}};
  assign ap_ctrl[31:8] = 0;

  always @(posedge clk_s or negedge rstn) begin
    if (!rstn) ap_done <= 1'b0;
    else if (output_cnt == (length_old - 12'd1)) ap_done <= 1'b1;
    else if (sw_lst) ap_done <= 1'b0;
    else ap_done <= ap_done;
  end

  bram512x128 RAM1 (
    .CLK (clk_mux),
    .WE  (ram1_we_mux),
    .EN  (ram1_en_mux),
    .Di  (ram1_di_mux),
    .Do  (ram1_do),
    .A   (ram1_a_mux)
  );

  bram512x128 RAM2 (
    .CLK (clk_mux),
    .WE  (WE_512_2),
    .EN  (ram2_en_mux),
    .Di  (sram_din_512_2),
    .Do  (ram_2_do),
    .A   (ram2_a_mux)
  );

  bram512x128 FFT_COEF_RAM (
    .CLK (clk_s),
    .WE  (fft_coef_ram_we_r),
    .EN  (fft_coef_ram_en_mux),
    .Di  (ss_buffer),
    .Do  (coef_sram_dout_512),
    .A   (fft_coef_ram_a_mux)
  );

  bram128x128 NTT_COEF_RAM (
    .CLK (clk_s),
    .WE  (ntt_coef_ram_we_r),
    .EN  (ntt_coef_ram_en_mux),
    .Di  (ss_buffer),
    .Do  (coef_sram_dout_ntt),
    .A   (ntt_coef_ram_a_mux)
  );

  bram128x128 iNTT_COEF_RAM (
    .CLK (clk_s),
    .WE  (intt_coef_ram_we_r),
    .EN  (intt_coef_ram_en_mux),
    .Di  (ss_buffer),
    .Do  (coef_sram_dout_intt),
    .A   (intt_coef_ram_a_mux)
  );

  kernel kernel_inst (
    .clk                (clk_s),
    .clk_2x             (clk),
    .rstn               (rstn),

    .mode               (mode_k),
    .decode             (decode),
    .sw_lst             (sw_lst),

    .WE_512_1           (WE_512_1),
    .sram_en_512_1      (sram_en_512_1),
    .sram_din_512_1     (sram_din_512_1),
    .sram_dout_512_1    (ram1_do),
    .sram_addr_512_1    (sram_addr_512_1),

    .WE_512_2           (WE_512_2),
    .sram_en_512_2      (sram_en_512_2),
    .sram_din_512_2     (sram_din_512_2),
    .sram_dout_512_2    (ram_2_do),
    .sram_addr_512_2    (sram_addr_512_2),

    .coef_WE_512        (coef_WE_512),
    .coef_sram_en_512   (coef_sram_en_512),
    .coef_sram_din_512  (coef_sram_din_512),
    .coef_sram_dout_512 (coef_sram_dout_512),
    .coef_sram_addr_512 (coef_sram_addr_512),

    .coef_WE_ntt        (coef_WE_ntt),
    .coef_sram_en_ntt   (coef_sram_en_ntt),
    .coef_sram_din_ntt  (coef_sram_din_ntt),
    .coef_sram_dout_ntt (coef_sram_dout_ntt),
    .coef_sram_addr_ntt (coef_sram_addr_ntt),

    .coef_WE_intt       (coef_WE_intt),
    .coef_sram_en_intt  (coef_sram_en_intt),
    .coef_sram_din_intt (coef_sram_din_intt),
    .coef_sram_dout_intt(coef_sram_dout_intt),
    .coef_sram_addr_intt(coef_sram_addr_intt)
  );

endmodule
