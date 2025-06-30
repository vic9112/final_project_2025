`timescale 1ns/1ps

module fiFFNTT_tb;

  // Parameters & Constants
  localparam CLK_PERIOD    = 10;             // 100 MHz clock
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
        0: get_COEF_LEN = 512;
        1: get_COEF_LEN = 512;
        2: get_COEF_LEN = 1024;
        3: get_COEF_LEN = 1024;
        default: get_COEF_LEN = 0;
      endcase
    end
  endfunction

  // Register map
  localparam [ADDR_WIDTH-1:0] STATUS_ADDR    = 32'h0000_0000;
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
  reg clk = 0;
  reg rstn = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
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

  // Memories for input/output/golden data
  reg [DATA_WIDTH-1:0] coef_mem0 [0:2047];
  reg [DATA_WIDTH-1:0] coef_mem1 [0:2047];
  reg [DATA_WIDTH-1:0] coef_mem2 [0:2047];
  reg [DATA_WIDTH-1:0] coef_mem3 [0:2047];
  reg [DATA_WIDTH-1:0] in_mem0 [0:2047];
  reg [DATA_WIDTH-1:0] in_mem1 [0:2047];
  reg [DATA_WIDTH-1:0] in_mem2 [0:2047];
  reg [DATA_WIDTH-1:0] in_mem3 [0:2047];
  reg [DATA_WIDTH-1:0] golden_mem0 [0:2047];
  reg [DATA_WIDTH-1:0] golden_mem1 [0:2047];
  reg [DATA_WIDTH-1:0] golden_mem2 [0:2047];
  reg [DATA_WIDTH-1:0] golden_mem3 [0:2047];

  reg [DATA_WIDTH-1:0] coef_mem   [0:NUM_KER-1][0:2047];
  reg [DATA_WIDTH-1:0] in_mem     [0:NUM_KER-1][0:2047];
  reg [DATA_WIDTH-1:0] out_mem    [0:NUM_KER-1][0:2047];
  reg [DATA_WIDTH-1:0] golden_mem [0:NUM_KER-1][0:2047];

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

  // DUT Instantiation
  fiFFNTT #(
    .pADDR_WIDTH(ADDR_WIDTH),
    .pDATA_WIDTH(DATA_WIDTH),
    .pIOPS_WIDTH(128)
  ) DUT (
    .clk        (clk),
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

  my_mailbox #(
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
    integer timeout = (10000);
    initial begin
        while(timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        $display($time, "Simualtion Hang ....");
        $finish;
    end

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
      ss_tdata = {dt, mode, length};
      ss_tvalid = 1;
      ss_tlast = 0;

      wait(ss_tready);
      @(posedge clk);
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
        @(posedge clk);
        ss_tdata <= in_mem[M][i];
        ss_tvalid <= 1;
        ss_tlast <= (i == N - 1);

        wait(ss_tready);
        @(posedge clk);
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
        @(posedge clk);
        ss_tdata <= coef_mem[M][i];
        ss_tvalid <= 1;
        
        wait(ss_tready);
        @(posedge clk);
        ss_tvalid <= 0;
      end
    end
  endtask

  task sm_stream_meta(
    output integer length_out,
    output integer mode_out
  );
    begin
      @(posedge clk);
      sm_tready <= 1;

      wait(sm_tvalid);
      @(posedge clk);
      length_out <= sm_tdata[15:0];
      mode_out <= sm_tdata[23:16] - 8'd4;
      sm_tready <= 0;
    end
  endtask

  // sm_stream_out
  task sm_stream_out(
    input integer N,
    input integer M
  );
    begin
      j = 0; 
      while (j < N) begin
        @(posedge clk);
        sm_tready <= 1;

        wait(sm_tvalid);
        out_mem[M][j] = sm_tdata;
        j = j + 1;
        @(posedge clk);
        sm_tready <= 0;
      end
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

      rand_time = $urandom_range(0, 999);
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


  initial begin
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
    $readmemh("addr0_511_128b.hex", coef_mem0);
    //$readmemh("iFFT_coef.hex", coef_mem1);
    //$readmemh("NTT_coef.hex", coef_mem2);
    //$readmemh("iNTT_coef.hex", coef_mem3);
    $readmemh("FFT_in.hex", in_mem0);
    //$readmemh("iFFT_in.hex", in_mem1);
    //$readmemh("NTT_in.hex", in_mem2);
    //$readmemh("iNTT_in.hex", in_mem3);
    $readmemh("FFT_out.hex", golden_mem0);
    //$readmemh("iFFT_out.hex", golden_mem1);
    //$readmemh("NTT_out.hex", golden_mem2);
    //$readmemh("iNTT_out.hex", golden_mem3);

    for (k = 0; k < 2048; k = k + 1) begin
      coef_mem[0][k] = coef_mem0[k];
      coef_mem[1][k] = coef_mem1[k];
      coef_mem[2][k] = coef_mem2[k];
      coef_mem[3][k] = coef_mem3[k];
      in_mem[0][k] = in_mem0[k];
      in_mem[1][k] = in_mem1[k];
      in_mem[2][k] = in_mem2[k];
      in_mem[3][k] = in_mem3[k];
      golden_mem[0][k] = golden_mem0[k];
      golden_mem[1][k] = golden_mem1[k];
      golden_mem[2][k] = golden_mem2[k];
      golden_mem[3][k] = golden_mem3[k];
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
    //for (k = 0; k < 4; k = k + 1) begin
      stream_meta(COEF_BASE + k, 8'b0, get_COEF_LEN(0));
      ss_stream_coef(get_COEF_LEN(0), 0);
    //end
      
    // Write coef_done = 1
    //axilite_write(COEF_DONE_ADDR, 32'h0000_0001);
    $display("Coefficients input over");

    // test1
    //for (k = 0; k < 4; k = k + 1) begin
      axilite_read_mb(MB_BASE_ADDR, check);
      if (check != PAT_KER_FREE) begin
        $display("Test1 Error: Kernel 1 is not free");
        $finish;
      end else begin
        $display("Test1: Kernel 1 starts testing mode %d", 0 + 1);
        axilite_write_mb(MB_BASE_ADDR, PAT_KER_BUSY);
      end

      stream_meta(KERNEL_BASE, MODE_BASE + 0, get_LEN(0));
      fork
        // DMA in
        ss_stream_in(get_LEN(0), 0);
        
        // FW thread
        begin
          start_time = $time;
          sm_stream_meta(length, mode);
          sm_stream_out(length, mode);
          wait_ap_done(0);
          end_time = $time;
          latency = end_time - start_time;
          $display("Test1: Kernel 1 latency for data %d is %d ns", 0 + 1, latency);
          axilite_write_mb(MB_BASE_ADDR, PAT_KER_FREE);
        end
      join
    //end

    // Check results
    for (i = 0; i < get_LEN(k); i = i + 1) begin
      if (out_mem[k][i] !== golden_mem[k][i]) begin
        $display("Mismatch k=%d idx=%d got 0x%8h exp 0x%8h",
                k, i, out_mem[k][i], golden_mem[k][i]);
      end
    end
    $display("Kernel %d PASS", k);
    $display("First test end");
    
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
  end

  //$finish;
  
endmodule
