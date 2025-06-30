
// Using Deep-Feedback structure, we will have
module stage_top
#(  
  parameter pDATA_WIDTH = 128, // two 64-bit numbers
  parameter pSS_WIDTH = 32 // two 64-bit numbers
)
(
  input   wire                     clk,
  input   wire                     clk_2x,
  input   wire                     rstn,

  //input   wire               [1:0] in1_sw,  // not used for now
  output   wire             [31:0] ap_ctrl,
  output   wire             [31:0] coef_ctrl,
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
  output  wire [(pSS_WIDTH-1):0]   sm_dat, 
  output  wire                     sm_lst,  // not used for now

  // 1st Kernel
  output   wire                    clk1,
  output   wire                    rstn1,

  output  wire                     k1_ld_vld,  // Stream: X[a], X[b], GM constant
  input   wire                     k1_ld_rdy,
  output  wire [(pDATA_WIDTH-1):0] k1_ld_dat,
  input   wire                     k1_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
  output  wire                     k1_sw_rdy,
  input   wire [(pDATA_WIDTH-1):0] k1_sw_dat,

  output  wire                     k1_coef_vld,
  input   wire                     k1_coef_rdy,
  output  wire [(pDATA_WIDTH-1):0] k1_coef_dat,
  input   wire               [4:0] k1_bpe_act,

  output  wire               [7:0] k1_mode,
  output  wire                     decode1,
  input   wire                     k1_sw_lst,
  
  // 2nd Kernel
  output   wire                    clk2,
  output   wire                    rstn2,
  output  wire                     k2_ld_vld,  // Stream: X[a], X[b], GM constant
  input   wire                     k2_ld_rdy,
  output  wire [(pDATA_WIDTH-1):0] k2_ld_dat,
  input   wire                     k2_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
  output  wire                     k2_sw_rdy,
  input   wire [(pDATA_WIDTH-1):0] k2_sw_dat,
  output  wire               [7:0] k2_mode,
  output  wire                     decode2, 
  input   wire                     k2_sw_lst,
  output  wire                     k2_coef_vld,
  input   wire                     k2_coef_rdy,
  output  wire [(pDATA_WIDTH-1):0] k2_coef_dat,
  input   wire               [4:0] k2_bpe_act,

  // 3rd Kernel
  output   wire                    clk3,
  output   wire                    rstn3,
  output  wire                     k3_ld_vld,  // Stream: X[a], X[b], GM constant
  input   wire                     k3_ld_rdy,
  output  wire [(pDATA_WIDTH-1):0] k3_ld_dat,
  input   wire                     k3_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
  output  wire                     k3_sw_rdy,
  input   wire [(pDATA_WIDTH-1):0] k3_sw_dat,
  output  wire               [7:0] k3_mode,
  output  wire                     decode3, 
  input   wire                     k3_sw_lst,
  output  wire                     k3_coef_vld,
  input   wire                     k3_coef_rdy,
  output  wire [(pDATA_WIDTH-1):0] k3_coef_dat,
  input   wire               [4:0] k3_bpe_act,
  
  // 4th Kernel
  output   wire                    clk4,
  output   wire                    rstn4,
  output  wire                     k4_ld_vld,  // Stream: X[a], X[b], GM constant
  input   wire                     k4_ld_rdy,
  output  wire [(pDATA_WIDTH-1):0] k4_ld_dat,
  input   wire                     k4_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
  output  wire                     k4_sw_rdy,
  input   wire [(pDATA_WIDTH-1):0] k4_sw_dat,
  output  wire               [7:0] k4_mode,
  output  wire                     decode4,
  input   wire                     k4_sw_lst,
  output  wire                     k4_coef_vld,
  input   wire                     k4_coef_rdy,
  output  wire [(pDATA_WIDTH-1):0] k4_coef_dat,
  input   wire               [4:0] k4_bpe_act
);

  reg   [15:0]              ss_buffer1;
  reg   [15:0]              ss_buffer2;
  reg   [15:0]              ss_buffer3;
  reg   [15:0]              ss_buffer4;
  reg   [15:0]              ss_buffer5;
  reg   [15:0]              ss_buffer6;
  reg   [15:0]              ss_buffer7;
  reg   [15:0]              ss_buffer8;
  wire  [(pDATA_WIDTH-1):0] ss_buffer;
  // data length
  reg   [15:0]              data_length;

  // kernal mode
  reg   [1:0]               k1_mode_r;
  reg   [1:0]               k2_mode_r;
  reg   [1:0]               k3_mode_r;
  reg   [1:0]               k4_mode_r;

  // meta data and meta counter
  reg   [11:0]              meta_counter;
  reg   [31:0]              meta_data;
  wire  [ 7:0]              kernal_mode;
  wire  [ 7:0]              destination;
  
  // pack counter
  reg   [ 3:0]              pack_counter;

  // fft coef ram
  wire  [(pDATA_WIDTH-1):0] fft_coef_ram_di;
  reg   [ 3:0]              fft_coef_ram_we;
  wire                      fft_coef_ram_en;
  wire  [12:0]              fft_coef_ram_a;
  wire  [(pDATA_WIDTH-1):0] fft_coef_ram_do;
  reg   [12:0]              fft_coef_addr_gen;

  // ntt coef ram
  wire  [(pDATA_WIDTH-1):0] ntt_coef_ram_di;
  reg   [ 3:0]              ntt_coef_ram_we;
  wire                      ntt_coef_ram_en;
  reg   [ 3:0]              intt_coef_ram_we;
  wire  [12:0]              ntt_coef_ram_a;
  wire  [(pDATA_WIDTH-1):0] ntt_coef_ram_do;
  reg   [12:0]              ntt_coef_addr_gen;

  // kernal data stream in
  reg                       k1_ld_vld_r;
  reg                       k2_ld_vld_r;
  reg                       k3_ld_vld_r;
  reg                       k4_ld_vld_r;

  //control kernal coef_vld
  wire                      isempty;
  wire                      k1_pop;
  wire                      k2_pop;
  wire                      k3_pop;
  wire                      k4_pop;
  wire                      k1_push;
  wire                      k2_push;
  wire                      k3_push;
  wire                      k4_push;
  wire                      push;
  wire                      pop;
  reg   [2:0]               fetching_kernal;
  reg   [2:0]               fetching_kernal_next;
  reg   [3:0]               acted_table;
  wire                      k1_coef_en;
  wire                      k2_coef_en;
  wire                      k3_coef_en;
  wire                      k4_coef_en;
  wire  [2:0]               coef_vld_mux;


  // send coef to kernal
  // KERNAL 1
  // BPE 1
  reg   [11:0]              stage1_cnt_k1;
  reg   [11:0]              stage2_cnt_k1;
  reg   [ 3:0]              step_cnt1_k1;
  wire  [11:0]              a_mux1_k1;
  // BPE 2
  reg   [11:0]              stage3_cnt_k1;
  reg   [11:0]              stage4_cnt_k1;
  reg   [ 3:0]              step_cnt2_k1;
  wire  [11:0]              a_mux2_k1;
  // BPE 3
  reg   [11:0]              stage5_cnt_k1;
  reg   [11:0]              stage6_cnt_k1;
  reg   [ 3:0]              step_cnt3_k1;
  wire  [11:0]              a_mux3_k1;
  // BPE 4
  reg   [11:0]              stage7_cnt_k1;
  reg   [11:0]              stage8_cnt_k1;
  reg   [ 3:0]              step_cnt4_k1;
  wire  [11:0]              a_mux4_k1;
  // BPE5
  reg   [11:0]              stage9_cnt_k1;
  reg   [ 3:0]              step_cnt5_k1;
  wire  [11:0]              a_mux5_k1;
  // MUX
  reg   [ 2:0]              bpe_mux_k1;
  // KERNAL 2
  // BPE 1
  reg   [11:0]              stage1_cnt_k2;
  reg   [11:0]              stage2_cnt_k2;
  reg   [ 3:0]              step_cnt1_k2;
  wire  [11:0]              a_mux1_k2;
  // BPE 2
  reg   [11:0]              stage3_cnt_k2;
  reg   [11:0]              stage4_cnt_k2;
  reg   [ 3:0]              step_cnt2_k2;
  wire  [11:0]              a_mux2_k2;
  // BPE 3
  reg   [11:0]              stage5_cnt_k2;
  reg   [11:0]              stage6_cnt_k2;
  reg   [ 3:0]              step_cnt3_k2;
  wire  [11:0]              a_mux3_k2;
  // BPE 4
  reg   [11:0]              stage7_cnt_k2;
  reg   [11:0]              stage8_cnt_k2;
  reg   [ 3:0]              step_cnt4_k2;
  wire  [11:0]              a_mux4_k2;
  // BPE5
  reg   [11:0]              stage9_cnt_k2;
  reg   [ 3:0]              step_cnt5_k2;
  wire  [11:0]              a_mux5_k2;
  // MUX
  reg   [ 2:0]              bpe_mux_k2;
  // KERNAL 3
  // BPE 1
  reg   [11:0]              stage1_cnt_k3;
  reg   [11:0]              stage2_cnt_k3;
  reg   [ 3:0]              step_cnt1_k3;
  wire  [11:0]              a_mux1_k3;
  // BPE 2
  reg   [11:0]              stage3_cnt_k3;
  reg   [11:0]              stage4_cnt_k3;
  reg   [ 3:0]              step_cnt2_k3;
  wire  [11:0]              a_mux2_k3;
  // BPE 3
  reg   [11:0]              stage5_cnt_k3;
  reg   [11:0]              stage6_cnt_k3;
  reg   [ 3:0]              step_cnt3_k3;
  wire  [11:0]              a_mux3_k3;
  // BPE 4
  reg   [11:0]              stage7_cnt_k3;
  reg   [11:0]              stage8_cnt_k3;
  reg   [ 3:0]              step_cnt4_k3;
  wire  [11:0]              a_mux4_k3;
  // BPE5
  reg   [11:0]              stage9_cnt_k3;
  reg   [ 3:0]              step_cnt5_k3;
  wire  [11:0]              a_mux5_k3;
  // MUX
  reg   [ 2:0]              bpe_mux_k3;
  // KERNAL 4
  // BPE 1
  reg   [11:0]              stage1_cnt_k4;
  reg   [11:0]              stage2_cnt_k4;
  reg   [ 3:0]              step_cnt1_k4;
  wire  [11:0]              a_mux1_k4;
  // BPE 2
  reg   [11:0]              stage3_cnt_k4;
  reg   [11:0]              stage4_cnt_k4;
  reg   [ 3:0]              step_cnt2_k4;
  wire  [11:0]              a_mux2_k4;
  // BPE 3
  reg   [11:0]              stage5_cnt_k4;
  reg   [11:0]              stage6_cnt_k4;
  reg   [ 3:0]              step_cnt3_k4;
  wire  [11:0]              a_mux3_k4;
  // BPE 4
  reg   [11:0]              stage7_cnt_k4;
  reg   [11:0]              stage8_cnt_k4;
  reg   [ 3:0]              step_cnt4_k4;
  wire  [11:0]              a_mux4_k4;
  // BPE5
  reg   [11:0]              stage9_cnt_k4;
  reg   [ 3:0]              step_cnt5_k4;
  wire  [11:0]              a_mux5_k4;
  // MUX
  reg   [ 2:0]              bpe_mux_k4;

  // MUX together
  wire  [ 7:0]               kernal_bpe_mux;
  wire  [ 7:0]               k1_mux;
  wire  [ 7:0]               k2_mux;
  wire  [ 7:0]               k3_mux;
  wire  [ 7:0]               k4_mux;
  // coef address generator
  wire  [12:0]               coef_fetch_a;

  // ntt send coef to kernal
  wire  [12:0]               ntt_kernal_a;


  parameter FOR_BPE1 = 1;
  parameter FOR_BPE2 = 2;
  parameter FOR_BPE3 = 3;
  parameter FOR_BPE4 = 4;
  parameter FOR_BPE5 = 5;

  //for test only
  assign clk1 = clk;
  assign clk2 = clk;
  assign clk3 = clk;
  assign clk4 = clk;
  assign ss_rdy = 1;


  /*----------------------------------------------------------------
                              data length
  -----------------------------------------------------------------*/

  always @* begin
    if (kernal_mode[7:1] == 7'b0001010) begin
      data_length = 16'd1024;
    end else if (kernal_mode[7:1] == 7'b0001011) begin
      data_length = 16'd512;
    end else if (kernal_mode[7:1] == 7'b0000010) begin
      data_length = 16'd2048;
    end else if (kernal_mode[7:1] == 7'b0000011) begin
      data_length = 16'd1024;
    end else begin
      data_length = 16'hFFFF;
    end
  end

  /*----------------------------------------------------------------
                              meta counter
  -----------------------------------------------------------------*/

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      meta_counter <= 12'h0;
    end else begin
      if (ss_rdy && ss_vld) begin
        if (meta_counter < data_length) begin
          meta_counter <= meta_counter + 1;
        end else begin
          meta_counter <= 12'h0;
        end
      end else begin
        meta_counter <= meta_counter;
      end
    end
  end
  
  /*----------------------------------------------------------------
                            decode meta data
  -----------------------------------------------------------------*/
  
  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      meta_data <= 0;
    end else begin
      meta_data <= (ss_rdy && ss_vld && meta_counter == 12'h0) ? ss_dat : meta_data;
    end
  end

  assign kernal_mode  = meta_data[23:16];
  assign destination  = meta_data[31:24];

  /*----------------------------------------------------------------
                            kernal mode
  -----------------------------------------------------------------*/

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      k1_mode_r <= 0;
      k2_mode_r <= 0;
      k3_mode_r <= 0;
      k4_mode_r <= 0;
    end else begin
      k1_mode_r <= (meta_data[31:24] == 8'b00000100) ? meta_data[23:16] : k1_mode_r;
      k2_mode_r <= (meta_data[31:24] == 8'b00000101) ? meta_data[23:16] : k2_mode_r;
      k3_mode_r <= (meta_data[31:24] == 8'b00000110) ? meta_data[23:16] : k3_mode_r;
      k4_mode_r <= (meta_data[31:24] == 8'b00000111) ? meta_data[23:16] : k4_mode_r;
    end
  end

  assign k1_mode = k1_mode_r;
  assign k2_mode = k2_mode_r;
  assign k3_mode = k3_mode_r;
  assign k4_mode = k4_mode_r;

  /*----------------------------------------------------------------
                            pack counter
  -----------------------------------------------------------------*/

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pack_counter <= 4'hF;
    end else begin
      if (ss_rdy && ss_vld) begin
        if (meta_counter == 0) begin
          pack_counter <= 0;
        end else if (pack_counter < 4'd7) begin
          pack_counter <= pack_counter + 1;
        end else begin
          pack_counter <= 4'h0;
        end
      end else begin
        pack_counter <= pack_counter;
      end
    end
  end

  /*----------------------------------------------------------------
                            ss buffer
  -----------------------------------------------------------------*/

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
        if (kernal_mode[2:1] == 2'b10) begin
          ss_buffer5 <= (pack_counter == 0 || pack_counter == 4) ? ss_dat[15: 0] : ss_buffer5;
          ss_buffer6 <= (pack_counter == 0 || pack_counter == 4) ? ss_dat[31:16] : ss_buffer6;
          ss_buffer7 <= (pack_counter == 1 || pack_counter == 5) ? ss_dat[15: 0] : ss_buffer7;
          ss_buffer8 <= (pack_counter == 1 || pack_counter == 5) ? ss_dat[31:16] : ss_buffer8;
          ss_buffer1 <= (pack_counter == 2 || pack_counter == 6) ? ss_dat[15: 0] : ss_buffer1;
          ss_buffer2 <= (pack_counter == 2 || pack_counter == 6) ? ss_dat[31:16] : ss_buffer2;
          ss_buffer3 <= (pack_counter == 3 || pack_counter == 7) ? ss_dat[15: 0] : ss_buffer3;
          ss_buffer4 <= (pack_counter == 3 || pack_counter == 7) ? ss_dat[31:16] : ss_buffer4;
        end else if (kernal_mode[2:1] == 2'b11) begin
          ss_buffer1 <= (pack_counter == 0) ? ss_dat[15: 0] : ss_buffer1;
          ss_buffer2 <= (pack_counter == 1) ? ss_dat[15: 0] : ss_buffer2;
          ss_buffer3 <= (pack_counter == 2) ? ss_dat[15: 0] : ss_buffer3;
          ss_buffer4 <= (pack_counter == 3) ? ss_dat[15: 0] : ss_buffer4;
          ss_buffer5 <= (pack_counter == 4) ? ss_dat[15: 0] : ss_buffer5;
          ss_buffer6 <= (pack_counter == 5) ? ss_dat[15: 0] : ss_buffer6;
          ss_buffer7 <= (pack_counter == 6) ? ss_dat[15: 0] : ss_buffer7;
          ss_buffer8 <= (pack_counter == 7) ? ss_dat[15: 0] : ss_buffer8;
        end else begin
          ss_buffer1 <= 0;
          ss_buffer2 <= 0;
          ss_buffer3 <= 0;
          ss_buffer4 <= 0;
          ss_buffer5 <= 0;
          ss_buffer6 <= 0;
          ss_buffer7 <= 0;
          ss_buffer8 <= 0;
        end
      end else begin
        ss_buffer1 <= 0;
        ss_buffer2 <= 0;
        ss_buffer3 <= 0;
        ss_buffer4 <= 0;
        ss_buffer5 <= 0;
        ss_buffer6 <= 0;
        ss_buffer7 <= 0;
        ss_buffer8 <= 0;
      end
    end
  end

  assign ss_buffer = {ss_buffer8, ss_buffer7, ss_buffer6, ss_buffer5, ss_buffer4, ss_buffer3, ss_buffer2, ss_buffer1};

  /*----------------------------------------------------------------
                      FFT coef ram and address
  -----------------------------------------------------------------*/

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      fft_coef_addr_gen <= 0;
    end else begin
      if (ss_vld && ss_rdy) begin
        if (meta_counter == 1) begin
          fft_coef_addr_gen <= 0;
        end else if (pack_counter == 3 && meta_counter != 4 || pack_counter == 7) begin
          fft_coef_addr_gen <= fft_coef_addr_gen + 4;
        end else begin
          fft_coef_addr_gen <= fft_coef_addr_gen;
        end
      end else begin
        fft_coef_addr_gen <= fft_coef_addr_gen;
      end
    end
  end

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      fft_coef_ram_we <= 4'h0;
    end else begin
      fft_coef_ram_we <= {4{(pack_counter == 3 || pack_counter == 7) && (destination == 8'b00010100) && ss_vld && ss_rdy}};
    end
  end

  assign fft_coef_ram_di = ss_buffer;
  assign fft_coef_ram_en = 1;
  assign fft_coef_ram_a  = fft_coef_addr_gen;

  /*----------------------------------------------------------------
                      NTT/INTT coef ram address
  -----------------------------------------------------------------*/

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      ntt_coef_addr_gen <= 0;
    end else begin
      if (ss_vld && ss_rdy) begin
        if (meta_counter == 1) begin
          ntt_coef_addr_gen <= 0;
        end else if (pack_counter == 7 && meta_counter != 8) begin
          ntt_coef_addr_gen <= ntt_coef_addr_gen + 4;
        end else begin
          ntt_coef_addr_gen <= ntt_coef_addr_gen;
        end
      end else begin
        ntt_coef_addr_gen <= ntt_coef_addr_gen;
      end
    end
  end

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      ntt_coef_ram_we <= 4'h0;
    end else begin
      ntt_coef_ram_we <= {4{((pack_counter == 7)) && (destination == 8'b00010110) && ss_vld && ss_rdy}};
    end
  end

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      intt_coef_ram_we <= 4'h0;
    end else begin
      intt_coef_ram_we <= {4{((pack_counter == 7)) && (destination == 8'b00010111) && ss_vld && ss_rdy}};
    end
  end

  assign ntt_coef_ram_di = ss_buffer;
  assign ntt_coef_ram_en = 1;
  assign ntt_coef_ram_a  = ntt_coef_addr_gen;

  /*----------------------------------------------------------------
                      kernal data stream in
  -----------------------------------------------------------------*/

  assign k1_ld_dat = ss_buffer;
  assign k2_ld_dat = ss_buffer;
  assign k3_ld_dat = ss_buffer;
  assign k4_ld_dat = ss_buffer;

  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      k1_ld_vld_r <= 0;
      k2_ld_vld_r <= 0;
      k3_ld_vld_r <= 0;
      k4_ld_vld_r <= 0;
    end else begin
      if (kernal_mode[2:1] == 2'b10) begin
        k1_ld_vld_r <= (destination == 8'b00000100 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
        k2_ld_vld_r <= (destination == 8'b00000101 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
        k3_ld_vld_r <= (destination == 8'b00000110 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
        k4_ld_vld_r <= (destination == 8'b00000111 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
      end else if (kernal_mode[2:1] == 2'b11) begin
        k1_ld_vld_r <= (destination == 8'b00000100 && pack_counter == 7 && ss_vld && ss_rdy);
        k2_ld_vld_r <= (destination == 8'b00000101 && pack_counter == 7 && ss_vld && ss_rdy);
        k3_ld_vld_r <= (destination == 8'b00000110 && pack_counter == 7 && ss_vld && ss_rdy);
        k4_ld_vld_r <= (destination == 8'b00000111 && pack_counter == 7 && ss_vld && ss_rdy);
      end else begin
        k1_ld_vld_r <= 0;
        k2_ld_vld_r <= 0;
        k3_ld_vld_r <= 0;
        k4_ld_vld_r <= 0;
      end
    end
  end

  assign k1_ld_vld = k1_ld_vld_r;
  assign k2_ld_vld = k2_ld_vld_r;
  assign k3_ld_vld = k3_ld_vld_r;
  assign k4_ld_vld = k4_ld_vld_r;

  /*----------------------------------------------------------------
                      control kernal coef_vld
  -----------------------------------------------------------------*/

  assign k1_push = |k1_bpe_act;
  assign k2_push = |k2_bpe_act;
  assign k3_push = |k3_bpe_act;
  assign k4_push = |k4_bpe_act;

  assign push = k1_push || k2_push || k3_push || k4_push;
  assign pop  = k1_pop  || k2_pop  || k3_pop  || k4_pop;
  assign isempty = !(acted_table == 4'b0000) ? 0 : 1;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      acted_table[0] <= 0;
      acted_table[1] <= 0;
      acted_table[2] <= 0;
      acted_table[3] <= 0;
    end else begin
      acted_table[0] <= (k1_push) ? 1 : (k1_pop) ? 0 : acted_table[0];
      acted_table[1] <= (k2_push) ? 1 : (k2_pop) ? 0 : acted_table[1];
      acted_table[2] <= (k3_push) ? 1 : (k3_pop) ? 0 : acted_table[2];
      acted_table[3] <= (k4_push) ? 1 : (k4_pop) ? 0 : acted_table[3];
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      fetching_kernal <= 0;
    end else begin
      fetching_kernal <= (isempty && push || pop) ? fetching_kernal_next : fetching_kernal;
    end
  end

  always @* begin
    if (isempty) begin
      if (k1_push) begin
        fetching_kernal_next = 3'd1;
      end else if (k2_push) begin
        fetching_kernal_next = 3'd2;
      end else if (k3_push) begin
        fetching_kernal_next = 3'd3;
      end else if (k4_push) begin
        fetching_kernal_next = 3'd4;
      end else begin
        fetching_kernal_next = 3'd0;
      end
    end else begin  
      if (acted_table[0] && fetching_kernal != 1) begin
        fetching_kernal_next = 3'd1;
      end else if (acted_table[1] && fetching_kernal != 2) begin
        fetching_kernal_next = 3'd2;
      end else if (acted_table[2] && fetching_kernal != 3) begin
        fetching_kernal_next = 3'd3;
      end else if (acted_table[3] && fetching_kernal != 4) begin
        fetching_kernal_next = 3'd4;
      end else begin
        fetching_kernal_next = 3'd0;
      end
    end
  end

  assign coef_vld_mux = (!isempty) ? fetching_kernal : 0;
  
  assign k1_coef_en = (isempty && push || pop) && fetching_kernal_next == 1 || (coef_vld_mux == 3'd1);
  assign k2_coef_en = (isempty && push || pop) && fetching_kernal_next == 2 || (coef_vld_mux == 3'd2);
  assign k3_coef_en = (isempty && push || pop) && fetching_kernal_next == 3 || (coef_vld_mux == 3'd3);
  assign k4_coef_en = (isempty && push || pop) && fetching_kernal_next == 4 || (coef_vld_mux == 3'd4);
  
  
  /*----------------------------------------------------------------
                         fft coef to kernal
  -----------------------------------------------------------------*/
  
  ///////////////////////////////////////////////
  //                  KERNAL 1                 //
  ///////////////////////////////////////////////

  ///////////
  // BPE 1 //
  ///////////

  wire k1_bpe1_en;
  assign k1_bpe1_en = (isempty) ? k1_bpe_act == 5'b00001 : pop && bpe_mux_k1 == 1;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k1 <= 4'hF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        step_cnt1_k1 <= 4'hF;
      end else if (step_cnt1_k1 == 4'hF && k1_bpe1_en) begin
        step_cnt1_k1 <= 4'h0;
      end else if (step_cnt1_k1 != 4'hF && step_cnt1_k1 != 4'h2) begin
        step_cnt1_k1 <= step_cnt1_k1 + 1;
      end else if (step_cnt1_k1 == 4'h2) begin
        step_cnt1_k1 <= 4'hF;
      end else begin
        step_cnt1_k1 <= step_cnt1_k1;
      end
    end else begin
      step_cnt1_k1 <= step_cnt1_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage1_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en && step_cnt1_k1 != 4'h2) begin
      if (k1_sw_lst) begin
        stage1_cnt_k1 <= 12'hFFF;
      end else if (k1_bpe1_en) begin
        if (stage1_cnt_k1 == 12'hFFF) begin
          stage1_cnt_k1 <= 0;
        end else begin
          stage1_cnt_k1 <= stage1_cnt_k1 + 1;
        end
      end else begin
        stage1_cnt_k1 <= stage1_cnt_k1;
      end
    end else begin
      stage1_cnt_k1 <= stage1_cnt_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage2_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        stage2_cnt_k1 <= 12'hFFF;
      end else if (step_cnt1_k1 == 0 || step_cnt1_k1 == 1) begin
        if (stage2_cnt_k1 == 12'hFFF) begin
          stage2_cnt_k1 <= 0;
        end else begin
          stage2_cnt_k1 <= stage2_cnt_k1 + 1;
        end
      end else begin
        stage2_cnt_k1 <= stage2_cnt_k1;
      end
    end else begin
      stage2_cnt_k1 <= stage2_cnt_k1;
    end
  end

  assign a_mux1_k1 = (step_cnt1_k1 == 0) ? stage1_cnt_k1 :
                      (step_cnt1_k1 == 1) ? stage2_cnt_k1 :
                      (step_cnt1_k1 == 2) ? stage2_cnt_k1 : 0;
  

  ///////////
  // BPE 2 //
  ///////////
  wire k1_bpe2_en;
  assign k1_bpe2_en = (isempty) ? k1_bpe_act == 5'b00010 : pop && bpe_mux_k1 == 2;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k1 <= 4'hF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        step_cnt2_k1 <= 4'hF;
      end else if (step_cnt2_k1 == 4'hF && k1_bpe2_en) begin
        step_cnt2_k1 <= 4'h0;
      end else if (step_cnt2_k1 != 4'hF && step_cnt2_k1 != 4'h2) begin
        step_cnt2_k1 <= step_cnt2_k1 + 1;
      end else if (step_cnt2_k1 == 4'h2) begin
        step_cnt2_k1 <= 4'hF;
      end else begin
        step_cnt2_k1 <= step_cnt2_k1;
      end
    end else begin
      step_cnt2_k1 <= step_cnt2_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage3_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en && step_cnt2_k1 != 4'h2) begin
      if (k1_sw_lst) begin
        stage3_cnt_k1 <= 12'hFFF;
      end else if (k1_bpe2_en) begin
        if (stage3_cnt_k1 == 12'hFFF) begin
          stage3_cnt_k1 <= 0;
        end else begin
          stage3_cnt_k1 <= stage3_cnt_k1 + 1;
        end
      end else begin
        stage3_cnt_k1 <= stage3_cnt_k1;
      end
    end else begin
      stage3_cnt_k1 <= stage3_cnt_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage4_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        stage4_cnt_k1 <= 12'hFFF;
      end else if (step_cnt2_k1 == 0 || step_cnt2_k1 == 1) begin
        if (stage4_cnt_k1 == 12'hFFF) begin
          stage4_cnt_k1 <= 0;
        end else begin
          stage4_cnt_k1 <= stage4_cnt_k1 + 1;
        end
      end else begin
        stage4_cnt_k1 <= stage4_cnt_k1;
      end
    end else begin
      stage4_cnt_k1 <= stage4_cnt_k1;
    end
  end

  assign a_mux2_k1 = (step_cnt2_k1 == 0) ? stage3_cnt_k1 :
                      (step_cnt2_k1 == 1) ? stage4_cnt_k1 :
                      (step_cnt2_k1 == 2) ? stage4_cnt_k1 : 0;

  ///////////
  // BPE 3 //
  ///////////
  wire k1_bpe3_en;
  assign k1_bpe3_en = (isempty) ? k1_bpe_act == 5'b00100 : pop && bpe_mux_k1 == 3;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k1 <= 4'hF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        step_cnt3_k1 <= 4'hF;
      end else if (step_cnt3_k1 == 4'hF && k1_bpe3_en) begin
        step_cnt3_k1 <= 4'h0;
      end else if (step_cnt3_k1 != 4'hF && step_cnt3_k1 != 4'h2) begin
        step_cnt3_k1 <= step_cnt3_k1 + 1;
      end else if (step_cnt3_k1 == 4'h2) begin
        step_cnt3_k1 <= 4'hF;
      end else begin
        step_cnt3_k1 <= step_cnt3_k1;
      end
    end else begin
      step_cnt3_k1 <= step_cnt3_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage5_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en && step_cnt3_k1 != 4'h2) begin
      if (k1_sw_lst) begin
        stage5_cnt_k1 <= 12'hFFF;
      end else if (k1_bpe3_en) begin
        if (stage5_cnt_k1 == 12'hFFF) begin
          stage5_cnt_k1 <= 0;
        end else begin
          stage5_cnt_k1 <= stage5_cnt_k1 + 1;
        end
      end else begin
        stage5_cnt_k1 <= stage5_cnt_k1;
      end
    end else begin
      stage5_cnt_k1 <= stage5_cnt_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage6_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        stage6_cnt_k1 <= 12'hFFF;
      end else if (step_cnt3_k1 == 0 || step_cnt3_k1 == 1) begin
        if (stage6_cnt_k1 == 12'hFFF) begin
          stage6_cnt_k1 <= 0;
        end else begin
          stage6_cnt_k1 <= stage6_cnt_k1 + 1;
        end
      end else begin
        stage6_cnt_k1 <= stage6_cnt_k1;
      end
    end else begin
      stage6_cnt_k1 <= stage6_cnt_k1;
    end
  end

  assign a_mux3_k1 = (step_cnt3_k1 == 0) ? stage5_cnt_k1 :
                      (step_cnt3_k1 == 1) ? stage6_cnt_k1 :
                      (step_cnt3_k1 == 2) ? stage6_cnt_k1 : 0;

  ///////////
  // BPE 4 //
  ///////////
  wire k1_bpe4_en;
  assign k1_bpe4_en = (isempty) ? k1_bpe_act == 5'b01000 : pop && bpe_mux_k1 == 4;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k1 <= 4'hF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        step_cnt4_k1 <= 4'hF;
      end else if (step_cnt4_k1 == 4'hF && k1_bpe4_en) begin
        step_cnt4_k1 <= 4'h0;
      end else if (step_cnt4_k1 != 4'hF && step_cnt4_k1 != 4'd11) begin
        step_cnt4_k1 <= step_cnt4_k1 + 1;
      end else if (step_cnt4_k1 == 4'd11) begin
        step_cnt4_k1 <= 4'hF;
      end else begin
        step_cnt4_k1 <= step_cnt4_k1;
      end
    end else begin
      step_cnt4_k1 <= step_cnt4_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage7_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en && step_cnt4_k1 != 4'd11) begin
      if (k1_sw_lst) begin
        stage7_cnt_k1 <= 12'hFFF;
      end else if (k1_bpe4_en || step_cnt4_k1 == 2 || step_cnt4_k1 == 5 || step_cnt4_k1 == 8) begin
        if (stage7_cnt_k1 == 12'hFFF) begin
          stage7_cnt_k1 <= 0;
        end else begin
          stage7_cnt_k1 <= stage7_cnt_k1 + 1;
        end
      end else begin
        stage7_cnt_k1 <= stage7_cnt_k1;
      end
    end else begin
      stage7_cnt_k1 <= stage7_cnt_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage8_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        stage8_cnt_k1 <= 12'hFFF;
      end else if (step_cnt4_k1 == 0 || step_cnt4_k1 == 1 || step_cnt4_k1 == 3 || step_cnt4_k1 == 4 
                || step_cnt4_k1 == 6 || step_cnt4_k1 == 7 || step_cnt4_k1 == 9 || step_cnt4_k1 == 10) begin
        if (stage8_cnt_k1 == 12'hFFF) begin
          stage8_cnt_k1 <= 0;
        end else begin
          stage8_cnt_k1 <= stage8_cnt_k1 + 1;
        end
      end else begin
        stage8_cnt_k1 <= stage8_cnt_k1;
      end
    end else begin
      stage8_cnt_k1 <= stage8_cnt_k1;
    end
  end

  assign a_mux4_k1 = (step_cnt4_k1 == 0 || step_cnt4_k1 == 3 || step_cnt4_k1 == 6 || step_cnt4_k1 == 9) ? stage7_cnt_k1 :
                      (step_cnt4_k1 == 1 || step_cnt4_k1 == 4 || step_cnt4_k1 == 7 || step_cnt4_k1 == 10) ? stage8_cnt_k1 :
                      (step_cnt4_k1 == 2 || step_cnt4_k1 == 5 || step_cnt4_k1 == 8 || step_cnt4_k1 == 11) ? stage8_cnt_k1 : 0;

  ///////////
  // BPE 5 //
  ///////////
  wire k1_bpe5_en;
  assign k1_bpe5_en = (isempty) ? k1_bpe_act == 5'b10000 : pop && bpe_mux_k1 == 5;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k1 <= 4'hF;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        step_cnt5_k1 <= 4'hF;
      end else if (step_cnt5_k1 == 4'hF && k1_bpe5_en) begin
        step_cnt5_k1 <= 4'h0;
      end else if (step_cnt5_k1 != 4'hF && step_cnt5_k1 != 4'd3) begin
        step_cnt5_k1 <= step_cnt5_k1 + 1;
      end else if (step_cnt5_k1 == 4'd3) begin
        step_cnt5_k1 <= 4'hF;
      end else begin
        step_cnt5_k1 <= step_cnt5_k1;
      end
    end else begin
      step_cnt5_k1 <= step_cnt5_k1;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage9_cnt_k1 <= 12'h0;
    end else if (k1_coef_rdy && k1_coef_en) begin
      if (k1_sw_lst) begin
        stage9_cnt_k1 <= 12'h0;
      end else if (step_cnt5_k1 != 4'hF) begin
          stage9_cnt_k1 <= stage9_cnt_k1 + 1;
      end else begin
        stage9_cnt_k1 <= stage9_cnt_k1;
      end
    end else begin
      stage9_cnt_k1 <= stage9_cnt_k1;
    end
  end

  assign a_mux5_k1 = ( step_cnt5_k1 != 4'hF) ? stage9_cnt_k1 : 0;

  /////////////////////////////
  // address mux for bpe 1-5 //
  /////////////////////////////

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      bpe_mux_k1 <= 0;
    end else begin
      bpe_mux_k1 <= (k1_bpe_act == 5'b00001) ? FOR_BPE1 :
                    (k1_bpe_act == 5'b00010) ? FOR_BPE2 :
                    (k1_bpe_act == 5'b00100) ? FOR_BPE3 :
                    (k1_bpe_act == 5'b01000) ? FOR_BPE4 :
                    (k1_bpe_act == 5'b10000) ? FOR_BPE5 :
                    (k1_bpe_act == 5'b00000) ? bpe_mux_k1 : 3'b111;
    end
  end

  ////////////
  // k1_pop //
  ////////////

  assign k1_pop = (bpe_mux_k1 == FOR_BPE1) ? step_cnt1_k1 == 2 : 
                  (bpe_mux_k1 == FOR_BPE2) ? step_cnt2_k1 == 2 : 
                  (bpe_mux_k1 == FOR_BPE3) ? step_cnt3_k1 == 2 : 
                  (bpe_mux_k1 == FOR_BPE4) ? step_cnt4_k1 == 11 : 
                  (bpe_mux_k1 == FOR_BPE5) ? step_cnt5_k1 == 3 : 0;



  ///////////////////////////////////////////////
  //                  KERNAL 2                 //
  ///////////////////////////////////////////////

  ///////////
  // BPE 1 //
  ///////////
  wire k2_bpe1_en;
  assign k2_bpe1_en = (isempty) ? k2_bpe_act == 5'b00001 : pop && bpe_mux_k2 == 1;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k2 <= 4'hF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        step_cnt1_k2 <= 4'hF;
      end else if (step_cnt1_k2 == 4'hF && k2_bpe1_en) begin
        step_cnt1_k2 <= 4'h0;
      end else if (step_cnt1_k2 != 4'hF && step_cnt1_k2 != 4'h2) begin
        step_cnt1_k2 <= step_cnt1_k2 + 1;
      end else if (step_cnt1_k2 == 4'h2) begin
        step_cnt1_k2 <= 4'hF;
      end else begin
        step_cnt1_k2 <= step_cnt1_k2;
      end
    end else begin
      step_cnt1_k2 <= step_cnt1_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage1_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en && step_cnt1_k2 != 4'h2) begin
      if (k2_sw_lst) begin
        stage1_cnt_k2 <= 12'hFFF;
      end else if (k2_bpe1_en) begin
        if (stage1_cnt_k2 == 12'hFFF) begin
          stage1_cnt_k2 <= 0;
        end else begin
          stage1_cnt_k2 <= stage1_cnt_k2 + 1;
        end
      end else begin
        stage1_cnt_k2 <= stage1_cnt_k2;
      end
    end else begin
      stage1_cnt_k2 <= stage1_cnt_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage2_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        stage2_cnt_k2 <= 12'hFFF;
      end else if (step_cnt1_k2 == 0 || step_cnt1_k2 == 1) begin
        if (stage2_cnt_k2 == 12'hFFF) begin
          stage2_cnt_k2 <= 0;
        end else begin
          stage2_cnt_k2 <= stage2_cnt_k2 + 1;
        end
      end else begin
        stage2_cnt_k2 <= stage2_cnt_k2;
      end
    end else begin
      stage2_cnt_k2 <= stage2_cnt_k2;
    end
  end

  assign a_mux1_k2 = (step_cnt1_k2 == 0) ? stage1_cnt_k2 :
                      (step_cnt1_k2 == 1) ? stage2_cnt_k2 :
                      (step_cnt1_k2 == 2) ? stage2_cnt_k2 : 0;
  

  ///////////
  // BPE 2 //
  ///////////
  wire k2_bpe2_en;
  assign k2_bpe2_en = (isempty) ? k2_bpe_act == 5'b00010 : pop && bpe_mux_k2 == 2;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k2 <= 4'hF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        step_cnt2_k2 <= 4'hF;
      end else if (step_cnt2_k2 == 4'hF && k2_bpe2_en) begin
        step_cnt2_k2 <= 4'h0;
      end else if (step_cnt2_k2 != 4'hF && step_cnt2_k2 != 4'h2) begin
        step_cnt2_k2 <= step_cnt2_k2 + 1;
      end else if (step_cnt2_k2 == 4'h2) begin
        step_cnt2_k2 <= 4'hF;
      end else begin
        step_cnt2_k2 <= step_cnt2_k2;
      end
    end else begin
      step_cnt2_k2 <= step_cnt2_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage3_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en && step_cnt2_k2 != 4'h2) begin
      if (k2_sw_lst) begin
        stage3_cnt_k2 <= 12'hFFF;
      end else if (k2_bpe2_en) begin
        if (stage3_cnt_k2 == 12'hFFF) begin
          stage3_cnt_k2 <= 0;
        end else begin
          stage3_cnt_k2 <= stage3_cnt_k2 + 1;
        end
      end else begin
        stage3_cnt_k2 <= stage3_cnt_k2;
      end
    end else begin
      stage3_cnt_k2 <= stage3_cnt_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage4_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        stage4_cnt_k2 <= 12'hFFF;
      end else if (step_cnt2_k2 == 0 || step_cnt2_k2 == 1) begin
        if (stage4_cnt_k2 == 12'hFFF) begin
          stage4_cnt_k2 <= 0;
        end else begin
          stage4_cnt_k2 <= stage4_cnt_k2 + 1;
        end
      end else begin
        stage4_cnt_k2 <= stage4_cnt_k2;
      end
    end else begin
      stage4_cnt_k2 <= stage4_cnt_k2;
    end
  end

  assign a_mux2_k2 = (step_cnt2_k2 == 0) ? stage3_cnt_k2 :
                      (step_cnt2_k2 == 1) ? stage4_cnt_k2 :
                      (step_cnt2_k2 == 2) ? stage4_cnt_k2 : 0;

  ///////////
  // BPE 3 //
  ///////////
  wire k2_bpe3_en;
  assign k2_bpe3_en = (isempty) ? k2_bpe_act == 5'b00100 : pop && bpe_mux_k2 == 3;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k2 <= 4'hF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        step_cnt3_k2 <= 4'hF;
      end else if (step_cnt3_k2 == 4'hF && k2_bpe3_en) begin
        step_cnt3_k2 <= 4'h0;
      end else if (step_cnt3_k2 != 4'hF && step_cnt3_k2 != 4'h2) begin
        step_cnt3_k2 <= step_cnt3_k2 + 1;
      end else if (step_cnt3_k2 == 4'h2) begin
        step_cnt3_k2 <= 4'hF;
      end else begin
        step_cnt3_k2 <= step_cnt3_k2;
      end
    end else begin
      step_cnt3_k2 <= step_cnt3_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage5_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en && step_cnt3_k2 != 4'h2) begin
      if (k2_sw_lst) begin
        stage5_cnt_k2 <= 12'hFFF;
      end else if (k2_bpe3_en) begin
        if (stage5_cnt_k2 == 12'hFFF) begin
          stage5_cnt_k2 <= 0;
        end else begin
          stage5_cnt_k2 <= stage5_cnt_k2 + 1;
        end
      end else begin
        stage5_cnt_k2 <= stage5_cnt_k2;
      end
    end else begin
      stage5_cnt_k2 <= stage5_cnt_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage6_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        stage6_cnt_k2 <= 12'hFFF;
      end else if (step_cnt3_k2 == 0 || step_cnt3_k2 == 1) begin
        if (stage6_cnt_k2 == 12'hFFF) begin
          stage6_cnt_k2 <= 0;
        end else begin
          stage6_cnt_k2 <= stage6_cnt_k2 + 1;
        end
      end else begin
        stage6_cnt_k2 <= stage6_cnt_k2;
      end
    end else begin
      stage6_cnt_k2 <= stage6_cnt_k2;
    end
  end

  assign a_mux3_k2 = (step_cnt3_k2 == 0) ? stage5_cnt_k2 :
                      (step_cnt3_k2 == 1) ? stage6_cnt_k2 :
                      (step_cnt3_k2 == 2) ? stage6_cnt_k2 : 0;

  ///////////
  // BPE 4 //
  ///////////
  wire k2_bpe4_en;
  assign k2_bpe4_en = (isempty) ? k2_bpe_act == 5'b01000 : pop && bpe_mux_k2 == 4;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k2 <= 4'hF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        step_cnt4_k2 <= 4'hF;
      end else if (step_cnt4_k2 == 4'hF && k2_bpe4_en) begin
        step_cnt4_k2 <= 4'h0;
      end else if (step_cnt4_k2 != 4'hF && step_cnt4_k2 != 4'd11) begin
        step_cnt4_k2 <= step_cnt4_k2 + 1;
      end else if (step_cnt4_k2 == 4'd11) begin
        step_cnt4_k2 <= 4'hF;
      end else begin
        step_cnt4_k2 <= step_cnt4_k2;
      end
    end else begin
      step_cnt4_k2 <= step_cnt4_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage7_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en && step_cnt4_k2 != 4'd11) begin
      if (k2_sw_lst) begin
        stage7_cnt_k2 <= 12'hFFF;
      end else if (k2_bpe4_en || step_cnt4_k2 == 2 || step_cnt4_k2 == 5 || step_cnt4_k2 == 8) begin
        if (stage7_cnt_k2 == 12'hFFF) begin
          stage7_cnt_k2 <= 0;
        end else begin
          stage7_cnt_k2 <= stage7_cnt_k2 + 1;
        end
      end else begin
        stage7_cnt_k2 <= stage7_cnt_k2;
      end
    end else begin
      stage7_cnt_k2 <= stage7_cnt_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage8_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        stage8_cnt_k2 <= 12'hFFF;
      end else if (step_cnt4_k2 == 0 || step_cnt4_k2 == 1 || step_cnt4_k2 == 3 || step_cnt4_k2 == 4 
                || step_cnt4_k2 == 6 || step_cnt4_k2 == 7 || step_cnt4_k2 == 9 || step_cnt4_k2 == 10) begin
        if (stage8_cnt_k2 == 12'hFFF) begin
          stage8_cnt_k2 <= 0;
        end else begin
          stage8_cnt_k2 <= stage8_cnt_k2 + 1;
        end
      end else begin
        stage8_cnt_k2 <= stage8_cnt_k2;
      end
    end else begin
      stage8_cnt_k2 <= stage8_cnt_k2;
    end
  end

  assign a_mux4_k2 = (step_cnt4_k2 == 0 || step_cnt4_k2 == 3 || step_cnt4_k2 == 6 || step_cnt4_k2 == 9) ? stage7_cnt_k2 :
                      (step_cnt4_k2 == 1 || step_cnt4_k2 == 4 || step_cnt4_k2 == 7 || step_cnt4_k2 == 10) ? stage8_cnt_k2 :
                      (step_cnt4_k2 == 2 || step_cnt4_k2 == 5 || step_cnt4_k2 == 8 || step_cnt4_k2 == 11) ? stage8_cnt_k2 : 0;

  ///////////
  // BPE 5 //
  ///////////
  wire k2_bpe5_en;
  assign k2_bpe5_en = (isempty) ? k2_bpe_act == 5'b10000 : pop && bpe_mux_k2 == 5;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k2 <= 4'hF;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        step_cnt5_k2 <= 4'hF;
      end else if (step_cnt5_k2 == 4'hF && k2_bpe5_en) begin
        step_cnt5_k2 <= 4'h0;
      end else if (step_cnt5_k2 != 4'hF && step_cnt5_k2 != 4'd3) begin
        step_cnt5_k2 <= step_cnt5_k2 + 1;
      end else if (step_cnt5_k2 == 4'd3) begin
        step_cnt5_k2 <= 4'hF;
      end else begin
        step_cnt5_k2 <= step_cnt5_k2;
      end
    end else begin
      step_cnt5_k2 <= step_cnt5_k2;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage9_cnt_k2 <= 12'h0;
    end else if (k2_coef_rdy && k2_coef_en) begin
      if (k2_sw_lst) begin
        stage9_cnt_k2 <= 12'h0;
      end else if (step_cnt5_k2 != 4'hF) begin
          stage9_cnt_k2 <= stage9_cnt_k2 + 1;
      end else begin
        stage9_cnt_k2 <= stage9_cnt_k2;
      end
    end else begin
      stage9_cnt_k2 <= stage9_cnt_k2;
    end
  end

  assign a_mux5_k2 = ( step_cnt5_k2 != 4'hF) ? stage9_cnt_k2 : 0;

  /////////////////////////////
  // address mux for bpe 1-5 //
  /////////////////////////////

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      bpe_mux_k2 <= 0;
    end else begin
      bpe_mux_k2 <= (k2_bpe_act == 5'b00001) ? FOR_BPE1 :
                    (k2_bpe_act == 5'b00010) ? FOR_BPE2 :
                    (k2_bpe_act == 5'b00100) ? FOR_BPE3 :
                    (k2_bpe_act == 5'b01000) ? FOR_BPE4 :
                    (k2_bpe_act == 5'b10000) ? FOR_BPE5 :
                    (k2_bpe_act == 5'b00000) ? bpe_mux_k2 : 3'b111;
    end
  end

  ////////////
  // k2_pop //
  ////////////

  assign k2_pop = (bpe_mux_k2 == FOR_BPE1) ? step_cnt1_k2 == 2 : 
                  (bpe_mux_k2 == FOR_BPE2) ? step_cnt2_k2 == 2 : 
                  (bpe_mux_k2 == FOR_BPE3) ? step_cnt3_k2 == 2 : 
                  (bpe_mux_k2 == FOR_BPE4) ? step_cnt4_k2 == 11 : 
                  (bpe_mux_k2 == FOR_BPE5) ? step_cnt5_k2 == 3 : 0;

  ///////////////////////////////////////////////
  //                  KERNAL 3                 //
  ///////////////////////////////////////////////

  ///////////
  // BPE 1 //
  ///////////
  wire k3_bpe1_en;
  assign k3_bpe1_en = (isempty) ? k3_bpe_act == 5'b00001 : pop && bpe_mux_k3 == 1;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k3 <= 4'hF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        step_cnt1_k3 <= 4'hF;
      end else if (step_cnt1_k3 == 4'hF && k3_bpe1_en) begin
        step_cnt1_k3 <= 4'h0;
      end else if (step_cnt1_k3 != 4'hF && step_cnt1_k3 != 4'h2) begin
        step_cnt1_k3 <= step_cnt1_k3 + 1;
      end else if (step_cnt1_k3 == 4'h2) begin
        step_cnt1_k3 <= 4'hF;
      end else begin
        step_cnt1_k3 <= step_cnt1_k3;
      end
    end else begin
      step_cnt1_k3 <= step_cnt1_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage1_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en && step_cnt1_k3 != 4'h2) begin
      if (k3_sw_lst) begin
        stage1_cnt_k3 <= 12'hFFF;
      end else if (k3_bpe1_en) begin
        if (stage1_cnt_k3 == 12'hFFF) begin
          stage1_cnt_k3 <= 0;
        end else begin
          stage1_cnt_k3 <= stage1_cnt_k3 + 1;
        end
      end else begin
        stage1_cnt_k3 <= stage1_cnt_k3;
      end
    end else begin
      stage1_cnt_k3 <= stage1_cnt_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage2_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        stage2_cnt_k3 <= 12'hFFF;
      end else if (step_cnt1_k3 == 0 || step_cnt1_k3 == 1) begin
        if (stage2_cnt_k3 == 12'hFFF) begin
          stage2_cnt_k3 <= 0;
        end else begin
          stage2_cnt_k3 <= stage2_cnt_k3 + 1;
        end
      end else begin
        stage2_cnt_k3 <= stage2_cnt_k3;
      end
    end else begin
      stage2_cnt_k3 <= stage2_cnt_k3;
    end
  end

  assign a_mux1_k3 = (step_cnt1_k3 == 0) ? stage1_cnt_k3 :
                      (step_cnt1_k3 == 1) ? stage2_cnt_k3 :
                      (step_cnt1_k3 == 2) ? stage2_cnt_k3 : 0;
  

  ///////////
  // BPE 2 //
  ///////////
  wire k3_bpe2_en;
  assign k3_bpe2_en = (isempty) ? k3_bpe_act == 5'b00010 : pop && bpe_mux_k3 == 2;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k3 <= 4'hF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        step_cnt2_k3 <= 4'hF;
      end else if (step_cnt2_k3 == 4'hF && k3_bpe2_en) begin
        step_cnt2_k3 <= 4'h0;
      end else if (step_cnt2_k3 != 4'hF && step_cnt2_k3 != 4'h2) begin
        step_cnt2_k3 <= step_cnt2_k3 + 1;
      end else if (step_cnt2_k3 == 4'h2) begin
        step_cnt2_k3 <= 4'hF;
      end else begin
        step_cnt2_k3 <= step_cnt2_k3;
      end
    end else begin
      step_cnt2_k3 <= step_cnt2_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage3_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en && step_cnt2_k3 != 4'h2) begin
      if (k3_sw_lst) begin
        stage3_cnt_k3 <= 12'hFFF;
      end else if (k3_bpe2_en) begin
        if (stage3_cnt_k3 == 12'hFFF) begin
          stage3_cnt_k3 <= 0;
        end else begin
          stage3_cnt_k3 <= stage3_cnt_k3 + 1;
        end
      end else begin
        stage3_cnt_k3 <= stage3_cnt_k3;
      end
    end else begin
      stage3_cnt_k3 <= stage3_cnt_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage4_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        stage4_cnt_k3 <= 12'hFFF;
      end else if (step_cnt2_k3 == 0 || step_cnt2_k3 == 1) begin
        if (stage4_cnt_k3 == 12'hFFF) begin
          stage4_cnt_k3 <= 0;
        end else begin
          stage4_cnt_k3 <= stage4_cnt_k3 + 1;
        end
      end else begin
        stage4_cnt_k3 <= stage4_cnt_k3;
      end
    end else begin
      stage4_cnt_k3 <= stage4_cnt_k3;
    end
  end

  assign a_mux2_k3 = (step_cnt2_k3 == 0) ? stage3_cnt_k3 :
                      (step_cnt2_k3 == 1) ? stage4_cnt_k3 :
                      (step_cnt2_k3 == 2) ? stage4_cnt_k3 : 0;

  ///////////
  // BPE 3 //
  ///////////
  wire k3_bpe3_en;
  assign k3_bpe3_en = (isempty) ? k3_bpe_act == 5'b00100 : pop && bpe_mux_k3 == 3;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k3 <= 4'hF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        step_cnt3_k3 <= 4'hF;
      end else if (step_cnt3_k3 == 4'hF && k3_bpe3_en) begin
        step_cnt3_k3 <= 4'h0;
      end else if (step_cnt3_k3 != 4'hF && step_cnt3_k3 != 4'h2) begin
        step_cnt3_k3 <= step_cnt3_k3 + 1;
      end else if (step_cnt3_k3 == 4'h2) begin
        step_cnt3_k3 <= 4'hF;
      end else begin
        step_cnt3_k3 <= step_cnt3_k3;
      end
    end else begin
      step_cnt3_k3 <= step_cnt3_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage5_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en && step_cnt3_k3 != 4'h2) begin
      if (k3_sw_lst) begin
        stage5_cnt_k3 <= 12'hFFF;
      end else if (k3_bpe3_en) begin
        if (stage5_cnt_k3 == 12'hFFF) begin
          stage5_cnt_k3 <= 0;
        end else begin
          stage5_cnt_k3 <= stage5_cnt_k3 + 1;
        end
      end else begin
        stage5_cnt_k3 <= stage5_cnt_k3;
      end
    end else begin
      stage5_cnt_k3 <= stage5_cnt_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage6_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        stage6_cnt_k3 <= 12'hFFF;
      end else if (step_cnt3_k3 == 0 || step_cnt3_k3 == 1) begin
        if (stage6_cnt_k3 == 12'hFFF) begin
          stage6_cnt_k3 <= 0;
        end else begin
          stage6_cnt_k3 <= stage6_cnt_k3 + 1;
        end
      end else begin
        stage6_cnt_k3 <= stage6_cnt_k3;
      end
    end else begin
      stage6_cnt_k3 <= stage6_cnt_k3;
    end
  end

  assign a_mux3_k3 = (step_cnt3_k3 == 0) ? stage5_cnt_k3 :
                      (step_cnt3_k3 == 1) ? stage6_cnt_k3 :
                      (step_cnt3_k3 == 2) ? stage6_cnt_k3 : 0;

  ///////////
  // BPE 4 //
  ///////////
  wire k3_bpe4_en;
  assign k3_bpe4_en = (isempty) ? k3_bpe_act == 5'b01000 : pop && bpe_mux_k3 == 4;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k3 <= 4'hF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        step_cnt4_k3 <= 4'hF;
      end else if (step_cnt4_k3 == 4'hF && k3_bpe4_en) begin
        step_cnt4_k3 <= 4'h0;
      end else if (step_cnt4_k3 != 4'hF && step_cnt4_k3 != 4'd11) begin
        step_cnt4_k3 <= step_cnt4_k3 + 1;
      end else if (step_cnt4_k3 == 4'd11) begin
        step_cnt4_k3 <= 4'hF;
      end else begin
        step_cnt4_k3 <= step_cnt4_k3;
      end
    end else begin
      step_cnt4_k3 <= step_cnt4_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage7_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en && step_cnt4_k3 != 4'd11) begin
      if (k3_sw_lst) begin
        stage7_cnt_k3 <= 12'hFFF;
      end else if (k3_bpe4_en || step_cnt4_k3 == 2 || step_cnt4_k3 == 5 || step_cnt4_k3 == 8) begin
        if (stage7_cnt_k3 == 12'hFFF) begin
          stage7_cnt_k3 <= 0;
        end else begin
          stage7_cnt_k3 <= stage7_cnt_k3 + 1;
        end
      end else begin
        stage7_cnt_k3 <= stage7_cnt_k3;
      end
    end else begin
      stage7_cnt_k3 <= stage7_cnt_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage8_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        stage8_cnt_k3 <= 12'hFFF;
      end else if (step_cnt4_k3 == 0 || step_cnt4_k3 == 1 || step_cnt4_k3 == 3 || step_cnt4_k3 == 4 
                || step_cnt4_k3 == 6 || step_cnt4_k3 == 7 || step_cnt4_k3 == 9 || step_cnt4_k3 == 10) begin
        if (stage8_cnt_k3 == 12'hFFF) begin
          stage8_cnt_k3 <= 0;
        end else begin
          stage8_cnt_k3 <= stage8_cnt_k3 + 1;
        end
      end else begin
        stage8_cnt_k3 <= stage8_cnt_k3;
      end
    end else begin
      stage8_cnt_k3 <= stage8_cnt_k3;
    end
  end

  assign a_mux4_k3 = (step_cnt4_k3 == 0 || step_cnt4_k3 == 3 || step_cnt4_k3 == 6 || step_cnt4_k3 == 9) ? stage7_cnt_k3 :
                      (step_cnt4_k3 == 1 || step_cnt4_k3 == 4 || step_cnt4_k3 == 7 || step_cnt4_k3 == 10) ? stage8_cnt_k3 :
                      (step_cnt4_k3 == 2 || step_cnt4_k3 == 5 || step_cnt4_k3 == 8 || step_cnt4_k3 == 11) ? stage8_cnt_k3 : 0;

  ///////////
  // BPE 5 //
  ///////////
  wire k3_bpe5_en;
  assign k3_bpe5_en = (isempty) ? k3_bpe_act == 5'b10000 : pop && bpe_mux_k3 == 5;
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k3 <= 4'hF;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        step_cnt5_k3 <= 4'hF;
      end else if (step_cnt5_k3 == 4'hF && k3_bpe5_en) begin
        step_cnt5_k3 <= 4'h0;
      end else if (step_cnt5_k3 != 4'hF && step_cnt5_k3 != 4'd3) begin
        step_cnt5_k3 <= step_cnt5_k3 + 1;
      end else if (step_cnt5_k3 == 4'd3) begin
        step_cnt5_k3 <= 4'hF;
      end else begin
        step_cnt5_k3 <= step_cnt5_k3;
      end
    end else begin
      step_cnt5_k3 <= step_cnt5_k3;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage9_cnt_k3 <= 12'h0;
    end else if (k3_coef_rdy && k3_coef_en) begin
      if (k3_sw_lst) begin
        stage9_cnt_k3 <= 12'h0;
      end else if (step_cnt5_k3 != 4'hF) begin
          stage9_cnt_k3 <= stage9_cnt_k3 + 1;
      end else begin
        stage9_cnt_k3 <= stage9_cnt_k3;
      end
    end else begin
      stage9_cnt_k3 <= stage9_cnt_k3;
    end
  end

  assign a_mux5_k3 = ( step_cnt5_k3 != 4'hF) ? stage9_cnt_k3 : 0;

  /////////////////////////////
  // address mux for bpe 1-5 //
  /////////////////////////////

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      bpe_mux_k3 <= 0;
    end else begin
      bpe_mux_k3 <= (k3_bpe_act == 5'b00001) ? FOR_BPE1 :
                    (k3_bpe_act == 5'b00010) ? FOR_BPE2 :
                    (k3_bpe_act == 5'b00100) ? FOR_BPE3 :
                    (k3_bpe_act == 5'b01000) ? FOR_BPE4 :
                    (k3_bpe_act == 5'b10000) ? FOR_BPE5 :
                    (k3_bpe_act == 5'b00000) ? bpe_mux_k3 : 3'b111;
    end
  end

  ////////////
  // k3_pop //
  ////////////

  assign k3_pop = (bpe_mux_k3 == FOR_BPE1) ? step_cnt1_k3 == 2 : 
                  (bpe_mux_k3 == FOR_BPE2) ? step_cnt2_k3 == 2 : 
                  (bpe_mux_k3 == FOR_BPE3) ? step_cnt3_k3 == 2 : 
                  (bpe_mux_k3 == FOR_BPE4) ? step_cnt4_k3 == 11 : 
                  (bpe_mux_k3 == FOR_BPE5) ? step_cnt5_k3 == 3 : 0;

  ///////////////////////////////////////////////
  //                  KERNAL 4                 //
  ///////////////////////////////////////////////

  ///////////
  // BPE 1 //
  ///////////
  wire k4_bpe1_en;
  assign k4_bpe1_en = (isempty) ? k4_bpe_act == 5'b00001 : pop && bpe_mux_k4 == 1;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k4 <= 4'hF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        step_cnt1_k4 <= 4'hF;
      end else if (step_cnt1_k4 == 4'hF && k4_bpe1_en) begin
        step_cnt1_k4 <= 4'h0;
      end else if (step_cnt1_k4 != 4'hF && step_cnt1_k4 != 4'h2) begin
        step_cnt1_k4 <= step_cnt1_k4 + 1;
      end else if (step_cnt1_k4 == 4'h2) begin
        step_cnt1_k4 <= 4'hF;
      end else begin
        step_cnt1_k4 <= step_cnt1_k4;
      end
    end else begin
      step_cnt1_k4 <= step_cnt1_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage1_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en && step_cnt1_k4 != 4'h2) begin
      if (k4_sw_lst) begin
        stage1_cnt_k4 <= 12'hFFF;
      end else if (k4_bpe1_en) begin
        if (stage1_cnt_k4 == 12'hFFF) begin
          stage1_cnt_k4 <= 0;
        end else begin
          stage1_cnt_k4 <= stage1_cnt_k4 + 1;
        end
      end else begin
        stage1_cnt_k4 <= stage1_cnt_k4;
      end
    end else begin
      stage1_cnt_k4 <= stage1_cnt_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage2_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        stage2_cnt_k4 <= 12'hFFF;
      end else if (step_cnt1_k4 == 0 || step_cnt1_k4 == 1) begin
        if (stage2_cnt_k4 == 12'hFFF) begin
          stage2_cnt_k4 <= 0;
        end else begin
          stage2_cnt_k4 <= stage2_cnt_k4 + 1;
        end
      end else begin
        stage2_cnt_k4 <= stage2_cnt_k4;
      end
    end else begin
      stage2_cnt_k4 <= stage2_cnt_k4;
    end
  end

  assign a_mux1_k4 = (step_cnt1_k4 == 0) ? stage1_cnt_k4 :
                      (step_cnt1_k4 == 1) ? stage2_cnt_k4 :
                      (step_cnt1_k4 == 2) ? stage2_cnt_k4 : 0;
  

  ///////////
  // BPE 2 //
  ///////////
  wire k4_bpe2_en;
  assign k4_bpe2_en = (isempty) ? k4_bpe_act == 5'b00010 : pop && bpe_mux_k4 == 2;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k4 <= 4'hF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        step_cnt2_k4 <= 4'hF;
      end else if (step_cnt2_k4 == 4'hF && k4_bpe2_en) begin
        step_cnt2_k4 <= 4'h0;
      end else if (step_cnt2_k4 != 4'hF && step_cnt2_k4 != 4'h2) begin
        step_cnt2_k4 <= step_cnt2_k4 + 1;
      end else if (step_cnt2_k4 == 4'h2) begin
        step_cnt2_k4 <= 4'hF;
      end else begin
        step_cnt2_k4 <= step_cnt2_k4;
      end
    end else begin
      step_cnt2_k4 <= step_cnt2_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage3_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en && step_cnt2_k4 != 4'h2) begin
      if (k4_sw_lst) begin
        stage3_cnt_k4 <= 12'hFFF;
      end else if (k4_bpe2_en) begin
        if (stage3_cnt_k4 == 12'hFFF) begin
          stage3_cnt_k4 <= 0;
        end else begin
          stage3_cnt_k4 <= stage3_cnt_k4 + 1;
        end
      end else begin
        stage3_cnt_k4 <= stage3_cnt_k4;
      end
    end else begin
      stage3_cnt_k4 <= stage3_cnt_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage4_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        stage4_cnt_k4 <= 12'hFFF;
      end else if (step_cnt2_k4 == 0 || step_cnt2_k4 == 1) begin
        if (stage4_cnt_k4 == 12'hFFF) begin
          stage4_cnt_k4 <= 0;
        end else begin
          stage4_cnt_k4 <= stage4_cnt_k4 + 1;
        end
      end else begin
        stage4_cnt_k4 <= stage4_cnt_k4;
      end
    end else begin
      stage4_cnt_k4 <= stage4_cnt_k4;
    end
  end

  assign a_mux2_k4 = (step_cnt2_k4 == 0) ? stage3_cnt_k4 :
                      (step_cnt2_k4 == 1) ? stage4_cnt_k4 :
                      (step_cnt2_k4 == 2) ? stage4_cnt_k4 : 0;

  ///////////
  // BPE 3 //
  ///////////
  wire k4_bpe3_en;
  assign k4_bpe3_en = (isempty) ? k4_bpe_act == 5'b00100 : pop && bpe_mux_k4 == 3;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k4 <= 4'hF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        step_cnt3_k4 <= 4'hF;
      end else if (step_cnt3_k4 == 4'hF && k4_bpe3_en) begin
        step_cnt3_k4 <= 4'h0;
      end else if (step_cnt3_k4 != 4'hF && step_cnt3_k4 != 4'h2) begin
        step_cnt3_k4 <= step_cnt3_k4 + 1;
      end else if (step_cnt3_k4 == 4'h2) begin
        step_cnt3_k4 <= 4'hF;
      end else begin
        step_cnt3_k4 <= step_cnt3_k4;
      end
    end else begin
      step_cnt3_k4 <= step_cnt3_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage5_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en && step_cnt3_k4 != 4'h2) begin
      if (k4_sw_lst) begin
        stage5_cnt_k4 <= 12'hFFF;
      end else if (k4_bpe3_en) begin
        if (stage5_cnt_k4 == 12'hFFF) begin
          stage5_cnt_k4 <= 0;
        end else begin
          stage5_cnt_k4 <= stage5_cnt_k4 + 1;
        end
      end else begin
        stage5_cnt_k4 <= stage5_cnt_k4;
      end
    end else begin
      stage5_cnt_k4 <= stage5_cnt_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage6_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        stage6_cnt_k4 <= 12'hFFF;
      end else if (step_cnt3_k4 == 0 || step_cnt3_k4 == 1) begin
        if (stage6_cnt_k4 == 12'hFFF) begin
          stage6_cnt_k4 <= 0;
        end else begin
          stage6_cnt_k4 <= stage6_cnt_k4 + 1;
        end
      end else begin
        stage6_cnt_k4 <= stage6_cnt_k4;
      end
    end else begin
      stage6_cnt_k4 <= stage6_cnt_k4;
    end
  end

  assign a_mux3_k4 = (step_cnt3_k4 == 0) ? stage5_cnt_k4 :
                      (step_cnt3_k4 == 1) ? stage6_cnt_k4 :
                      (step_cnt3_k4 == 2) ? stage6_cnt_k4 : 0;

  ///////////
  // BPE 4 //
  ///////////
  wire k4_bpe4_en;
  assign k4_bpe4_en = (isempty) ? k4_bpe_act == 5'b01000 : pop && bpe_mux_k4 == 4;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k4 <= 4'hF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        step_cnt4_k4 <= 4'hF;
      end else if (step_cnt4_k4 == 4'hF && k4_bpe4_en) begin
        step_cnt4_k4 <= 4'h0;
      end else if (step_cnt4_k4 != 4'hF && step_cnt4_k4 != 4'd11) begin
        step_cnt4_k4 <= step_cnt4_k4 + 1;
      end else if (step_cnt4_k4 == 4'd11) begin
        step_cnt4_k4 <= 4'hF;
      end else begin
        step_cnt4_k4 <= step_cnt4_k4;
      end
    end else begin
      step_cnt4_k4 <= step_cnt4_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage7_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en && step_cnt4_k4 != 4'd11) begin
      if (k4_sw_lst) begin
        stage7_cnt_k4 <= 12'hFFF;
      end else if (k4_bpe4_en || step_cnt4_k4 == 2 || step_cnt4_k4 == 5 || step_cnt4_k4 == 8) begin
        if (stage7_cnt_k4 == 12'hFFF) begin
          stage7_cnt_k4 <= 0;
        end else begin
          stage7_cnt_k4 <= stage7_cnt_k4 + 1;
        end
      end else begin
        stage7_cnt_k4 <= stage7_cnt_k4;
      end
    end else begin
      stage7_cnt_k4 <= stage7_cnt_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage8_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        stage8_cnt_k4 <= 12'hFFF;
      end else if (step_cnt4_k4 == 0 || step_cnt4_k4 == 1 || step_cnt4_k4 == 3 || step_cnt4_k4 == 4 
                || step_cnt4_k4 == 6 || step_cnt4_k4 == 7 || step_cnt4_k4 == 9 || step_cnt4_k4 == 10) begin
        if (stage8_cnt_k4 == 12'hFFF) begin
          stage8_cnt_k4 <= 0;
        end else begin
          stage8_cnt_k4 <= stage8_cnt_k4 + 1;
        end
      end else begin
        stage8_cnt_k4 <= stage8_cnt_k4;
      end
    end else begin
      stage8_cnt_k4 <= stage8_cnt_k4;
    end
  end

  assign a_mux4_k4 = (step_cnt4_k4 == 0 || step_cnt4_k4 == 3 || step_cnt4_k4 == 6 || step_cnt4_k4 == 9) ? stage7_cnt_k4 :
                      (step_cnt4_k4 == 1 || step_cnt4_k4 == 4 || step_cnt4_k4 == 7 || step_cnt4_k4 == 10) ? stage8_cnt_k4 :
                      (step_cnt4_k4 == 2 || step_cnt4_k4 == 5 || step_cnt4_k4 == 8 || step_cnt4_k4 == 11) ? stage8_cnt_k4 : 0;

  ///////////
  // BPE 5 //
  ///////////
  wire k4_bpe5_en;
  assign k4_bpe5_en = (isempty) ? k4_bpe_act == 5'b10000 : pop && bpe_mux_k4 == 5;
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k4 <= 4'hF;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        step_cnt5_k4 <= 4'hF;
      end else if (step_cnt5_k4 == 4'hF && k4_bpe5_en) begin
        step_cnt5_k4 <= 4'h0;
      end else if (step_cnt5_k4 != 4'hF && step_cnt5_k4 != 4'd3) begin
        step_cnt5_k4 <= step_cnt5_k4 + 1;
      end else if (step_cnt5_k4 == 4'd3) begin
        step_cnt5_k4 <= 4'hF;
      end else begin
        step_cnt5_k4 <= step_cnt5_k4;
      end
    end else begin
      step_cnt5_k4 <= step_cnt5_k4;
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      stage9_cnt_k4 <= 12'h0;
    end else if (k4_coef_rdy && k4_coef_en) begin
      if (k4_sw_lst) begin
        stage9_cnt_k4 <= 12'h0;
      end else if (step_cnt5_k4 != 4'hF) begin
          stage9_cnt_k4 <= stage9_cnt_k4 + 1;
      end else begin
        stage9_cnt_k4 <= stage9_cnt_k4;
      end
    end else begin
      stage9_cnt_k4 <= stage9_cnt_k4;
    end
  end

  assign a_mux5_k4 = ( step_cnt5_k4 != 4'hF) ? stage9_cnt_k4 : 0;

  /////////////////////////////
  // address mux for bpe 1-5 //
  /////////////////////////////

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      bpe_mux_k4 <= 0;
    end else begin
      bpe_mux_k4 <= (k4_bpe_act == 5'b00001) ? FOR_BPE1 :
                    (k4_bpe_act == 5'b00010) ? FOR_BPE2 :
                    (k4_bpe_act == 5'b00100) ? FOR_BPE3 :
                    (k4_bpe_act == 5'b01000) ? FOR_BPE4 :
                    (k4_bpe_act == 5'b10000) ? FOR_BPE5 :
                    (k4_bpe_act == 5'b00000) ? bpe_mux_k4 : 3'b111;
    end
  end

  ////////////
  // k4_pop //
  ////////////

  assign k4_pop = (bpe_mux_k4 == FOR_BPE1) ? step_cnt1_k4 == 2 : 
                  (bpe_mux_k4 == FOR_BPE2) ? step_cnt2_k4 == 2 : 
                  (bpe_mux_k4 == FOR_BPE3) ? step_cnt3_k4 == 2 : 
                  (bpe_mux_k4 == FOR_BPE4) ? step_cnt4_k4 == 11 : 
                  (bpe_mux_k4 == FOR_BPE5) ? step_cnt5_k4 == 3 : 0;

  ////////////////////////////////////
  //      address mux together      //
  ////////////////////////////////////

  assign k1_mux = (bpe_mux_k1 == FOR_BPE1) ? a_mux1_k1[7:0] :
                  (bpe_mux_k1 == FOR_BPE2) ? a_mux2_k1[7:0] :
                  (bpe_mux_k1 == FOR_BPE3) ? a_mux3_k1[7:0] :
                  (bpe_mux_k1 == FOR_BPE4) ? a_mux4_k1[7:0] :
                  (bpe_mux_k1 == FOR_BPE5) ? a_mux5_k1[7:0] : 0;
  assign k2_mux = (bpe_mux_k2 == FOR_BPE1) ? a_mux1_k2[7:0] :
                  (bpe_mux_k2 == FOR_BPE2) ? a_mux2_k2[7:0] :
                  (bpe_mux_k2 == FOR_BPE3) ? a_mux3_k2[7:0] :
                  (bpe_mux_k2 == FOR_BPE4) ? a_mux4_k2[7:0] :
                  (bpe_mux_k2 == FOR_BPE5) ? a_mux5_k2[7:0] : 0;

  assign k3_mux = (bpe_mux_k3 == FOR_BPE1) ? a_mux1_k3[7:0] :
                  (bpe_mux_k3 == FOR_BPE2) ? a_mux2_k3[7:0] :
                  (bpe_mux_k3 == FOR_BPE3) ? a_mux3_k3[7:0] :
                  (bpe_mux_k3 == FOR_BPE4) ? a_mux4_k3[7:0] :
                  (bpe_mux_k3 == FOR_BPE5) ? a_mux5_k3[7:0] : 0;

  assign k4_mux = (bpe_mux_k4 == FOR_BPE1) ? a_mux1_k4[7:0] :
                  (bpe_mux_k4 == FOR_BPE2) ? a_mux2_k4[7:0] :
                  (bpe_mux_k4 == FOR_BPE3) ? a_mux3_k4[7:0] :
                  (bpe_mux_k4 == FOR_BPE4) ? a_mux4_k4[7:0] :
                  (bpe_mux_k4 == FOR_BPE5) ? a_mux5_k4[7:0] : 0;
  
  assign kernal_bpe_mux = (fetching_kernal == 1) ? k1_mux :
                          (fetching_kernal == 2) ? k2_mux :
                          (fetching_kernal == 3) ? k3_mux :
                          (fetching_kernal == 4) ? k4_mux : 0;
  
  /////////////////////////
  // bit reverse address //
  /////////////////////////

  assign coef_fetch_a = {3'b000, kernal_bpe_mux[0], kernal_bpe_mux[1], kernal_bpe_mux[2], kernal_bpe_mux[3]
                               , kernal_bpe_mux[4], kernal_bpe_mux[5], kernal_bpe_mux[6], kernal_bpe_mux[7], 2'b00};


  /*----------------------------------------------------------------
                         ntt coef to kernal
  -----------------------------------------------------------------*/

  assign ntt_kernal_a = (meta_counter - 1 < 64 && destination[7:1] == 7'b0000011) ? (meta_counter - 1) * 4 : 0;

  /*----------------------------------------------------------------
                            coef ram mux
  -----------------------------------------------------------------*/
  wire    [12:0] fft_coef_ram_a_mux;
  wire    [12:0] ntt_coef_ram_a_mux;

  assign fft_coef_ram_a_mux = (fetching_kernal == 0) ? fft_coef_ram_a : coef_fetch_a;
  assign ntt_coef_ram_a_mux = (destination[7:4] == 4'b0000 && meta_counter - 1 < 64) ? ntt_kernal_a : ntt_coef_ram_a;

  /*----------------------------------------------------------------
                    coef_data and coef_vld logic
  -----------------------------------------------------------------*/

  ///////////////
  // coef data //
  ///////////////
  assign k1_coef_dat = (k1_mode == 2'b10) ? fft_coef_ram_do : (k1_mode == 2'b11) ?  ntt_coef_ram_do : 0 ;
  assign k2_coef_dat = (k2_mode == 2'b10) ? fft_coef_ram_do : (k2_mode == 2'b11) ?  ntt_coef_ram_do : 0 ;
  assign k3_coef_dat = (k3_mode == 2'b10) ? fft_coef_ram_do : (k3_mode == 2'b11) ?  ntt_coef_ram_do : 0 ;
  assign k4_coef_dat = (k4_mode == 2'b10) ? fft_coef_ram_do : (k4_mode == 2'b11) ?  ntt_coef_ram_do : 0 ;

  //////////////
  // coef vld //
  //////////////
  assign k1_coef_vld = (coef_vld_mux == 1);
  assign k2_coef_vld = (coef_vld_mux == 2);
  assign k3_coef_vld = (coef_vld_mux == 3);
  assign k4_coef_vld = (coef_vld_mux == 4);

  /*----------------------------------------------------------------
                      sm pack and stream out
  -----------------------------------------------------------------*/









  bram512x128 FFT_COEF_RAM (
    .CLK  (clk),
    .WE   (fft_coef_ram_we),
    .EN   (fft_coef_ram_en),
    .Di   (fft_coef_ram_di),
    .Do   (fft_coef_ram_do),
    .A    (fft_coef_ram_a_mux)
  );

  bram64x128 NTT_COEF_RAM (
    .CLK  (clk),
    .WE   (ntt_coef_ram_we),
    .EN   (ntt_coef_ram_en),
    .Di   (ntt_coef_ram_di),
    .Do   (ntt_coef_ram_do),
    .A    (ntt_coef_ram_a_mux)
  );

  bram64x128 iNTT_COEF_RAM (
    .CLK  (clk),
    .WE   (intt_coef_ram_we),
    .EN   (ntt_coef_ram_en),
    .Di   (ntt_coef_ram_di),
    .Do   (ntt_coef_ram_do),
    .A    (ntt_coef_ram_a_mux)
  );

endmodule

