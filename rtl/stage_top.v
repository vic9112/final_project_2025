// Using Deep-Feedback structure, we will have
module stage_top
#(  
  parameter pDATA_WIDTH = 128, // two 64-bit numbers
  parameter pSS_WIDTH = 32 // two 64-bit numbers
)
(
  input   wire                     clk,
  input   wire                     clk_s,
  input   wire                     rstn,

  //input   wire               [1:0] in1_sw,  // not used for now
  output   wire             [31:0] ap_ctrl,
  //output   wire             [31:0] coef_ctrl,
  input   wire                     ap_read,
  // SS/SM interface:
  // FFT/iFFT SS: concat 4 32-bit data to 128-bit
  // FFT/iFFT SM: split 128-bit data to 32-bit
  input   wire                     ss_vld, 
  input   wire [(pSS_WIDTH-1):0]   ss_dat, 
  input   wire                     ss_lst,  // not used for now
  output  wire                     ss_rdy, 
  input   wire                     sm_rdy, 
  output  wire                     sm_vld, 
  output  reg  [(pSS_WIDTH-1):0]   sm_dat, 
  output  wire                     sm_lst,  // not used for now
  output  wire                     sm_mode
);

  reg [11:0] meta_cnt;
  reg [2:0] pack_cnt;
  reg [7:0] mode;
  reg [15:0] length;
  reg [7:0] destination;
  reg [15:0] ss_buffer1;
  reg [15:0] ss_buffer2;
  reg [15:0] ss_buffer3;
  reg [15:0] ss_buffer4;
  reg [15:0] ss_buffer5;
  reg [15:0] ss_buffer6;
  reg [15:0] ss_buffer7;
  reg [15:0] ss_buffer8;
  reg [11:0] coef_addr_cnt_fft;
  reg [11:0] coef_addr_cnt_ntt;
  wire [127:0] ss_buffer;
  reg [1:0] state;
  reg [11:0] output_cnt;
  wire [ 3:0] fft_coef_ram_we;
  wire [12:0] fft_coef_ram_a;
  reg [3:0] fft_coef_ram_we_r;
  wire [ 3:0] ntt_coef_ram_we;
  wire [12:0] ntt_coef_ram_a;
  reg  [3:0] ntt_coef_ram_we_r;
  wire [ 3:0] intt_coef_ram_we;
  wire [12:0] intt_coef_ram_a;
  reg  [3:0] intt_coef_ram_we_r;
  wire [ 3:0] ram1_we;
  wire [12:0] ram1_a;
  reg  [127:0] ram1_di;
  wire [12:0] ram1_a_fft;
  wire [12:0] ram1_a_ifft;
  wire [12:0] ram1_a_ntt;
  wire [12:0] ram1_a_intt;
  wire [3:0]  ram1_we_fft;
  wire [3:0]  ram1_we_ntt;
  wire [3:0]  ram1_we_intt;
  reg         phase;
  reg [11:0] length_old;

  // ========= kernel IO wires =========

  // control
  wire               [1:0] mode_k;
  wire                     sw_lst;

  assign mode_k = mode[1:0];
  // ============ data RAM ============
  /* SRAM1 512x128 */
  wire                [3:0] WE_512_1;
  wire                      sram_en_512_1;
  wire              [127:0] sram_din_512_1;
  wire              [127:0] sram_dout_512_1;
  wire               [12:0] sram_addr_512_1;

  /* SRAM2 512x128 */
  wire                [3:0] WE_512_2;
  wire                      sram_en_512_2;
  wire              [127:0] sram_din_512_2;
  wire              [127:0] sram_dout_512_2;
  wire               [12:0] sram_addr_512_2;

  // ============ coef RAM ============
  /* fft/ifft 512x128 */
  wire                [3:0] coef_WE_512;
  wire                      coef_sram_en_512;
  wire              [127:0] coef_sram_din_512;
  wire              [127:0] coef_sram_dout_512;
  wire               [12:0] coef_sram_addr_512;

  /* ntt 128x128 */
  wire                [3:0] coef_WE_ntt;
  wire                      coef_sram_en_ntt;
  wire              [127:0] coef_sram_din_ntt;
  wire              [127:0] coef_sram_dout_ntt;
  wire               [12:0] coef_sram_addr_ntt;

  /* intt 128x128 */
  wire                [3:0] coef_WE_intt;
  wire                      coef_sram_en_intt;
  wire              [127:0] coef_sram_din_intt;
  wire              [127:0] coef_sram_dout_intt;
  wire               [12:0] coef_sram_addr_intt;


  localparam COEF_FFT  = 8'b00010100;
  localparam COEF_iFFT = 8'b00010101;
  localparam COEF_NTT  = 8'b00010110;
  localparam COEF_iNTT = 8'b00010111;
  localparam MODE_FFT  = 8'b00000100;
  localparam MODE_iFFT = 8'b00000101;
  localparam MODE_NTT  = 8'b00000110;
  localparam MODE_iNTT = 8'b00000111;

  /*---------------------------------------------
                decode meta data
  ---------------------------------------------*/

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      mode <= 0;
    end else begin
      if (ss_rdy && ss_vld && meta_cnt == 0) begin
        mode <= ss_dat[23:16];
      end else begin
        mode <= mode;
      end
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      length <= 16'hffff;
    end else begin
      if (ss_rdy && ss_vld && meta_cnt == 0) begin
        length <= ss_dat[15:0];
      end else begin
        length <= length;
      end
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      destination <= 0;
    end else begin
      if (ss_rdy && ss_vld && meta_cnt == 0) begin
        destination <= ss_dat[31:24];
      end else begin
        destination <= destination;
      end
    end
  end

  /*---------------------------------------------
                meta counter
  ---------------------------------------------*/

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      meta_cnt <= 0;
    end else begin
      meta_cnt <= (ss_rdy && ss_vld) ? (meta_cnt == length ? 0 : meta_cnt + 1) : meta_cnt;
    end
  end

  /*---------------------------------------------
                pack counter
  ---------------------------------------------*/

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pack_cnt <= 0;
    end else begin
      if (ss_rdy && ss_vld) begin
        if (meta_cnt == 0 || pack_cnt == 7) begin
          pack_cnt <= 0;
        end else begin
          pack_cnt <= pack_cnt + 1;
        end
      end
    end
  end

  /*---------------------------------------------
                coef addr counter
  ---------------------------------------------*/

  // fft
  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      coef_addr_cnt_fft <= 0;
    end else begin
      if (ss_rdy && ss_vld) begin
        if (meta_cnt == 0) begin
          coef_addr_cnt_fft <= 0;
        end else if (pack_cnt == 3 || pack_cnt == 7) begin
          coef_addr_cnt_fft <= coef_addr_cnt_fft + 1;
        end else begin
          coef_addr_cnt_fft <= coef_addr_cnt_fft;
        end
      end else begin
        coef_addr_cnt_fft <= coef_addr_cnt_fft;
      end
    end
  end

  // ntt
  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      coef_addr_cnt_ntt <= 0;
    end else begin
      if (ss_rdy && ss_vld) begin
        if (meta_cnt == 0) begin
          coef_addr_cnt_ntt <= 0;
        end else if (pack_cnt == 7) begin
          coef_addr_cnt_ntt <= coef_addr_cnt_ntt + 1;
        end else begin
          coef_addr_cnt_ntt <= coef_addr_cnt_ntt;
        end
      end else begin
        coef_addr_cnt_ntt <= coef_addr_cnt_ntt;
      end
    end
  end

  /*---------------------------------------------
                ss buffer
  ---------------------------------------------*/

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      ss_buffer1 <= 0;
      ss_buffer2 <= 0;
      ss_buffer3 <= 0;
      ss_buffer4 <= 0;
      ss_buffer5 <= 0;
      ss_buffer6 <= 0;
      ss_buffer7 <= 0;
      ss_buffer8 <= 0;
    end else begin
      if (ss_rdy && ss_vld) begin
        if (mode[2:1] == 2'b10) begin
          ss_buffer7 <= (pack_cnt == 0 || pack_cnt == 4) ? ss_dat[15: 0] : ss_buffer7;
          ss_buffer8 <= (pack_cnt == 0 || pack_cnt == 4) ? ss_dat[31:16] : ss_buffer8;
          ss_buffer5 <= (pack_cnt == 1 || pack_cnt == 5) ? ss_dat[15: 0] : ss_buffer5;
          ss_buffer6 <= (pack_cnt == 1 || pack_cnt == 5) ? ss_dat[31:16] : ss_buffer6;
          ss_buffer3 <= (pack_cnt == 2 || pack_cnt == 6) ? ss_dat[15: 0] : ss_buffer3;
          ss_buffer4 <= (pack_cnt == 2 || pack_cnt == 6) ? ss_dat[31:16] : ss_buffer4;
          ss_buffer1 <= (pack_cnt == 3 || pack_cnt == 7) ? ss_dat[15: 0] : ss_buffer1;
          ss_buffer2 <= (pack_cnt == 3 || pack_cnt == 7) ? ss_dat[31:16] : ss_buffer2;
        end else if (mode[2:1] == 2'b11) begin
          ss_buffer1 <= (pack_cnt == 0) ? ss_dat[15: 0] : ss_buffer1;
          ss_buffer2 <= (pack_cnt == 1) ? ss_dat[15: 0] : ss_buffer2;
          ss_buffer3 <= (pack_cnt == 2) ? ss_dat[15: 0] : ss_buffer3;
          ss_buffer4 <= (pack_cnt == 3) ? ss_dat[15: 0] : ss_buffer4;
          ss_buffer5 <= (pack_cnt == 4) ? ss_dat[15: 0] : ss_buffer5;
          ss_buffer6 <= (pack_cnt == 5) ? ss_dat[15: 0] : ss_buffer6;
          ss_buffer7 <= (pack_cnt == 6) ? ss_dat[15: 0] : ss_buffer7;
          ss_buffer8 <= (pack_cnt == 7) ? ss_dat[15: 0] : ss_buffer8;
        end else begin
          ss_buffer1 <= ss_buffer1;
          ss_buffer2 <= ss_buffer2;
          ss_buffer3 <= ss_buffer3;
          ss_buffer4 <= ss_buffer4;
          ss_buffer5 <= ss_buffer5;
          ss_buffer6 <= ss_buffer6;
          ss_buffer7 <= ss_buffer7;
          ss_buffer8 <= ss_buffer8;
        end
      end else begin
        ss_buffer1 <= ss_buffer1;
        ss_buffer2 <= ss_buffer2;
        ss_buffer3 <= ss_buffer3;
        ss_buffer4 <= ss_buffer4;
        ss_buffer5 <= ss_buffer5;
        ss_buffer6 <= ss_buffer6;
        ss_buffer7 <= ss_buffer7;
        ss_buffer8 <= ss_buffer8;
      end
    end
  end

  assign ss_buffer = {ss_buffer8, ss_buffer7, ss_buffer6, ss_buffer5,
                      ss_buffer4, ss_buffer3, ss_buffer2, ss_buffer1};


  reg l;
  always @(posedge clk) begin
    l <= 1;
  end

  /*---------------------------------------------
                    coef input
  ---------------------------------------------*/

  // fft, ifft


  assign fft_coef_ram_we = {4{(pack_cnt == 3 || pack_cnt == 7) && (ss_vld && ss_rdy)
                           && (destination == COEF_FFT || destination == COEF_iFFT)}};

  always @(posedge clk) begin
    fft_coef_ram_we_r <= fft_coef_ram_we;
  end

  assign fft_coef_ram_a =  {coef_addr_cnt_fft - 1, 2'b00};

  // ntt


  assign ntt_coef_ram_we = {4{(pack_cnt == 7) && (ss_vld && ss_rdy) 
                            && (destination == COEF_NTT)}};

  always @(posedge clk) begin
    ntt_coef_ram_we_r <= ntt_coef_ram_we;
  end

  assign ntt_coef_ram_a = {coef_addr_cnt_ntt - 1, 2'b00};

  // intt

  assign intt_coef_ram_we = {4{(pack_cnt == 7) && (ss_vld && ss_rdy) 
                            && (destination == COEF_iNTT)}};
  always @(posedge clk) begin
    intt_coef_ram_we_r <= intt_coef_ram_we;
  end
  assign intt_coef_ram_a = {coef_addr_cnt_ntt - 1, 2'b00};

  /*---------------------------------------------
                    ss_tready
  ---------------------------------------------*/

  reg ss_rdy_i;
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      ss_rdy_i <= 1'b0;
    end else begin
      ss_rdy_i <= (mode == MODE_iNTT) ? ((ss_vld && ss_rdy_i) ? 0 : 1) : 0;
    end
  end

  assign ss_rdy = (state == 0 || (state == 2 && meta_cnt < length)) ?  (mode == MODE_iNTT) ? ss_rdy_i : l : 0;

  /*---------------------------------------------
                    data input
  ---------------------------------------------*/

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      phase <= 1'b0;
    end else begin
      if (mode == MODE_FFT || mode == MODE_NTT) begin
        phase <= 0;
      end else if (mode == MODE_iNTT) begin
        phase <= (ss_rdy && ss_vld && meta_cnt != 0) ? 1 : 0;
      end else begin
        phase <= phase;
      end
    end
  end

  reg [3:0] ram1_we_fft_r;
  always @(posedge clk) begin
    ram1_we_fft_r <= ram1_we_fft;
  end

  reg [3:0] ram1_we_ntt_r;
  always @(posedge clk) begin
    ram1_we_ntt_r <= ram1_we_ntt;
  end

  reg [3:0] ram1_we_intt_r;
  always @(posedge clk) begin
    ram1_we_intt_r <= ram1_we_intt;
  end

  assign ram1_we_fft = {4{(pack_cnt == 3 || pack_cnt == 7) && (ss_vld && ss_rdy) && (mode == MODE_FFT || mode == MODE_iFFT)}};

  assign ram1_we_ntt = {4{(pack_cnt == 7) && (ss_vld && ss_rdy) 
                        && (mode == MODE_NTT)}};

  assign ram1_we_intt = {4{phase}};

  assign ram1_we = (mode == MODE_FFT || mode == MODE_iFFT) ? ram1_we_fft_r :
                   (mode == MODE_NTT) ? ram1_we_ntt_r :
                   (mode == MODE_iNTT) ? ram1_we_intt : 4'b0000;

  reg  [127:0] latch_do;
  reg  [12:0] latch_a;
  wire [127:0] ram1_do;

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      latch_do <= 0;
    end else begin
      if (ss_rdy && ss_vld && meta_cnt != 0 && (mode == MODE_iNTT) ) begin
        latch_do <= ram1_do;
      end else begin
        latch_do <= 0;
      end
    end
  end

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      latch_a <= 0;
    end else begin
      if (ss_rdy && ss_vld && meta_cnt != 0 && (mode == MODE_iNTT) ) begin
        latch_a <= ram1_a_intt;
      end else begin
        latch_a <= 0;
      end
    end
  end

  assign ram1_a_fft = {coef_addr_cnt_fft - 1, 2'b00};
  assign ram1_a_ntt = {coef_addr_cnt_ntt - 1, 2'b00};
  assign ram1_a_ifft = {ram1_a_fft[0], ram1_a_fft[1], ram1_a_fft[2], ram1_a_fft[3], ram1_a_fft[4],
                        ram1_a_fft[5], ram1_a_fft[6], ram1_a_fft[7], ram1_a_fft[8], ram1_a_fft[9],
                        ram1_a_fft[10], ram1_a_fft[11], ram1_a_fft[12]};

  wire [12:0] ram1_a_intt_no;
  assign ram1_a_intt_no = (meta_cnt - 1);
  assign ram1_a_intt = {ram1_a_intt_no[0], ram1_a_intt_no[1], ram1_a_intt_no[2], ram1_a_intt_no[3], ram1_a_intt_no[4],
                        ram1_a_intt_no[5], ram1_a_intt_no[6], ram1_a_intt_no[7], ram1_a_intt_no[8], ram1_a_intt_no[9]} >> 3;

  assign ram1_a = (mode == MODE_FFT) ? ram1_a_fft :
                  (mode == MODE_NTT) ? ram1_a_ntt :
                  (mode == MODE_iFFT) ? ram1_a_ifft :
                  (mode == MODE_iNTT) ? phase ? latch_a : {ram1_a_intt, 2'b00} 
                    : 13'b0000000000000;
  
  always @* begin
    if (mode == MODE_FFT || mode == MODE_iFFT || mode == MODE_NTT) begin
      ram1_di = ss_buffer;
    end else if ( mode == MODE_iNTT) begin
      case (ram1_a_intt[2:0])
        0: ram1_di = {latch_do[127:16], ss_dat[15:0]};
        1: ram1_di = {latch_do[127:32], ss_dat[15:0], latch_do[15:0]};
        2: ram1_di = {latch_do[127:48], ss_dat[15:0], latch_do[31:0]};
        3: ram1_di = {latch_do[127:64], ss_dat[15:0], latch_do[47:0]};
        4: ram1_di = {latch_do[127:80], ss_dat[15:0], latch_do[63:0]};
        5: ram1_di = {latch_do[127:96], ss_dat[15:0], latch_do[79:0]};
        6: ram1_di = {latch_do[127:112], ss_dat[15:0], latch_do[95:0]};
        7: ram1_di = {ss_dat[15:0], latch_do[111:0]};
        default: ram1_di = 128'b0;
      endcase
    end else begin
      ram1_di = ss_buffer;
    end
  end

  /*---------------------------------------------
            state: input, process, output
  ---------------------------------------------*/

  wire   start_output;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      state <= 0;
    end else begin
      if (state == 0 &&ss_vld && ss_rdy && meta_cnt == length && destination[4] == 0) begin
        state <= 1;
      end else if (state == 1 && sw_lst) begin
        state <= 2;
      end else if (state == 2 && output_cnt == length_old - 1) begin
        state <= 0;
      end else begin
        state <= state;
      end
    end
  end

  /*---------------------------------------------
                    decode
  ---------------------------------------------*/

  reg decode;

  assign decode_q = state && ram1_we == 4'hf  && (state != 2);

  always @ (posedge clk_s or negedge rstn) begin
    if (!rstn) begin
      decode <= 0;
    end else begin
      decode <= decode_q;
    end
  end

  /*---------------------------------------------
                    output
  ---------------------------------------------*/

  //output addr counter;
  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      output_cnt <= 0;
    end else begin
      if (state == 2 ) begin
        if (output_cnt == length_old && sm_rdy && sm_vld) begin
          output_cnt <= 0;
        end else begin
          output_cnt <= output_cnt + 1;
        end
      end else begin
        output_cnt <= 0;
      end
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      length_old <= 0;
    end else begin
      length_old <= (decode) ? length : length_old;
    end
  end

  reg [1:0] mode_latch;
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      mode_latch <= 0;
    end else begin
      mode_latch <= (decode) ? mode[1:0] : mode_latch;
    end
  end

  assign sm_vld = state == 2;

  /*---------------------------------------------
                    output addr
  ---------------------------------------------*/

  wire [11:0] output_cnt_ro_ifft;
  wire [11:0] output_cnt_ro_intt;
  wire [12:0] output_addr_fft;
  wire [12:0] output_addr_ifft;
  wire [12:0] output_addr_intt;
  wire [12:0] output_addr_ntt;

  wire [12:0] output_a;
  wire [127:0] ram_2_do;

  assign output_cnt_ro_ifft = {output_addr_fft[0], output_addr_fft[1], output_addr_fft[2], output_addr_fft[3], output_addr_fft[4],
                          output_addr_fft[5], output_addr_fft[6], output_addr_fft[7], output_addr_fft[8], output_addr_fft[9], output_addr_fft[10]};


  assign output_cnt_ro_intt = {output_cnt[0], output_cnt[1], output_cnt[2], output_cnt[3], output_cnt[4],
                          output_cnt[5], output_cnt[6], output_cnt[7], output_cnt[8], output_cnt[9]};

  assign output_addr_fft = {output_cnt >> 2, 2'b00};
  assign output_addr_ifft = {output_cnt_ro_ifft , 2'b00};
  assign output_addr_intt = {output_cnt_ro_intt >> 3, 2'b00};
  assign output_addr_ntt = {output_cnt >> 3, 2'b00};

  assign output_a = (mode_latch == 0) ? output_addr_fft :
                    (mode_latch == 1) ? output_addr_ifft :
                    (mode_latch == 2) ? output_addr_ntt :
                    (mode_latch == 3) ? output_addr_intt :
                    13'b0000000000000;

  always @* begin
    if (mode_latch == 2'b00 || mode_latch == 2'b01) begin
      sm_dat = ram_2_do;
    end else if (mode_latch == 2'b10) begin
      case (output_cnt[2:0])
        0: sm_dat = ram_2_do[15:0];
        1: sm_dat = ram_2_do[31:16];
        2: sm_dat = ram_2_do[47:32];
        3: sm_dat = ram_2_do[63:48];
        4: sm_dat = ram_2_do[79:64];
        5: sm_dat = ram_2_do[95:80];
        6: sm_dat = ram_2_do[111:96];
        7: sm_dat = ram_2_do[127:112];
        default: sm_dat = 32'b0;
      endcase
    end else if (mode_latch == 2'b11) begin
      case (output_cnt_ro_intt[2:0])
        0: sm_dat = ram_2_do[15:0];
        1: sm_dat = ram_2_do[31:16];
        2: sm_dat = ram_2_do[47:32];
        3: sm_dat = ram_2_do[63:48];
        4: sm_dat = ram_2_do[79:64];
        5: sm_dat = ram_2_do[95:80];
        6: sm_dat = ram_2_do[111:96];
        7: sm_dat = ram_2_do[127:112];
        default: sm_dat = 32'b0;
      endcase
    end else begin
      sm_dat = 32'b0;
    end
  end

  ////////////////////////////////////////////////////////////////
  // use the state register state[1:0] (already declared)
  // state == 0: input data
  // state == 1: decode impulse and kernal processes the data
  // state == 2: output data
  ////////////////////////////////////////////////////////////////

  // enable signal of ram still need to be modified

  /*---------------------------------------------
                    RAM instance
  ---------------------------------------------*/

  wire         ram1_clk_mux;
  wire [  3:0] ram1_we_mux;
  wire         ram1_en_mux;
  wire [127:0] ram1_di_mux;
  wire [127:0] ram1_do_mux;
  wire [ 12:0] ram1_a_mux;

  assign ram1_we_mux  = (state == 1) ? WE_512_1 : ram1_we;
  assign ram1_en_mux  = (state == 1) ? sram_en_512_1 : l;
  assign ram1_di_mux  = (state == 1) ? sram_din_512_1 : ram1_di;
  assign ram1_a_mux   = (state == 1) ? sram_addr_512_1 : ram1_a;

  wire        ram2_clk_mux;
  wire [  3:0] ram2_we_mux;
  wire         ram2_en_mux;
  wire [127:0] ram2_di_mux;
  wire [127:0] ram2_do_mux;
  wire [ 12:0] ram2_a_mux;

  assign ram2_en_mux  = (state == 1) ? sram_en_512_2 : l;
  assign ram2_a_mux   = (state == 1) ? sram_addr_512_2 : output_a;

  wire         fft_coef_ram_en_mux;
  wire [ 12:0] fft_coef_ram_a_mux;

  assign fft_coef_ram_en_mux  = (state == 1) ? coef_sram_en_512 : l;
  assign fft_coef_ram_a_mux   = (state == 1) ? coef_sram_addr_512 : fft_coef_ram_a;

  wire        ntt_coef_ram_en_mux;
  wire [ 12:0] ntt_coef_ram_a_mux;

  assign ntt_coef_ram_en_mux  = (state == 1) ? coef_sram_en_ntt : l;
  assign ntt_coef_ram_a_mux   = (state == 1) ? coef_sram_addr_ntt : ntt_coef_ram_a;

  wire        intt_coef_ram_en_mux;
  wire [ 12:0] intt_coef_ram_a_mux;

  assign intt_coef_ram_en_mux  = (state == 1) ? coef_sram_en_intt : l;
  assign intt_coef_ram_a_mux   = (state == 1) ? coef_sram_addr_intt : intt_coef_ram_a;

  bram512x128 RAM1 (
    .CLK  (clk),
    .WE   (ram1_we_mux),
    .EN   (ram1_en_mux),
    .Di   (ram1_di_mux),
    .Do   (ram1_do),
    .A    (ram1_a_mux)
  );

  bram512x128 RAM2 (
    .CLK  (clk),
    .WE   (WE_512_2),
    .EN   (ram2_en_mux),
    .Di   (sram_din_512_2),
    .Do   (ram_2_do),
    .A    (ram2_a_mux)
  );

  bram512x128 FFT_COEF_RAM (
    .CLK  (clk),
    .WE   (fft_coef_ram_we_r),
    .EN   (fft_coef_ram_en_mux),
    .Di   (ss_buffer),
    .Do   (coef_sram_dout_512),
    .A    (fft_coef_ram_a_mux)
  );

  bram128x128 NTT_COEF_RAM (
    .CLK  (clk),
    .WE   (ntt_coef_ram_we_r),
    .EN   (ntt_coef_ram_en_mux),
    .Di   (ss_buffer),
    .Do   (coef_sram_dout_ntt),
    .A    (ntt_coef_ram_a_mux)
  );

  bram128x128 iNTT_COEF_RAM (
    .CLK  (clk),
    .WE   (intt_coef_ram_we_r),
    .EN   (intt_coef_ram_en_mux),
    .Di   (ss_buffer),
    .Do   (coef_sram_dout_intt),
    .A    (intt_coef_ram_a_mux)
  );

  kernel kernel_inst (
    .clk(clk_s),
    .clk_2x(clk),
    .rstn(rstn),

    .mode(mode_k),
    .decode(decode),
    .sw_lst(sw_lst),

    .WE_512_1(WE_512_1),
    .sram_en_512_1(sram_en_512_1),
    .sram_din_512_1(sram_din_512_1),
    .sram_dout_512_1(ram1_do),
    .sram_addr_512_1(sram_addr_512_1),

    .WE_512_2(WE_512_2),
    .sram_en_512_2(sram_en_512_2),
    .sram_din_512_2(sram_din_512_2),
    .sram_dout_512_2(ram_2_do),
    .sram_addr_512_2(sram_addr_512_2),

    .coef_WE_512(coef_WE_512),
    .coef_sram_en_512(coef_sram_en_512),
    .coef_sram_din_512(coef_sram_din_512),
    .coef_sram_dout_512(coef_sram_dout_512),
    .coef_sram_addr_512(coef_sram_addr_512),

    .coef_WE_ntt(coef_WE_ntt),
    .coef_sram_en_ntt(coef_sram_en_ntt),
    .coef_sram_din_ntt(coef_sram_din_ntt),
    .coef_sram_dout_ntt(coef_sram_dout_ntt),
    .coef_sram_addr_ntt(coef_sram_addr_ntt),

    .coef_WE_intt(coef_WE_intt),
    .coef_sram_en_intt(coef_sram_en_intt),
    .coef_sram_din_intt(coef_sram_din_intt),
    .coef_sram_dout_intt(coef_sram_dout_intt),
    .coef_sram_addr_intt(coef_sram_addr_intt)

  );





endmodule
