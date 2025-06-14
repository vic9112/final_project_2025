`timescale 1ns/1ps

module fiFFNTT_tb;

  // Parameters & Constants
  localparam CLK_PERIOD    = 10;             // 100 MHz clock
  localparam ADDR_WIDTH    = 32;
  localparam DATA_WIDTH    = 32;
  localparam NUM_KER       = 4;

  // Stream lengths


  // File names
  /*
  string coeffile [NUM_KER] = {"FFT_coef.hex", "iFFT_coef.hex", "NTT_coef.hex", "iNTT_coef.hex"};
  string infile   [NUM_KER] = {"FFT_in.hex", "iFFT_in.hex", "NTT_in.hex", "iNTT_in.hex"};
  string goldfile [NUM_KER] = {"FFT_out.hex", "iFFT_out.hex", "NTT_out.hex", "iNTT_out.hex"};
  */

  
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
  reg clk = 0;
  reg rstn = 0;
  always #(CLK_PERIOD/2) clk = ~clk;
  initial begin 
    rstn = 0;
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
  reg [63:0] coef_mem [0:64];
  reg [DATA_WIDTH-1:0] stat;
  integer idx;
  integer i, j, k;

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

  // AXI-Lite write task
  task axilite_write(
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data
  );
    begin
      // Address channel
      awaddr   = addr;
      awvalid  = 1;
      arvalid  = 0;    
      rready  = 0;
      wait (awready);
      @(posedge clk);
      awvalid  = 0;

      wdata = data;
      wvalid = 1;
      wait(wready);
      @(posedge clk);
      wvalid = 0;

      @(posedge clk);
    end
  endtask

  task axilite_write_mb(
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data
  );
    begin
      // Address channel
      awaddr_mb   = addr;
      awvalid_mb  = 1;
      arvalid_mb  = 0;    
      rready_mb  = 0;
      wait(awready_mb);
      @(posedge clk);
      awvalid_mb = 0;

      wdata_mb = data;
      wvalid_mb = 1;
      wait(wready_mb);
      @(posedge clk);
      wvalid_mb = 0;

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
      wvalid  = 0;

      wait(arready);
      @(posedge clk); 
      arvalid = 0;
      rready = 1;

      wait(rvalid);
      data = rdata;
      @(posedge clk); 
      rready = 0;
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
      arvalid_mb = 0;
      rready_mb = 1;

      wait(rvalid_mb);
      data = rdata_mb;
      @(posedge clk); 
      rready_mb = 0;
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
    end
  endtask


  // ss_stream_in: send N words over ss_t*
  task ss_stream_in_coeff(
    input integer N
  );
    begin
      for (i = 0; i < N; i = i + 1) begin
        for (j = 0; j < 2; j = j + 1) begin
            @(posedge clk);
            if (j == 0) begin
              ss_tdata = coef_mem[i][31:0];
            end else begin
              ss_tdata = coef_mem[i][63:32];
            end
            ss_tvalid = 1;
            ss_tlast  = (i == N - 1);
    
            wait(ss_tready);
            ss_tlast  = 0;
        end
      end
    end
  endtask

  // Memories for input/output/golden data

  //
  reg [DATA_WIDTH-1:0] in_mem     [0:NUM_KER-1][0:2048];
  reg [DATA_WIDTH-1:0] out_mem    [0:NUM_KER-1][0:2048];
  reg [DATA_WIDTH-1:0] golden_mem [0:NUM_KER-1][0:2048];


  // Main test sequence
  integer start_time, end_time, latency;
  reg [DATA_WIDTH-1:0] check;
  
  integer timeout = (100000);
  initial begin
      while(timeout > 0) begin
          @(posedge clk);
          timeout = timeout - 1;
      end
      $display($time, "Simualtion Hang ....");
      $finish;
  end

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
    ss_tdata = 0;
    wait (rstn); 
    #(CLK_PERIOD / 2);
    // coef in

    $readmemh("fft_16pt_coef.hex", coef_mem);
    stream_meta(COEF_BASE, 8'b0, 15);
    ss_stream_in_coeff(32);

    @(posedge clk);
    stream_meta(KERNEL_BASE, 8'b0, 15);
    ss_stream_in_coeff(32);

  end

endmodule
