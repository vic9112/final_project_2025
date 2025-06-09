module mailbox #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter MB_COUNT = 4
)(
  input  wire                   ACLK,
  input  wire                   ARESETN,

  // AXI-Lite write address channel
  input  wire [ADDR_WIDTH-1:0]  awaddr,
  input  wire                   awvalid,
  output reg                    awready,

  // AXI-Lite write data channel
  input  wire [DATA_WIDTH-1:0]   wdata,
  input  wire                    wvalid,
  output reg                     wready,

  // AXI-Lite read address channel
  input  wire [ADDR_WIDTH-1:0]  araddr,
  input  wire                   arvalid,
  output reg                    arready,

  // AXI-Lite read data channel
  output reg [DATA_WIDTH-1:0]   rdata,
  output reg                    rvalid,
  input  wire                   rready,
);

  localparam BASE_ADDR = 32'h3000_2000;
  // Internal mailbox registers
  reg [DATA_WIDTH-1:0] mb_reg [0:MB_COUNT-1];
  reg [ADDR_WIDTH-1:0] addr_in, addr_out;
  reg read_req;

  // Default resets and handshakes
  integer i;

  always @(posedge ACLK) begin
    if (!ARESETN) begin
      awready <= 1'b0;
      wready <= 1'b0;
      arready <= 1'b0;
      read_req <= 1'b0;
      rvalid <= 1'b0;
      addr_in <= {ADDR_WIDTH{1'b0}};
      addr_out <= {ADDR_WIDTH{1'b0}};
    end else begin
      awready <= (awvalid && ~awready) ? 1 : 0;
      wready <= (awready == 1 || (wready && ~wvalid));
      arready <= (arvalid && ~arready) ? 1 : 0;
      read_req <= (arready == 1) ? 1 : 0; 
      rvalid <= (read_req == 1 || (rvalid && ~rready));
      addr_in <= (awvalid && awready) ? awaddr : addr_in;
      addr_out <= (arvalid && arready) ? araddr : addr_out;
    end
  end


  always @(posedge ACLK) begin
    if (!ARESETN) begin
      mb_reg[0] <= {DATA_WIDTH{1'b0}};
      mb_reg[1] <= {DATA_WIDTH{1'b0}};
      mb_reg[2] <= {DATA_WIDTH{1'b0}};
      mb_reg[3] <= {DATA_WIDTH{1'b0}};
    end else begin
      if (wvalid && wready) begin
        case (addr_in - BASE_ADDR)
          32'd0: mb_reg[0] <= WDATA;
          32'd4: mb_reg[1] <= WDATA;
          32'd8: mb_reg[2] <= WDATA;
          32'd12: mb_reg[3] <= WDATA;
          default: begin
            mb_reg[0] <= mb_reg[0];
            mb_reg[1] <= mb_reg[1];
            mb_reg[2] <= mb_reg[2];
            mb_reg[3] <= mb_reg[3];
          end
        endcase
      end else begin
        mb_reg[0] <= mb_reg[0];
        mb_reg[1] <= mb_reg[1];
        mb_reg[2] <= mb_reg[2];
        mb_reg[3] <= mb_reg[3];
      end
    end
  end

  always @* begin
    if (rvalid == 1 || read_req == 1) begin
      case (addr_out - BASE_ADDR)
        32'd0: rdata = mb_reg[0] ;
        32'd4: rdata = mb_reg[1];
        32'd8: rdata = mb_reg[2];
        32'd12: rdata = mb_reg[3];
        default: rdata = {DATA_WIDTH{1'b0}};
      endcase
    end else begin
      rdata = {DATA_WIDTH{1'b0}};
    end
  end

endmodule
