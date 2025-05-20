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

    
    /*================================================================================================
    #                                     AXI Configuration                                          #
    ================================================================================================*/
    reg ap_done, ap_idle; // 0x00: Kernel status (configuration address: 0x3000_0000) read by middleware
    reg coef_done;        // 0x10: Indicate coefficient is initialized

    /*================================================================================================
    #                                            IOP                                                 #
    ================================================================================================*/
    stage_top IOP (
      .clk          (clk),
      .rstn         (rstn),

      .ss_tvalid    (ss_vld),
      .ss_tdata     (ss_dat),
      .ss_tlast     (ss_lst),
      .ss_tready    (ss_rdy),
      .sm_tready    (sm_rdy),
      .sm_tvalid    (sm_vld),
      .sm_tdata     (sm_dat),
      .sm_tlast     (sm_lst),

      .k1_load_vld  (k1_ld_vld),
      .k1_load_rdy  (k1_ld_rdy),
      .k1_load_dat  (k1_ld_dat),
      .k1_store_vld (k1_sw_vld),
      .k1_store_rdy (k1_sw_rdy),
      .k1_store_dat (k1_sw_dat),

      .k2_load_vld  (k2_ld_vld),
      .k2_load_rdy  (k2_ld_rdy),
      .k2_load_dat  (k2_ld_dat),
      .k2_store_vld (k2_sw_vld),
      .k2_store_rdy (k2_sw_rdy),
      .k2_store_dat (k2_sw_dat),
      
      .k3_load_vld  (k3_ld_vld),
      .k3_load_rdy  (k3_ld_rdy),
      .k3_load_dat  (k3_ld_dat),
      .k3_store_vld (k3_sw_vld),
      .k3_store_rdy (k3_sw_rdy),
      .k3_store_dat (k3_sw_dat),
      
      .k4_load_vld  (k4_ld_vld),
      .k4_load_rdy  (k4_ld_rdy),
      .k4_load_dat  (k4_ld_dat),
      .k4_store_vld (k4_sw_vld),
      .k4_store_rdy (k4_sw_rdy),
      .k4_store_dat (k4_sw_dat)
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

