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
        read_ap_stat_tmp <= PULL_DN;
      end else begin
        awready_tmp <= awready_next;
        wready_tmp <= wready_next;
        arready_tmp <= arready_next;
        rvalid_tmp <= rvalid_next;
        araddr_tmp <= araddr_next;
        read_ap_stat_tmp <= read_ap_stat_next;
      end
    end

    always @(*) begin
      // axi write (used for coef_done)
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

      // if (araddr_tmp == COEF_STAT && wready && wvalid && !coef_ctrl_tmp) begin
      //   coef_ctrl_next = PULL_UP; //wdata
      // end else begin
      //   coef_ctrl_next = coef_ctrl_tmp;
      // end
    end

    // assign to port wire
    assign awready = awready_tmp;
    assign wready = wready_tmp;
    assign arready = arready_tmp;
    assign rvalid = rvalid_tmp;
    assign rdata = rdata_tmp;
    assign ap_read = read_ap_stat_tmp;

    /*================================================================================================
    #                                            Data Ram                                            #
    ================================================================================================*/
    // declaration
    wire        data_ram_en;
    wire [ 3:0] data_ram_we;
    wire [31:0] data_ram_do;
    reg  [12:0] data_ram_aout;
    reg  [12:0] data_ram_ain;
    wire [12:0] data_ram_a;
    reg  [15:0] data_length;
    reg  [ 7:0] kernal_mode;
    reg  [11:0] meta_counter;
    reg         data_ram_state;
    reg  [31:0] meta_data;
    wire [12:0] bit_reverse_a512;
    wire [12:0] bit_reverse_a1024;
    wire [12:0] normal_order_a;
    wire [10:0] address_counter;
    reg         ss_tvalid2_reg;
    wire        ss_tvalid2;
    wire        ss_tready2;
    wire [31:0] ss_tdata2;
    parameter STREAM_IN  = 0;
    parameter STREAM_OUT = 1;
    // implementation

    //////////////////////
    // decode meta data //
    //////////////////////

    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        data_length <= 16'hFFFF;
        kernal_mode <= 0;
      end else begin
          data_length <= (ss_tready && ss_tvalid && meta_counter == 12'h0) ? ss_tdata[15:0]  : data_length;
          kernal_mode <= (ss_tready && ss_tvalid && meta_counter == 12'h0) ? ss_tdata[23:16] : kernal_mode;
          meta_data   <= (ss_tready && ss_tvalid && meta_counter == 12'h0) ? ss_tdata        : meta_data;
      end
    end

    //////////////////
    // meta counter //
    //////////////////
    wire counter_en;
    assign counter_en = ss_tready && ss_tvalid && data_ram_state == STREAM_IN || ss_tready2 && ss_tvalid2 && data_ram_state == STREAM_OUT;
    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        meta_counter <= 12'h0;
      end else begin
          if (counter_en) begin
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


    ///////////////////
    // state control //
    ///////////////////
    wire state_trans;
    assign state_trans = ss_tready && ss_tvalid && meta_counter == data_length || ss_tready2 && ss_tvalid2 && meta_counter == data_length;
    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        data_ram_state <= STREAM_IN;
      end else begin
        data_ram_state <= (state_trans) ? ~data_ram_state : data_ram_state;
      end
    end

    ///////////////////////////////////
    // counter and address generator //
    ///////////////////////////////////
    //normal order address
    assign address_counter = meta_counter - 1;
    // bit reverse order address
    assign normal_order_a = {address_counter, 2'b00};
    
    //data_ram_ain

    reg [8:0] FFT_OFFSET;
    wire FFT_OFFSET_ADD;
    reg [3:0] pack_counter_fft;
    wire pack_counter_en_fft;

    assign FFT_OFFSET_ADD = ss_tready && ss_tvalid && data_ram_state == STREAM_IN && pack_counter_fft == 3;
    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        FFT_OFFSET <= 0;
      end else begin 
        FFT_OFFSET <= (meta_counter == 0) ? 0 : (FFT_OFFSET_ADD) ? (FFT_OFFSET == 511) ? 0 : FFT_OFFSET + 1 : FFT_OFFSET;
      end
    end

    assign pack_counter_en_fft = ss_tready && ss_tvalid && data_ram_state == STREAM_IN && kernal_mode[2:1] == 2'b10;
    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        pack_counter_fft <= 4'h0;
      end else begin 
        pack_counter_fft <= (pack_counter_en_fft) ? (meta_counter == 0) ? 0 : (pack_counter_fft == 3) ? 0 : pack_counter_fft + 1 : pack_counter_fft;
      end
    end

    assign bit_reverse_a512 = {pack_counter_fft, 2'b00}+ 
                            {FFT_OFFSET[0], FFT_OFFSET[1], FFT_OFFSET[2], FFT_OFFSET[3], FFT_OFFSET[4], 
                                    FFT_OFFSET[5], FFT_OFFSET[6], FFT_OFFSET[7], FFT_OFFSET[8], 4'b0000};
    assign bit_reverse_a1024 = {1'b0, address_counter[0], address_counter[1], address_counter[2], address_counter[3],
                                address_counter[4], address_counter[5], address_counter[6], address_counter[7], address_counter[8], address_counter[9], 2'b00};

    reg [9:0] NTT_OFFSET1;
    wire      NTT_OFFSET1_ADD;
    reg       NTT_OFFSET2;
    wire      NTT_OFFSET2_ADD;
    reg       NTT_OFFSET3;
    wire      NTT_OFFSET3_ADD;
    reg [3:0] pack_counter_ntt;
    wire      pack_counter_en_ntt;

    assign pack_counter_en_ntt = ss_tready2 && ss_tvalid2 && data_ram_state == STREAM_OUT && kernal_mode[2:1] == 2'b11;
    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        pack_counter_ntt <= 4'h0;
      end else begin 
        pack_counter_ntt <= (meta_counter == 0) ? 0 : (pack_counter_en_ntt) ? (pack_counter_ntt == 7) ? 0 : pack_counter_ntt + 1 : pack_counter_ntt;
      end
    end

    assign NTT_OFFSET1_ADD = ss_tready2 && ss_tvalid2 && data_ram_state == STREAM_OUT && pack_counter_ntt == 7;
    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        NTT_OFFSET1 <= 0;
      end else begin 
        NTT_OFFSET1 <= (meta_counter == 0) ? 0 : (NTT_OFFSET1_ADD) ? (NTT_OFFSET1 == 511) ? 0 : NTT_OFFSET1 + 4 : NTT_OFFSET1;
      end
    end

    assign NTT_OFFSET2_ADD = ss_tready2 && ss_tvalid2 && data_ram_state == STREAM_OUT && pack_counter_ntt == 7;
    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        NTT_OFFSET2 <= 0;
      end else begin 
        NTT_OFFSET2 <= (meta_counter == 0) ? 0 : (NTT_OFFSET2_ADD) ? ~ NTT_OFFSET2 : NTT_OFFSET2;
      end
    end

    wire [9:0] NTT_OFFSET_MUX;
    wire [12:0] NTT_COEF_AOUT;
    assign NTT_OFFSET_MUX = (NTT_OFFSET2) ? 512 + NTT_OFFSET1 - 4 + pack_counter_ntt : NTT_OFFSET1 + pack_counter_ntt;
    assign NTT_COEF_AOUT  = pack_counter_ntt * 4 + {NTT_OFFSET1[0], NTT_OFFSET1[1], NTT_OFFSET1[2], NTT_OFFSET1[3], NTT_OFFSET1[4], NTT_OFFSET1[5], NTT_OFFSET1[6], NTT_OFFSET1[7],NTT_OFFSET1[8], 4'b0000 };

    wire coef_mode;
    assign coef_mode = kernal_mode[7:4] == 4'h1;

    always @* begin
      if (coef_mode) begin
        if (data_length == 1024) begin
          data_ram_ain = normal_order_a;
          data_ram_aout = normal_order_a;
        end else begin
          data_ram_ain =  normal_order_a;
          data_ram_aout =  NTT_COEF_AOUT;
        end
      end else if (kernal_mode[0]) begin
        if (data_length == 2048) begin
          data_ram_ain = bit_reverse_a512;
          data_ram_aout = normal_order_a;
        end else begin
          data_ram_ain =  bit_reverse_a1024;
          data_ram_aout =  {1'b0, NTT_OFFSET_MUX, 2'b0};
        end
      end else begin
        if (data_length == 2048) begin
          data_ram_ain = normal_order_a;
          data_ram_aout =  normal_order_a;
        end else begin
          data_ram_ain = normal_order_a;
          data_ram_aout = {1'b0, NTT_OFFSET_MUX, 2'b0};
        end
      end
    end 



    //data_ram_aout
    assign data_ram_a = (data_ram_state) ? data_ram_aout : data_ram_ain;
    assign data_ram_we = {4{(ss_tvalid && ss_tready)&& !ss_tvalid2}};
    assign data_ram_en = ss_tready || ss_tready2;

    bram2048x32 Data_Ram (
      .CLK  (clk),
      .WE   (data_ram_we),
      .EN   (data_ram_en),
      .Di   (ss_tdata),
      .Do   (data_ram_do),
      .A    (data_ram_a)
    );

    assign ss_tready = !data_ram_state;
    /////////////////////////////////
    // axi_stream from here to IOP //
    /////////////////////////////////
    assign ss_tdata2 = meta_counter == 1 ? meta_data : data_ram_do;

    always @ (posedge clk or negedge rstn) begin
      if (!rstn) begin
        ss_tvalid2_reg <= 0;
      end else begin
        ss_tvalid2_reg <= data_ram_state;
      end
    end
    assign ss_tvalid2 = ss_tvalid2_reg;

    wire ss_vld;
    assign ss_vld = ss_tvalid2 && !(meta_counter == 0 && data_ram_state == 1);

    /*================================================================================================
    #                                            IOP                                                 #
    ================================================================================================*/
    stage_top #(
      .pDATA_WIDTH (pIOPS_WIDTH), 
      .pSS_WIDTH (pDATA_WIDTH)
    ) IOP (
      .clk         (clk),
      .rstn        (rstn),
      
      //.in1_sw      (     ),
      .ap_ctrl     (ap_ctrl),
      .coef_ctrl   (coef_ctrl),
      .ap_read     (ap_read),

      .ss_vld      (ss_vld),
      .ss_dat      (ss_tdata2),
      .ss_lst      (ss_tlast),
      .ss_rdy      (ss_tready2),
      
      .sm_rdy      (sm_tready),
      .sm_vld      (sm_tvalid),
      .sm_dat      (sm_tdata),
      .sm_lst      (sm_tlast),
      //---------- kernel 1  ----------//
      .clk1        (clk_k1),
      .rstn1       (rstn),

      .k1_ld_vld   (k1_load_vld),
      .k1_ld_rdy   (k1_load_rdy),
      .k1_ld_dat   (k1_load_dat),
      .k1_sw_vld   (k1_store_vld),
      .k1_sw_rdy   (k1_store_rdy),
      .k1_sw_dat   (k1_store_dat),
      
      .k1_coef_vld (k1_coef_vld),
      .k1_coef_rdy (k1_coef_rdy),
      .k1_coef_dat (k1_coef_dat),
      .k1_bpe_act  (k1_bpe_act),
    
      .k1_mode     (k1_mode),
      .decode1     (decode1),
      .k1_sw_lst   (k1_sw_lst),

      //---------- kernel 2  ----------//
      .clk2        (clk_k2),
      .rstn2       (rstn),

      .k2_ld_vld   (k2_load_vld),
      .k2_ld_rdy   (k2_load_rdy),
      .k2_ld_dat   (k2_load_dat),
      .k2_sw_vld   (k2_store_vld),
      .k2_sw_rdy   (k2_store_rdy),
      .k2_sw_dat   (k2_store_dat),

      .k2_coef_vld (k2_coef_vld),
      .k2_coef_rdy (k2_coef_rdy),
      .k2_coef_dat (k2_coef_dat),
      .k2_bpe_act  (k2_bpe_act),
      
      .k2_mode     (k2_mode),
      .decode2     (decode2),
      .k2_sw_lst   (k2_sw_lst),

      //---------- kernel 3  ----------//
      .clk3        (clk_k3),
      .rstn3       (rstn),

      .k3_ld_vld   (k3_load_vld),
      .k3_ld_rdy   (k3_load_rdy),
      .k3_ld_dat   (k3_load_dat),
      .k3_sw_vld   (k3_store_vld),
      .k3_sw_rdy   (k3_store_rdy),
      .k3_sw_dat   (k3_store_dat),

      .k3_coef_vld (k3_coef_vld),
      .k3_coef_rdy (k3_coef_rdy),
      .k3_coef_dat (k3_coef_dat),
      .k3_bpe_act  (k3_bpe_act),
      
      .k3_mode     (k3_mode),
      .decode3     (decode3),
      .k3_sw_lst   (k3_sw_lst),

      //---------- kernel 4  ----------//
      .clk4        (clk_k4),
      .rstn4       (rstn),

      .k4_ld_vld   (k4_load_vld),
      .k4_ld_rdy   (k4_load_rdy),
      .k4_ld_dat   (k4_load_dat),
      .k4_sw_vld   (k4_store_vld),
      .k4_sw_rdy   (k4_store_rdy),
      .k4_sw_dat   (k4_store_dat),
      
      .k4_coef_vld (k4_coef_vld),
      .k4_coef_rdy (k4_coef_rdy),
      .k4_coef_dat (k4_coef_dat),
      .k4_bpe_act  (k4_bpe_act),

      .k4_mode     (k4_mode),
      .decode4     (decode4),
      .k4_sw_lst   (k4_sw_lst) 
    );


    /*================================================================================================
    #                                          Kernels                                               #
    ================================================================================================*/    
    kernel_top #(
      .pDATA_WIDTH(pIOPS_WIDTH)
    ) kernel1 (
      .clk        (clk_k1),
      .clk_2x     (clk_2x),
      .rstn       (rstn),

      .ld_vld     (k1_load_vld),
      .ld_rdy     (k1_load_rdy),
      .ld_dat     (k1_load_dat),

      .sw_vld     (k1_store_vld),
      .sw_rdy     (k1_store_rdy),
      .sw_dat     (k1_store_dat),

      .coef_vld   (k1_coef_vld),
      .coef_rdy   (k1_coef_rdy),
      .coef_dat   (k1_coef_dat),

      .bpe_act    (k1_bpe_act),

      .mode       (k1_mode),
      .decode     (decode1),
      .sw_lst     (k1_sw_lst)
    );

    kernel_top #(
        .pDATA_WIDTH(pIOPS_WIDTH)
    ) kernel2 (
        .clk        (clk_k2),
        .clk_2x     (clk_2x),
        .rstn       (rstn),

        .ld_vld     (k2_load_vld),
        .ld_rdy     (k2_load_rdy),
        .ld_dat     (k2_load_dat),

        .sw_vld     (k2_store_vld),
        .sw_rdy     (k2_store_rdy),
        .sw_dat     (k2_store_dat),

        .coef_vld   (k2_coef_vld),
        .coef_rdy   (k2_coef_rdy),
        .coef_dat   (k2_coef_dat),

        .bpe_act    (k2_bpe_act),

        .mode       (k2_mode),
        .decode     (decode2),
        .sw_lst     (k2_sw_lst)
    );

    kernel_top #(
        .pDATA_WIDTH(pIOPS_WIDTH)
    ) kernel3 (
        .clk        (clk_k3),
        .clk_2x     (clk_2x),
        .rstn       (rstn),

        .ld_vld     (k3_load_vld),
        .ld_rdy     (k3_load_rdy),
        .ld_dat     (k3_load_dat),

        .sw_vld     (k3_store_vld),
        .sw_rdy     (k3_store_rdy),
        .sw_dat     (k3_store_dat),

        .coef_vld   (k3_coef_vld),
        .coef_rdy   (k3_coef_rdy),
        .coef_dat   (k3_coef_dat),

        .bpe_act    (k3_bpe_act),

        .mode       (k3_mode),
        .decode     (decode3),
        .sw_lst     (k3_sw_lst)
    );

    kernel_top #(
        .pDATA_WIDTH(pIOPS_WIDTH)
    ) kernel4 (
        .clk        (clk_k4),
        .clk_2x     (clk_2x),
        .rstn       (rstn),

        .ld_vld     (k4_load_vld),
        .ld_rdy     (k4_load_rdy),
        .ld_dat     (k4_load_dat),

        .sw_vld     (k4_store_vld),
        .sw_rdy     (k4_store_rdy),
        .sw_dat     (k4_store_dat),

        .coef_vld   (k4_coef_vld),
        .coef_rdy   (k4_coef_rdy),
        .coef_dat   (k4_coef_dat),

        .bpe_act    (k4_bpe_act),

        .mode       (k4_mode),
        .decode     (decode4),
        .sw_lst     (k4_sw_lst)
    );
    
endmodule