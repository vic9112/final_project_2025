
// Using Deep-Feedback structure, we will have
module stage_top
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers
    parameter pSS_WIDTH = 32 // two 64-bit numbers
)
(
    input   wire                     clk,
    input   wire                     rstn,

    input   wire               [1:0] in1_sw,  // not used for now
    output   wire             [31:0] ap_crtl,
    output   wire             [31:0] coef_crtl,
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
    input   wire                     k4_sw_lst

);
        
    //========================== Declaration ==========================
    // =============== axi stream =============== //
    reg ss_rdy_tmp;
    reg ss_rdy_next;
    // one stage pipe for receiving data from DMA
    reg [(pSS_WIDTH-1):0] ss_buffer_tmp1;
    reg [(pSS_WIDTH-1):0] ss_buffer_tmp2;
    reg [(pSS_WIDTH-1):0] ss_buffer_tmp3;
    reg [(pSS_WIDTH-1):0] ss_buffer_tmp4;
    reg [(pSS_WIDTH-1):0] ss_buffer_next1;
    reg [(pSS_WIDTH-1):0] ss_buffer_next2;
    reg [(pSS_WIDTH-1):0] ss_buffer_next3;
    reg [(pSS_WIDTH-1):0] ss_buffer_next4;
    wire [(pDATA_WIDTH-1):0] ss_buffer;
    wire [3:0] condition;

    reg sm_vld_tmp;
    reg sm_vld_next;
    reg [(pDATA_WIDTH-1):0] sm_buffer_tmp;
    reg [(pDATA_WIDTH-1):0] sm_buffer_next;

    // cnter for packing 128 bit
    reg [1:0] pack_cnter_tmp;
    reg [1:0] pack_cnter_next;
    // local parameter
    localparam PULL_DN = 0;
    localparam PULL_UP = 1;
    localparam INDEX_3 = 2'b11;

    // =============== metadata =============== //
    // indicate if the coming data is metadata
    reg read_meta_tmp;
    reg read_meta_next;
    // indicate the cycle for decoding
    reg decode_meta_tmp;
    reg decode_meta_next;

    reg [(pSS_WIDTH-1):0] meta_buffer_tmp;
    reg [(pSS_WIDTH-1):0] meta_buffer_next;

    // cnter for data length
    reg [10:0] meta_cnter_tmp;
    reg [10:0] meta_cnter_next;

    // destination & mode
    wire [7:0] dst_tmp; // destination
    wire [7:0] mode_tmp;

    // local parameter
    localparam MAX_LEN = 1024;
    // parameter for destination
    localparam KERNEL_1 = 8'b00000100;
    localparam KERNEL_2 = 8'b00000101;
    localparam KERNEL_3 = 8'b00000110;
    localparam KERNEL_4 = 8'b00000111;
    localparam COEF = 8'b00010000;
    
    // =============== kernel =============== //
    // kernel handshake
    reg k1_ld_vld_tmp;
    reg k1_ld_vld_next;
    reg k1_sw_rdy_tmp;
    reg k1_sw_rdy_next;

    reg k2_ld_vld_tmp;
    reg k2_ld_vld_next;
    reg k2_sw_rdy_tmp;
    reg k2_sw_rdy_next;

    reg k3_ld_vld_tmp;
    reg k3_ld_vld_next;
    reg k3_sw_rdy_tmp;
    reg k3_sw_rdy_next;

    reg k4_ld_vld_tmp;
    reg k4_ld_vld_next;
    reg k4_sw_rdy_tmp;
    reg k4_sw_rdy_next;

    // destination
    wire [15:0] status;

    // local parameter for kenel mode
    // need to make sure with the operator group
    localparam FFT = 8'd1;
    localparam IFFT = 8'd2;
    localparam NTT = 8'd3;
    localparam INTT = 8'd4;

    // =============== ap_ctrl & coef_ctrl =============== //
    reg [3:0] ap_done1_tmp;
    reg [3:0] ap_done1_next;
    reg [3:0] ap_done2_tmp;
    reg [3:0] ap_done2_next;
    reg [3:0] ap_done3_tmp;
    reg [3:0] ap_done3_next;
    reg [3:0] ap_done4_tmp;
    reg [3:0] ap_done4_next;

    reg [3:0] ap_idle1_tmp;
    reg [3:0] ap_idle1_next;
    reg [3:0] ap_idle2_tmp;
    reg [3:0] ap_idle2_next;
    reg [3:0] ap_idle3_tmp;
    reg [3:0] ap_idle3_next;
    reg [3:0] ap_idle4_tmp;
    reg [3:0] ap_idle4_next;

    // 0x00: Kernel status (configuration address: 0x3000_0000) read by middleware
    //reg coef_done;        // 0x10: Indicate coefficient is initialized
    reg coef_crtl_tmp;
    reg coef_crtl_next;

    // =============== address generator for tap =============== //
    


    //========================== Function ==========================
    // =============== axi stream =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        ss_rdy_tmp <= PULL_DN;
        ss_buffer_tmp1 <= PULL_DN;
        ss_buffer_tmp2 <= PULL_DN;
        ss_buffer_tmp3 <= PULL_DN;
        ss_buffer_tmp4 <= PULL_DN;
        pack_cnter_tmp <= PULL_DN;
        sm_vld_tmp <= PULL_DN;
        sm_buffer_tmp <= PULL_DN;
      end else begin
        ss_rdy_tmp <= ss_rdy_next;
        ss_buffer_tmp1 <= ss_buffer_next1;
        ss_buffer_tmp2 <= ss_buffer_next2;
        ss_buffer_tmp3 <= ss_buffer_next3;
        ss_buffer_tmp4 <= ss_buffer_next4;
        pack_cnter_tmp <= pack_cnter_next;
        sm_vld_tmp <= sm_vld_next;
        sm_buffer_tmp <= sm_buffer_next;
      end
    end

    assign condition = {read_meta_tmp, ss_rdy, pack_cnter_tmp};

    always @(*) begin
      // ss_rdy
      if (ss_vld && !ss_rdy) begin
        ss_rdy_next = PULL_UP;
      end begin
        ss_rdy_next = PULL_DN;
      end
      // pack_cnter
      if (ss_rdy && !(pack_cnter_tmp == INDEX_3) && !read_meta_tmp) begin
        pack_cnter_next = pack_cnter_tmp + 1;
      end else if (pack_cnter_tmp == INDEX_3 && !read_meta_tmp) begin
        pack_cnter_next = PULL_DN;
      end else begin
        pack_cnter_next = pack_cnter_tmp;
      end
      // fill in buffer
      case (condition)
        4'b0100: begin
          ss_buffer_next1 = ss_dat;
          ss_buffer_next2 = ss_buffer_tmp2;
          ss_buffer_next3 = ss_buffer_tmp3;
          ss_buffer_next4 = ss_buffer_tmp4;
        end
        4'b0101: begin
          ss_buffer_next1 = ss_buffer_tmp1;
          ss_buffer_next2 = ss_dat;
          ss_buffer_next3 = ss_buffer_tmp3;
          ss_buffer_next4 = ss_buffer_tmp4;
        end
        4'b0110: begin
          ss_buffer_next1 = ss_buffer_tmp1;
          ss_buffer_next2 = ss_buffer_tmp2;
          ss_buffer_next3 = ss_dat;
          ss_buffer_next4 = ss_buffer_tmp4;
        end
        4'b0111: begin
          ss_buffer_next1 = ss_buffer_tmp1;
          ss_buffer_next2 = ss_buffer_tmp2;
          ss_buffer_next3 = ss_buffer_tmp3;
          ss_buffer_next4 = ss_dat;
        end
        default: begin
          ss_buffer_next1 = PULL_DN;
          ss_buffer_next2 = PULL_DN;
          ss_buffer_next3 = PULL_DN;
          ss_buffer_next4 = PULL_DN;
        end
      endcase
      // sm_vld
      if ((k1_sw_vld && k1_sw_rdy) || (k2_sw_vld && k2_sw_rdy) || (k2_sw_vld && k2_sw_rdy) || (k2_sw_vld && k2_sw_rdy)) begin
        sm_vld_next = PULL_UP;
      end else if (sm_rdy) begin
        sm_vld_next = PULL_DN;
      end else begin
        sm_vld_next = sm_vld_tmp;
      end
      // sm_buffer
      if (k1_sw_vld && k1_sw_rdy) begin
        sm_buffer_next = k1_sw_dat;
      end else if (k2_sw_vld && k2_sw_rdy) begin
        sm_buffer_next = k1_sw_dat;
      end else if (k3_sw_vld && k3_sw_rdy) begin
        sm_buffer_next = k1_sw_dat;
      end else if (k4_sw_vld && k4_sw_rdy) begin
        sm_buffer_next = k1_sw_dat;
      end else begin
        sm_buffer_next = sm_buffer_tmp;
      end
    end

    assign ss_buffer = {ss_buffer_tmp1, ss_buffer_tmp2, ss_buffer_tmp3, ss_buffer_tmp4};
    // assign to port wire
    assign ss_rdy = ss_rdy_tmp;
    assign sm_vld = sm_vld_tmp;
    assign sm_dat = sm_buffer_tmp;

    // =============== metadata =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        read_meta_tmp <= PULL_UP;
        decode_meta_tmp <= PULL_DN;
        meta_buffer_tmp <= PULL_DN;
        meta_cnter_tmp <= PULL_DN;
      end else begin
        read_meta_tmp <= read_meta_next;
        decode_meta_tmp <= decode_meta_next;
        meta_buffer_tmp <= meta_buffer_next;
        meta_cnter_tmp <= meta_cnter_next;
      end
    end

    always @(*) begin
      // read_meta
      if (ss_rdy && !(meta_cnter_tmp == MAX_LEN)) begin
        read_meta_next = PULL_DN;
      end else (ss_rdy && meta_cnter_tmp == MAX_LEN) begin
        read_meta_next = PULL_UP;
      end else begin
        read_meta_next = read_meta_tmp;
      end
      // decode_meta & meta_buffer & meta_cnter
      if (ss_rdy && read_meta_tmp) begin
        decode_meta_next = PULL_UP;
        meta_buffer_next = ss_dat;
        meta_cnter_next = PULL_UP; // set to 1
      end else begin
        decode_meta_next = PULL_DN;
        meta_buffer_next = meta_buffer_tmp;
        meta_cnter_next = meta_cnter_tmp + 1; // set to 1
      end
    end

    assign dst_tmp = meta_buffer_tmp[31:24];
    assign mode_tmp = meta_buffer_tmp[23:16];
    // I did not extract data length here
    // add it if u need

    // =============== kernel =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        k1_ld_vld_tmp <= PULL_DN;
        k1_sw_rdy_tmp <= PULL_DN;
        k2_ld_vld_tmp <= PULL_DN;
        k2_sw_rdy_tmp <= PULL_DN;
        k3_ld_vld_tmp <= PULL_DN;
        k3_sw_rdy_tmp <= PULL_DN;
        k4_ld_vld_tmp <= PULL_DN;
        k4_sw_rdy_tmp <= PULL_DN;
      end else begin
        k1_ld_vld_tmp <= k1_ld_vld_next;
        k1_sw_rdy_tmp <= k1_sw_rdy_next;
        k2_ld_vld_tmp <= k2_ld_vld_next;
        k2_sw_rdy_tmp <= k2_sw_rdy_next;
        k3_ld_vld_tmp <= k3_ld_vld_next;
        k3_sw_rdy_tmp <= k3_sw_rdy_next;
        k4_ld_vld_tmp <= k4_ld_vld_next;
        k4_sw_rdy_tmp <= k4_sw_rdy_next;
      end
    end

    always @(*) begin
      if (k1_sw_vld && !k1_sw_rdy_tmp && !sm_vld) begin
        k1_sw_rdy_next = PULL_UP;
        k2_sw_rdy_next = k2_sw_rdy_tmp;
        k3_sw_rdy_next = k3_sw_rdy_tmp;
        k4_sw_rdy_next = k4_sw_rdy_tmp;
      end else if (k2_sw_vld && !k2_sw_rdy_tmp && !sm_vld) begin
        k2_sw_rdy_next = PULL_UP;
        k1_sw_rdy_next = k1_sw_rdy_tmp;
        k3_sw_rdy_next = k3_sw_rdy_tmp;
        k4_sw_rdy_next = k4_sw_rdy_tmp;
      end else if (k3_sw_vld && !k3_sw_rdy_tmp && !sm_vld) begin
        k3_sw_rdy_next = PULL_UP;
        k1_sw_rdy_next = k1_sw_rdy_tmp;
        k2_sw_rdy_next = k2_sw_rdy_tmp;
        k4_sw_rdy_next = k4_sw_rdy_tmp;
      end else if (k4_sw_vld && !k4_sw_rdy_tmp && !sm_vld) begin
        k4_sw_rdy_next = PULL_UP;
        k1_sw_rdy_next = k1_sw_rdy_tmp;
        k2_sw_rdy_next = k2_sw_rdy_tmp;
        k3_sw_rdy_next = k3_sw_rdy_tmp;
      end else begin
        k1_sw_rdy_next = PULL_DN;
        k2_sw_rdy_next = PULL_DN;
        k3_sw_rdy_next = PULL_DN;
        k4_sw_rdy_next = PULL_DN;
      end
    end

    assign status = {read_meta_tmp, ss_rdy, pack_cnter_tmp, k1_ld_rdy, k2_ld_rdy, k3_ld_rdy, k4_ld_rdy, dst_tmp};
    // for destination
    always @(*) begin
      casez (status)
        {8'b01110???, KERNEL_1}: begin
          k1_ld_vld_next = PULL_UP;
          k2_ld_vld_next = k2_ld_vld_tmp;
          k3_ld_vld_next = k3_ld_vld_tmp;
          k4_ld_vld_next = k4_ld_vld_tmp;
        end
        {8'b01??1???, KERNEL_1}: begin
          k1_ld_vld_next = PULL_DN;
          k2_ld_vld_next = k2_ld_vld_tmp;
          k3_ld_vld_next = k3_ld_vld_tmp;
          k4_ld_vld_next = k4_ld_vld_tmp;
        end
        {8'b0111?0??, KERNEL_2}: begin
          k2_ld_vld_next = PULL_UP;
          k1_ld_vld_next = k1_ld_vld_tmp;
          k3_ld_vld_next = k3_ld_vld_tmp;
          k4_ld_vld_next = k4_ld_vld_tmp;
        end
        {8'b01???1??, KERNEL_2}: begin
          k2_ld_vld_next = PULL_DN;
          k1_ld_vld_next = k1_ld_vld_tmp;
          k3_ld_vld_next = k3_ld_vld_tmp;
          k4_ld_vld_next = k4_ld_vld_tmp;
        end
        {8'b0111??0?, KERNEL_3}: begin
          k3_ld_vld_next = PULL_UP;
          k1_ld_vld_next = k1_ld_vld_tmp;
          k2_ld_vld_next = k2_ld_vld_tmp;
          k4_ld_vld_next = k4_ld_vld_tmp;
        end
        {8'b01????1?, KERNEL_3}: begin
          k3_ld_vld_next = PULL_DN;
          k1_ld_vld_next = k1_ld_vld_tmp;
          k2_ld_vld_next = k2_ld_vld_tmp;
          k4_ld_vld_next = k4_ld_vld_tmp;
        end
        {8'b0111???0, KERNEL_4}: begin
          k4_ld_vld_next = PULL_UP;
          k1_ld_vld_next = k1_ld_vld_tmp;
          k2_ld_vld_next = k2_ld_vld_tmp;
          k3_ld_vld_next = k3_ld_vld_tmp;
        end
        {8'b01?????1, KERNEL_4}: begin
          k4_ld_vld_next = PULL_DN;
          k1_ld_vld_next = k1_ld_vld_tmp;
          k2_ld_vld_next = k2_ld_vld_tmp;
          k3_ld_vld_next = k3_ld_vld_tmp;
        end
        default: begin
          k1_ld_vld_next = k1_ld_vld_tmp;
          k2_ld_vld_next = k2_ld_vld_tmp;
          k3_ld_vld_next = k3_ld_vld_tmp;
          k4_ld_vld_next = k4_ld_vld_tmp;
        end
      endcase
    end
    // for kenel mode
    assign decode1 = (decode_meta_tmp && dst_tmp == KERNEL_1) ? PULL_UP : PULL_DN;
    assign decode2 = (decode_meta_tmp && dst_tmp == KERNEL_2) ? PULL_UP : PULL_DN;
    assign decode3 = (decode_meta_tmp && dst_tmp == KERNEL_3) ? PULL_UP : PULL_DN;
    assign decode4 = (decode_meta_tmp && dst_tmp == KERNEL_4) ? PULL_UP : PULL_DN;
    // kenel mode is update when decode is set in kernel.v
    assign k1_mode = mode_tmp;
    assign k2_mode = mode_tmp;
    assign k3_mode = mode_tmp;
    assign k4_mode = mode_tmp;

    // whether input data is valid is determined by vld & rdy 
    assign k1_ld_dat = ss_buffer;
    assign k2_ld_dat = ss_buffer;
    assign k3_ld_dat = ss_buffer;
    assign k4_ld_dat = ss_buffer;

    assign k1_ld_vld = k1_ld_vld_tmp;
    assign k2_ld_vld = k2_ld_vld_tmp;
    assign k3_ld_vld = k3_ld_vld_tmp;
    assign k4_ld_vld = k4_ld_vld_tmp;

    assign k1_sw_rdy = k1_sw_rdy_tmp;
    assign k1_sw_rdy = k1_sw_rdy_tmp;
    assign k1_sw_rdy = k1_sw_rdy_tmp;
    assign k1_sw_rdy = k1_sw_rdy_tmp;

    // =============== ap_ctrl & coef_ctrl =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        coef_crtl_tmp <= PULL_DN;
        ap_idle1_tmp <= PULL_UP;
        ap_idle2_tmp <= PULL_UP;
        ap_idle3_tmp <= PULL_UP;
        ap_idle4_tmp <= PULL_UP;
        ap_done1_tmp <= PULL_DN;
        ap_done2_tmp <= PULL_DN;
        ap_done3_tmp <= PULL_DN;
        ap_done4_tmp <= PULL_DN;
      end else begin
        coef_crtl_tmp <= coef_crtl_next;
        ap_idle1_tmp <= ap_idle1_next;
        ap_idle2_tmp <= ap_idle2_next;
        ap_idle3_tmp <= ap_idle3_next;
        ap_idle4_tmp <= ap_idle4_next;
        ap_done1_tmp <= ap_done1_next;
        ap_done2_tmp <= ap_done2_next;
        ap_done3_tmp <= ap_done3_next;
        ap_done4_tmp <= ap_done4_next;
      end
    end

    // assume that coef length is as same as 1024
    always @(*) begin
      // coef_crtl
      if ((meta_cnter_tmp == MAX_LEN) && ss_rdy && (dst_tmp == COEF)) begin
        coef_crtl_next = PULL_UP;
      end else begin
        coef_crtl_next = coef_crtl_tmp;
      end
      // ap_idle1
      if (decode_meta_tmp == PULL_UP && dst_tmp == KERNEL_1) begin
        ap_idle1_next = PULL_DN
      end else if (k1_sw_lst) begin
        ap_idle1_next = PULL_UP;
      end else begin
        ap_idle1_next = ap_idle1_tmp;
      end
      // ap_idle2
      if (decode_meta_tmp == PULL_UP && dst_tmp == KERNEL_2) begin
        ap_idle2_next = PULL_DN
      end else if (k2_sw_lst) begin
        ap_idle2_next = PULL_UP;
      end else begin
        ap_idle2_next = ap_idle2_tmp;
      end
      // ap_idle3
      if (decode_meta_tmp == PULL_UP && dst_tmp == KERNEL_3) begin
        ap_idle3_next = PULL_DN
      end else if (k3_sw_lst) begin
        ap_idle3_next = PULL_UP;
      end else begin
        ap_idle3_next = ap_idle3_tmp;
      end
      // ap_idle4
      if (decode_meta_tmp == PULL_UP && dst_tmp == KERNEL_4) begin
        ap_idle4_next = PULL_DN
      end else if (k4_sw_lst) begin
        ap_idle4_next = PULL_UP;
      end else begin
        ap_idle4_next = ap_idle4_tmp;
      end
      // ap_done1
      if (k1_sw_lst) begin
        ap_done1_next = PULL_UP;
      end else if (ap_read && ap_done1_tmp) begin
        ap_done1_next = PULL_DN;
      end else begin
        ap_done1_next = ap_done1_tmp;
      end
      // ap_done2
      if (k2_sw_lst) begin
        ap_done2_next = PULL_UP;
      end else if (ap_read && ap_done2_tmp) begin
        ap_done2_next = PULL_DN;
      end else begin
        ap_done2_next = ap_done2_tmp;
      end
      // ap_done3
      if (k3_sw_lst) begin
        ap_done3_next = PULL_UP;
      end else if (ap_read && ap_done3_tmp) begin
        ap_done3_next = PULL_DN;
      end else begin
        ap_done3_next = ap_done3_tmp;
      end
      // ap_done4
      if (k4_sw_lst) begin
        ap_done4_next = PULL_UP;
      end else if (ap_read && ap_done4_tmp) begin
        ap_done4_next = PULL_DN;
      end else begin
        ap_done4_next = ap_done4_tmp;
      end
    end

    assign coef_crtl = coef_crtl_tmp;
    assign ap_ctrl = {ap_idle4_next, ap_done4_next, ap_idle3_next, ap_done3_next, ap_idle2_next, ap_done2_next, ap_idle1_next, ap_done1_next};

    // =============== address generator for tap =============== //
   


    
    bram32 tap_RAM (
        .CLK(),
        .WE(write_tmp),
        .EN(),
        .Di(),
        .A(),
        .Do()
    );


endmodule

