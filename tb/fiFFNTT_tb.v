`timescale 1ns/1ps

module fiFFNTT_tb;

  // Parameters & Constants
  localparam CLK_PERIOD    = 12;             // 100 MHz clock
  localparam ADDR_WIDTH    = 32;
  localparam DATA_WIDTH    = 32;
  localparam NUM_KER       = 4;

  // Stream lengths
  /*
  localparam int LEN [NUM_KER] = {2048, 2048, 1024, 1024};
  localparam int COEF_LEN [NUM_KER] = {512, 512, 1024, 1024};
  */
  function [15:0] get_LEN;
  input integer idx;
  begin
    case(idx)
      0: get_LEN = 2048;
      1: get_LEN = 2048;
      2: get_LEN = 1024;
      3: get_LEN = 1024;
      default: get_LEN = 0;
    endcase
  end
  endfunction

  function [15:0] get_COEF_LEN;
    input integer idx;
    begin
      case(idx)
        0: get_COEF_LEN = 2044;
        1: get_COEF_LEN = 2044;
        2: get_COEF_LEN = 1024;
        3: get_COEF_LEN = 1024;
        default: get_COEF_LEN = 0;
      endcase
    end
  endfunction

  // Register map
  localparam [ADDR_WIDTH-1:0] STATUS_ADDR    = 32'h3000_0000;
  localparam [ADDR_WIDTH-1:0] COEF_DONE_ADDR = 32'h3000_0010;
  localparam [ADDR_WIDTH-1:0] MB_BASE_ADDR   = 32'h3000_2000;
  localparam [7:0]            COEF_BASE      = 8'b0001_0100;
  localparam [7:0]            KERNEL_BASE    = 8'b0000_0100;
  localparam [7:0]            MODE_BASE      = 8'b0000_0100;
  localparam                  MB_STRIDE      = 4;

  // Patterns
  localparam [DATA_WIDTH-1:0] PAT_KER_FREE = 32'h3A3A3A3A;
  localparam [DATA_WIDTH-1:0] PAT_KER_BUSY = 32'h5A5A5A5A;

  // Clock & Reset
  reg clk = 1;
  reg rstn = 0;
  reg clk_2x = 1;
  always #(CLK_PERIOD/2) clk = ~clk;
  always #(CLK_PERIOD/4) clk_2x = ~clk_2x;  // 2x freq clock
  initial begin 
    #(CLK_PERIOD*5); 
    rstn = 1; 
  end

  // AXI-Lite interface signals
  reg                        awvalid, wvalid, arvalid, rready;
  reg  [ADDR_WIDTH-1:0]      awaddr, araddr;
  reg  [DATA_WIDTH-1:0]      wdata;
  wire                       awready, wready, arready, rvalid;
  wire [DATA_WIDTH-1:0]      rdata;
  
  reg                        awvalid_mb, wvalid_mb, arvalid_mb, rready_mb;
  reg  [ADDR_WIDTH-1:0]      awaddr_mb, araddr_mb;
  reg  [DATA_WIDTH-1:0]      wdata_mb;
  wire                       awready_mb, wready_mb, arready_mb, rvalid_mb;
  wire [DATA_WIDTH-1:0]      rdata_mb;

  // Streaming interfaces
  reg                        ss_tvalid, ss_tlast;
  reg  [DATA_WIDTH-1:0]      ss_tdata;
  wire                       ss_tready;
  reg                        sm_tready;
  wire                       sm_tvalid, sm_tlast;
  wire [DATA_WIDTH-1:0]      sm_tdata;

  reg [DATA_WIDTH-1:0] stat;
  integer idx;
  integer i, j, k, m;
  integer cal_time;

  // Memories for input/output/golden data
  reg [DATA_WIDTH-1:0] coef_mem   [0:NUM_KER-1][0:2047];
  reg [DATA_WIDTH-1:0] in_mem     [0:NUM_KER-1][0:2047];
  reg [DATA_WIDTH-1:0] out_mem    [0:NUM_KER-1][0:2047];
  reg [DATA_WIDTH-1:0] golden_mem [0:NUM_KER-1][0:2047];

  reg [DATA_WIDTH-1:0] coef_mem_FFT    [0:2047];
  reg [31:0] coef_mem_NTT              [0:1023];
  reg [31:0] coef_mem_iNTT             [0:1023];
  reg [DATA_WIDTH-1:0] in_mem_FFT      [0:2047];
  reg [DATA_WIDTH-1:0] in_mem_iFFT     [0:2047];
  reg [31:0] in_mem_NTT                [0:1023];
  reg [31:0] in_mem_iNTT               [0:1023];
  reg [DATA_WIDTH-1:0] golden_mem_FFT  [0:2047];
  reg [DATA_WIDTH-1:0] golden_mem_iFFT [0:2047];
  reg [31:0] golden_mem_NTT            [0:1023];
  reg [31:0] golden_mem_iNTT           [0:1023];

  reg [DATA_WIDTH-1:0] coef_FFT    [0:2047];
  reg [DATA_WIDTH-1:0] coef_NTT    [0:1023];
  reg [DATA_WIDTH-1:0] coef_iNTT   [0:1023];
  reg [DATA_WIDTH-1:0] in_FFT      [0:2047];
  reg [DATA_WIDTH-1:0] in_iFFT     [0:2047];
  reg [DATA_WIDTH-1:0] in_NTT      [0:1023];
  reg [DATA_WIDTH-1:0] in_iNTT     [0:1023];
  reg [DATA_WIDTH-1:0] out_FFT     [0:2047];
  reg [DATA_WIDTH-1:0] out_iFFT    [0:2047];
  reg [DATA_WIDTH-1:0] out_NTT     [0:1023];
  reg [DATA_WIDTH-1:0] out_iNTT    [0:1023];
  reg [DATA_WIDTH-1:0] golden_FFT  [0:2047];
  reg [DATA_WIDTH-1:0] golden_iFFT [0:2047];
  reg [DATA_WIDTH-1:0] golden_NTT  [0:1023];
  reg [DATA_WIDTH-1:0] golden_iNTT [0:1023];

  // Main test sequence
  integer start_time, end_time, latency;
  reg [DATA_WIDTH-1:0] check;
  reg [DATA_WIDTH-1:0] check_k1;
  reg [DATA_WIDTH-1:0] check_k2;
  reg [DATA_WIDTH-1:0] check_k3;
  reg [DATA_WIDTH-1:0] check_k4;
  integer rand_time;
  integer length;
  integer mode;

  // file is used to calculate kernel utilization
  integer log_file_1_1, log_file_2_1, log_file_3_1, log_file_4_1; // these file record changes of BPE1.i_vld and BPE5.o_vld
  integer log_file_1_2, log_file_2_2, log_file_3_2, log_file_4_2;

  // DUT Instantiation
  fiFFNTT #(
    .pADDR_WIDTH(ADDR_WIDTH),
    .pDATA_WIDTH(DATA_WIDTH),
    .pIOPS_WIDTH(128)
  ) DUT (
    .clk        (clk),
    .clk_2x     (clk_2x),
    .rstn       (rstn),
    .awready    (awready),
    .awvalid    (awvalid),
    .awaddr     (awaddr),
    .wready     (wready),
    .wvalid     (wvalid),
    .wdata      (wdata),
    .arready    (arready),
    .arvalid    (arvalid),
    .araddr     (araddr),
    .rvalid     (rvalid),
    .rdata      (rdata),
    .rready     (rready),
    .ss_tvalid  (ss_tvalid),
    .ss_tdata   (ss_tdata),
    .ss_tlast   (ss_tlast),
    .ss_tready  (ss_tready),
    .sm_tready  (sm_tready),
    .sm_tvalid  (sm_tvalid),
    .sm_tdata   (sm_tdata),
    .sm_tlast   (sm_tlast)
  );

  mailbox #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .MB_COUNT(NUM_KER)
  ) mb (
    .ACLK(clk),
    .ARESETN(rstn),
    .awready    (awready_mb),
    .awvalid    (awvalid_mb),
    .awaddr     (awaddr_mb),
    .wready     (wready_mb),
    .wvalid     (wvalid_mb),
    .wdata      (wdata_mb),
    .arready    (arready_mb),
    .arvalid    (arvalid_mb),
    .araddr     (araddr_mb),
    .rvalid     (rvalid_mb),
    .rdata      (rdata_mb),
    .rready     (rready_mb)
  );

  //Prevent hang
  integer timeout = (60000);
  initial begin
      while(timeout > 0) begin
          @(posedge clk);
          timeout = timeout - 1;
      end
      $display($time, "Simualtion Hang ....");
      $finish;
  end

reg [4:0] prev_i_vld, prev_o_vld;
reg [4:0] i_count, o_count;
reg [31:0] input_count, output_count;
reg [4:0] curr_i_vld;
reg [4:0] curr_o_vld;
reg [4:0] rise_i;
reg [4:0] rise_o;

// initial begin
//   prev_i_vld   = 5'b0;
//   prev_o_vld   = 5'b0;
//   i_count      = 5'd0;
//   o_count      = 5'd0;
//   input_count  = 32'd0;
//   output_count = 32'd0;
// end

// always @(posedge clk, negedge rstn) begin
//   if (!rstn) begin
//     curr_i_vld <= 5'd0;
//     curr_o_vld <= 5'd0;
//     rise_i <= 5'd0;
//     rise_o <= 5'd0;
//     prev_i_vld   <= 5'b0;
//     prev_o_vld   <= 5'b0;
//     i_count      <= 5'd0;
//     o_count      <= 5'd0;
//     input_count  <= 32'd0;
//     output_count <= 32'd0;
//   end else begin
//     // 取得現在的 vld 訊號
//     curr_i_vld <= {
//       DUT.kernel1.BPE5_i_vld,
//       DUT.kernel1.BPE4_i_vld,
//       DUT.kernel1.BPE3_i_vld,
//       DUT.kernel1.BPE2_i_vld,
//       DUT.kernel1.BPE1_i_vld
//     };

//     curr_o_vld <= {
//       DUT.kernel1.BPE5_o_vld,
//       DUT.kernel1.BPE4_o_vld,
//       DUT.kernel1.BPE3_o_vld,
//       DUT.kernel1.BPE2_o_vld,
//       DUT.kernel1.BPE1_o_vld
//     };

//     // 偵測上升沿
//     rise_i <= curr_i_vld & ~prev_i_vld;
//     rise_o <= curr_o_vld & ~prev_o_vld;

//     // 累加每條線的計數
//     i_count <= i_count + rise_i;
//     o_count <= o_count + rise_o;

//     // 累加總 input/output
//     input_count  <= input_count  + rise_i[0] + rise_i[1] + rise_i[2] + rise_i[3] + rise_i[4];
//     output_count <= output_count + rise_o[0] + rise_o[1] + rise_o[2] + rise_o[3] + rise_o[4];

//     // 更新 previous 訊號
//     prev_i_vld <= curr_i_vld;
//     prev_o_vld <= curr_o_vld;
//   end
// end

// //////////////////////////////////////////////////////////////// calculate kernel utilization
//   reg [31:0] idle_cycle_count_kernel1, idle_cycle_count_kernel2, idle_cycle_count_kernel3, idle_cycle_count_kernel4;
//   always @(posedge clk, negedge rstn) begin
//     if (!rstn) begin
//       idle_cycle_count_kernel1 <= 32'd0;
//       idle_cycle_count_kernel2 <= 32'd0;
//       idle_cycle_count_kernel3 <= 32'd0;
//       idle_cycle_count_kernel4 <= 32'd0;
//     end else begin
//       if (DUT.kernel1.BPE1.i_vld == 1'b0 && DUT.kernel1.BPE1.i_rdy == 1'b1) begin //we can change signal here to know different kernel and bpe's idle rate
//         idle_cycle_count_kernel1 <= idle_cycle_count_kernel1 + 32'd1;
//       end else begin
//         idle_cycle_count_kernel1 <= idle_cycle_count_kernel1;
//       end
//       if (DUT.kernel2.BPE1.i_vld == 1'b0 && DUT.kernel2.BPE1.i_rdy == 1'b1) begin
//         idle_cycle_count_kernel2 <= idle_cycle_count_kernel2 + 32'd1;
//       end else begin
//         idle_cycle_count_kernel2 <= idle_cycle_count_kernel2;
//       end
//       if (DUT.kernel3.BPE4.i_vld == 1'b0 && DUT.kernel3.BPE4.i_rdy == 1'b1) begin
//         idle_cycle_count_kernel3 <= idle_cycle_count_kernel3 + 32'd1;
//       end else begin
//         idle_cycle_count_kernel3 <= idle_cycle_count_kernel3;
//       end
//       if (DUT.kernel4.BPE4.i_vld == 1'b0 && DUT.kernel4.BPE4.i_rdy == 1'b1) begin
//         idle_cycle_count_kernel4 <= idle_cycle_count_kernel4 + 32'd1;
//       end else begin
//         idle_cycle_count_kernel4 <= idle_cycle_count_kernel4;
//       end
//     end
//   end

  // initial begin
  //   log_file_1_1 = $fopen("moniter_time_kernek1.txt", "w");  // "w" 表示寫入模式（會覆蓋原檔）
  //   log_file_2_1 = $fopen("moniter_time_kernek2.txt", "w");
  //   log_file_3_1 = $fopen("moniter_time_kernek3.txt", "w");
  //   log_file_4_1 = $fopen("moniter_time_kernek4.txt", "w");
  //   log_file_1_2 = $fopen("require_time_kernek1.txt", "w");  // "w" 表示寫入模式（會覆蓋原檔）
  //   log_file_2_2 = $fopen("require_time_kernek2.txt", "w");
  //   log_file_3_2 = $fopen("require_time_kernek3.txt", "w");
  //   log_file_4_2 = $fopen("require_time_kernek4.txt", "w");

  //   if (log_file_1_1 == 0 || log_file_2_1 == 0 || log_file_3_1 == 0 || log_file_4_1 == 0) begin
  //     $display("Error opening file!");
  //     $finish;
  //   end

  //   // 類似 $monitor，只是輸出到檔案
  //   $fmonitor(log_file_1_1, "Time=%0t, DUT.kernel1.BPE1.i_vld=%b, DUT.kernel1.BPE5.o_vld=%b", $time, DUT.kernel1.BPE1.i_vld, DUT.kernel1.BPE5.o_vld);
  //   $fmonitor(log_file_2_1, "Time=%0t, DUT.kernel2.BPE1.i_vld=%b, DUT.kernel2.BPE5.o_vld=%b", $time, DUT.kernel2.BPE1.i_vld, DUT.kernel2.BPE5.o_vld);
  //   $fmonitor(log_file_3_1, "Time=%0t, DUT.kernel3.BPE1.i_vld=%b, DUT.kernel3.BPE4.o_vld=%b", $time, DUT.kernel3.BPE1.i_vld, DUT.kernel3.BPE4.o_vld);
  //   $fmonitor(log_file_4_1, "Time=%0t, DUT.kernel4.BPE1.i_vld=%b, DUT.kernel4.BPE4.o_vld=%b", $time, DUT.kernel4.BPE1.i_vld, DUT.kernel4.BPE4.o_vld); 
  //   $fmonitor(log_file_1_2, "Time=%0t, idle cycle count kernel1=%d", $time, idle_cycle_count_kernel1);
  //   $fmonitor(log_file_2_2, "Time=%0t, idle cycle count kernel2=%d", $time, idle_cycle_count_kernel2);
  //   $fmonitor(log_file_3_2, "Time=%0t, idle cycle count kernel3=%d", $time, idle_cycle_count_kernel3);
  //   $fmonitor(log_file_4_2, "Time=%0t, idle cycle count kernel4=%d", $time, idle_cycle_count_kernel4);
  // end

////////////////////////////////////////////////////////////////

  // AXI-Lite write task
  task axilite_write(
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data
  );
    begin
      // Address channel
      awaddr = addr;
      awvalid = 1;
      arvalid = 0;    
      rready = 0;
      wait (awready);
      @(posedge clk);
      awvalid <= 0;

      wdata <= data;
      wvalid <= 1;
      wait(wready);
      @(posedge clk);
      wvalid <= 0;

      @(posedge clk);
    end
  endtask

  task axilite_write_mb(
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data
  );
    begin
      // Address channel
      awaddr_mb = addr;
      awvalid_mb = 1;
      arvalid_mb = 0;    
      rready_mb = 0;
      wait(awready_mb);
      @(posedge clk);
      awvalid_mb <= 0;

      wdata_mb <= data;
      wvalid_mb <= 1;
      wait(wready_mb);
      @(posedge clk);
      wvalid_mb <= 0;

      @(posedge clk);
    end
  endtask

  // AXI-Lite read task
  task axilite_read(
    input  [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] data
  );
    begin
      araddr = addr; 
      arvalid = 1;
      awvalid = 0;    
      wvalid = 0;

      wait(arready);
      @(posedge clk); 
      arvalid <= 0;
      rready <= 1;

      wait(rvalid);
      data <= rdata;
      @(posedge clk); 
      rready <= 0;
    end
  endtask

  task axilite_read_mb(
    input  [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] data
  );
    begin
      araddr_mb = addr; 
      arvalid_mb = 1;
      awvalid_mb = 0;    
      wvalid_mb  = 0;

      wait(arready_mb);
      @(posedge clk); 
      arvalid_mb <= 0;
      rready_mb <= 1;

      wait(rvalid_mb);
      @(posedge clk); 
      data <= rdata_mb;
      rready_mb <= 0;
    end
  endtask

  // Wait for ap_idle[k] == 1 via STATUS_ADDR
  task wait_ap_idle(input integer ker);
    begin
      idx = ker * 8 + 4;
      axilite_read(STATUS_ADDR, stat);
      @(posedge clk);
      while (!stat[idx]) begin
        #(CLK_PERIOD * 10);
        axilite_read(STATUS_ADDR, stat);
        @(posedge clk);
      end
    end
  endtask


  // Wait for ap_done[k] == 1 (and clear) via STATUS_ADDR
  task wait_ap_done(input integer ker);
    begin
      idx = ker * 8;
      axilite_read(STATUS_ADDR, stat);
      @(posedge clk);
      while (!stat[idx]) begin
        #(CLK_PERIOD * 10);
        axilite_read(STATUS_ADDR, stat);
        @(posedge clk);
      end
    end
  endtask

  task stream_meta(
    input [7:0] dt,
    input [7:0] mode,
    input [15:0] length
  );
    begin
      ss_tdata <= {dt, mode, length};
      ss_tvalid <= 1;
      ss_tlast <= 0;

      wait(ss_tready);
      @(posedge clk_2x);
      ss_tvalid <= 0;
    end
  endtask


  // ss_stream_in: send N words over ss_t*
  task ss_stream_in(
    input integer N,
    input integer M
  );
    begin
      for (i = 0; i < N; i = i + 1) begin
        @(posedge clk_2x);
        ss_tdata <= in_mem[M][i];
        ss_tvalid <= 1;
        ss_tlast <= (i == N - 1);

        wait(ss_tready);
        @(posedge clk_2x);
        ss_tvalid <= 0;
        ss_tlast <= 0;
      end
    end
  endtask

  task ss_stream_coef(
    input integer N,
    input integer M
  );
    begin
      for (i = 0; i < N; i = i + 1) begin
        @(posedge clk_2x);
        ss_tdata <= coef_mem[M][i];
        ss_tvalid <= 1;
        
        wait(ss_tready);
        @(posedge clk_2x);
        ss_tvalid <= 0;
      end
    end
  endtask

  task sm_stream_meta(
    output integer length_out,
    output integer mode_out
  );
    begin
      @(posedge clk_2x);
      sm_tready <= 1;

      wait(sm_tvalid);
      @(posedge clk_2x);
      length_out <= sm_tdata[15:0];
      mode_out <= sm_tdata[23:16] - 8'd4;
      sm_tready <= 0;
    end
  endtask

  // Wrong code by Team TB
  task sm_stream_out(
    input integer N,
    input integer M
  );
    begin
      j = 0; 
      while (j < N) begin
        sm_tready <= 1;
        @(posedge clk_2x);
        if (sm_tvalid) begin
          case (M)
            0: out_FFT[j]  = sm_tdata;
            1: out_iFFT[j] = sm_tdata;
            2: out_NTT[j]  = sm_tdata;
            3: out_iNTT[j] = sm_tdata;
          endcase
          j = j + 1;
          //sm_tready <= 0; // 每收完一筆，ready往下拉
          //@(posedge clk);
        end
      end
      sm_tready <= 0;
    end
  endtask

  task kernel_start(
    input integer N,
    input integer M
  );
    begin
      axilite_write_mb(MB_BASE_ADDR + N * MB_STRIDE, PAT_KER_BUSY);
      stream_meta(KERNEL_BASE + N, MODE_BASE + M, get_LEN(M));
      ss_stream_in(get_LEN(M), M);
    end
  endtask


  task polling;
    begin
      axilite_read(STATUS_ADDR, stat);
      if (stat[0]) axilite_write_mb(MB_BASE_ADDR, PAT_KER_FREE);
      if (stat[8]) axilite_write_mb(MB_BASE_ADDR + 4, PAT_KER_FREE);
      if (stat[16]) axilite_write_mb(MB_BASE_ADDR + 8, PAT_KER_FREE);
      if (stat[24]) axilite_write_mb(MB_BASE_ADDR + 12, PAT_KER_FREE);
    end
  endtask

  task test2_data_in;
    begin
      polling;
      axilite_read_mb(MB_BASE_ADDR, check);
      if (check != PAT_KER_FREE) begin
        $display("Test2 Error: kernel 1 is not free");
        $finish;
      end
      kernel_start(0, 0);

      rand_time = $random % 1000;
      if (rand_time < 0) begin
        rand_time = -rand_time;
      end
      #(rand_time * CLK_PERIOD);

      polling;
      axilite_read_mb(MB_BASE_ADDR + 4, check);
      if (check != PAT_KER_FREE) begin
        $display("Test2 Error: kernel 2 is not free");
        $finish;
      end
      kernel_start(1, 0);

      rand_time = $random % 1000;
      if (rand_time < 0) begin
        rand_time = -rand_time;
      end
      #(rand_time * CLK_PERIOD);

      polling;
      axilite_read_mb(MB_BASE_ADDR + 8, check);
      if (check != PAT_KER_FREE) begin
        $display("Test2 Error: kernel 3 is not free");
        $finish;
      end
      kernel_start(2, 0);

      rand_time = $random % 1000;
      if (rand_time < 0) begin
        rand_time = -rand_time;
      end
      #(rand_time * CLK_PERIOD);

      polling;
      axilite_read_mb(MB_BASE_ADDR + 12, check);
      if (check != PAT_KER_FREE) begin
        $display("Test2 Error: kernel 4 is not free");
        $finish;
      end
      kernel_start(3, 0);
    end
  endtask

  task test3_data_in;
    begin
      for (m = 0; m < 100; m = m + 1) begin
        polling;
        axilite_read_mb(MB_BASE_ADDR, check_k1);
        axilite_read_mb(MB_BASE_ADDR + 4, check_k2);
        axilite_read_mb(MB_BASE_ADDR + 8, check_k3);
        axilite_read_mb(MB_BASE_ADDR + 12, check_k4);
        while (check_k1 == PAT_KER_BUSY && check_k2 == PAT_KER_BUSY &&
          check_k3 == PAT_KER_BUSY && check_k4 == PAT_KER_BUSY) begin
          #500;
          polling;
          axilite_read_mb(MB_BASE_ADDR, check_k1);
          axilite_read_mb(MB_BASE_ADDR + 4, check_k2);
          axilite_read_mb(MB_BASE_ADDR + 8, check_k3);
          axilite_read_mb(MB_BASE_ADDR + 12, check_k4);
        end
        if (check_k1 == PAT_KER_FREE) begin
          kernel_start(0, 0);
        end else if (check_k2 == PAT_KER_FREE) begin
          kernel_start(1, 0);
        end else if (check_k3 == PAT_KER_FREE) begin
          kernel_start(2, 0);
        end else if (check_k4 == PAT_KER_FREE) begin
          kernel_start(3, 0);
        end
      end
    end
  endtask

function [79:0] extract_digits;
  input [1023:0] str;
  integer i, j, k;
  reg [87:0] tmp11;  // 11 bytes = 88 bits
  reg [7:0] ch;
  reg carry;
  begin
    tmp11 = 88'd0;
    j = 0;

    // 從後往前掃描，抓到 11 個數字字元
    for (i = 1023; i >= 7 && j < 11; i = i - 8) begin
      ch = str[i -: 8];
      if (ch >= "0" && ch <= "9") begin
        tmp11[87 - j*8 -: 8] = ch;
        j = j + 1;
      end
    end

    // 如果抓不到至少 1 個數字，直接回傳 0
    if (j == 0) begin
      extract_digits = 80'd0;
    end else begin
      // 檢查第 11 個字元（最低位）是否需要進位
      carry = 0;
      if (j == 11) begin
        if (tmp11[7:0] >= "5")
          carry = 1;
      end

      // 對前 10 位做進位處理（從最低位開始處理）
      for (k = 1; k <= 10; k = k + 1) begin
        if (k > j - 1) begin
          // 未滿10位補0
          tmp11[8*k +: 8] = "0";
        end

        if (carry) begin
          if (tmp11[8*k +: 8] < "9") begin
            tmp11[8*k +: 8] = tmp11[8*k +: 8] + 1;
            carry = 0;
          end else begin
            tmp11[8*k +: 8] = "0"; // 9 + 1 = 0，繼續進位
          end
        end
      end
      
      if  (carry) begin
        tmp11[87:80] = "1";
      end

      // 將處理後的高 10 bytes 回傳
      extract_digits = tmp11[87:8];
    end
  end
endfunction


task compare_fp64;
  input  [63:0] golden_bits;
  input  [63:0] output_bits;
  output        err;

  real golden_val;
  real output_val;
  real div_val; // used to check exponent correct

  reg [1023:0] str_golden;
  reg [1023:0] str_output;
  reg [79:0] digits_golden;
  reg [79:0] digits_output;

  integer i, j;


  begin
    golden_val = $bitstoreal(golden_bits);
    output_val = $bitstoreal(output_bits);
    div_val = golden_val / output_val;
    // 轉成字串（最多17位有效數字）
    str_golden = "";
    str_output = "";
    $sformat(str_golden, "%0.17e", golden_val);
    $sformat(str_output, "%0.17e", output_val);

    // 擷取前10位有效數字（去掉符號、小數點、e+指數）
    digits_golden = extract_digits(str_golden);
    digits_output = extract_digits(str_output);

    // 比對
    if (digits_golden == digits_output && (div_val < 1.1 && div_val > 0.9))
      err = 0;
    else
      err = 1;

    // Optional debug
    $display("Golden = %s => digit = %s", str_golden, digits_golden);
    $display("Output = %s => digit = %s", str_output, digits_output);
    $display("Result: err = %0d", err);
  end
endtask




  integer fd; 
  reg [63:0] golden_tmp;
  reg [63:0] output_tmp;
  reg err_tmp;


  initial begin
    fd = $fopen("terminal_message.txt", "w");
    $dumpfile("fiFFNTT.vcd");
    $dumpvars(0, fiFFNTT_tb);
    awvalid = 0; 
    wvalid = 0;
    arvalid = 0; 
    rready = 0;
    ss_tvalid = 0;
    ss_tlast = 0; 
    sm_tready = 0;
    
    awvalid_mb = 0;
    wvalid_mb = 0;
    arvalid_mb = 0;
    rready_mb = 0;

    wait (rstn); 
    #CLK_PERIOD;

    // Load data files
    $readmemh("coef.hex", coef_mem_FFT);
    //$readmemh("addr0_511_128b.hex", coef_mem1);
    $readmemh("NTT_coef.hex", coef_mem_NTT);
    $readmemh("iNTT_coef.hex", coef_mem_iNTT);
    $readmemh("input.hex", in_mem_FFT);
    $readmemh("input_iFFT.hex", in_iFFT);
    $readmemh("NTT_in.hex", in_mem_NTT);
    $readmemh("iNTT_in.hex", in_mem_iNTT);
    $readmemh("output.hex", golden_mem_FFT);
    $readmemh("output_iFFT.hex", golden_mem_iFFT);
    $readmemh("NTT_out.hex", golden_mem_NTT);
    $readmemh("iNTT_out.hex", golden_mem_iNTT);

    for (k = 0; k < 1024; k = k + 1) begin
      coef_NTT[k] = {coef_mem_NTT[k]};
      coef_iNTT[k] = {coef_mem_iNTT[k]};
    end

    for (k = 0; k < 1024; k = k + 1) begin
      in_NTT[k] = {in_mem_NTT[k]};
      in_iNTT[k] = {in_mem_iNTT[k]};
      golden_NTT[k] = {golden_mem_NTT[k]};
      golden_iNTT[k] = {golden_mem_iNTT[k]};
    end

    for (k = 0; k < 2048; k = k + 1) begin
      coef_FFT[k] = coef_mem_FFT[k];
      in_FFT[k] = in_mem_FFT[k];
      in_iFFT[k] = in_iFFT[k];
      golden_FFT[k] = golden_mem_FFT[k];
      golden_iFFT[k] = golden_mem_iFFT[k];
    end
    
    for (k = 0; k < 2048; k = k + 1) begin
      in_mem[0][k] = in_FFT[k];
      in_mem[1][k] = in_iFFT[k];
      in_mem[2][k] = in_NTT[k];
      in_mem[3][k] = in_iNTT[k];
      coef_mem[0][k] = coef_FFT[k];
      coef_mem[1][k] = coef_FFT[k];
      coef_mem[2][k] = coef_NTT[k];
      coef_mem[3][k] = coef_iNTT[k];
    end

    axilite_read(STATUS_ADDR, stat);
    if (stat[7:0] != 8'h10) begin
      $display("initial ap_idle state wrong");
      $finish;
    end

    // initialize mailbox
    $display("TB: init mailboxes -> FREE");
    for (k = 0; k < NUM_KER; k = k + 1) begin
      axilite_write_mb(MB_BASE_ADDR + k * MB_STRIDE, PAT_KER_FREE);
    end

    // coef in
    for (k = 0; k < 4; k = k + 1) begin
      stream_meta(COEF_BASE + k, 8'b0001_0100 + k, get_COEF_LEN(k));
      ss_stream_coef(get_COEF_LEN(k), k);
      @(posedge clk);
    end
      
    // Write coef_done = 1
    //axilite_write(COEF_DONE_ADDR, 32'h0000_0001);
    $display("Coefficients input over");

    // test1
    for (k = 0; k < 4; k = k + 1) begin
      axilite_read_mb(MB_BASE_ADDR + k * MB_STRIDE, check);
      if (check != PAT_KER_FREE) begin
        $display("Test1 Error: Kernel %d is not free", 0 + 1);
        $finish;
      end else begin
        $display("Test1: Kernel %d is free", 0 + 1);
        axilite_write_mb(MB_BASE_ADDR + k * MB_STRIDE, PAT_KER_BUSY);
      end

      stream_meta(KERNEL_BASE + 0, MODE_BASE + k, get_LEN(k));
      // DMA in
      ss_stream_in(get_LEN(k), k);

      sm_stream_out(get_LEN(k), k);
      
      $display("here %d", k);
      wait_ap_done(0);
      
      //end_time = $time;
      //latency = end_time - start_time;
      //$display("Test1: Kernel 1 latency for data %d is %d ns", k + 1, latency);
      axilite_write_mb(MB_BASE_ADDR + k, PAT_KER_FREE);

      // Check results
      case (k)
        0 : begin
          for (i = 0; i < 2048; i = i + 2) begin
            golden_tmp = {golden_FFT[i], golden_FFT[i+1]};
            output_tmp = {out_FFT[i], out_FFT[i+1]};
            compare_fp64(golden_tmp, output_tmp, err_tmp);
            if (err_tmp == 1) begin
              $display("\033[1;31m[ERROR] FFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
              $fwrite(fd, "FFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
            end else begin
              $display("\033[1;32m[SUCCESS] FFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
              $fwrite(fd, "FFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
            end
          end
        end
        1 : begin
          for (i = 0; i < 2048; i = i + 2) begin
            golden_tmp = {golden_iFFT[i], golden_iFFT[i+1]};
            output_tmp = {out_iFFT[i], out_iFFT[i+1]};
            compare_fp64(golden_tmp, output_tmp, err_tmp);
            if (err_tmp == 1) begin
              $display("\033[1;31m[ERROR] iFFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
              $fwrite(fd, "iFFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
            end else begin
              $display("\033[1;32m[SUCCESS] iFFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
              $fwrite(fd, "iFFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
            end
          end
        end
        2 : begin
          for (i = 0; i < 1024; i = i + 1) begin
            if (out_NTT[i][15:0] != golden_NTT[i]) begin
              $display("\033[1;31m[ERROR] NTT mismatch idx=%d got 0x%4h exp 0x%4h\033[0m", i, out_NTT[i][15:0], golden_NTT[i]);
            end else begin
              $display("\033[1;32m[SUCCESS] NTT match idx=%d got 0x%4h exp 0x%4h\033[0m", i, out_NTT[i][15:0], golden_NTT[i]);
            end
          end
        end
        3 : begin
          for (i = 0; i < 1024; i = i + 1) begin
            if (out_iNTT[i][15:0] != golden_iNTT[i]) begin
              $display("\033[1;31m[ERROR] iNTT mismatch idx=%d got 0x%8h exp 0x%8h\033[0m", i, out_iNTT[i][15:0], golden_iNTT[i]);
            end else begin
              $display("\033[1;32m[SUCCESS] iNTT match idx=%d got 0x%8h exp 0x%8h\033[0m", i, out_iNTT[i][15:0], golden_iNTT[i]);
            end
          end
        end
      endcase
      
    end



    // // Check results
    // for (i = 0; i < 2048; i = i + 2) begin
    //   golden_tmp = {golden_FFT[i], golden_FFT[i+1]};
    //   output_tmp = {out_FFT[i], out_FFT[i+1]};
    //   compare_fp64(golden_tmp, output_tmp, err_tmp);
    //   if (err_tmp == 1) begin
    //     $display("\033[1;31m[ERROR] FFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
    //     $fwrite(fd, "FFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
    //   end else begin
    //     $display("\033[1;32m[SUCCESS] FFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
    //     $fwrite(fd, "FFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_FFT[i], out_FFT[i+1], golden_FFT[i], golden_FFT[i+1]);
    //   end
    // end

    $display("\n=== Valid Signal Statistics ===");
    $display("Total Input  Valid Count  = %0d", input_count);
    $display("Total Output Valid Count  = %0d", output_count);

    // for (i = 0; i < 2048; i = i + 2) begin
    //   golden_tmp = {golden_iFFT[i], golden_iFFT[i+1]};
    //   output_tmp = {out_iFFT[i], out_iFFT[i+1]};
    //   compare_fp64(golden_tmp, output_tmp, err_tmp);
    //   if (err_tmp == 1) begin
    //     $display("\033[1;31m[ERROR] iFFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
    //     $fwrite(fd, "iFFT mismatch idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
    //   end else begin
    //     $display("\033[1;32m[SUCCESS] iFFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\033[0m", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
    //     $fwrite(fd, "iFFT match idx=%d got:0x%8h_%8h exp:0x%8h_%8h\n", i/4, out_iFFT[i], out_iFFT[i+1], golden_iFFT[i], golden_iFFT[i+1]);
    //   end
    // end

    // for (i = 0; i < 1024; i = i + 1) begin
    //   if (out_NTT[i][15:0] != golden_NTT[i]) begin
    //     $display("\033[1;31m[ERROR] NTT mismatch idx=%d got 0x%4h exp 0x%4h\033[0m", i, out_NTT[i][15:0], golden_NTT[i]);
    //   end else begin
    //     $display("\033[1;32m[SUCCESS] NTT match idx=%d got 0x%4h exp 0x%4h\033[0m", i, out_NTT[i][15:0], golden_NTT[i]);
    //   end
    // end

    // for (i = 0; i < 1024; i = i + 1) begin
    //   if (out_iNTT[i][15:0] != golden_iNTT[i]) begin
    //     $display("\033[1;31m[ERROR] iNTT mismatch idx=%d got 0x%8h exp 0x%8h\033[0m", i, out_iNTT[i][15:0], golden_iNTT[i]);
    //   end else begin
    //     $display("\033[1;32m[SUCCESS] iNTT match idx=%d got 0x%8h exp 0x%8h\033[0m", i, out_iNTT[i][15:0], golden_iNTT[i]);
    //   end
    // end

    $display("Kernel %d PASS", k);
    $display("First test end");
    $fclose(fd);
    /*
    // test 2 starts
    fork
      test2_data_in;
      for (k = 0; k < 4; k = k + 1) begin
        sm_stream_meta(length, mode);
        sm_stream_out(length, mode);
      end
    join
    $display("Test2 pass!!");

    // test 3 starts
    fork
      test3_data_in;
      for (k = 0; k < 100; k = k + 1) begin
        sm_stream_meta(length, mode);
        sm_stream_out(length, mode);
      end
    join
    $display("Test3 pass!!");
    $finish;
  
  */
  //$finish;
  end
endmodule
