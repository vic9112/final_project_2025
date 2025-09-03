// forward / inverse FFT & NTT
module fiFFNTT 
#(  
    parameter pADDR_WIDTH = 32,
    parameter pDATA_WIDTH = 32,
    parameter pIOPS_WIDTH = 128
)
(
    input   wire                     clk,
    input   wire                     clk_2x,
    input   wire                     rstn,

    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,

    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast
);
    //========================== Declaration ==========================
    // =============== axi-lite =============== //
    wire [31:0] ap_ctrl;
    // axi write seems to be useless in the current plan
    reg awready_tmp;
    reg awready_next;
    reg wready_tmp;
    reg wready_next;
    reg [(pADDR_WIDTH-1):0] awaddr_tmp;
    reg [(pADDR_WIDTH-1):0] awaddr_next;

    // axi read is used to read the ap_state of the kenel
    // coef_done can be determined by the metadata -> dont need axi write for now
    reg arready_tmp;
    reg arready_next;
    reg rvalid_tmp;
    reg rvalid_next;
    reg [(pADDR_WIDTH-1):0] araddr_tmp;
    reg [(pADDR_WIDTH-1):0] araddr_next;
    reg [(pDATA_WIDTH-1):0] rdata_tmp;

    // telling IOP that done is read
    reg read_ap_stat_tmp;
    reg read_ap_stat_next;
    wire ap_read;
    reg  [31:0] coef_ctrl_next;
    reg  [31:0] coef_ctrl;

    // local parameter
    localparam PULL_DN = 0; // pull down
    localparam PULL_UP = 1; 
    localparam AP_STAT = 32'h3000_0000; // 0x00
    localparam COEF_STAT = 32'h3000_0010; // 0x10
    // =============== IOP =============== //
    wire clk_k1, clk_k2, clk_k3, clk_k4;
    wire [7:0] k1_mode;    
    wire decode1;          
    wire k1_sw_lst;         
  
    wire [7:0] k2_mode;
    wire decode2;
    wire k2_sw_lst;
    
    wire [7:0] k3_mode;
    wire decode3;
    wire k3_sw_lst;
    
    wire [7:0] k4_mode;
    wire decode4;
    wire k4_sw_lst;

    wire rst_mode;
    
    // =============== Kernel interface =============== //
    // Kernel 1
    wire k1_load_vld;
    wire k1_load_rdy;
    wire [(pIOPS_WIDTH-1):0] k1_load_dat;
    wire k1_store_vld;
    wire k1_store_rdy;
    wire [(pIOPS_WIDTH-1):0] k1_store_dat;
    
    // Kernel 2
    wire k2_load_vld;
    wire k2_load_rdy;
    wire [(pIOPS_WIDTH-1):0] k2_load_dat;
    wire k2_store_vld;
    wire k2_store_rdy;
    wire [(pIOPS_WIDTH-1):0] k2_store_dat;
    
    // Kernel 3
    wire k3_load_vld;
    wire k3_load_rdy;
    wire [(pIOPS_WIDTH-1):0] k3_load_dat;
    wire k3_store_vld;
    wire k3_store_rdy;
    wire [(pIOPS_WIDTH-1):0] k3_store_dat;
    
    // Kernel 4
    wire k4_load_vld;
    wire k4_load_rdy;
    wire [(pIOPS_WIDTH-1):0] k4_load_dat;
    wire k4_store_vld;
    wire k4_store_rdy;
    wire [(pIOPS_WIDTH-1):0] k4_store_dat;

    // Coefficient port signals
    wire [4:0] k1_coef_vld, k2_coef_vld, k3_coef_vld, k4_coef_vld;
    wire [4:0] k1_coef_rdy, k2_coef_rdy, k3_coef_rdy, k4_coef_rdy;
    wire [pIOPS_WIDTH-1:0] k1_coef_dat, k2_coef_dat, k3_coef_dat, k4_coef_dat;

    // BPE activation control
    wire [4:0]  k1_bpe_act, k2_bpe_act, k3_bpe_act, k4_bpe_act;
    // double-speed clock
    wire clk_2;

    //========================== Function ==========================
    // =============== axi-lite =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        awready_tmp <= PULL_DN;
        wready_tmp <= PULL_DN;
        arready_tmp <= PULL_DN;
        rvalid_tmp <= PULL_DN;
        araddr_tmp <= PULL_DN;
        awaddr_tmp <= PULL_DN;
        read_ap_stat_tmp <= PULL_DN;
        coef_ctrl <= PULL_DN;
      end else begin
        awready_tmp <= awready_next;
        wready_tmp <= wready_next;
        arready_tmp <= arready_next;
        rvalid_tmp <= rvalid_next;
        araddr_tmp <= araddr_next;
        awaddr_tmp <= awaddr_next;
        read_ap_stat_tmp <= read_ap_stat_next;
        coef_ctrl <= coef_ctrl_next;
      end
    end

    always @(*) begin
      // axi write (used for coef_done)
      if (awvalid && !awready) begin
        awready_next = PULL_UP;
      end else begin
        awready_next = PULL_DN;
      end

      if (wvalid && !wready) begin
        wready_next = PULL_UP;
      end else begin
        wready_next = PULL_DN;
      end

      if (awvalid && awready) begin
        awaddr_next = awaddr;
      end else begin
        awaddr_next = awaddr_tmp;
      end

      // axi read - arready
      if (arvalid && !arready) begin
        arready_next = PULL_UP;
      end else begin
        arready_next = PULL_DN;
      end
      // axi read - rvalid
      if (arready) begin
        rvalid_next = PULL_UP;
      end else if (rready) begin
        rvalid_next = PULL_DN;
      end else begin
        rvalid_next = rvalid_tmp;
      end
      // axi read - araddr_buffer
      if (arvalid) begin
        araddr_next = araddr;
      end else if (rready && rvalid) begin
        araddr_next = PULL_DN;
      end else begin
        araddr_next = araddr_tmp;
      end
      // determine rdata
      if (araddr_tmp == AP_STAT) begin
        rdata_tmp = ap_ctrl;
      end else if (araddr_tmp == COEF_STAT) begin
        rdata_tmp = coef_ctrl;
      end else begin
        rdata_tmp = PULL_DN;
      end
      // read_ap_stat
      if (araddr_tmp == AP_STAT && rready && rvalid && !read_ap_stat_tmp) begin
        read_ap_stat_next = PULL_UP;
      end else begin
        read_ap_stat_next = PULL_DN;
      end
    end

    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        coef_ctrl <= 0;
      end else begin
        coef_ctrl <= ((awaddr_tmp == COEF_STAT) && wready && wvalid) ? wdata : coef_ctrl;
      end
    end

    // assign to port wire
    assign awready = awready_tmp;
    assign wready = wready_tmp;
    assign arready = arready_tmp;
    assign rvalid = rvalid_tmp;
    assign rdata = rdata_tmp;
    assign ap_read = read_ap_stat_tmp;

    /*================================================================================================
    #                                            IOP                                                 #
    ================================================================================================*/
    stage_top #(
      .pDATA_WIDTH (pIOPS_WIDTH), 
      .pSS_WIDTH (pDATA_WIDTH)
    ) IOP (
      .clk         (clk_2x),
      .clk_s       (clk),
      .rstn        (rstn),
      
      //.in1_sw      (     ),
      .ap_ctrl     (ap_ctrl),
      // .coef_ctrl   (coef_ctrl),
      .ap_read     (ap_read),

      .ss_vld      (ss_tvalid),
      .ss_dat      (ss_tdata),
      .ss_lst      (ss_tlast),
      .ss_rdy      (ss_tready),
      
      .sm_rdy      (sm_tready),
      .sm_vld      (sm_tvalid),
      .sm_dat      (sm_tdata),
      .sm_lst      (sm_tlast),
      .sm_mode     (sm_mode)
    );

endmodule