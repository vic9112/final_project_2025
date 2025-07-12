
// Using Deep-Feedback structure, we will have
module stage_top
#(  
  parameter pDATA_WIDTH = 128, // two 64-bit numbers
  parameter pSS_WIDTH = 32 // two 64-bit numbers
)
(
  input   wire                     clk,
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

  output  wire               [4:0] k1_coef_vld,
  input   wire               [4:0] k1_coef_rdy,
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
  output  wire               [4:0] k2_coef_vld,
  input   wire               [4:0] k2_coef_rdy,
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
  output  wire               [4:0] k3_coef_vld,
  input   wire               [4:0] k3_coef_rdy,
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
  output  wire               [4:0] k4_coef_vld,
  input   wire               [4:0] k4_coef_rdy,
  output  wire [(pDATA_WIDTH-1):0] k4_coef_dat,
  input   wire               [4:0] k4_bpe_act,
  output  wire                     rst_mode
);

// parameter for destination
  localparam KERNEL_1 = 8'b00000100;
  localparam KERNEL_2 = 8'b00000101;
  localparam KERNEL_3 = 8'b00000110;
  localparam KERNEL_4 = 8'b00000111;
  localparam COEF     = 8'b00010100;
  
  localparam KERNEL_NUM = 4;

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
  wire  [(pDATA_WIDTH-1):0] intt_coef_ram_do;
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
  wire                      k5_pop;
  wire                      k6_pop;
  wire                      k7_pop;
  wire                      k8_pop;
  wire                      k9_pop;
  wire                      k10_pop;
  wire                      k11_pop;
  wire                      k12_pop;
  wire                      k13_pop;
  wire                      k14_pop;
  wire                      k15_pop;
  wire                      k16_pop;
  wire                      k17_pop;
  wire                      k18_pop;
  wire                      k19_pop;
  wire                      k20_pop;
  wire                      k1_push;
  wire                      k2_push;
  wire                      k3_push;
  wire                      k4_push;
  wire                      push;
  wire                      pop;
  reg   [ 4:0]              fetching_kernal;
  reg   [ 4:0]              fetching_kernal_next;
  reg   [19:0]              acted_table;
  wire                      k1_coef_en;
  wire                      k2_coef_en;
  wire                      k3_coef_en;
  wire                      k4_coef_en;
  wire  [ 4:0]              coef_vld_mux;


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
  reg   [ 4:0]              step_cnt5_k1;
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
  reg   [ 4:0]              step_cnt5_k2;
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
  reg   [ 4:0]              step_cnt5_k3;
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
  reg   [ 4:0]              step_cnt5_k4;
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
  reg   [ 4:0]               k1_coef_vld_r;
  reg   [ 4:0]               k2_coef_vld_r;
  reg   [ 4:0]               k3_coef_vld_r;
  reg   [ 4:0]               k4_coef_vld_r;

  // ntt send coef to kernal
  wire  [12:0]               ntt_kernal_a;


  parameter FOR_BPE1 = 1;
  parameter FOR_BPE2 = 2;
  parameter FOR_BPE3 = 3;
  parameter FOR_BPE4 = 4;
  parameter FOR_BPE5 = 5;

  //for test only
  reg l;
  always @ (posedge clk) begin
    l <= 1;
  end
  assign clk1 = clk;
  assign clk2 = clk;
  assign clk3 = clk;
  assign clk4 = clk;
  assign ss_rdy = l;

  assign rst_mode = (meta_counter == 30);

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
                            meta_flag and meta_decode 
  -----------------------------------------------------------------*/

    wire meta_flag;          // indicate if the coming data is metadata
    
    assign  meta_flag = (meta_counter == 4'h0) && ss_vld;

    // meta_decode delay one cyc relativet to meta_flag for decoding metadata
    reg meta_decode;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            meta_decode <= 0;
        end else begin
            meta_decode <= meta_flag;
        end
    end

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
      k1_mode_r <= (meta_data[31:24] == KERNEL_1) ? meta_data[17:16] : k1_mode_r;
      k2_mode_r <= (meta_data[31:24] == KERNEL_2) ? meta_data[17:16] : k2_mode_r;
      k3_mode_r <= (meta_data[31:24] == KERNEL_3) ? meta_data[17:16] : k3_mode_r;
      k4_mode_r <= (meta_data[31:24] == KERNEL_4) ? meta_data[17:16] : k4_mode_r;
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
          ss_buffer7 <= (pack_counter == 0 || pack_counter == 4) ? ss_dat[15: 0] : ss_buffer7;
          ss_buffer8 <= (pack_counter == 0 || pack_counter == 4) ? ss_dat[31:16] : ss_buffer8;
          ss_buffer5 <= (pack_counter == 1 || pack_counter == 5) ? ss_dat[15: 0] : ss_buffer5;
          ss_buffer6 <= (pack_counter == 1 || pack_counter == 5) ? ss_dat[31:16] : ss_buffer6;
          ss_buffer3 <= (pack_counter == 2 || pack_counter == 6) ? ss_dat[15: 0] : ss_buffer3;
          ss_buffer4 <= (pack_counter == 2 || pack_counter == 6) ? ss_dat[31:16] : ss_buffer4;
          ss_buffer1 <= (pack_counter == 3 || pack_counter == 7) ? ss_dat[15: 0] : ss_buffer1;
          ss_buffer2 <= (pack_counter == 3 || pack_counter == 7) ? ss_dat[31:16] : ss_buffer2;
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
      fft_coef_ram_we <= {4{(pack_counter == 3 || pack_counter == 7) && (destination == COEF) && ss_vld && ss_rdy}};
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
        k1_ld_vld_r <= (destination == KERNEL_1 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
        k2_ld_vld_r <= (destination == KERNEL_2 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
        k3_ld_vld_r <= (destination == KERNEL_3 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
        k4_ld_vld_r <= (destination == KERNEL_4 && (pack_counter == 3 || pack_counter == 7) && ss_vld && ss_rdy);
      end else if (kernal_mode[2:1] == 2'b11) begin
        k1_ld_vld_r <= (destination == KERNEL_1 && pack_counter == 7 && ss_vld && ss_rdy);
        k2_ld_vld_r <= (destination == KERNEL_2 && pack_counter == 7 && ss_vld && ss_rdy);
        k3_ld_vld_r <= (destination == KERNEL_3 && pack_counter == 7 && ss_vld && ss_rdy);
        k4_ld_vld_r <= (destination == KERNEL_4 && pack_counter == 7 && ss_vld && ss_rdy);
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

  assign pop  = k1_pop   || k2_pop   || k3_pop   || k4_pop  ||
                k5_pop   || k6_pop   || k7_pop   || k8_pop  ||
                k9_pop   || k10_pop  || k11_pop  || k12_pop ||
                k13_pop  || k14_pop  || k15_pop  || k16_pop ||
                k17_pop  || k18_pop  || k19_pop  || k20_pop;

  assign isempty = !(acted_table == 20'h00000) ? 0 : 1;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      acted_table[ 0] <= 0;
      acted_table[ 1] <= 0;
      acted_table[ 2] <= 0;
      acted_table[ 3] <= 0;
      acted_table[ 4] <= 0;
      acted_table[ 5] <= 0;
      acted_table[ 6] <= 0;
      acted_table[ 7] <= 0;
      acted_table[ 8] <= 0;
      acted_table[ 9] <= 0;
      acted_table[10] <= 0;
      acted_table[11] <= 0;
      acted_table[12] <= 0;
      acted_table[13] <= 0;
      acted_table[14] <= 0;
      acted_table[15] <= 0;
      acted_table[16] <= 0;
      acted_table[17] <= 0;
      acted_table[18] <= 0;
      acted_table[19] <= 0;
    end else begin
      acted_table[ 0] <= (k1_bpe_act[0]) ? 1 : (k1_pop ) ? 0 : acted_table[ 0];
      acted_table[ 1] <= (k1_bpe_act[1]) ? 1 : (k2_pop ) ? 0 : acted_table[ 1];
      acted_table[ 2] <= (k1_bpe_act[2]) ? 1 : (k3_pop ) ? 0 : acted_table[ 2];
      acted_table[ 3] <= (k1_bpe_act[3]) ? 1 : (k4_pop ) ? 0 : acted_table[ 3];
      acted_table[ 4] <= (k1_bpe_act[4]) ? 1 : (k5_pop ) ? 0 : acted_table[ 4];
      acted_table[ 5] <= (k2_bpe_act[0]) ? 1 : (k6_pop ) ? 0 : acted_table[ 5];
      acted_table[ 6] <= (k2_bpe_act[1]) ? 1 : (k7_pop ) ? 0 : acted_table[ 6];
      acted_table[ 7] <= (k2_bpe_act[2]) ? 1 : (k8_pop ) ? 0 : acted_table[ 7];
      acted_table[ 8] <= (k2_bpe_act[3]) ? 1 : (k9_pop ) ? 0 : acted_table[ 8];
      acted_table[ 9] <= (k2_bpe_act[4]) ? 1 : (k10_pop) ? 0 : acted_table[ 9];
      acted_table[10] <= (k3_bpe_act[0]) ? 1 : (k11_pop) ? 0 : acted_table[10];
      acted_table[11] <= (k3_bpe_act[1]) ? 1 : (k12_pop) ? 0 : acted_table[11];
      acted_table[12] <= (k3_bpe_act[2]) ? 1 : (k13_pop) ? 0 : acted_table[12];
      acted_table[13] <= (k3_bpe_act[3]) ? 1 : (k14_pop) ? 0 : acted_table[13];
      acted_table[14] <= (k3_bpe_act[4]) ? 1 : (k15_pop) ? 0 : acted_table[14];
      acted_table[15] <= (k4_bpe_act[0]) ? 1 : (k16_pop) ? 0 : acted_table[15];
      acted_table[16] <= (k4_bpe_act[1]) ? 1 : (k17_pop) ? 0 : acted_table[16];
      acted_table[17] <= (k4_bpe_act[2]) ? 1 : (k18_pop) ? 0 : acted_table[17];
      acted_table[18] <= (k4_bpe_act[3]) ? 1 : (k19_pop) ? 0 : acted_table[18];
      acted_table[19] <= (k4_bpe_act[4]) ? 1 : (k20_pop) ? 0 : acted_table[19];
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
    if      (k1_bpe_act[0])  fetching_kernal_next = 5'd1;
    else if (k1_bpe_act[1])  fetching_kernal_next = 5'd2;
    else if (k1_bpe_act[2])  fetching_kernal_next = 5'd3;
    else if (k1_bpe_act[3])  fetching_kernal_next = 5'd4;
    else if (k1_bpe_act[4])  fetching_kernal_next = 5'd5;
    else if (k2_bpe_act[0])  fetching_kernal_next = 5'd6;
    else if (k2_bpe_act[1])  fetching_kernal_next = 5'd7;
    else if (k2_bpe_act[2])  fetching_kernal_next = 5'd8;
    else if (k2_bpe_act[3])  fetching_kernal_next = 5'd9;
    else if (k2_bpe_act[4])  fetching_kernal_next = 5'd10;
    else if (k3_bpe_act[0])  fetching_kernal_next = 5'd11;
    else if (k3_bpe_act[1])  fetching_kernal_next = 5'd12;
    else if (k3_bpe_act[2])  fetching_kernal_next = 5'd13;
    else if (k3_bpe_act[3])  fetching_kernal_next = 5'd14;
    else if (k3_bpe_act[4])  fetching_kernal_next = 5'd15;
    else if (k4_bpe_act[0])  fetching_kernal_next = 5'd16;
    else if (k4_bpe_act[1])  fetching_kernal_next = 5'd17;
    else if (k4_bpe_act[2])  fetching_kernal_next = 5'd18;
    else if (k4_bpe_act[3])  fetching_kernal_next = 5'd19;
    else if (k4_bpe_act[4])  fetching_kernal_next = 5'd20;
    else                     fetching_kernal_next = 5'd0;
  end else begin
    if      (acted_table[0]  && fetching_kernal != 5'd1)  fetching_kernal_next = 5'd1;
    else if (acted_table[1]  && fetching_kernal != 5'd2)  fetching_kernal_next = 5'd2;
    else if (acted_table[2]  && fetching_kernal != 5'd3)  fetching_kernal_next = 5'd3;
    else if (acted_table[3]  && fetching_kernal != 5'd4)  fetching_kernal_next = 5'd4;
    else if (acted_table[4]  && fetching_kernal != 5'd5)  fetching_kernal_next = 5'd5;
    else if (acted_table[5]  && fetching_kernal != 5'd6)  fetching_kernal_next = 5'd6;
    else if (acted_table[6]  && fetching_kernal != 5'd7)  fetching_kernal_next = 5'd7;
    else if (acted_table[7]  && fetching_kernal != 5'd8)  fetching_kernal_next = 5'd8;
    else if (acted_table[8]  && fetching_kernal != 5'd9)  fetching_kernal_next = 5'd9;
    else if (acted_table[9]  && fetching_kernal != 5'd10) fetching_kernal_next = 5'd10;
    else if (acted_table[10] && fetching_kernal != 5'd11) fetching_kernal_next = 5'd11;
    else if (acted_table[11] && fetching_kernal != 5'd12) fetching_kernal_next = 5'd12;
    else if (acted_table[12] && fetching_kernal != 5'd13) fetching_kernal_next = 5'd13;
    else if (acted_table[13] && fetching_kernal != 5'd14) fetching_kernal_next = 5'd14;
    else if (acted_table[14] && fetching_kernal != 5'd15) fetching_kernal_next = 5'd15;
    else if (acted_table[15] && fetching_kernal != 5'd16) fetching_kernal_next = 5'd16;
    else if (acted_table[16] && fetching_kernal != 5'd17) fetching_kernal_next = 5'd17;
    else if (acted_table[17] && fetching_kernal != 5'd18) fetching_kernal_next = 5'd18;
    else if (acted_table[18] && fetching_kernal != 5'd19) fetching_kernal_next = 5'd19;
    else if (acted_table[19] && fetching_kernal != 5'd20) fetching_kernal_next = 5'd20;
    else                                                  fetching_kernal_next = 5'd0;
  end
end


assign coef_vld_mux = (!isempty) ? fetching_kernal : 0;

assign k1_coef_en1 = (isempty && push || pop) && fetching_kernal_next == 5'd1  || (coef_vld_mux == 5'd1);
assign k1_coef_en2 = (isempty && push || pop) && fetching_kernal_next == 5'd2  || (coef_vld_mux == 5'd2);
assign k1_coef_en3 = (isempty && push || pop) && fetching_kernal_next == 5'd3  || (coef_vld_mux == 5'd3);
assign k1_coef_en4 = (isempty && push || pop) && fetching_kernal_next == 5'd4  || (coef_vld_mux == 5'd4);
assign k1_coef_en5 = (isempty && push || pop) && fetching_kernal_next == 5'd5  || (coef_vld_mux == 5'd5);
assign k2_coef_en1 = (isempty && push || pop) && fetching_kernal_next == 5'd6  || (coef_vld_mux == 5'd6);
assign k2_coef_en2 = (isempty && push || pop) && fetching_kernal_next == 5'd7  || (coef_vld_mux == 5'd7);
assign k2_coef_en3 = (isempty && push || pop) && fetching_kernal_next == 5'd8  || (coef_vld_mux == 5'd8);
assign k2_coef_en4 = (isempty && push || pop) && fetching_kernal_next == 5'd9  || (coef_vld_mux == 5'd9);
assign k2_coef_en5 = (isempty && push || pop) && fetching_kernal_next == 5'd10 || (coef_vld_mux == 5'd10);
assign k3_coef_en1 = (isempty && push || pop) && fetching_kernal_next == 5'd11 || (coef_vld_mux == 5'd11);
assign k3_coef_en2 = (isempty && push || pop) && fetching_kernal_next == 5'd12 || (coef_vld_mux == 5'd12);
assign k3_coef_en3 = (isempty && push || pop) && fetching_kernal_next == 5'd13 || (coef_vld_mux == 5'd13);
assign k3_coef_en4 = (isempty && push || pop) && fetching_kernal_next == 5'd14 || (coef_vld_mux == 5'd14);
assign k3_coef_en5 = (isempty && push || pop) && fetching_kernal_next == 5'd15 || (coef_vld_mux == 5'd15);
assign k4_coef_en1 = (isempty && push || pop) && fetching_kernal_next == 5'd16 || (coef_vld_mux == 5'd16);
assign k4_coef_en2 = (isempty && push || pop) && fetching_kernal_next == 5'd17 || (coef_vld_mux == 5'd17);
assign k4_coef_en3 = (isempty && push || pop) && fetching_kernal_next == 5'd18 || (coef_vld_mux == 5'd18);
assign k4_coef_en4 = (isempty && push || pop) && fetching_kernal_next == 5'd19 || (coef_vld_mux == 5'd19);
assign k4_coef_en5 = (isempty && push || pop) && fetching_kernal_next == 5'd20 || (coef_vld_mux == 5'd20);


  /*----------------------------------------------------------------
                         kernal decode
  -----------------------------------------------------------------*/  

  assign decode1 = (destination == KERNEL_1 && meta_counter == 2);
  assign decode2 = (destination == KERNEL_2 && meta_counter == 2);
  assign decode3 = (destination == KERNEL_3 && meta_counter == 2);
  assign decode4 = (destination == KERNEL_4 && meta_counter == 2);

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
  assign k1_bpe1_en = (isempty) ? k1_bpe_act[0]: pop && fetching_kernal_next == 1;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k1 <= 4'hF;
    end else if (k1_sw_lst) begin
      step_cnt1_k1 <= 4'hF;
    end else if (k1_coef_rdy[0] && k1_coef_en1) begin
      if (step_cnt1_k1 == 4'hF && k1_bpe1_en) begin
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
    end else if (k1_sw_lst) begin
      stage1_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[0] && k1_coef_en1 && step_cnt1_k1 != 4'h2) begin
      if (k1_bpe1_en) begin
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
    end else if (k1_sw_lst) begin
      stage2_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[0] && k1_coef_en1) begin
    if (step_cnt1_k1 == 0 || step_cnt1_k1 == 1) begin
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
  
  assign k1_pop = (step_cnt1_k1 == 2);

  ///////////
  // BPE 2 //
  ///////////
  wire k1_bpe2_en;
  assign k1_bpe2_en = (isempty) ? k1_bpe_act[1] : pop && fetching_kernal_next == 2;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k1 <= 4'hF;
    end else if (k1_sw_lst) begin
      step_cnt2_k1 <= 4'hF;
    end else if (k1_coef_rdy[1] && k1_coef_en2) begin
      if (step_cnt2_k1 == 4'hF && k1_bpe2_en) begin
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
    end else if (k1_sw_lst) begin
      stage3_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[1] && k1_coef_en2 && step_cnt2_k1 != 4'h2) begin
      if (k1_bpe2_en) begin
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
    end else if (k1_sw_lst) begin
      stage4_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[1] && k1_coef_en2) begin
      if (step_cnt2_k1 == 0 || step_cnt2_k1 == 1) begin
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

  assign k2_pop = (step_cnt2_k1 == 2);
  ///////////
  // BPE 3 //
  ///////////
  wire k1_bpe3_en;
  assign k1_bpe3_en = (isempty) ? k1_bpe_act[2] : pop && fetching_kernal_next == 3;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k1 <= 4'hF;
    end else if (k1_sw_lst) begin
      step_cnt3_k1 <= 4'hF;
    end else if (k1_coef_rdy[2] && k1_coef_en3) begin
      if (step_cnt3_k1 == 4'hF && k1_bpe3_en) begin
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
    end else if (k1_sw_lst) begin
      stage5_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[2] && k1_coef_en3 && step_cnt3_k1 != 4'h2) begin
      if (k1_bpe3_en) begin
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
    end else if (k1_sw_lst) begin
      stage6_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[2] && k1_coef_en3) begin
      if (step_cnt3_k1 == 0 || step_cnt3_k1 == 1) begin
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

  assign k3_pop = (step_cnt3_k1 == 2);

  ///////////
  // BPE 4 //
  ///////////
  wire k1_bpe4_en;
  assign k1_bpe4_en = (isempty) ? k1_bpe_act[3] : pop && fetching_kernal_next == 4;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k1 <= 4'hF;
    end else if (k1_sw_lst) begin
      step_cnt4_k1 <= 4'hF;
    end else if (k1_coef_rdy[3] && k1_coef_en4) begin
      if (step_cnt4_k1 == 4'hF && k1_bpe4_en) begin
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
    end else if (k1_sw_lst) begin
      stage7_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[3] && k1_coef_en4 && step_cnt4_k1 != 4'd11) begin
      if (k1_bpe4_en || step_cnt4_k1 == 2 || step_cnt4_k1 == 5 || step_cnt4_k1 == 8) begin
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
    end else if (k1_sw_lst) begin
      stage8_cnt_k1 <= 12'hFFF;
    end else if (k1_coef_rdy[3] && k1_coef_en4) begin
      if (step_cnt4_k1 == 0 || step_cnt4_k1 == 1 || step_cnt4_k1 == 3 || step_cnt4_k1 == 4 
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
  
  assign k4_pop = (step_cnt4_k1 == 11);

  ///////////
  // BPE 5 //
  ///////////
  wire k1_bpe5_en;
  assign k1_bpe5_en = (isempty) ? k1_bpe_act[4] : pop && (fetching_kernal_next == 5);
  wire test;
  assign test = step_cnt5_k1 == 5'h1F && k1_bpe5_en;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k1 <= 5'h1F;
    end else if (k1_sw_lst) begin
      step_cnt5_k1 <= 5'h1F;
    end else if (k1_coef_rdy[4] && k1_coef_en5) begin
      if (step_cnt5_k1 == 5'h1F && k1_bpe5_en) begin
        step_cnt5_k1 <= 5'h0;
      end else if (step_cnt5_k1 != 5'h1F && step_cnt5_k1 != 5'd15) begin
        step_cnt5_k1 <= step_cnt5_k1 + 1;
      end else if (step_cnt5_k1 == 5'd15) begin
        step_cnt5_k1 <= 5'h1F;
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
    end else if (k1_sw_lst) begin
      stage9_cnt_k1 <= 12'h0;
    end else if (k1_coef_rdy[4] && k1_coef_en5) begin
      if (step_cnt5_k1 != 5'h1F) begin
          stage9_cnt_k1 <= stage9_cnt_k1 + 1;
      end else begin
        stage9_cnt_k1 <= stage9_cnt_k1;
      end
    end else begin
      stage9_cnt_k1 <= stage9_cnt_k1;
    end
  end

  assign a_mux5_k1 = ( step_cnt5_k1 != 5'h1F) ? stage9_cnt_k1 : 0;
  assign k5_pop = (step_cnt5_k1 == 5'd15);

  ///////////////////////////////////////////////
  //                  KERNAL 2                 //
  ///////////////////////////////////////////////

  ///////////
  // BPE 1 //
  ///////////
  wire k2_bpe1_en;
  assign k2_bpe1_en = (isempty) ? k2_bpe_act[0] : pop && fetching_kernal_next == 6;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k2 <= 4'hF;
    end else if (k2_sw_lst) begin
      step_cnt1_k2 <= 4'hF;
    end else if (k2_coef_rdy[0] && k2_coef_en1) begin
      if (step_cnt1_k2 == 4'hF && k2_bpe1_en) begin
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
    end else if (k2_sw_lst) begin
      stage1_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[0] && k2_coef_en1 && step_cnt1_k2 != 4'h2) begin
      if (k2_bpe1_en) begin
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
    end else if (k2_sw_lst) begin
      stage2_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[0] && k2_coef_en1) begin
      if (step_cnt1_k2 == 0 || step_cnt1_k2 == 1) begin
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
  
  assign k6_pop = (step_cnt1_k2 == 2);

  ///////////
  // BPE 2 //
  ///////////
  wire k2_bpe2_en;
  assign k2_bpe2_en = (isempty) ? k2_bpe_act[1] : pop && fetching_kernal_next == 7;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k2 <= 4'hF;
    end else if (k2_sw_lst) begin
      step_cnt2_k2 <= 4'hF;
    end else if (k2_coef_rdy[1] && k2_coef_en2) begin
      if (step_cnt2_k2 == 4'hF && k2_bpe2_en) begin
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
    end else if (k2_sw_lst) begin
      stage3_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[1] && k2_coef_en2 && step_cnt2_k2 != 4'h2) begin
      if (k2_bpe2_en) begin
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
    end else if (k2_sw_lst) begin
      stage4_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[1] && k2_coef_en2) begin
      if (step_cnt2_k2 == 0 || step_cnt2_k2 == 1) begin
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

  assign k7_pop = (step_cnt2_k2 == 2);

  ///////////
  // BPE 3 //
  ///////////
  wire k2_bpe3_en;
  assign k2_bpe3_en = (isempty) ? k2_bpe_act[2] : pop && fetching_kernal_next == 8;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k2 <= 4'hF;
    end else if (k2_sw_lst) begin
      step_cnt3_k2 <= 4'hF;
    end else if (k2_coef_rdy[2] && k2_coef_en3) begin
      if (step_cnt3_k2 == 4'hF && k2_bpe3_en) begin
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
    end else if (k2_sw_lst) begin
      stage5_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[2] && k2_coef_en3 && step_cnt3_k2 != 4'h2) begin
      if (k2_bpe3_en) begin
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
    end else if (k2_sw_lst) begin
      stage6_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[2] && k2_coef_en3) begin
      if (step_cnt3_k2 == 0 || step_cnt3_k2 == 1) begin
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

  assign k8_pop = (step_cnt3_k2 == 2);

  ///////////
  // BPE 4 //
  ///////////
  wire k2_bpe4_en;
  assign k2_bpe4_en = (isempty) ? k2_bpe_act[3] : pop && fetching_kernal_next == 9;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k2 <= 4'hF;
    end else if (k2_sw_lst) begin
      step_cnt4_k2 <= 4'hF;
    end else if (k2_coef_rdy[3] && k2_coef_en4) begin
      if (step_cnt4_k2 == 4'hF && k2_bpe4_en) begin
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
    end else if (k2_sw_lst) begin
      stage7_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[3] && k2_coef_en4 && step_cnt4_k2 != 4'd11) begin
      if (k2_bpe4_en || step_cnt4_k2 == 2 || step_cnt4_k2 == 5 || step_cnt4_k2 == 8) begin
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
    end else if (k2_sw_lst) begin
      stage8_cnt_k2 <= 12'hFFF;
    end else if (k2_coef_rdy[3] && k2_coef_en4) begin
      if (step_cnt4_k2 == 0 || step_cnt4_k2 == 1 || step_cnt4_k2 == 3 || step_cnt4_k2 == 4 
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

  assign k9_pop = (step_cnt4_k2 == 11);
  ///////////
  // BPE 5 //
  ///////////
  wire k2_bpe5_en;
  assign k2_bpe5_en = (isempty) ? k2_bpe_act[4] : pop && (fetching_kernal_next == 10);

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k2 <= 5'h1F;
    end else if (k2_sw_lst) begin
      step_cnt5_k2 <= 5'h1F;
    end else if (k2_coef_rdy[4] && k2_coef_en5) begin
      if (step_cnt5_k2 == 5'h1F && k2_bpe5_en) begin
        step_cnt5_k2 <= 5'h0;
      end else if (step_cnt5_k2 != 5'h1F && step_cnt5_k2 != 5'd15) begin
        step_cnt5_k2 <= step_cnt5_k2 + 1;
      end else if (step_cnt5_k2 == 5'd15) begin
        step_cnt5_k2 <= 5'h1F;
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
    end else if (k2_sw_lst) begin
      stage9_cnt_k2 <= 12'h0;
    end else if (k2_coef_rdy[4] && k2_coef_en5) begin
      if (step_cnt5_k2 != 5'h1F) begin
          stage9_cnt_k2 <= stage9_cnt_k2 + 1;
      end else begin
        stage9_cnt_k2 <= stage9_cnt_k2;
      end
    end else begin
      stage9_cnt_k2 <= stage9_cnt_k2;
    end
  end

  assign a_mux5_k2 = ( step_cnt5_k2 != 5'h1F) ? stage9_cnt_k2 : 0;
  assign k10_pop = (step_cnt5_k2 == 5'd15);

  ///////////////////////////////////////////////
  //                  KERNAL 3                 //
  ///////////////////////////////////////////////

  ///////////
  // BPE 1 //
  ///////////
  wire k3_bpe1_en;
  assign k3_bpe1_en = (isempty) ? k3_bpe_act[0] : pop && fetching_kernal_next == 11;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k3 <= 4'hF;
    end else if (k3_sw_lst) begin
      step_cnt1_k3 <= 4'hF;
    end else if (k3_coef_rdy[0] && k3_coef_en1) begin
      if (step_cnt1_k3 == 4'hF && k3_bpe1_en) begin
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
    end else if (k3_sw_lst) begin
      stage1_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[0] && k3_coef_en1 && step_cnt1_k3 != 4'h2) begin
      if (k3_bpe1_en) begin
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
    end else if (k3_sw_lst) begin
      stage2_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[0] && k3_coef_en1) begin
      if (step_cnt1_k3 == 0 || step_cnt1_k3 == 1) begin
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
  
  assign k11_pop = (step_cnt1_k3 == 2);

  ///////////
  // BPE 2 //
  ///////////
  wire k3_bpe2_en;
  assign k3_bpe2_en = (isempty) ? k3_bpe_act[1] : pop && fetching_kernal_next == 12;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k3 <= 4'hF;
    end else if (k3_sw_lst) begin
      step_cnt2_k3 <= 4'hF;
    end else if (k3_coef_rdy[1] && k3_coef_en2) begin
      if (step_cnt2_k3 == 4'hF && k3_bpe2_en) begin
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
    end else if (k3_sw_lst) begin
      stage3_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[1] && k3_coef_en2 && step_cnt2_k3 != 4'h2) begin
      if (k3_bpe2_en) begin
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
    end else if (k3_sw_lst) begin
      stage4_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[1] && k3_coef_en2) begin
      if (step_cnt2_k3 == 0 || step_cnt2_k3 == 1) begin
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

  assign k12_pop = (step_cnt2_k3 == 2);

  ///////////
  // BPE 3 //
  ///////////
  wire k3_bpe3_en;
  assign k3_bpe3_en = (isempty) ? k3_bpe_act[2] : pop && fetching_kernal_next == 13;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k3 <= 4'hF;
    end else if (k3_sw_lst) begin
      step_cnt3_k3 <= 4'hF;
    end else if (k3_coef_rdy[2] && k3_coef_en3) begin
      if (step_cnt3_k3 == 4'hF && k3_bpe3_en) begin
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
    end else if (k3_sw_lst) begin
      stage5_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[2] && k3_coef_en3 && step_cnt3_k3 != 4'h2) begin
      if (k3_bpe3_en) begin
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
    end else if (k3_sw_lst) begin
      stage6_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[2] && k3_coef_en3) begin
      if (step_cnt3_k3 == 0 || step_cnt3_k3 == 1) begin
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

  assign k13_pop = (step_cnt3_k3 == 2);

  ///////////
  // BPE 4 //
  ///////////
  wire k3_bpe4_en;
  assign k3_bpe4_en = (isempty) ? k3_bpe_act[3] : pop && fetching_kernal_next == 14;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k3 <= 4'hF;
    end else if (k3_sw_lst) begin
      step_cnt4_k3 <= 4'hF;
    end else if (k3_coef_rdy[3] && k3_coef_en4) begin
      if (step_cnt4_k3 == 4'hF && k3_bpe4_en) begin
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
    end else if (k3_sw_lst) begin
      stage7_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[3] && k3_coef_en4 && step_cnt4_k3 != 4'd11) begin
      if (k3_bpe4_en || step_cnt4_k3 == 2 || step_cnt4_k3 == 5 || step_cnt4_k3 == 8) begin
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
    end else if (k3_sw_lst) begin
      stage8_cnt_k3 <= 12'hFFF;
    end else if (k3_coef_rdy[3] && k3_coef_en4) begin
      if (step_cnt4_k3 == 0 || step_cnt4_k3 == 1 || step_cnt4_k3 == 3 || step_cnt4_k3 == 4 
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

  assign k14_pop = (step_cnt4_k3 == 11);

  ///////////
  // BPE 5 //
  ///////////
  wire k3_bpe5_en;
  assign k3_bpe5_en = (isempty) ? k3_bpe_act[4] : pop && (fetching_kernal_next == 15);

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k3 <= 5'h1F;
    end else if (k3_sw_lst) begin
      step_cnt5_k3 <= 5'h1F;
    end else if (k3_coef_rdy[4] && k3_coef_en5) begin
      if (step_cnt5_k3 == 5'h1F && k3_bpe5_en) begin
        step_cnt5_k3 <= 5'h0;
      end else if (step_cnt5_k3 != 5'h1F && step_cnt5_k3 != 5'd15) begin
        step_cnt5_k3 <= step_cnt5_k3 + 1;
      end else if (step_cnt5_k3 == 5'd15) begin
        step_cnt5_k3 <= 5'h1F;
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
    end else if (k3_sw_lst) begin
      stage9_cnt_k3 <= 12'h0;
    end else if (k3_coef_rdy[4] && k3_coef_en5) begin
      if (step_cnt5_k3 != 5'h1F) begin
          stage9_cnt_k3 <= stage9_cnt_k3 + 1;
      end else begin
        stage9_cnt_k3 <= stage9_cnt_k3;
      end
    end else begin
      stage9_cnt_k3 <= stage9_cnt_k3;
    end
  end

  assign a_mux5_k3 = ( step_cnt5_k3 != 5'h1F) ? stage9_cnt_k3 : 0;
  assign k15_pop = (step_cnt5_k3 == 5'd15);

  ///////////////////////////////////////////////
  //                  KERNAL 4                 //
  ///////////////////////////////////////////////

  ///////////
  // BPE 1 //
  ///////////
  wire k4_bpe1_en;
  assign k4_bpe1_en = (isempty) ? k4_bpe_act[0] : pop && fetching_kernal_next == 16;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt1_k4 <= 4'hF;
    end else if (k4_sw_lst) begin
      step_cnt1_k4 <= 4'hF;
    end else if (k4_coef_rdy[0] && k4_coef_en1) begin
      if (step_cnt1_k4 == 4'hF && k4_bpe1_en) begin
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
    end else if (k4_sw_lst) begin
      stage1_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[0] && k4_coef_en1 && step_cnt1_k4 != 4'h2) begin
      if (k4_bpe1_en) begin
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
    end else if (k4_sw_lst) begin
      stage2_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[0] && k4_coef_en1) begin
      if (step_cnt1_k4 == 0 || step_cnt1_k4 == 1) begin
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
  
  assign k16_pop = (step_cnt1_k4 == 2);

  ///////////
  // BPE 2 //
  ///////////
  wire k4_bpe2_en;
  assign k4_bpe2_en = (isempty) ? k4_bpe_act[1] : pop && fetching_kernal_next == 17;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt2_k4 <= 4'hF;
    end else if (k4_sw_lst) begin
      step_cnt2_k4 <= 4'hF;
    end else if (k4_coef_rdy[1] && k4_coef_en2) begin
      if (step_cnt2_k4 == 4'hF && k4_bpe2_en) begin
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
    end else if (k4_sw_lst) begin
      stage3_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[1] && k4_coef_en2 && step_cnt2_k4 != 4'h2) begin
      if (k4_bpe2_en) begin
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
    end else if (k4_sw_lst) begin
      stage4_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[1] && k4_coef_en2) begin
      if (step_cnt2_k4 == 0 || step_cnt2_k4 == 1) begin
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

  assign k17_pop = (step_cnt2_k4 == 2);

  ///////////
  // BPE 3 //
  ///////////
  wire k4_bpe3_en;
  assign k4_bpe3_en = (isempty) ? k4_bpe_act[2] : pop && fetching_kernal_next == 18;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt3_k4 <= 4'hF;
    end else if (k4_sw_lst) begin
      step_cnt3_k4 <= 4'hF;
    end else if (k4_coef_rdy[2] && k4_coef_en3) begin
      if (step_cnt3_k4 == 4'hF && k4_bpe3_en) begin
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
    end else if (k4_sw_lst) begin
      stage5_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[2] && k4_coef_en3 && step_cnt3_k4 != 4'h2) begin
      if (k4_bpe3_en) begin
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
    end else if (k4_sw_lst) begin
      stage6_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[2] && k4_coef_en3) begin
      if (step_cnt3_k4 == 0 || step_cnt3_k4 == 1) begin
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

  assign k18_pop = (step_cnt3_k4 == 2);

  ///////////
  // BPE 4 //
  ///////////
  wire k4_bpe4_en;
  assign k4_bpe4_en = (isempty) ? k4_bpe_act[3] : pop && fetching_kernal_next == 19;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt4_k4 <= 4'hF;
    end else if (k4_sw_lst) begin
      step_cnt4_k4 <= 4'hF;
    end else if (k4_coef_rdy[3] && k4_coef_en4) begin
      if (step_cnt4_k4 == 4'hF && k4_bpe4_en) begin
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
    end else if (k4_sw_lst) begin
      stage7_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[3] && k4_coef_en4 && step_cnt4_k4 != 4'd11) begin
      if (k4_bpe4_en || step_cnt4_k4 == 2 || step_cnt4_k4 == 5 || step_cnt4_k4 == 8) begin
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
    end else if (k4_sw_lst) begin
      stage8_cnt_k4 <= 12'hFFF;
    end else if (k4_coef_rdy[3] && k4_coef_en4) begin
      if (step_cnt4_k4 == 0 || step_cnt4_k4 == 1 || step_cnt4_k4 == 3 || step_cnt4_k4 == 4 
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

  assign k19_pop = (step_cnt4_k4 == 11);

  ///////////
  // BPE 5 //
  ///////////
  wire k4_bpe5_en;
  assign k4_bpe5_en = (isempty) ? k4_bpe_act[4] : pop && (fetching_kernal_next == 20);

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      step_cnt5_k4 <= 5'h1F;
    end else if (k4_sw_lst) begin
      step_cnt5_k4 <= 5'h1F;
    end else if (k4_coef_rdy[4] && k4_coef_en5) begin
      if (step_cnt5_k4 == 5'h1F && k4_bpe5_en) begin
        step_cnt5_k4 <= 5'h0;
      end else if (step_cnt5_k4 != 5'h1F && step_cnt5_k4 != 5'd15) begin
        step_cnt5_k4 <= step_cnt5_k4 + 1;
      end else if (step_cnt5_k4 == 5'd15) begin
        step_cnt5_k4 <= 5'h1F;
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
    end else if (k4_sw_lst) begin
      stage9_cnt_k4 <= 12'h0;
    end else if (k4_coef_rdy[4] && k4_coef_en5) begin
      if (step_cnt5_k4 != 5'h1F) begin
          stage9_cnt_k4 <= stage9_cnt_k4 + 1;
      end else begin
        stage9_cnt_k4 <= stage9_cnt_k4;
      end
    end else begin
      stage9_cnt_k4 <= stage9_cnt_k4;
    end
  end

  assign a_mux5_k4 = ( step_cnt5_k4 != 5'h1F) ? stage9_cnt_k4 : 0;
  assign k20_pop = (step_cnt5_k4 == 5'd15);


  ////////////////////////////////////
  //      address mux together      //
  ////////////////////////////////////
  
  assign kernal_bpe_mux = (fetching_kernal ==  1) ? a_mux1_k1[7:0] :
                          (fetching_kernal ==  2) ? a_mux2_k1[7:0] :
                          (fetching_kernal ==  3) ? a_mux3_k1[7:0] :
                          (fetching_kernal ==  4) ? a_mux4_k1[7:0] :
                          (fetching_kernal ==  5) ? a_mux5_k1[7:0] :
                          (fetching_kernal ==  6) ? a_mux1_k2[7:0] :
                          (fetching_kernal ==  7) ? a_mux2_k2[7:0] :
                          (fetching_kernal ==  8) ? a_mux3_k2[7:0] :
                          (fetching_kernal ==  9) ? a_mux4_k2[7:0] :
                          (fetching_kernal == 10) ? a_mux5_k2[7:0] :
                          (fetching_kernal == 11) ? a_mux1_k3[7:0] :
                          (fetching_kernal == 12) ? a_mux2_k3[7:0] :
                          (fetching_kernal == 13) ? a_mux3_k3[7:0] :
                          (fetching_kernal == 14) ? a_mux4_k3[7:0] :
                          (fetching_kernal == 15) ? a_mux5_k3[7:0] :
                          (fetching_kernal == 16) ? a_mux1_k4[7:0] :
                          (fetching_kernal == 17) ? a_mux2_k4[7:0] :
                          (fetching_kernal == 18) ? a_mux3_k4[7:0] :
                          (fetching_kernal == 19) ? a_mux4_k4[7:0] :
                          (fetching_kernal == 20) ? a_mux5_k4[7:0] : 0;
  
  /////////////////////////
  // bit reverse address //
  /////////////////////////

  assign coef_fetch_a = {3'b000, kernal_bpe_mux[0], kernal_bpe_mux[1], kernal_bpe_mux[2], kernal_bpe_mux[3]
                               , kernal_bpe_mux[4], kernal_bpe_mux[5], kernal_bpe_mux[6], kernal_bpe_mux[7], 2'b00};


  /*----------------------------------------------------------------
                         ntt coef to kernal
  -----------------------------------------------------------------*/

  assign ntt_kernal_a = (meta_counter - 1 < 64) ? (meta_counter - 1) * 4 : 0;

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
  wire neg1;
  wire neg2;
  wire neg3;
  wire neg4;
  assign neg1 = k1_mode_r == 2'b01;
  assign neg2 = k2_mode_r == 2'b01;
  assign neg3 = k3_mode_r == 2'b01;
  assign neg4 = k4_mode_r == 2'b01;

  assign k1_coef_dat = (k1_mode_r == 2'b00) ? fft_coef_ram_do : (neg1) ? {fft_coef_ram_do[127:64], ~fft_coef_ram_do[63], fft_coef_ram_do[62:0]} :  (k1_mode_r == 2'b10) ? ntt_coef_ram_do : (k1_mode_r == 2'b11) ?  intt_coef_ram_do : 0 ;
  assign k2_coef_dat = (k2_mode_r == 2'b00) ? fft_coef_ram_do : (neg2) ? {fft_coef_ram_do[127:64], ~fft_coef_ram_do[63], fft_coef_ram_do[62:0]} :  (k2_mode_r == 2'b10) ? ntt_coef_ram_do : (k2_mode_r == 2'b11) ?  intt_coef_ram_do : 0 ;
  assign k3_coef_dat = (k3_mode_r == 2'b00) ? fft_coef_ram_do : (neg3) ? {fft_coef_ram_do[127:64], ~fft_coef_ram_do[63], fft_coef_ram_do[62:0]} :  (k3_mode_r == 2'b10) ? ntt_coef_ram_do : (k3_mode_r == 2'b11) ?  intt_coef_ram_do : 0 ;
  assign k4_coef_dat = (k4_mode_r == 2'b00) ? fft_coef_ram_do : (neg4) ? {fft_coef_ram_do[127:64], ~fft_coef_ram_do[63], fft_coef_ram_do[62:0]} :  (k4_mode_r == 2'b10) ? ntt_coef_ram_do : (k4_mode_r == 2'b11) ?  intt_coef_ram_do : 0 ;

  //////////////
  // coef vld //
  //////////////
  always @ (posedge clk or negedge rstn) begin
    if (!rstn) begin
      k1_coef_vld_r[0] <= 0;
      k1_coef_vld_r[1] <= 0;
      k1_coef_vld_r[2] <= 0;
      k1_coef_vld_r[3] <= 0;
      k1_coef_vld_r[4] <= 0;
      k2_coef_vld_r[0] <= 0;
      k2_coef_vld_r[1] <= 0;
      k2_coef_vld_r[2] <= 0;
      k2_coef_vld_r[3] <= 0;
      k2_coef_vld_r[4] <= 0;
      k3_coef_vld_r[0] <= 0;
      k3_coef_vld_r[1] <= 0;
      k3_coef_vld_r[2] <= 0;
      k3_coef_vld_r[3] <= 0;
      k3_coef_vld_r[4] <= 0;
      k4_coef_vld_r[0] <= 0;
      k4_coef_vld_r[1] <= 0;
      k4_coef_vld_r[2] <= 0;
      k4_coef_vld_r[3] <= 0;
      k4_coef_vld_r[4] <= 0;
    end else begin
      k1_coef_vld_r[0] <= (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? (coef_vld_mux ==  1) : 0;
      k1_coef_vld_r[1] <= (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? (coef_vld_mux ==  2) : 0;
      k1_coef_vld_r[2] <= (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? (coef_vld_mux ==  3) : 0;
      k1_coef_vld_r[3] <= (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? (coef_vld_mux ==  4) : 0;
      k1_coef_vld_r[4] <= (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? (coef_vld_mux ==  5) : 0;
      k2_coef_vld_r[0] <= (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? (coef_vld_mux ==  6) : 0;
      k2_coef_vld_r[1] <= (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? (coef_vld_mux ==  7) : 0;
      k2_coef_vld_r[2] <= (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? (coef_vld_mux ==  8) : 0;
      k2_coef_vld_r[3] <= (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? (coef_vld_mux ==  9) : 0;
      k2_coef_vld_r[4] <= (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? (coef_vld_mux == 10) : 0;
      k3_coef_vld_r[0] <= (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? (coef_vld_mux == 11) : 0;
      k3_coef_vld_r[1] <= (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? (coef_vld_mux == 12) : 0;
      k3_coef_vld_r[2] <= (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? (coef_vld_mux == 13) : 0;
      k3_coef_vld_r[3] <= (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? (coef_vld_mux == 14) : 0;
      k3_coef_vld_r[4] <= (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? (coef_vld_mux == 15) : 0;
      k4_coef_vld_r[0] <= (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? (coef_vld_mux == 16) : 0;
      k4_coef_vld_r[1] <= (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? (coef_vld_mux == 17) : 0;
      k4_coef_vld_r[2] <= (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? (coef_vld_mux == 18) : 0;
      k4_coef_vld_r[3] <= (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? (coef_vld_mux == 19) : 0;
      k4_coef_vld_r[4] <= (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? (coef_vld_mux == 20) : 0;
    end
  end

  assign k1_coef_vld[0] = (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? k1_coef_vld_r[0] : (k1_mode_r == 2'b10 || k1_mode_r == 2'b11) ? (destination == 8'b00000100 && meta_counter - 1 < 65) : 0;
  assign k1_coef_vld[1] = (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? k1_coef_vld_r[1] : (k1_mode_r == 2'b10 || k1_mode_r == 2'b11) ? (destination == 8'b00000100 && meta_counter - 1 < 65) : 0;
  assign k1_coef_vld[2] = (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? k1_coef_vld_r[2] : (k1_mode_r == 2'b10 || k1_mode_r == 2'b11) ? (destination == 8'b00000100 && meta_counter - 1 < 65) : 0;
  assign k1_coef_vld[3] = (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? k1_coef_vld_r[3] : (k1_mode_r == 2'b10 || k1_mode_r == 2'b11) ? (destination == 8'b00000100 && meta_counter - 1 < 65) : 0;
  assign k1_coef_vld[4] = (k1_mode_r == 2'b00 || k1_mode_r == 2'b01) ? k1_coef_vld_r[4] : (k1_mode_r == 2'b10 || k1_mode_r == 2'b11) ? (destination == 8'b00000100 && meta_counter - 1 < 65) : 0;
  assign k2_coef_vld[0] = (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? k2_coef_vld_r[0] : (k2_mode_r == 2'b10 || k2_mode_r == 2'b11) ? (destination == 8'b00000101 && meta_counter - 1 < 65) : 0;
  assign k2_coef_vld[1] = (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? k2_coef_vld_r[1] : (k2_mode_r == 2'b10 || k2_mode_r == 2'b11) ? (destination == 8'b00000101 && meta_counter - 1 < 65) : 0;
  assign k2_coef_vld[2] = (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? k2_coef_vld_r[2] : (k2_mode_r == 2'b10 || k2_mode_r == 2'b11) ? (destination == 8'b00000101 && meta_counter - 1 < 65) : 0;
  assign k2_coef_vld[3] = (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? k2_coef_vld_r[3] : (k2_mode_r == 2'b10 || k2_mode_r == 2'b11) ? (destination == 8'b00000101 && meta_counter - 1 < 65) : 0;
  assign k2_coef_vld[4] = (k2_mode_r == 2'b00 || k2_mode_r == 2'b01) ? k2_coef_vld_r[4] : (k2_mode_r == 2'b10 || k2_mode_r == 2'b11) ? (destination == 8'b00000101 && meta_counter - 1 < 65) : 0;
  assign k3_coef_vld[0] = (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? k3_coef_vld_r[0] : (k3_mode_r == 2'b10 || k3_mode_r == 2'b11) ? (destination == 8'b00000110 && meta_counter - 1 < 65) : 0;
  assign k3_coef_vld[1] = (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? k3_coef_vld_r[1] : (k3_mode_r == 2'b10 || k3_mode_r == 2'b11) ? (destination == 8'b00000110 && meta_counter - 1 < 65) : 0;
  assign k3_coef_vld[2] = (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? k3_coef_vld_r[2] : (k3_mode_r == 2'b10 || k3_mode_r == 2'b11) ? (destination == 8'b00000110 && meta_counter - 1 < 65) : 0;
  assign k3_coef_vld[3] = (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? k3_coef_vld_r[3] : (k3_mode_r == 2'b10 || k3_mode_r == 2'b11) ? (destination == 8'b00000110 && meta_counter - 1 < 65) : 0;
  assign k3_coef_vld[4] = (k3_mode_r == 2'b00 || k3_mode_r == 2'b01) ? k3_coef_vld_r[4] : (k3_mode_r == 2'b10 || k3_mode_r == 2'b11) ? (destination == 8'b00000110 && meta_counter - 1 < 65) : 0;
  assign k4_coef_vld[0] = (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? k4_coef_vld_r[0] : (k4_mode_r == 2'b10 || k4_mode_r == 2'b11) ? (destination == 8'b00000111 && meta_counter - 1 < 65) : 0;
  assign k4_coef_vld[1] = (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? k4_coef_vld_r[1] : (k4_mode_r == 2'b10 || k4_mode_r == 2'b11) ? (destination == 8'b00000111 && meta_counter - 1 < 65) : 0;
  assign k4_coef_vld[2] = (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? k4_coef_vld_r[2] : (k4_mode_r == 2'b10 || k4_mode_r == 2'b11) ? (destination == 8'b00000111 && meta_counter - 1 < 65) : 0;
  assign k4_coef_vld[3] = (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? k4_coef_vld_r[3] : (k4_mode_r == 2'b10 || k4_mode_r == 2'b11) ? (destination == 8'b00000111 && meta_counter - 1 < 65) : 0;
  assign k4_coef_vld[4] = (k4_mode_r == 2'b00 || k4_mode_r == 2'b01) ? k4_coef_vld_r[4] : (k4_mode_r == 2'b10 || k4_mode_r == 2'b11) ? (destination == 8'b00000111 && meta_counter - 1 < 65) : 0;



  /*----------------------------------------------------------------
                      sm pack and stream out
  -----------------------------------------------------------------*/
  // FIFO record the output order
    reg  [3:0] FIFO_mem [0:KERNEL_NUM-1]; // mode(2 bits), kernel(2 bits)
    wire [3:0] FIFO_in;
    reg  [3:0] FIFO_out;
    wire       FIFO_wr_en;
    wire       FIFO_rd_en;
    reg  [1:0] wr_ptr, rd_ptr;
    reg  [1:0] wr_ptr_next, rd_ptr_next;
    wire       empty;
    wire       en_sm;
    reg        lst_flag;

  // sm stream_out
    reg [(pDATA_WIDTH-1):0] sm_buffer;
    reg [(pDATA_WIDTH-1):0] sm_buffer_next;
    reg sm_buffer_state;     // 0 for idle; 1 for occupied
    reg sm_buffer_state_next;    
    reg [2:0] sm_cnt;
    reg [2:0] sm_cnt_next;
    reg [(pSS_WIDTH-1):0] sm_dat_r;
    reg last_flag;
    
    assign  en_sm = (k1_sw_vld && k1_sw_rdy) || (k2_sw_vld && k2_sw_rdy) || (k3_sw_vld && k3_sw_rdy) || (k4_sw_vld && k4_sw_rdy);
    assign  empty = (wr_ptr == rd_ptr);

    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        last_flag <= 0;
      end else if (en_sm && (k1_sw_lst || k2_sw_lst || k3_sw_lst || k4_sw_lst)) begin
        last_flag <= 1;
      end else if ((FIFO_out[2] == 0 && sm_cnt == 3 && sm_rdy) || (FIFO_out[2] == 1 && sm_cnt == 7 && sm_rdy)) begin
        last_flag <= 0;
      end else begin
        last_flag <= last_flag;
      end
    end

    assign  FIFO_wr_en = meta_decode && ~destination[4];
    assign  FIFO_rd_en = last_flag && ((FIFO_out[2] == 0 && sm_cnt == 3 && sm_rdy) || (FIFO_out[2] == 1 && sm_cnt == 7 && sm_rdy));

    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
      end else begin
        wr_ptr <= wr_ptr_next;
        rd_ptr <= rd_ptr_next;
      end
    end

    always @* begin
      if (FIFO_wr_en) begin
        wr_ptr_next = wr_ptr + 1;
      end else begin
        wr_ptr_next = wr_ptr;
      end

      if (FIFO_rd_en && !empty) begin
          rd_ptr_next = rd_ptr + 1;
      end else begin
          rd_ptr_next = rd_ptr;
      end
    end

    assign FIFO_in = {kernal_mode[2:1], destination[1:0]};

    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        FIFO_mem[0] <= 0;
        FIFO_mem[1] <= 0;
        FIFO_mem[2] <= 0;
        FIFO_mem[3] <= 0;
      end else if (FIFO_wr_en) begin
        FIFO_mem[wr_ptr[1:0]] <= FIFO_in;
      end else begin
        FIFO_mem[0] <= FIFO_mem[0];
        FIFO_mem[1] <= FIFO_mem[1];
        FIFO_mem[2] <= FIFO_mem[2];
        FIFO_mem[3] <= FIFO_mem[3];
      end
    end
    
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        FIFO_out <= 0;
      end else begin
        FIFO_out <= FIFO_mem[rd_ptr[1:0]];
      end 
    end
    

    // sm_buffer

    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        sm_buffer <= 0;
        sm_buffer_state <= 0;
        sm_cnt <= 0;
      end else begin
        sm_buffer <= sm_buffer_next;
        sm_buffer_state <= sm_buffer_state_next;
        sm_cnt <= sm_cnt_next;
      end
    end
    
    always@* begin
      if (en_sm) begin
        case (FIFO_out[1:0])
          2'b00: begin
            sm_buffer_next = k1_sw_dat;
          end
          2'b01: begin
            sm_buffer_next = k2_sw_dat;
          end
          2'b10: begin 
            sm_buffer_next = k3_sw_dat;
          end
          2'b11: begin 
            sm_buffer_next = k4_sw_dat;
          end
          default: begin
            sm_buffer_next = sm_buffer;
          end 
        endcase
      end else begin
            sm_buffer_next = sm_buffer;
      end
    end

    always@* begin
      if (FIFO_out[2] == 0) begin     // FFT or iFFT
        if (en_sm) begin
          sm_buffer_state_next = 1;
        end else if (sm_buffer_state == 1 && sm_cnt == 3 && sm_rdy) begin
          sm_buffer_state_next = 0;
        end else begin
          sm_buffer_state_next = sm_buffer_state;
        end
      end else begin                  // NTT or iNTT
        if (en_sm) begin
          sm_buffer_state_next = 1;
        end else if (sm_buffer_state == 1 && sm_cnt == 7 && sm_rdy) begin
          sm_buffer_state_next = 0;
        end else begin
          sm_buffer_state_next = sm_buffer_state;
        end
      end
    end

    always@* begin
      if (FIFO_out[2] == 0) begin     // FFT or iFFT
        if (sm_buffer_state == 1 && sm_cnt < 3 && sm_rdy) begin
          sm_cnt_next = sm_cnt + 1;
        end else if (sm_buffer_state == 0) begin
          sm_cnt_next = 0;
        end else begin
          sm_cnt_next = sm_cnt;
        end
      end else begin                  // NTT or iNTT
        if (sm_buffer_state == 1 && sm_cnt < 7 && sm_rdy) begin
          sm_cnt_next = sm_cnt + 1;
        end else if (sm_buffer_state == 0) begin
          sm_cnt_next = 0;
        end else begin
          sm_cnt_next = sm_cnt;
        end
      end
    end

    always@* begin       
      if (FIFO_out[2] == 0) begin     // FFT or iFFT
        case (sm_cnt)
        3'b000: sm_dat_r = sm_buffer[127:96];
        3'b001: sm_dat_r = sm_buffer[95:64];
        3'b010: sm_dat_r = sm_buffer[63:32];
        3'b011: sm_dat_r = sm_buffer[31:0];
          default: sm_dat_r = 32'hFFFFFFFF;
        endcase
      end else begin                  // NTT or iNTT
        case (sm_cnt)
          3'b000: sm_dat_r = {16'd0, sm_buffer[15:0]   };
          3'b001: sm_dat_r = {16'd0, sm_buffer[31:16]  };
          3'b010: sm_dat_r = {16'd0, sm_buffer[47:32]  };
          3'b011: sm_dat_r = {16'd0, sm_buffer[63:48]  };
          3'b100: sm_dat_r = {16'd0, sm_buffer[79:64]  };
          3'b101: sm_dat_r = {16'd0, sm_buffer[95:80]  };
          3'b110: sm_dat_r = {16'd0, sm_buffer[111:96] };
          3'b111: sm_dat_r = {16'd0, sm_buffer[127:112]};
          default: sm_dat_r = 32'hFFFFFFFF;
        endcase
      end
    end

    assign sm_vld = sm_buffer_state;
    assign sm_dat = sm_dat_r;
  /*----------------------------------------------------------------
                      kernal data stream out
  -----------------------------------------------------------------*/

  assign k1_sw_rdy = (sm_buffer_state == 0) && (FIFO_out[1:0] == 2'b00) ;
  assign k2_sw_rdy = (sm_buffer_state == 0) && (FIFO_out[1:0] == 2'b01) ;
  assign k3_sw_rdy = (sm_buffer_state == 0) && (FIFO_out[1:0] == 2'b10) ;
  assign k4_sw_rdy = (sm_buffer_state == 0) && (FIFO_out[1:0] == 2'b11) ;
  
  /*----------------------------------------------------------------
                      Configuration Register
  -----------------------------------------------------------------*/
//--- ap_ctrl & coef_ctrl  ---//

    reg [3:0] ap_done1_r;
    reg [3:0] ap_done1_next;
    reg [3:0] ap_done2_r;
    reg [3:0] ap_done2_next;
    reg [3:0] ap_done3_r;
    reg [3:0] ap_done3_next;
    reg [3:0] ap_done4_r;
    reg [3:0] ap_done4_next;

    reg [3:0] ap_idle1_r;
    reg [3:0] ap_idle1_next;
    reg [3:0] ap_idle2_r;
    reg [3:0] ap_idle2_next;
    reg [3:0] ap_idle3_r;
    reg [3:0] ap_idle3_next;
    reg [3:0] ap_idle4_r;
    reg [3:0] ap_idle4_next;
/*
    reg coef_ctrl_r;
    reg coef_ctrl_next;

    assign coef_ctrl = coef_ctrl_r;
*/
    assign ap_ctrl = {ap_idle4_r, ap_done4_r, ap_idle3_r, ap_done3_r, ap_idle2_r, ap_done2_r, ap_idle1_r, ap_done1_r};

    always @(*) begin
/*
        // coef_ctrl
        if ((meta_counter == data_length) && ss_rdy && (destination == COEF)) begin
            coef_ctrl_next = 1;
        end else begin
            coef_ctrl_next = coef_ctrl_r;
        end
*/
        // ap_idle1
        if (meta_decode == 1 && destination == KERNEL_1) begin
            ap_idle1_next = 0;
        end else if (k1_sw_lst) begin
            ap_idle1_next = 1;
        end else begin
            ap_idle1_next = ap_idle1_r;
        end
        // ap_idle2
        if (meta_decode == 1 && destination == KERNEL_2) begin
            ap_idle2_next = 0;
        end else if (k2_sw_lst) begin
            ap_idle2_next = 1;
        end else begin
            ap_idle2_next = ap_idle2_r;
        end
        // ap_idle3
        if (meta_decode == 1 && destination == KERNEL_3) begin
            ap_idle3_next = 0;
        end else if (k3_sw_lst) begin
            ap_idle3_next = 1;
        end else begin
            ap_idle3_next = ap_idle3_r;
        end
        // ap_idle4
        if (meta_decode == 1 && destination == KERNEL_4) begin
            ap_idle4_next = 0;
        end else if (k4_sw_lst) begin
            ap_idle4_next = 1;
        end else begin
            ap_idle4_next = ap_idle4_r;
        end
        // ap_done1
        if (k1_sw_lst) begin
            ap_done1_next = 1;
        end else if (ap_read && ap_done1_r) begin
            ap_done1_next = 0;
        end else begin
            ap_done1_next = ap_done1_r;
        end
        // ap_done2
        if (k2_sw_lst) begin
            ap_done2_next = 1;
        end else if (ap_read && ap_done2_r) begin
            ap_done2_next = 0;
        end else begin
            ap_done2_next = ap_done2_r;
        end
        // ap_done3
        if (k3_sw_lst) begin
            ap_done3_next = 1;
        end else if (ap_read && ap_done3_r) begin
            ap_done3_next = 0;
        end else begin
            ap_done3_next = ap_done3_r;
        end
        // ap_done4
        if (k4_sw_lst) begin
            ap_done4_next = 1;
        end else if (ap_read && ap_done4_r) begin
            ap_done4_next = 0;
        end else begin
            ap_done4_next = ap_done4_r;
        end
    end

    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        // coef_ctrl_r <= 0;
        ap_idle1_r <= 1;
        ap_idle2_r <= 1;
        ap_idle3_r <= 1;
        ap_idle4_r <= 1;
        ap_done1_r <= 0;
        ap_done2_r <= 0;
        ap_done3_r <= 0;
        ap_done4_r <= 0;
      end else begin
        // coef_ctrl_r <= coef_ctrl_next;
        ap_idle1_r <= ap_idle1_next;
        ap_idle2_r <= ap_idle2_next;
        ap_idle3_r <= ap_idle3_next;
        ap_idle4_r <= ap_idle4_next;
        ap_done1_r <= ap_done1_next;
        ap_done2_r <= ap_done2_next;
        ap_done3_r <= ap_done3_next;
        ap_done4_r <= ap_done4_next;
      end
    end

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
    .Do   (intt_coef_ram_do),
    .A    (ntt_coef_ram_a_mux)
  );

endmodule
