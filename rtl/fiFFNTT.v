// forward / inverse FFT & NTT
module fiFFNTT 
#(  
    parameter pADDR_WIDTH = 32,
    parameter pDATA_WIDTH = 32,
    parameter pIOPS_WIDTH = 128
)
(
    input   wire                     clk,
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
    wire [31:0] coef_ctrl;
    // axi write seems to be useless in the current plan
    reg awready_tmp;
    reg awready_next;
    reg wready_tmp;
    reg wready_next;

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

    // local parameter
    localparam PULL_DN = 0; // pull down
    localparam PULL_UP = 1; 
    localparam AP_STAT = 32'h00; // 0x00
    localparam COEF_STAT = 32'h10; // 0x10

    //========================== Function ==========================
    // =============== axi-lite =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        awready_tmp <= PULL_DN;
        wready_tmp <= PULL_DN;
        arready_tmp <= PULL_DN;
        rvalid <= PULL_DN;
        araddr_tmp <= PULL_DN;
        read_ap_stat_tmp <= PULL_DN;
      end else begin
        awready_tmp <= awready_next;
        wready_tmp <= wready_next;
        arready_tmp <= arready_next;
        rvalid <= rvalid_next;
        araddr_tmp <= araddr_next;
        read_ap_stat_tmp <= read_ap_stat_next;
      end
    end

    always @(*) begin
      // axi write (not used for now)
      if (awvalid && wvalid && !wready) begin
        awready_next = PULL_UP;
        wready_next = PULL_UP;
      end else begin
        awready_next = PULL_DN;
        wready_next = PULL_DN;
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
    stage_top IOP (
      .clk          (clk),
      .rstn         (rstn),
      
      .in1_sw       (     ),
      .ap_crtl      (ap_crtl),
      .coef_crtl    (coef_crtl),
      .ap_read      (ap_read),

      .ss_vld       (ss_tvalid),
      .ss_dat       (ss_tdata),
      .ss_lst       (ss_tlast),
      .ss_rdy       (ss_tready),
      
      .sm_rdy       (sm_tready),
      .sm_vld       (sm_tvalid),
      .sm_dat       (sm_tdata),
      .sm_lst       (sm_tlast),

      .k1_ld_vld    (k1_load_vld),
      .k1_ld_rdy    (k1_load_rdy),
      .k1_ld_dat    (k1_load_dat),
      .k1_sw_vld    (k1_store_vld),
      .k1_sw_rdy    (k1_store_rdy),
      .k1_sw_dat    (k1_store_dat),

      .k2_ld_vld    (k2_load_vld),
      .k2_ld_rdy    (k2_load_rdy),
      .k2_ld_dat    (k2_load_dat),
      .k2_sw_vld    (k2_store_vld),
      .k2_sw_rdy    (k2_store_rdy),
      .k2_sw_dat    (k2_store_dat),
      
      .k3_ld_vld    (k3_load_vld),
      .k3_ld_rdy    (k3_load_rdy),
      .k3_ld_dat    (k3_load_dat),
      .k3_sw_vld    (k3_store_vld),
      .k3_sw_rdy    (k3_store_rdy),
      .k3_sw_dat    (k3_store_dat),
      
      .k4_ld_vld    (k4_load_vld),
      .k4_ld_rdy    (k4_load_rdy),
      .k4_ld_dat    (k4_load_dat),
      .k4_sw_vld    (k4_store_vld),
      .k4_sw_rdy    (k4_store_rdy),
      .k4_sw_dat    (k4_store_dat)
    );


    /*================================================================================================
    #                                          Kernels                                               #
    ================================================================================================*/
    kernel K1 (
      .ld_vld  (k1_ld_vld),
      .ld_rdy  (k1_ld_rdy),
      .ld_dat  (k1_ld_dat),
      .sw_vld  (k1_sw_vld),
      .sw_rdy  (k1_sw_rdy),
      .sw_dat  (k1_sw_dat)
    );

    kernel K2 (
      .ld_vld  (k2_ld_vld),
      .ld_rdy  (k2_ld_rdy),
      .ld_dat  (k2_ld_dat),
      .sw_vld  (k2_sw_vld),
      .sw_rdy  (k2_sw_rdy),
      .sw_dat  (k2_sw_dat)
    );

    kernel K3 (
      .ld_vld  (k3_ld_vld),
      .ld_rdy  (k3_ld_rdy),
      .ld_dat  (k3_ld_dat),
      .sw_vld  (k3_sw_vld),
      .sw_rdy  (k3_sw_rdy),
      .sw_dat  (k3_sw_dat)
    );

    kernel K4 (
      .ld_vld  (k4_ld_vld),
      .ld_rdy  (k4_ld_rdy),
      .ld_dat  (k4_ld_dat),
      .sw_vld  (k4_sw_vld),
      .sw_rdy  (k4_sw_rdy),
      .sw_dat  (k4_sw_dat)
    );

endmodule

