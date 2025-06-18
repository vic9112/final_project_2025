module kernel 
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers
)
(
    input  wire                     clk,
    input  wire                     clk_2x,//for dataRAM (double-speed)
    input  wire                     rstn,

    input  wire                     ld_vld,
    output wire                     ld_rdy,
    input  wire [(pDATA_WIDTH-1):0] ld_dat,

    output wire                     sw_vld,
    input  wire                     sw_rdy,
    output wire [(pDATA_WIDTH-1):0] sw_dat,

    input  wire                     coef_vld,
    output wire                     coef_rdy,
    input  wire [(pDATA_WIDTH-1):0] coef_dat, 

    output wire               [4:0] bpe_act,//for bpe1 to bpe4 counter 

    input  wire               [7:0] mode,
    input  wire                     decode,
    output wire                     sw_lst  // this is set when handshake
);

    //========================== Declaration ==========================

    // =============== kernel mode =============== //
    reg [7:0] mode_state;
    reg [7:0] mode_state_next;
    wire [7:0] butterfly_mode;

    // =============== FFT Coefficient ============ //
    // real, im
    localparam [127:0] W0   = 128'h3ff0000000000000_0000000000000000;
    localparam [127:0] W32  = 128'h3feb504f333f9de6_bfe1c73b39ae68a6;
    localparam [127:0] W64  = 128'h3fe6a09e667f3bcd_bfe6a09e667f3bcd;
    localparam [127:0] W96  = 128'h3fe1c73b39ae68a6_bfeb504f333f9de6;
    localparam [127:0] W128 = 128'h0000000000000000_bff0000000000000;
    localparam [127:0] W160 = 128'hbfe1c73b39ae68a6_bfeb504f333f9de6;
    localparam [127:0] W192 = 128'hbfe6a09e667f3bcd_bfe6a09e667f3bcd;
    localparam [127:0] W224 = 128'hbfeb504f333f9de6_bfe1c73b39ae68a6;

    // ================ BPE 1 ===================== //
    // Coefficient
    wire [127:0] COE0_1st;
    wire [127:0] COE1_1st;
    wire [127:0] COE2_1st;

    // 1st BPE IO
    reg [127:0] BPE1_ain;
    reg [127:0] BPE1_bin;
    reg BPE1_i_vld;
    wire BPE1_i_rdy;
    wire [127:0] BPE1_aout;
    wire [127:0] BPE1_bout;
    wire BPE1_o_vld;
    wire BPE1_o_rdy;
    reg [127:0] BPE1_bin_buffer;
    reg [127:0] BPE1_bin_buffer_next;
    reg [127:0] BPE1_coef;

    // FSM for 1st BPE
    reg BPE_1st_idle;
    reg [3:0] state_1st;
    reg [3:0] state_1st_next;


    reg [15:0] counter_1st;
    reg [15:0] counter_1st_delay;
    reg [15:0] counter_1st_adv;
    reg counting_1st;
    reg trigger_once;

    wire [15:0] counter_1st_next;
    wire [15:0] counter_1st_delay_next;
    wire [15:0] counter_1st_adv_next;
    wire counting_1st_next;
    wire trigger_once_next;


    wire enable_output_1st;
    wire [127:0] ld_dat_2nd;
    wire ld_vld_2nd;
    reg BPE1_out_done;

    reg [11:0] counter_1st_output;
    wire [11:0] counter_1st_output_next;
    wire BPE1_out_done_next;

    reg  [255:0] data_to_sram;      
    wire [127:0] sram_din;
    reg          sram_we;
    reg          sram_en;
    reg  [25:0]  sram_addr_one_cycle;
    wire  [12:0] sram_addr;
    reg          phase;     // 在 clk_2x 切兩次送或切兩次讀
    wire         phase_next;
    wire  [127:0] sram_dout;


    // ===================BPE 2=================== //
     // Coefficient
    reg [127:0] COE0_2nd;
    reg [127:0] COE1_2nd;
    reg [127:0] COE2_2nd;

    // 2nd BPE IO
    reg [127:0] BPE2_ain;
    reg [127:0] BPE2_bin;
    reg BPE2_i_vld;
    wire BPE2_i_rdy;
    wire [127:0] BPE2_aout;
    wire [127:0] BPE2_bout;
    wire BPE2_o_vld;
    wire BPE2_o_rdy;
    reg [127:0] BPE2_bin_buffer;
    reg [127:0] BPE2_bin_buffer_next;
    reg [127:0] BPE2_coef;

    // FSM for 2nd BPE
    reg BPE_2nd_idle;
    reg [3:0] state_2nd;
    reg [3:0] state_2nd_next;


    reg [15:0] counter_2nd;
    reg [15:0] counter_2nd_delay;
    reg [15:0] counter_2nd_adv;
    reg counting_2nd;
    reg trigger_once_2nd;

    wire [15:0] counter_2nd_next;
    wire [15:0] counter_2nd_delay_next;
    wire [15:0] counter_2nd_adv_next;
    wire counting_2nd_next;
    wire trigger_once_2nd_next;

    wire enable_output_2nd;
    wire [127:0] ld_dat_3rd;
    wire ld_vld_3rd;
    reg BPE2_out_done;

    reg [11:0] counter_2nd_output;
    wire [11:0] counter_2nd_output_next;
    wire BPE2_out_done_next;

    reg  [255:0] data_to_sram_2nd;      
    wire [127:0] sram_din_2nd;
    reg          sram_we_2nd;
    reg          sram_en_2nd;
    reg  [25:0]  sram_addr_one_cycle_2nd;
    wire  [12:0] sram_addr_2nd;
    wire  [127:0] sram_dout_2nd; 

    //==========================BPE 3=======================//
    // Coefficient
    reg [127:0] COE0_3rd;
    reg [127:0] COE1_3rd;
    reg [127:0] COE2_3rd;

    wire [127:0] COE0_3rd_tmp;
    wire [127:0] COE1_3rd_tmp;
    wire [127:0] COE2_3rd_tmp;

    // 3rd BPE IO
    reg [127:0] BPE3_ain;
    reg [127:0] BPE3_bin;
    reg BPE3_i_vld;
    wire BPE3_i_rdy;
    wire [127:0] BPE3_aout;
    wire [127:0] BPE3_bout;
    wire BPE3_o_vld;
    wire BPE3_o_rdy;
    reg [127:0] BPE3_bin_buffer;
    reg [127:0] BPE3_bin_buffer_next;
    reg [127:0] BPE3_coef;

    // FSM for 3rd BPE
    reg BPE_3rd_idle;
    reg [3:0] state_3rd;
    reg [3:0] state_3rd_next;


    reg [15:0] counter_3rd;
    reg [15:0] counter_3rd_delay;
    reg [15:0] counter_3rd_adv;
    reg counting_3rd;
    reg trigger_once_3rd;

    wire [15:0] counter_3rd_next;
    wire [15:0] counter_3rd_delay_next;
    wire [15:0] counter_3rd_adv_next;
    wire counting_3rd_next;
    wire trigger_once_3rd_next;


    wire enable_output_3rd;
    wire [127:0] ld_dat_4th;
    wire ld_vld_4th;
    reg BPE3_out_done;

    reg [11:0] counter_3rd_output;
    wire [11:0] counter_3rd_output_next;
    wire BPE3_out_done_next;


    reg  [255:0] data_to_sram_3rd;      
    wire [127:0] sram_din_3rd;
    reg          sram_we_3rd;
    reg          sram_en_3rd;
    reg  [25:0]  sram_addr_one_cycle_3rd;
    wire  [12:0] sram_addr_3rd;
    wire  [127:0] sram_dout_3rd; 

    //==========================BPE 4=======================//
    wire BPE4_idle;
    assign BPE4_idle = 1; // For test
    // BPE 4, 5 declaration
    wire ss_vld_4th;
    wire ss_rdy_4th;
    wire sm_vld_4th;
    wire sm_rdy_4th;
    wire ss_vld_5th;
    wire ss_rdy_5th;
    wire sm_vld_5th;
    wire sm_rdy_5th;
    wire [pDATA_WIDTH-1:0] data_789;
    // =========================== Output Buffer ========================== // 
    reg [pDATA_WIDTH:0] output_buffer_w[0:7];
    reg [pDATA_WIDTH:0] output_buffer[0:7]; //
    reg [$clog2(pDATA_WIDTH)-1:0] output_buf_in_cnt_r; 
    reg [$clog2(pDATA_WIDTH)-1:0] output_buf_in_cnt_w; // input counter for output buffer
    wire [pDATA_WIDTH-1:0] BPE5_dout;
  
    // counters
    reg [$clog2(pDATA_WIDTH)-1:0] kern_out_cnt_r; // output counter for kernel
    reg [$clog2(pDATA_WIDTH)-1:0] kern_out_cnt_w;
    reg [1:0] out_byte_cnt_r; // output byte counter for kernel
    wire [1:0] out_byte_cnt_w;
    //========================== Function ==========================

    // =============== kernel mode =============== //
    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        mode_state <= 0;
      end else begin
        mode_state <= mode_state_next;
      end
    end

    always @(*) begin
      if (decode) begin
        mode_state_next = mode;
      end else begin
        mode_state_next = mode_state;
      end
    end

    assign butterfly_mode = mode_state;

    // =================ld_signal================ //

    assign ld_rdy = 1;
    assign sw_lst = (state_1st == 4'b0) & (state_2nd == 4'b0) & (state_3rd == 4'b0); // Test Performance
    assign bpe_act[1:0] = 2'b00;
    assign bpe_act[4:3] = 2'b00; // For Test
    assign coef_rdy = 1;
    

    /*===============================================================================================
    #                                       Kernel FSM                                              #
    ================================================================================================*/
    
    reg [1:0] state_kernel;     
    reg [1:0] state_kernel_next;
    localparam kernel_IDLE = 2'b00;
    localparam kernel_CAL = 2'b01;

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        state_kernel <= 0;
      end else begin
        state_kernel <= state_kernel_next;
      end
    end

    always @(*) begin
      case (state_kernel)
        kernel_IDLE: begin
          if (ld_vld) begin     
            state_kernel_next = kernel_CAL;
          end else begin     
            state_kernel_next = kernel_IDLE;
          end
        end
        kernel_CAL: begin
          if (sw_lst) begin     
            state_kernel_next = kernel_IDLE;
          end else begin     
            state_kernel_next = kernel_CAL;
          end
        end
        default: begin     
          state_kernel_next = kernel_IDLE;
        end
      endcase
    end

    /*===============================================================================================
    #                                       1st BPE                                                 #
    ================================================================================================*/

    // Coefficient
    /*wire [127:0] COE0_1st;
    wire [127:0] COE1_1st;
    wire [127:0] COE2_1st;

    // 1st BPE IO
    reg [127:0] BPE1_ain;
    reg [127:0] BPE1_bin;
    reg BPE1_i_vld;
    wire BPE1_i_rdy;
    wire [127:0] BPE1_aout;
    wire [127:0] BPE1_bout;
    wire BPE1_o_vld;
    wire BPE1_o_rdy;
    reg [127:0] BPE1_bin_buffer;
    reg [127:0] BPE1_bin_buffer_next;
    reg [127:0] BPE1_coef;

    // FSM for 1st BPE
    reg BPE_1st_idle;
    reg [3:0] state_1st;
    reg [3:0] state_1st_next;*/

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        state_1st <= 0;
      end else begin
        state_1st <= state_1st_next;
      end
    end

    always @(*) begin
      case (state_1st)
        4'b0000: begin
          state_1st_next = (counter_1st == 1022) ? 4'b0001 : state_1st;
        end
        4'b0001: begin
          state_1st_next = (counter_1st == 1046) ? 4'b0010 : state_1st;
        end
        4'b0010: begin
          state_1st_next = (counter_1st == 2045) ? 4'b0011 : state_1st;
        end
        4'b0011: begin
          state_1st_next = (counter_1st == 2073) ? 4'b0100 : state_1st;
        end
        4'b0100: begin
          state_1st_next = (counter_1st == 2557) ? 4'b0101 : state_1st;
        end
        4'b0101: begin
          state_1st_next = (counter_1st == 2585) ? 4'b0110 : state_1st;
        end
        4'b0110: begin
          state_1st_next = (counter_1st == 3070) ? 4'b0111 : state_1st;
        end
        4'b0111: begin
          state_1st_next = (counter_1st == 3096) ? 4'b1000 : state_1st;
        end
        4'b1000: begin
          state_1st_next = (state_2nd == 4'b0000) ? 4'b1001 : state_1st;
        end
        4'b1001: begin
          state_1st_next = (BPE1_out_done) ? 4'b1010 : state_1st;
        end
        4'b1010: begin
          state_1st_next = (state_2nd == 4'b0000) ? 4'b1011 : state_1st;
        end
        4'b1011: begin
          state_1st_next = (BPE1_out_done) ? 4'b1100 : state_1st;
        end
        4'b1100: begin
          state_1st_next = (state_2nd == 4'b0000) ? 4'b1101 : state_1st;
        end
        4'b1101: begin
          state_1st_next = (BPE1_out_done) ? 4'b1110 : state_1st;
        end
        4'b1110: begin
          state_1st_next = (state_2nd == 4'b0000) ? 4'b1111 : state_1st;
        end
        4'b1111: begin
          state_1st_next = (BPE1_out_done) ? 4'b0000 : state_1st;
        end
        default: begin
          state_1st_next = 4'b0000;
        end
      endcase
    end

    // ====================================counter_1st===================================== //

    /*reg [15:0] counter_1st;
    reg [15:0] counter_1st_delay;
    reg [15:0] counter_1st_adv;
    reg counting_1st;
    reg trigger_once;

    wire [15:0] counter_1st_next;
    wire [15:0] counter_1st_delay_next;
    wire [15:0] counter_1st_adv_next;
    wire counting_1st_next;
    wire trigger_once_next;*/

    assign trigger_once_next  = trigger_once | ld_vld;
    assign counting_1st_next  = (ld_vld && !trigger_once) ? 1'b1 :
                                counting_1st;
    assign counter_1st_next   = (ld_vld && !trigger_once) ? 16'd1 :
                                counting_1st ? counter_1st + 1 :
                                counter_1st;
    assign counter_1st_delay_next = counter_1st_next - 27;
    assign counter_1st_adv_next = counter_1st_next + 2;

    always @(posedge clk or negedge rstn) begin
      if (~rstn | decode | BPE1_out_done) begin
        counter_1st    <= 16'd0;
        counting_1st   <= 1'b0;
        trigger_once   <= 1'b0;
        counter_1st_delay <= 16'd0;
        counter_1st_adv <= 16'd0;
      end else begin
        counter_1st    <= counter_1st_next;
        counting_1st   <= counting_1st_next;
        trigger_once   <= trigger_once_next;
        counter_1st_delay <= counter_1st_delay_next;
        counter_1st_adv <= counter_1st_adv_next;
      end
    end



    // ====================================Output Logic=========================================== //
    assign enable_output_1st = 
    (state_1st == 4'b1001 || 
     state_1st == 4'b1011 || 
     state_1st == 4'b1101 || 
     state_1st == 4'b1111);

    /*wire [127:0] ld_dat_2nd;
    wire ld_vld_2nd;
    reg BPE1_out_done;

    reg [11:0] counter_1st_output;
    wire [11:0] counter_1st_output_next;
    wire BPE1_out_done_next; */

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        counter_1st_output <= 0;
      end else begin
        counter_1st_output <= counter_1st_output_next;
      end
    end

    assign counter_1st_output_next = (enable_output_1st) ? counter_1st_output + 1 : 0;

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        BPE1_out_done <= 0;
      end else begin
        BPE1_out_done <= BPE1_out_done_next;
      end
    end

    assign BPE1_out_done_next = (counter_1st_output == 508);

    assign ld_vld_2nd = enable_output_1st & (counter_1st_output[1:0] == 2'b00);

    assign ld_dat_2nd = (enable_output_1st) ? sram_dout : 0;
    

    // ====================================Data Ram Logic========================================= //
   
    /*reg  [255:0] data_to_sram;      
    wire [127:0] sram_din;
    reg          sram_we;
    reg          sram_en;
    reg  [25:0]  sram_addr_one_cycle;
    wire  [12:0] sram_addr;
    reg          phase;     // 在 clk_2x 切兩次送或切兩次讀
    wire         phase_next;
    reg  [127:0] sram_dout;*/



    always @(posedge clk_2x or negedge rstn) begin
      if (~rstn) begin
        phase <= 0;
      end else begin
        phase <= phase_next;
      end
    end

    assign phase_next = ~phase;

    assign sram_din = (phase) ? data_to_sram[255:128] : data_to_sram[127:0];
    assign sram_addr = (phase) ? sram_addr_one_cycle[25:13] : sram_addr_one_cycle[12:0];

    // SRAM_WE
    always @(*) begin
      case (state_1st)
        4'b0000: begin
          sram_we = {(~phase) & (counter_1st[1:0] == 2'b00)}; 
        end
        4'b0001: begin
          sram_we = 0;
        end
        4'b0010: begin
          sram_we = (counter_1st[1:0] == 2'b11);
        end
        4'b0011: begin
          sram_we = (counter_1st[1:0] == 2'b11);
        end
        4'b0100: begin
          sram_we = (counter_1st[1:0] == 2'b11);
        end
        4'b0101: begin
          sram_we = (counter_1st[1:0] == 2'b11);
        end
        4'b0110: begin
          sram_we = (counter_1st[1:0] == 2'b11);
        end
        4'b0111: begin
          sram_we = (counter_1st[1:0] == 2'b11);
        end
        default: begin
          sram_we = 0;
        end
      endcase
    end


    // SRAM_EN
    always @(*) begin
      case (state_1st)
        4'b0000: begin
          sram_en = (counter_1st[1:0] == 2'b00); 
        end
        4'b0001: begin
          sram_en = (counter_1st[1:0] == 2'b00) | (counter_1st[1:0] == 2'b11);
        end
        4'b0010: begin
          sram_en = ~(counter_1st[1:0] == 2'b01);
        end
        4'b0011: begin
          sram_en = ~(counter_1st[1:0] == 2'b01);
        end
        4'b0100: begin
          sram_en = ~(counter_1st[1:0] == 2'b01);
        end
        4'b0101: begin
          sram_en = ~(counter_1st[1:0] == 2'b01);
        end
        4'b0110: begin
          sram_en = ~(counter_1st[1:0] == 2'b01);
        end
        4'b0111: begin
          sram_en = ~(counter_1st[1:0] == 2'b01);
        end
        4'b1001: begin
          sram_en = (counter_1st_output[1:0] == 2'b00);
        end
        4'b1011: begin
          sram_en = (counter_1st_output[1:0] == 2'b00);
        end
        4'b1101: begin
          sram_en = (counter_1st_output[1:0] == 2'b00);
        end
        4'b1111: begin
          sram_en = (counter_1st_output[1:0] == 2'b00);
        end
        default: begin
          sram_en = 0;
        end
      endcase
    end

    // Data_to_SRAM
    always @(*) begin
      case (state_1st)
        4'b0000: begin
          data_to_sram = {128'b0, ld_dat[127:0]}; 
        end
        4'b0001: begin
          data_to_sram = 0;
        end
        4'b0010: begin
          data_to_sram = {BPE1_bout[127:0], BPE1_aout[127:0]};
        end
        4'b0011: begin
          data_to_sram = {BPE1_bout[127:0], BPE1_aout[127:0]};
        end
        4'b0100: begin
          data_to_sram = {BPE1_bout[127:0], BPE1_aout[127:0]};
        end
        4'b0101: begin
          data_to_sram = {BPE1_bout[127:0], BPE1_aout[127:0]};
        end
        4'b0110: begin
          data_to_sram = {BPE1_bout[127:0], BPE1_aout[127:0]};
        end
        4'b0111: begin
          data_to_sram = {BPE1_bout[127:0], BPE1_aout[127:0]};
        end
        4'b1000: begin
          data_to_sram = 0;
        end
        default: begin
          data_to_sram = 0;
        end
      endcase
    end

    // Sram Address
    always @(*) begin
      case (state_1st)
        4'b0000: begin
          sram_addr_one_cycle = {13'b0, 3'b0, counter_1st[9:0]}; 
        end
        4'b0001: begin
          sram_addr_one_cycle = {13'b0, 3'b0, counter_1st[9:0]};                                                                                   
        end
        4'b0010: begin
          sram_addr_one_cycle = (counter_1st[1:0] == 2'b11) ? {3'b001, counter_1st_delay[9:0], 3'b0, counter_1st_delay[9:0]} : {13'b0, 3'b0, counter_1st[9:0]};
        end
        4'b0011: begin
          sram_addr_one_cycle = (counter_1st[1:0] == 2'b11) ? {3'b001, counter_1st_delay[9:0], 3'b0, counter_1st_delay[9:0]} :
                                (counter_1st[1:0] == 2'b00) ? {13'b0, 4'b0, counter_1st[8:0]} : {13'b0, 4'b0001, counter_1st_adv[8:0]};
        end
        4'b0100: begin
          sram_addr_one_cycle = (counter_1st[1:0] == 2'b11) ? {4'b0001, counter_1st_delay[9:0], 4'b0, counter_1st_delay[9:0]} :
                                (counter_1st[1:0] == 2'b00) ? {13'b0, 4'b0, counter_1st[8:0]} : {13'b0, 4'b0001, counter_1st_adv[8:0]};
        end
        4'b0101: begin
          sram_addr_one_cycle = (counter_1st[1:0] == 2'b11) ? {4'b0001, counter_1st_delay[9:0], 4'b0, counter_1st_delay[9:0]} :
                                (counter_1st[1:0] == 2'b00) ? {13'b0, 4'b0010, counter_1st[8:0]} : {13'b0, 4'b0011, counter_1st_adv[8:0]};
        end
        4'b0110: begin
          sram_addr_one_cycle = (counter_1st[1:0] == 2'b11) ? {4'b0011, counter_1st_delay[9:0], 4'b0010, counter_1st_delay[9:0]} :
                                (counter_1st[1:0] == 2'b00) ? {13'b0, 4'b0010, counter_1st[8:0]} : {13'b0, 4'b0011, counter_1st_adv[8:0]};
        end
        4'b0111: begin
          sram_addr_one_cycle = {4'b0011, counter_1st_delay[9:0], 4'b0010, counter_1st_delay[9:0]};
        end
        4'b1001: begin
          sram_addr_one_cycle = {13'b0, 4'b0, counter_1st_output[8:0]};
        end
        4'b1011: begin
          sram_addr_one_cycle = {13'b0, 4'b0001, counter_1st_output[8:0]};
        end
        4'b1101: begin
          sram_addr_one_cycle = {13'b0, 4'b0010, counter_1st_output[8:0]};
        end
        4'b1111: begin
          sram_addr_one_cycle = {13'b0, 4'b0011, counter_1st_output[8:0]};
        end
        default: begin
          sram_addr_one_cycle = 0;
        end
      endcase
    end


 // ====================================BPE input========================================= //

    // BPEinA
    always @(*) begin
      case (state_1st)
        4'b0001: begin
          BPE1_ain = sram_dout;
        end
        4'b0010: begin
          BPE1_ain = sram_dout;
        end
        4'b0011: begin
          BPE1_ain = sram_dout;
        end
        4'b0100: begin
          BPE1_ain = sram_dout;
        end
        4'b0101: begin
          BPE1_ain = sram_dout;
        end
        4'b0110: begin
          BPE1_ain = sram_dout;
        end
        default: begin
          BPE1_ain = 0;
        end
      endcase
    end

    //BPEinPreBuffer
    always @(posedge clk) begin
       BPE1_bin_buffer <= BPE1_bin_buffer_next;
    end


    // BPEinBpreBufferNext
    always @(*) begin
      case (state_1st)
        4'b0011: begin
          BPE1_bin_buffer_next = (counter_1st[1:0] == 2'b10) ? sram_dout : BPE1_bin_buffer;
        end
        4'b0100: begin
          BPE1_bin_buffer_next = (counter_1st[1:0] == 2'b10) ? sram_dout : BPE1_bin_buffer;
        end
        4'b0101: begin
          BPE1_bin_buffer_next = (counter_1st[1:0] == 2'b10) ? sram_dout : BPE1_bin_buffer;
        end
        4'b0110: begin
          BPE1_bin_buffer_next = (counter_1st[1:0] == 2'b10) ? sram_dout : BPE1_bin_buffer;
        end
        default: begin
          BPE1_bin_buffer_next = 0;
        end
      endcase
    end

    // BPEinB
    always @(*) begin
      case (state_1st)
        4'b0001: begin
          BPE1_bin = ld_dat;
        end
        4'b0010: begin
          BPE1_bin = ld_dat;
        end
        4'b0011: begin
          BPE1_bin = BPE1_bin_buffer;
        end
        4'b0100: begin
          BPE1_bin = BPE1_bin_buffer;
        end
        4'b0101: begin
          BPE1_bin = BPE1_bin_buffer;
        end
        4'b0110: begin
          BPE1_bin = BPE1_bin_buffer;
        end
        default: begin
          BPE1_bin = 0;
        end
      endcase
    end

    // BPEinValid
    always @(*) begin
      case (state_1st)
        4'b0001: begin
          BPE1_i_vld = (counter_1st[1:0] == 2'b00);
        end
        4'b0010: begin
          BPE1_i_vld = (counter_1st[1:0] == 2'b00);
        end
        4'b0011: begin
          BPE1_i_vld = (counter_1st[1:0] == 2'b00);
        end
        4'b0100: begin
          BPE1_i_vld = (counter_1st[1:0] == 2'b00);
        end
        4'b0101: begin
          BPE1_i_vld = (counter_1st[1:0] == 2'b00);
        end
        4'b0110: begin
          BPE1_i_vld = (counter_1st[1:0] == 2'b00);
        end
        default: begin
          BPE1_i_vld = 0;
        end
      endcase
    end

    // BPEoutReady
    assign BPE1_o_rdy = 1;

    // BPE Coefficient
    always @(*) begin
      case (state_1st)
        4'b0001: begin
          BPE1_coef = COE0_1st;
        end
        4'b0010: begin
          BPE1_coef = COE0_1st;
        end
        4'b0011: begin
          BPE1_coef = COE1_1st;
        end
        4'b0100: begin
          BPE1_coef = COE1_1st;
        end
        4'b0101: begin
          BPE1_coef = COE2_1st;
        end
        4'b0110: begin
          BPE1_coef = COE2_1st;
        end
        default: begin
          BPE1_coef = 0;
        end
      endcase
    end

    // Coefficient (Test)
    assign COE0_1st = W0;
    assign COE1_1st = W0;
    assign COE2_1st = W128;

    /*===============================================================================================
    #                                       2nd BPE                                                 #
    ================================================================================================*/

    // Coefficient
    /*reg [127:0] COE0_2nd;
    reg [127:0] COE1_2nd;
    reg [127:0] COE2_2nd;

    // 2nd BPE IO
    reg [127:0] BPE2_ain;
    reg [127:0] BPE2_bin;
    reg BPE2_i_vld;
    wire BPE2_i_rdy;
    wire [127:0] BPE2_aout;
    wire [127:0] BPE2_bout;
    wire BPE2_o_vld;
    wire BPE2_o_rdy;
    reg [127:0] BPE2_bin_buffer;
    reg [127:0] BPE2_bin_buffer_next;
    reg [127:0] BPE2_coef;

    // FSM for 2nd BPE
    reg BPE_2nd_idle;
    reg [3:0] state_2nd;
    reg [3:0] state_2nd_next;*/

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        state_2nd <= 0;
      end else begin
        state_2nd <= state_2nd_next;
      end
    end

    always @(*) begin
      case (state_2nd)
        4'b0000: begin
          state_2nd_next = (counter_2nd == 254) ? 4'b0001 : state_2nd;
        end
        4'b0001: begin
          state_2nd_next = (counter_2nd == 281) ? 4'b0010 : state_2nd;
        end
        4'b0010: begin
          state_2nd_next = (counter_2nd == 508) ? 4'b0011 : state_2nd;
        end
        4'b0011: begin
          state_2nd_next = (counter_2nd == 536) ? 4'b0100 : state_2nd;
        end
        4'b0100: begin
          state_2nd_next = (counter_2nd == 636) ? 4'b0101 : state_2nd;
        end
        4'b0101: begin
          state_2nd_next = (counter_2nd == 664) ? 4'b0110 : state_2nd;
        end
        4'b0110: begin
          state_2nd_next = (counter_2nd == 764) ? 4'b0111 : state_2nd;
        end
        4'b0111: begin
          state_2nd_next = (counter_2nd == 792) ? 4'b1000 : state_2nd;
        end
        4'b1000: begin
          state_2nd_next = (state_3rd == 4'b0000) ? 4'b1001 : state_2nd;
        end
        4'b1001: begin
          state_2nd_next = (BPE2_out_done) ? 4'b1010 : state_2nd;
        end
        4'b1010: begin
          state_2nd_next = (state_3rd == 4'b0000) ? 4'b1011 : state_2nd;
        end
        4'b1011: begin
          state_2nd_next = (BPE2_out_done) ? 4'b1100 : state_2nd;
        end
        4'b1100: begin
          state_2nd_next = (state_3rd == 4'b0000) ? 4'b1101 : state_2nd;
        end
        4'b1101: begin
          state_2nd_next = (BPE2_out_done) ? 4'b1110 : state_2nd;
        end
        4'b1110: begin
          state_2nd_next = (state_3rd == 4'b0000) ? 4'b1111 : state_2nd;
        end
        4'b1111: begin
          state_2nd_next = (BPE2_out_done) ? 4'b0000 : state_2nd;
        end
        default: begin
          state_2nd_next = 4'b0000;
        end
      endcase
    end

 
    // ====================================counter_2nd===================================== //

    /*reg [15:0] counter_2nd;
    reg [15:0] counter_2nd_delay;
    reg [15:0] counter_2nd_adv;
    reg counting_2nd;
    reg trigger_once_2nd;

    wire [15:0] counter_2nd_next;
    wire [15:0] counter_2nd_delay_next;
    wire [15:0] counter_2nd_adv_next;
    wire counting_2nd_next;
    wire trigger_once_2nd_next;*/

    assign trigger_once_2nd_next  = trigger_once_2nd | ld_vld_2nd;
    assign counting_2nd_next  = (ld_vld_2nd && !trigger_once_2nd) ? 1'b1 :
                                counting_2nd;
    assign counter_2nd_next   = (ld_vld_2nd && !trigger_once_2nd) ? 16'd1 :
                                counting_2nd ? counter_2nd + 1 :
                                counter_2nd;
    assign counter_2nd_delay_next = counter_2nd_next - 27;
    assign counter_2nd_adv_next = counter_2nd_next + 2;

    always @(posedge clk or negedge rstn) begin
      if (~rstn | decode | BPE2_out_done) begin
        counter_2nd    <= 16'd0;
        counting_2nd   <= 1'b0;
        trigger_once_2nd   <= 1'b0;
        counter_2nd_delay <= 16'd0;
        counter_2nd_adv <= 16'd0;
      end else begin
        counter_2nd    <= counter_2nd_next;
        counting_2nd   <= counting_2nd_next;
        trigger_once_2nd   <= trigger_once_2nd_next;
        counter_2nd_delay <= counter_2nd_delay_next;
        counter_2nd_adv <= counter_2nd_adv_next;
      end
    end



    // ====================================Output Logic=========================================== //
    
    assign enable_output_2nd = 
    (state_2nd == 4'b1001 || 
     state_2nd == 4'b1011 || 
     state_2nd == 4'b1101 || 
     state_2nd == 4'b1111);

    /*wire enable_output_2nd;
    wire [127:0] ld_dat_3rd;
    wire ld_vld_3rd;
    reg BPE2_out_done;

    reg [11:0] counter_2nd_output;
    wire [11:0] counter_2nd_output_next;
    wire BPE2_out_done_next; */

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        counter_2nd_output <= 0;
      end else begin
        counter_2nd_output <= counter_2nd_output_next;
      end
    end

    assign counter_2nd_output_next = (enable_output_2nd) ? counter_2nd_output + 1 : 0;

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        BPE2_out_done <= 0;
      end else begin
        BPE2_out_done <= BPE2_out_done_next;
      end
    end

    assign BPE2_out_done_next = (counter_2nd_output == 124);

    assign ld_vld_3rd = enable_output_2nd & (counter_2nd_output[1:0] == 2'b00);

    assign ld_dat_3rd = (enable_output_2nd) ? sram_dout_2nd : 0;
    

    // ====================================Data Ram Logic========================================= //
   
    /*reg  [255:0] data_to_sram_2nd;      
    wire [127:0] sram_din_2nd;
    reg          sram_we_2nd;
    reg          sram_en_2nd;
    reg  [25:0]  sram_addr_one_cycle_2nd;
    wire  [12:0] sram_addr_2nd;
    reg  [127:0] sram_dout_2nd;*/

    assign sram_din_2nd = (phase) ? data_to_sram_2nd[255:128] : data_to_sram_2nd[127:0];
    assign sram_addr_2nd = (phase) ? sram_addr_one_cycle_2nd[25:13] : sram_addr_one_cycle_2nd[12:0];

    // SRAM_WE
    always @(*) begin
      case (state_2nd)
        4'b0000: begin
          sram_we_2nd = (phase) & (counter_2nd[1:0] == 2'b00); 
        end
        4'b0001: begin
          sram_we_2nd = 0;
        end
        4'b0010: begin
          sram_we_2nd = (counter_2nd[1:0] == 2'b11);
        end
        4'b0011: begin
          sram_we_2nd = (counter_2nd[1:0] == 2'b11);
        end
        4'b0100: begin
          sram_we_2nd = (counter_2nd[1:0] == 2'b11);
        end
        4'b0101: begin
          sram_we_2nd = (counter_2nd[1:0] == 2'b11);
        end
        4'b0110: begin
          sram_we_2nd = (counter_2nd[1:0] == 2'b11);
        end
        4'b0111: begin
          sram_we_2nd = (counter_2nd[1:0] == 2'b11);
        end
        default: begin
          sram_we_2nd = 0;
        end
      endcase
    end


    // SRAM_EN
    always @(*) begin
      case (state_2nd)
        4'b0000: begin
          sram_en_2nd = (counter_2nd[1:0] == 2'b00); 
        end
        4'b0001: begin
          sram_en_2nd = (counter_2nd[1:0] == 2'b00) | (counter_2nd[1:0] == 2'b11);
        end
        4'b0010: begin
          sram_en_2nd = ~(counter_2nd[1:0] == 2'b01);
        end
        4'b0011: begin
          sram_en_2nd = ~(counter_2nd[1:0] == 2'b01);
        end
        4'b0100: begin
          sram_en_2nd = ~(counter_2nd[1:0] == 2'b01);
        end
        4'b0101: begin
          sram_en_2nd = ~(counter_2nd[1:0] == 2'b01);
        end
        4'b0110: begin
          sram_en_2nd = ~(counter_2nd[1:0] == 2'b01);
        end
        4'b0111: begin
          sram_en_2nd = ~(counter_2nd[1:0] == 2'b01);
        end
        4'b1001: begin
          sram_en_2nd = (counter_2nd_output[1:0] == 2'b00);
        end
        4'b1011: begin
          sram_en_2nd = (counter_2nd_output[1:0] == 2'b00);
        end
        4'b1101: begin
          sram_en_2nd = (counter_2nd_output[1:0] == 2'b00);
        end
        4'b1111: begin
          sram_en_2nd = (counter_2nd_output[1:0] == 2'b00);
        end
        default: begin
          sram_en_2nd = 0;
        end
      endcase
    end

    // Data_to_SRAM
    always @(*) begin
      case (state_2nd)
        4'b0000: begin
          data_to_sram_2nd = {ld_dat_2nd[127:0], 128'b0}; 
        end
        4'b0001: begin
          data_to_sram_2nd = 0;
        end
        4'b0010: begin
          data_to_sram_2nd = {BPE2_bout[127:0], BPE2_aout[127:0]};
        end
        4'b0011: begin
          data_to_sram_2nd = {BPE2_bout[127:0], BPE2_aout[127:0]};
        end
        4'b0100: begin
          data_to_sram_2nd = {BPE2_bout[127:0], BPE2_aout[127:0]};
        end
        4'b0101: begin
          data_to_sram_2nd = {BPE2_bout[127:0], BPE2_aout[127:0]};
        end
        4'b0110: begin
          data_to_sram_2nd = {BPE2_bout[127:0], BPE2_aout[127:0]};
        end
        4'b0111: begin
          data_to_sram_2nd = {BPE2_bout[127:0], BPE2_aout[127:0]};
        end
        default: begin
          data_to_sram_2nd = 0;
        end
      endcase
    end

    // Sram Address
    always @(*) begin
      case (state_2nd)
        4'b0000: begin
          sram_addr_one_cycle_2nd = {5'b0, counter_2nd[7:0], 13'b0}; 
        end
        4'b0001: begin
          sram_addr_one_cycle_2nd = {13'b0, 5'b0, counter_2nd[7:0]};                                                                                   
        end
        4'b0010: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {5'b00001, counter_2nd_delay[7:0], 5'b0, counter_2nd_delay[7:0]} : {13'b0, 5'b0, counter_2nd[7:0]};
        end
        4'b0011: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {5'b00001, counter_2nd_delay[7:0], 5'b0, counter_2nd_delay[7:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 6'b0, counter_2nd[6:0]} : {13'b0, 6'b000001, counter_2nd_adv[6:0]};
        end
        4'b0100: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {6'b000001, counter_2nd_delay[6:0], 6'b0, counter_2nd_delay[6:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 6'b0, counter_2nd[6:0]} : {13'b0, 6'b000001, counter_2nd_adv[6:0]};
        end
        4'b0101: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {6'b000001, counter_2nd_delay[6:0], 6'b0, counter_2nd_delay[6:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 6'b000010, counter_2nd[6:0]} : {13'b0, 6'b000011, counter_2nd_adv[6:0]};
        end
        4'b0110: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {6'b000011, counter_2nd_delay[6:0], 6'b000010, counter_2nd_delay[6:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 6'b000010, counter_2nd[6:0]} : {13'b0, 6'b000011, counter_2nd_adv[6:0]};
        end
        4'b0111: begin
          sram_addr_one_cycle_2nd = {6'b000011, counter_2nd_delay[6:0], 6'b000010, counter_2nd_delay[6:0]};
        end
        4'b1001: begin
          sram_addr_one_cycle_2nd = {13'b0, 6'b0, counter_2nd_output[6:0]};
        end
        4'b1011: begin
          sram_addr_one_cycle_2nd = {13'b0, 6'b000001, counter_2nd_output[6:0]};
        end
        4'b1101: begin
          sram_addr_one_cycle_2nd = {13'b0, 6'b000010, counter_2nd_output[6:0]};
        end
        4'b1111: begin
          sram_addr_one_cycle_2nd = {13'b0, 6'b000011, counter_2nd_output[6:0]};
        end
        default: begin
          sram_addr_one_cycle_2nd = 0;
        end
      endcase
    end


 // ====================================BPE input========================================= //

    // BPEinA
    always @(*) begin
      case (state_2nd)
        4'b0001: begin
          BPE2_ain = sram_dout_2nd;
        end
        4'b0010: begin
          BPE2_ain = sram_dout_2nd;
        end
        4'b0011: begin
          BPE2_ain = sram_dout_2nd;
        end
        4'b0100: begin
          BPE2_ain = sram_dout_2nd;
        end
        4'b0101: begin
          BPE2_ain = sram_dout_2nd;
        end
        4'b0110: begin
          BPE2_ain = sram_dout_2nd;
        end
        default: begin
          BPE2_ain = 0;
        end
      endcase
    end

    //BPEinPreBuffer
    always @(posedge clk) begin
       BPE2_bin_buffer <= BPE2_bin_buffer_next;
    end


    // BPEinBpreBufferNext
    always @(*) begin
      case (state_2nd)
        4'b0011: begin
          BPE2_bin_buffer_next = (counter_2nd[1:0] == 2'b10) ? sram_dout_2nd : BPE2_bin_buffer;
        end
        4'b0100: begin
          BPE2_bin_buffer_next = (counter_2nd[1:0] == 2'b10) ? sram_dout_2nd : BPE2_bin_buffer;
        end
        4'b0101: begin
          BPE2_bin_buffer_next = (counter_2nd[1:0] == 2'b10) ? sram_dout_2nd : BPE2_bin_buffer;
        end
        4'b0110: begin
          BPE2_bin_buffer_next = (counter_2nd[1:0] == 2'b10) ? sram_dout_2nd : BPE2_bin_buffer;
        end
        default: begin
          BPE2_bin_buffer_next = 0;
        end
      endcase
    end

    // BPEinB
    always @(*) begin
      case (state_2nd)
        4'b0001: begin
          BPE2_bin = ld_dat_2nd;
        end
        4'b0010: begin
          BPE2_bin = ld_dat_2nd;
        end
        4'b0011: begin
          BPE2_bin = BPE2_bin_buffer;
        end
        4'b0100: begin
          BPE2_bin = BPE2_bin_buffer;
        end
        4'b0101: begin
          BPE2_bin = BPE2_bin_buffer;
        end
        4'b0110: begin
          BPE2_bin = BPE2_bin_buffer;
        end
        default: begin
          BPE2_bin = 0;
        end
      endcase
    end

    // BPEinValid
    always @(*) begin
      case (state_2nd)
        4'b0001: begin
          BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
        end
        4'b0010: begin
          BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
        end
        4'b0011: begin
          BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
        end
        4'b0100: begin
          BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
        end
        4'b0101: begin
          BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
        end
        4'b0110: begin
          BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
        end
        default: begin
          BPE2_i_vld = 0;
        end
      endcase
    end

    // BPEoutReady
    assign BPE2_o_rdy = 1;

    // BPE Coefficient
    always @(*) begin
      case (state_2nd)
        4'b0001: begin
          BPE2_coef = COE0_2nd;
        end
        4'b0010: begin
          BPE2_coef = COE0_2nd;
        end
        4'b0011: begin
          BPE2_coef = COE1_2nd;
        end
        4'b0100: begin
          BPE2_coef = COE1_2nd;
        end
        4'b0101: begin
          BPE2_coef = COE2_2nd;
        end
        4'b0110: begin
          BPE2_coef = COE2_2nd;
        end
        default: begin
          BPE2_coef = 0;
        end
      endcase
    end

    reg [1:0] coef_counter;
    wire [1:0] coef_counter_next;

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        coef_counter <= 0;
      end else begin
        coef_counter <= coef_counter_next;
      end
    end

    assign coef_counter_next = (counter_2nd == 740) ? coef_counter + 1 : coef_counter; 

    // Coefficient (Test)
    always @(*) begin
      case (coef_counter)
        2'b00: begin
          COE0_2nd = W0;
          COE1_2nd = W0;
          COE2_2nd = W128;
        end
        2'b01: begin
          COE0_2nd = W128;
          COE1_2nd = W64;
          COE2_2nd = W192;
        end
        2'b10: begin
          COE0_2nd = W64;
          COE1_2nd = W32;
          COE2_2nd = W160;
        end
        2'b11: begin
          COE0_2nd = W192;
          COE1_2nd = W96;
          COE2_2nd = W224;
        end  
      endcase
    end 

    /*===============================================================================================
    #                                       3rd BPE                                                 #
    ================================================================================================*/

     // Coefficient
    /*reg [127:0] COE0_3rd;
    reg [127:0] COE1_3rd;
    reg [127:0] COE2_3rd;

    wire [127:0] COE0_3rd_tmp;
    wire [127:0] COE1_3rd_tmp;
    wire [127:0] COE2_3rd_tmp;

    // 3rd BPE IO
    reg [127:0] BPE3_ain;
    reg [127:0] BPE3_bin;
    reg BPE3_i_vld;
    wire BPE3_i_rdy;
    wire [127:0] BPE3_aout;
    wire [127:0] BPE3_bout;
    wire BPE3_o_vld;
    wire BPE3_o_rdy;
    reg [127:0] BPE3_bin_buffer;
    reg [127:0] BPE3_bin_buffer_next;
    reg [127:0] BPE3_coef;

    // FSM for 3rd BPE
    reg BPE_3rd_idle;
    reg [3:0] state_3rd;
    reg [3:0] state_3rd_next;*/

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        state_3rd <= 0;
      end else begin
        state_3rd <= state_3rd_next;
      end
    end

    always @(*) begin
      case (state_3rd)
        4'b0000: begin
          state_3rd_next = (counter_3rd == 62) ? 4'b0001 : state_3rd;
        end
        4'b0001: begin
          state_3rd_next = (counter_3rd == 87) ? 4'b0010 : state_3rd;
        end
        4'b0010: begin
          state_3rd_next = (counter_3rd == 124) ? 4'b0011 : state_3rd;
        end
        4'b0011: begin
          state_3rd_next = (counter_3rd == 152) ? 4'b0100 : state_3rd;
        end
        4'b0100: begin
          state_3rd_next = (counter_3rd == 156) ? 4'b0101 : state_3rd;
        end
        4'b0101: begin
          state_3rd_next = (counter_3rd == 184) ? 4'b0110 : state_3rd;
        end
        4'b0110: begin
          state_3rd_next = (counter_3rd == 188) ? 4'b0111 : state_3rd;
        end
        4'b0111: begin
          state_3rd_next = (counter_3rd == 216) ? 4'b1000 : state_3rd;
        end
        4'b1000: begin
          state_3rd_next = (BPE4_idle) ? 4'b1001 : state_3rd;
        end
        4'b1001: begin
          state_3rd_next = (BPE3_out_done) ? 4'b1010 : state_3rd;
        end
        4'b1010: begin
          state_3rd_next = (BPE4_idle) ? 4'b1011 : state_3rd;
        end
        4'b1011: begin
          state_3rd_next = (BPE3_out_done) ? 4'b1100 : state_3rd;
        end
        4'b1100: begin
          state_3rd_next = (BPE4_idle) ? 4'b1101 : state_3rd;
        end
        4'b1101: begin
          state_3rd_next = (BPE3_out_done) ? 4'b1110 : state_3rd;
        end
        4'b1110: begin
          state_3rd_next = (BPE4_idle) ? 4'b1111 : state_3rd;
        end
        4'b1111: begin
          state_3rd_next = (BPE3_out_done) ? 4'b0000 : state_3rd;
        end
        default: begin
          state_3rd_next = 4'b0000;
        end
      endcase
    end

 
    // ====================================counter_3rd===================================== //

    /*reg [15:0] counter_3rd;
    reg [15:0] counter_3rd_delay;
    reg [15:0] counter_3rd_adv;
    reg counting_3rd;
    reg trigger_once_3rd;

    wire [15:0] counter_3rd_next;
    wire [15:0] counter_3rd_delay_next;
    wire [15:0] counter_3rd_adv_next;
    wire counting_3rd_next;
    wire trigger_once_3rd_next;*/

    assign trigger_once_3rd_next  = trigger_once_3rd | ld_vld_3rd;
    assign counting_3rd_next  = (ld_vld_3rd && !trigger_once_3rd) ? 1'b1 :
                                counting_3rd;
    assign counter_3rd_next   = (ld_vld_3rd && !trigger_once_3rd) ? 16'd1 :
                                counting_3rd ? counter_3rd + 1 :
                                counter_3rd;
    assign counter_3rd_delay_next = counter_3rd_next - 27;
    assign counter_3rd_adv_next = counter_3rd_next + 2;

    always @(posedge clk or negedge rstn) begin
      if (~rstn | decode | BPE3_out_done) begin
        counter_3rd    <= 16'd0;
        counting_3rd   <= 1'b0;
        trigger_once_3rd   <= 1'b0;
        counter_3rd_delay <= 16'd0;
        counter_3rd_adv <= 16'd0;
      end else begin
        counter_3rd    <= counter_3rd_next;
        counting_3rd   <= counting_3rd_next;
        trigger_once_3rd   <= trigger_once_3rd_next;
        counter_3rd_delay <= counter_3rd_delay_next;
        counter_3rd_adv <= counter_3rd_adv_next;
      end
    end



    // ====================================Output Logic=========================================== //
    assign enable_output_3rd = 
    (state_3rd == 4'b1001 || 
     state_3rd == 4'b1011 || 
     state_3rd == 4'b1101 || 
     state_3rd == 4'b1111);

    /*wire enable_output_3rd;
    wire [127:0] ld_dat_4th;
    wire ld_vld_4th;
    reg BPE3_out_done;

    reg [11:0] counter_3rd_output;
    wire [11:0] counter_3rd_output_next;
    wire BPE3_out_done_next; */

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        counter_3rd_output <= 0;
      end else begin
        counter_3rd_output <= counter_3rd_output_next;
      end
    end

    assign counter_3rd_output_next = (enable_output_3rd) ? counter_3rd_output + 1 : 0;

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        BPE3_out_done <= 0;
      end else begin
        BPE3_out_done <= BPE3_out_done_next;
      end
    end

    assign BPE3_out_done_next = (counter_3rd_output == 7);

    assign ld_vld_4th = enable_output_3rd & (~BPE3_out_done);
    assign ld_dat_4th = (enable_output_3rd) ? sram_dout_3rd : 0;
    

    // ====================================Data Ram Logic========================================= //
   
    /*reg  [255:0] data_to_sram_3rd;      
    wire [127:0] sram_din_3rd;
    reg          sram_we_3rd;
    reg          sram_en_3rd;
    reg  [25:0]  sram_addr_one_cycle_3rd;
    wire  [12:0] sram_addr_3rd;
    reg  [127:0] sram_dout_3rd;*/

    assign sram_din_3rd = (phase) ? data_to_sram_3rd[255:128] : data_to_sram_3rd[127:0];
    assign sram_addr_3rd = (phase) ? sram_addr_one_cycle_3rd[25:13] : sram_addr_one_cycle_3rd[12:0];

    // SRAM_WE
    always @(*) begin
      case (state_3rd)
        4'b0000: begin
          sram_we_3rd = (phase) & (counter_3rd[1:0] == 2'b00); 
        end
        4'b0001: begin
          sram_we_3rd = 0;
        end
        4'b0010: begin
          sram_we_3rd = (counter_3rd[1:0] == 2'b11);
        end
        4'b0011: begin
          sram_we_3rd = (counter_3rd[1:0] == 2'b11);
        end
        4'b0100: begin
          sram_we_3rd = (counter_3rd[1:0] == 2'b11);
        end
        4'b0101: begin
          sram_we_3rd = (counter_3rd[1:0] == 2'b11);
        end
        4'b0110: begin
          sram_we_3rd = (counter_3rd[1:0] == 2'b11);
        end
        4'b0111: begin
          sram_we_3rd = (counter_3rd[1:0] == 2'b11);
        end
        default: begin
          sram_we_3rd = 0;
        end
      endcase
    end


    // SRAM_EN
    always @(*) begin
      case (state_3rd)
        4'b0000: begin
          sram_en_3rd = (counter_3rd[1:0] == 2'b00); 
        end
        4'b0001: begin
          sram_en_3rd = (counter_3rd[1:0] == 2'b00) | (counter_3rd[1:0] == 2'b11);
        end
        4'b0010: begin
          sram_en_3rd = ~(counter_3rd[1:0] == 2'b01);
        end
        4'b0011: begin
          sram_en_3rd = ~(counter_3rd[1:0] == 2'b01);
        end
        4'b0100: begin
          sram_en_3rd = ~(counter_3rd[1:0] == 2'b01);
        end
        4'b0101: begin
          sram_en_3rd = ~(counter_3rd[1:0] == 2'b01);
        end
        4'b0110: begin
          sram_en_3rd = ~(counter_3rd[1:0] == 2'b01);
        end
        4'b0111: begin
          sram_en_3rd = ~(counter_3rd[1:0] == 2'b01);
        end
        4'b1001: begin
          sram_en_3rd = 1;
        end
        4'b1011: begin
          sram_en_3rd = 1;
        end
        4'b1101: begin
          sram_en_3rd = 1;
        end
        4'b1111: begin
          sram_en_3rd = 1;
        end
        default: begin
          sram_en_3rd = 0;
        end
      endcase
    end

    // Data_to_SRAM
    always @(*) begin
      case (state_3rd)
        4'b0000: begin
          data_to_sram_3rd = {ld_dat_3rd[127:0], 128'b0}; 
        end
        4'b0001: begin
          data_to_sram_3rd = 0;
        end
        4'b0010: begin
          data_to_sram_3rd = {BPE3_bout[127:0], BPE3_aout[127:0]};
        end
        4'b0011: begin
          data_to_sram_3rd = {BPE3_bout[127:0], BPE3_aout[127:0]};
        end
        4'b0100: begin
          data_to_sram_3rd = {BPE3_bout[127:0], BPE3_aout[127:0]};
        end
        4'b0101: begin
          data_to_sram_3rd = {BPE3_bout[127:0], BPE3_aout[127:0]};
        end
        4'b0110: begin
          data_to_sram_3rd = {BPE3_bout[127:0], BPE3_aout[127:0]};
        end
        4'b0111: begin
          data_to_sram_3rd = {BPE3_bout[127:0], BPE3_aout[127:0]};
        end
        default: begin
          data_to_sram_3rd = 0;
        end
      endcase
    end

    // Sram Address
    always @(*) begin
      case (state_3rd)
        4'b0000: begin
          sram_addr_one_cycle_3rd = {7'b0, counter_3rd[5:0], 13'b0}; 
        end
        4'b0001: begin
          sram_addr_one_cycle_3rd = {13'b0, 7'b0, counter_3rd[5:0]};                                                                                   
        end
        4'b0010: begin
          sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b11) ? {7'b0000001, counter_3rd_delay[5:0], 7'b0, counter_3rd_delay[5:0]} : {13'b0, 7'b0, counter_3rd[5:0]};
        end
        4'b0011: begin
          sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b11) ? {7'b0000001, counter_3rd_delay[5:0], 7'b0, counter_3rd_delay[5:0]} :
                                (counter_3rd[1:0] == 2'b00) ? {13'b0, 8'b0, counter_3rd[4:0]} : {13'b0, 8'b00000001, counter_3rd_adv[4:0]};
        end
        4'b0100: begin
          sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b11) ? {8'b00000001, counter_3rd_delay[4:0], 8'b0, counter_3rd_delay[4:0]} :
                                (counter_3rd[1:0] == 2'b00) ? {13'b0, 8'b0, counter_3rd[4:0]} : {13'b0, 8'b00000001, counter_3rd_adv[4:0]};
        end
        4'b0101: begin
          sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b11) ? {8'b00000001, counter_3rd_delay[4:0], 8'b0, counter_3rd_delay[4:0]} :
                                (counter_3rd[1:0] == 2'b00) ? {13'b0, 8'b00000010, counter_3rd[4:0]} : {13'b0, 8'b00000011, counter_3rd_adv[4:0]};
        end
        4'b0110: begin
          sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b11) ? {8'b00000011, counter_3rd_delay[4:0], 8'b00000010, counter_3rd_delay[4:0]} :
                                (counter_3rd[1:0] == 2'b00) ? {13'b0, 8'b00000010, counter_3rd[4:0]} : {13'b0, 8'b00000011, counter_3rd_adv[4:0]};
        end
        4'b0111: begin
          sram_addr_one_cycle_3rd = {8'b00000011, counter_3rd_delay[4:0], 8'b00000010, counter_3rd_delay[4:0]};
        end
        4'b1001: begin
          sram_addr_one_cycle_3rd = {13'b0, 8'b0, counter_3rd_output[2:0], 2'b0};
        end
        4'b1011: begin
          sram_addr_one_cycle_3rd = {13'b0, 6'b0, 2'b01, counter_3rd_output[2:0], 2'b0};
        end
        4'b1101: begin
          sram_addr_one_cycle_3rd = {13'b0, 6'b0, 2'b10, counter_3rd_output[2:0], 2'b0};
        end
        4'b1111: begin
          sram_addr_one_cycle_3rd = {13'b0, 6'b0, 2'b11, counter_3rd_output[2:0], 2'b0};
        end
        default: begin
          sram_addr_one_cycle_3rd = 0;
        end
      endcase
    end


 // ====================================BPE input========================================= //

    // BPEinA
    always @(*) begin
      case (state_3rd)
        4'b0001: begin
          BPE3_ain = sram_dout_3rd;
        end
        4'b0010: begin
          BPE3_ain = sram_dout_3rd;
        end
        4'b0011: begin
          BPE3_ain = sram_dout_3rd;
        end
        4'b0100: begin
          BPE3_ain = sram_dout_3rd;
        end
        4'b0101: begin
          BPE3_ain = sram_dout_3rd;
        end
        4'b0110: begin
          BPE3_ain = sram_dout_3rd;
        end
        default: begin
          BPE3_ain = 0;
        end
      endcase
    end

    //BPEinPreBuffer
    always @(posedge clk) begin
       BPE3_bin_buffer <= BPE3_bin_buffer_next;
    end


    // BPEinBpreBufferNext
    always @(*) begin
      case (state_3rd)
        4'b0011: begin
          BPE3_bin_buffer_next = (counter_3rd[1:0] == 2'b10) ? sram_dout_3rd : BPE3_bin_buffer;
        end
        4'b0100: begin
          BPE3_bin_buffer_next = (counter_3rd[1:0] == 2'b10) ? sram_dout_3rd : BPE3_bin_buffer;
        end
        4'b0101: begin
          BPE3_bin_buffer_next = (counter_3rd[1:0] == 2'b10) ? sram_dout_3rd : BPE3_bin_buffer;
        end
        4'b0110: begin
          BPE3_bin_buffer_next = (counter_3rd[1:0] == 2'b10) ? sram_dout_3rd : BPE3_bin_buffer;
        end
        default: begin
          BPE2_bin_buffer_next = 0;
        end
      endcase
    end

    // BPEinB
    always @(*) begin
      case (state_3rd)
        4'b0001: begin
          BPE3_bin = ld_dat_3rd;
        end
        4'b0010: begin
          BPE3_bin = ld_dat_3rd;
        end
        4'b0011: begin
          BPE3_bin = BPE3_bin_buffer;
        end
        4'b0100: begin
          BPE3_bin = BPE3_bin_buffer;
        end
        4'b0101: begin
          BPE3_bin = BPE3_bin_buffer;
        end
        4'b0110: begin
          BPE3_bin = BPE3_bin_buffer;
        end
        default: begin
          BPE3_bin = 0;
        end
      endcase
    end

    // BPEinValid
    always @(*) begin
      case (state_3rd)
        4'b0001: begin
          BPE3_i_vld = (counter_3rd[1:0] == 2'b00);
        end
        4'b0010: begin
          BPE3_i_vld = (counter_3rd[1:0] == 2'b00);
        end
        4'b0011: begin
          BPE3_i_vld = (counter_3rd[1:0] == 2'b00);
        end
        4'b0100: begin
          BPE3_i_vld = (counter_3rd[1:0] == 2'b00);
        end
        4'b0101: begin
          BPE3_i_vld = (counter_3rd[1:0] == 2'b00);
        end
        4'b0110: begin
          BPE3_i_vld = (counter_3rd[1:0] == 2'b00);
        end
        default: begin
          BPE3_i_vld = 0;
        end
      endcase
    end

    // BPEoutReady
    assign BPE3_o_rdy = 1;

    // BPE Coefficient
    always @(*) begin
      case (state_3rd)
        4'b0001: begin
          BPE3_coef = COE0_3rd;
        end
        4'b0010: begin
          BPE3_coef = COE0_3rd;
        end
        4'b0011: begin
          BPE3_coef = COE1_3rd;
        end
        4'b0100: begin
          BPE3_coef = COE1_3rd;
        end
        4'b0101: begin
          BPE3_coef = COE2_3rd;
        end
        4'b0110: begin
          BPE3_coef = COE2_3rd;
        end
        default: begin
          BPE3_coef = 0;
        end
      endcase
    end

    assign bpe_act[2] = (counter_3rd == 1);
    assign COE0_3rd_tmp = (counter_3rd == 3) ? coef_dat : COE0_3rd;
    assign COE1_3rd_tmp = (counter_3rd == 4) ? coef_dat : COE1_3rd; 
    assign COE2_3rd_tmp = (counter_3rd == 5) ? coef_dat : COE2_3rd; 

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        COE0_3rd <= 0;
        COE1_3rd <= 0;
        COE2_3rd <= 0;
      end else begin
        COE0_3rd <= COE0_3rd_tmp;
        COE1_3rd <= COE1_3rd_tmp;
        COE2_3rd <= COE2_3rd_tmp;
      end
    end


    /*===============================================================================================
    #                                       4th BPE                                                 #
    ================================================================================================*/
    
    BPE_4th_module STAGE7_8(
        .clk          (clk),
        .rstn         (rstn),
        .ss_vld_4th   (ld_vld_4th),
        .ss_rdy_4th   (ss_rdy_4th),
        .sm_vld_4th   (sm_vld_4th),
        .sm_rdy_4th   (sm_rdy_4th),
        .ld_dat_4th   (ld_dat_4th),
        .nxt_dat_4th  (data_789),
        .coef_4th_vld (coef_vld),
        .coef_4th_rdy (coef_rdy),
        .coef_dat     (coef_dat),
        .mode_state   (mode_state),
        .bpe_act      (bpe_act[3])
    );
    BPE_5th_module STAGE9(
        .clk          (clk),
        .rstn         (rstn),
        .ss_vld_5th   (ss_vld_5th),
        .ss_rdy_5th   (ss_rdy_5th),
        .sm_vld_5th   (sm_vld_5th),
        .sm_rdy_5th   (sm_rdy_5th),
        .ld_dat_5th   (data_789),
        .nxt_dat_5th  (BPE5_dout),
        .coef_5th_vld (coef_vld),
        .coef_5th_rdy (coef_rdy),
        .coef_dat     (coef_dat),
        .mode_state   (mode_state),
        .bpe_act      (bpe_act[4])
    );

    // =========================== Output Buffer ========================== // 
    // reg [pDATA_WIDTH:0] output_buffer_w[0:7];
    // reg [pDATA_WIDTH:0] output_buffer[0:7]; //
    // reg [$clog2(pDATA_WIDTH)-1:0] output_buf_in_cnt_r; 
    // reg [$clog2(pDATA_WIDTH)-1:0] output_buf_in_cnt_w; // input counter for output buffer
    // wire [pDATA_WIDTH-1:0] BPE5_dout;

    integer i;
    always@(posedge clk or negedge rstn) begin
        if (~rstn) begin
          for (i = 0; i < 8; i = i + 1) begin
            output_buffer[i] <= 0;
          end
        end else begin
          for (i = 0; i < 8; i = i + 1) begin
            output_buffer[i] <= output_buffer_w[i];
          end
        end
    end

    // always@(*)begin // output buffer for 32 bit BW
    //   for (i = 0; i < 8; i = i + 1) output_buffer_w[i] = output_buffer[i];
    //   case(output_buf_in_cnt_r[0+:3]) // valid pulled down when output finished
    //     3'b000: output_buffer_w[0] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd0) & (&out_byte_cnt_r) ? output_buffer[0]>>1 : output_buffer[0]);
    //     3'b001: output_buffer_w[1] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd1) & (&out_byte_cnt_r) ? output_buffer[1]>>1 : output_buffer[1]);;
    //     3'b010: output_buffer_w[2] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd2) & (&out_byte_cnt_r) ? output_buffer[2]>>1 : output_buffer[2]);;
    //     3'b011: output_buffer_w[3] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd3) & (&out_byte_cnt_r) ? output_buffer[3]>>1 : output_buffer[3]);;
    //     3'b100: output_buffer_w[4] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd4) & (&out_byte_cnt_r) ? output_buffer[4]>>1 : output_buffer[4]);;
    //     3'b101: output_buffer_w[5] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd5) & (&out_byte_cnt_r) ? output_buffer[5]>>1 : output_buffer[5]);;
    //     3'b110: output_buffer_w[6] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd6) & (&out_byte_cnt_r) ? output_buffer[6]>>1 : output_buffer[6]);;
    //     3'b111: output_buffer_w[7] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
    //                                  ((kern_out_cnt_r == 3'd7) & (&out_byte_cnt_r) ? output_buffer[7]>>1 : output_buffer[7]);;
    //     default: begin
    //       output_buffer_w[0] = output_buffer[0];
    //       output_buffer_w[1] = output_buffer[1];
    //       output_buffer_w[2] = output_buffer[2];
    //       output_buffer_w[3] = output_buffer[3];
    //       output_buffer_w[4] = output_buffer[4];
    //       output_buffer_w[5] = output_buffer[5];
    //       output_buffer_w[6] = output_buffer[6];
    //       output_buffer_w[7] = output_buffer[7];
    //     end
    //   endcase
    // end
    always@(*)begin // output buffer for 32 bit BW
      for (i = 0; i < 8; i = i + 1) output_buffer_w[i] = output_buffer[i];
      case(output_buf_in_cnt_r[0+:3]) // valid pulled down when output finished
        3'b000: output_buffer_w[0] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd0) ? output_buffer[0]>>1 : output_buffer[0]);
        3'b001: output_buffer_w[1] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd1) ? output_buffer[1]>>1 : output_buffer[1]);
        3'b010: output_buffer_w[2] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd2) ? output_buffer[2]>>1 : output_buffer[2]);
        3'b011: output_buffer_w[3] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd3) ? output_buffer[3]>>1 : output_buffer[3]);
        3'b100: output_buffer_w[4] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd4) ? output_buffer[4]>>1 : output_buffer[4]);
        3'b101: output_buffer_w[5] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd5) ? output_buffer[5]>>1 : output_buffer[5]);
        3'b110: output_buffer_w[6] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd6) ? output_buffer[6]>>1 : output_buffer[6]);
        3'b111: output_buffer_w[7] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : 
                                     ((kern_out_cnt_r[0+:3] == 3'd7) ? output_buffer[7]>>1 : output_buffer[7]);
        default: begin
          output_buffer_w[0] = output_buffer[0];
          output_buffer_w[1] = output_buffer[1];
          output_buffer_w[2] = output_buffer[2];
          output_buffer_w[3] = output_buffer[3];
          output_buffer_w[4] = output_buffer[4];
          output_buffer_w[5] = output_buffer[5];
          output_buffer_w[6] = output_buffer[6];
          output_buffer_w[7] = output_buffer[7];
        end
      endcase
    end

    
    // assign out_byte_cnt_w = (sw_vld & sw_rdy) ? out_byte_cnt_r + 1 : out_byte_cnt_r;
    assign kern_out_cnt_w = (sw_vld & sw_rdy) & (&out_byte_cnt_r) ? kern_out_cnt_r + 1 : kern_out_cnt_r; 
    // assign sw_data = output_buffer[output_buf_in_cnt_r[0+:3]][(kern_out_cnt_r << 5) +: (pDATA_WIDTH >> 2)];                      
    assign sw_data = output_buffer[output_buf_in_cnt_r[0+:3]];
    assign sw_vld = output_buffer[output_buf_in_cnt_r[0+:3]][pDATA_WIDTH];

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        kern_out_cnt_r <= 0;
        out_byte_cnt_r <= 0;
      end else begin
        kern_out_cnt_r <= kern_out_cnt_w;
        out_byte_cnt_r <= out_byte_cnt_w;
      end
    end







    wire [3:0] WE1;
    wire [3:0] WE2;
    wire [3:0] WE3;

    assign WE1 = {4{sram_we}};
    assign WE2 = {4{sram_we_2nd}};
    assign WE3 = {4{sram_we_3rd}};

    butterfly BPE1 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (mode_state),
        .i_vld (BPE1_i_vld),
        .i_rdy (BPE1_i_rdy),
        .o_vld (BPE1_o_vld),
        .o_rdy (BPE1_o_rdy),
        .ai    (BPE1_ain),
        .bi    (BPE1_bin),
        .gm    (BPE1_coef),
        .ao    (BPE1_aout),
        .bo    (BPE1_bout)
    );

    butterfly BPE2 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (mode_state),
        .i_vld (BPE2_i_vld),
        .i_rdy (BPE2_i_rdy),
        .o_vld (BPE2_o_vld),
        .o_rdy (BPE2_o_rdy),
        .ai    (BPE2_ain),
        .bi    (BPE2_bin),
        .gm    (BPE2_coef),
        .ao    (BPE2_aout),
        .bo    (BPE2_bout)
    );

    butterfly BPE3 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (mode_state),
        .i_vld (BPE3_i_vld),
        .i_rdy (BPE3_i_rdy),
        .o_vld (BPE3_o_vld),
        .o_rdy (BPE3_o_rdy),
        .ai    (BPE3_ain),
        .bi    (BPE3_bin),
        .gm    (BPE3_coef),
        .ao    (BPE3_aout),
        .bo    (BPE3_bout)
    );
    bram512x128 SRAM1 (
        .CLK(clk_2x),
        .WE(WE1),
        .EN(sram_en),
        .Di(sram_din),
        .Do(sram_dout),
        .A(sram_addr)
    );

    bram128x128 SRAM2 (
        .CLK(clk_2x),
        .WE(WE2),
        .EN(sram_en_2nd),
        .Di(sram_din_2nd),
        .Do(sram_dout_2nd),
        .A(sram_addr_2nd)
    );

    bram32x128 SRAM3 (
        .CLK(clk_2x),
        .WE(WE3),
        .EN(sram_en_3rd),
        .Di(sram_din_3rd),
        .Do(sram_dout_3rd),
        .A(sram_addr_3rd)
    );

endmodule

module BPE_4th_module #(
    parameter pDATA_WIDTH = 128,
    parameter MUL_DELAY = 27, // delay of butterfly
    parameter INPUT_DELAY = 4 
)(
    input  wire                     clk, 
    input  wire                     rstn,

    input  wire                     ss_vld_4th,
    output wire                     ss_rdy_4th, // ready to receive data from 4th BPE
    output wire                     sm_vld_4th, 
    input  wire                     sm_rdy_4th,
    input  wire [(pDATA_WIDTH-1):0] ld_dat_4th, // input data
    output wire [(pDATA_WIDTH-1):0] nxt_dat_4th,

    input  wire                     coef_4th_vld,
    output wire                     coef_4th_rdy,
    input  wire [(pDATA_WIDTH-1):0] coef_dat, 

    input  wire [7:0]               mode_state, 
    output wire                     bpe_act
);
/* ========================================================================================================
                                                4th BPE
// ======================================================================================================== */
  // Note: Apart from 1st to 3rd BPE, this one concludes last 3 stages(stage 7 to stage 9) operation of a FFT.
  /* Assumption: This section is designed based on the fact that every 4 cycles input a data, it has to be redesigned if there is any change about input data timing.
                 Furthermore, coefficients always get right after the cycle it asks.
  */             
  /* waveform: 
     clk:           _____/-----\_____/-----\_____/-----\_____/-----\_____/-----\_____/-----\_____/-----\_____/-----\_____/-----\
     clk_2x:        __/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\__/--\
     rstn:          ---\______/-------------------------------------------------------------------------------------------------
     ss_vld_4th:    xxxxx/------------------------------------------------------------------------------------------------------
     ss_rdy_4th:    _____/------------------------------------------------------------------------------------------------------
  */
  // 要做的: 寫FSM, 每次啟動把counter清0, ......
  //=========================================================================================================
    // parameters
    //parameter MUL_DELAY = 27; // delay of butterfly
    //parameter INPUT_DELAY = 4; 

    localparam IDLE_4th = 0;
    localparam FILL_FIFO0_4th = 1;
    localparam CAL0_4th = 2;
    localparam WAIT_FIFO1_4th = 3;
    localparam FILL_FIFO1_4th = 4;
    localparam CAL1_4th = 5;
    localparam WAIT_FIFO2_4th = 6;
    localparam FILL_FIFO2_4th = 7;
    localparam FINISH_4th = 8;

    // ============================= Declaration ============================= //
    
    // Coefficient Register
    reg [127:0] COEF0_4th, COEF0_4th_next;
    reg [127:0] COEF1_4th, COEF1_4th_next;
    reg [127:0] COEF2_4th, COEF2_4th_next;

    // coefficient signal
    wire coef_4th_rdy_next;
    //reg coef_4th_vld;

    // 4th BPE IO
    reg [127:0] BPE4_ain;
    reg [127:0] BPE4_bin;
    reg  BPE4_i_vld;
    wire BPE4_i_rdy;
    wire [127:0] BPE4_aout;
    wire [127:0] BPE4_bout;
    wire BPE4_o_vld;
    wire BPE4_o_rdy;
    reg [127:0] BPE4_bin_buffer;
    reg [127:0] BPE4_bin_buffer_next;
    reg [127:0] BPE4_coef;

    // FSM for 4th BPE
    reg BPE_4th_idle;
    reg [3:0] state_4th;
    reg [3:0] state_4th_next;

    // Cycle counter 
    reg [1:0] counter_4th;
    wire[1:0] counter_4th_next;
    reg [15:0] cycle_q_num_4th; // every 4 cycles + 1
    wire[15:0] cycle_q_num_4th_next;

    // input/output counter
    reg [2:0] in_cnt_4th; 
    wire[2:0] in_cnt_4th_next;
    reg [2:0] out_cnt_4th; // all clear when count to 8
    wire[2:0] out_cnt_4th_next;

    // multiply delay counter
    reg [4:0] counter_MUL_DELAY_4th; 
    reg [4:0] counter_MUL_DELAY_4th_next;

    // coef counter
    reg [1:0] coef_cnt_4th; 
    wire [1:0] coef_cnt_4th_next;

    // BPE4 input counter
    reg [2:0] bpe_in_cnt_4th;
    // BPE4 output counter
    reg [2:0] bpe_out_cnt_4th;
    wire [2:0] bpe_out_cnt_4th_next;
    
    // engine state
    // AXI signal
    //wire ss_vld_4th;
    //reg  ss_rdy_4th;
    wire ss_rdy_4th_next;

    //reg  sm_vld_4th;
    wire sm_vld_4th_next;
    //wire sm_rdy_4th;

    // Data FIFO(2x clk)
    reg [3:0] data_reg_4th_ram0[0:pDATA_WIDTH-1];
    reg [3:0] data_reg_4th_ram0_next[0:pDATA_WIDTH-1];
    reg [1:0] data_reg_4th_ram1[0:pDATA_WIDTH-1];
    reg [1:0] data_reg_4th_ram1_next[0:pDATA_WIDTH-1];
    reg [1:0] data_reg_4th_ram2[0:pDATA_WIDTH-1];
    reg [1:0] data_reg_4th_ram2_next[0:pDATA_WIDTH-1];
    //control signal
    wire BPE4_o_rdy_next;
    reg BPE4_i_vld_next;

    butterfly BPE4 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (mode_state),
        .i_vld (BPE4_i_vld),
        .i_rdy (BPE4_i_rdy),
        .o_vld (BPE4_o_vld),
        .o_rdy (BPE4_o_rdy),
        .ai    (BPE4_ain),
        .bi    (BPE4_bin),
        .gm    (BPE4_coef),
        .ao    (BPE4_aout),
        .bo    (BPE4_bout)
    );
    assign bpe_act = (state_4th == IDLE_4th) & ss_vld_4th; // 4th BPE activated when input successfully get

    // =========================== counters for input and output ========================== //
    assign counter_4th_next = (ss_vld_4th & ss_rdy_4th) ? counter_4th + 1 : counter_4th;
    assign in_cnt_4th_next = (ss_vld_4th & ss_rdy_4th) ? in_cnt_4th + 1 : in_cnt_4th;
    assign out_cnt_4th_next = (sm_vld_4th & sm_rdy_4th) ? out_cnt_4th + 1 : out_cnt_4th;
    assign cycle_q_num_4th_next = &counter_4th ? cycle_q_num_4th + 1 : cycle_q_num_4th;
    assign bpe_in_cnt_4th_next = (BPE4_i_vld & BPE4_i_rdy) ? bpe_in_cnt_4th + 1 : bpe_in_cnt_4th;
    assign bpe_out_cnt_4th_next = (BPE4_o_vld & BPE4_o_rdy) ? bpe_out_cnt_4th + 1 : bpe_out_cnt_4th;
    assign counter_MUL_DELAY_4th_next = ((state_4th == WAIT_FIFO1_4th)|(state_4th == WAIT_FIFO2_4th)) ?
                                        (counter_MUL_DELAY_4th + 1) : 0;
    assign coef_cnt_4th_next = (coef_4th_vld & coef_4th_rdy) ? coef_cnt_4th + 1 : coef_cnt_4th;


    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        counter_4th <= 0;
        in_cnt_4th <= 0;
        out_cnt_4th <= 0;
        cycle_q_num_4th <= 0;
        bpe_in_cnt_4th <= 0;
        bpe_out_cnt_4th <= 0;
        counter_MUL_DELAY_4th <= 0;
        coef_cnt_4th <= 0;
      end else begin
        counter_4th <= counter_4th_next;
        in_cnt_4th <= in_cnt_4th_next;
        out_cnt_4th <= out_cnt_4th_next;
        cycle_q_num_4th <= cycle_q_num_4th_next;
        bpe_in_cnt_4th <= bpe_in_cnt_4th_next;
        bpe_out_cnt_4th <= bpe_out_cnt_4th_next;
        counter_MUL_DELAY_4th <= counter_MUL_DELAY_4th_next;
        coef_cnt_4th <= coef_cnt_4th_next;
      end
    end
    // =========================== control signal ========================== //


    assign BPE4_o_rdy_next = 1;
    assign ss_rdy_4th_next = ((state_4th_next == FILL_FIFO0_4th) | 
                             ((state_4th == CAL0_4th) & (state_4th_next != WAIT_FIFO1_4th))) ? 1 : 0;
    assign sm_vld_4th_next = (state_4th_next == FILL_FIFO2_4th) | 
                             ((state_4th == FILL_FIFO2_4th) & (state_4th_next != FINISH_4th)) ? 1 : 0;
    

    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        BPE4_o_rdy <= 0;
        BPE4_i_vld <= 0;
        ss_rdy_4th <= 0;
        sm_vld_4th <= 0;
      end else begin
        BPE4_o_rdy <= BPE4_o_rdy_next;
        BPE4_i_vld <= BPE4_i_vld_next;
        ss_rdy_4th <= ss_rdy_4th_next;
        sm_vld_4th <= sm_vld_4th_next;
      end
    end
    always@(*)begin
      case(state_4th)
         FILL_FIFO0_4th: BPE4_i_vld_next = (state_4th_next == CAL0_4th) ? 1 : 0;
         CAL0_4th: BPE4_i_vld_next = (state_4th_next == WAIT_FIFO1_4th) ? 0 : 1;
         FILL_FIFO1_4th: BPE4_i_vld_next = (state_4th_next == CAL1_4th) ? 1 : 0;
         CAL1_4th: BPE4_i_vld_next = (state_4th_next == WAIT_FIFO2_4th) ? 0 : 1;
         default: BPE4_i_vld_next = 0;
      endcase
    end
    
    // =========================== BPE input ========================== //
    always @(*)begin
      case(state_4th)
        CAL0_4th: begin
          BPE4_ain = data_reg_4th_ram0[3];
          BPE4_bin = ld_dat_4th;
          BPE4_coef = COEF0_4th;
        end
        CAL1_4th: begin
          if(bpe_in_cnt_4th > 5)begin
            BPE4_ain = data_reg_4th_ram2[1];
            BPE4_bin = data_reg_4th_ram0[3];
            BPE4_coef = COEF2_4th;
          end else begin
            BPE4_ain = data_reg_4th_ram2[1];
            BPE4_bin = data_reg_4th_ram1[1];
            BPE4_coef = COEF1_4th;
          end
        end
        default: BPE4_ain = 0;
      endcase
    end


    // =========================== FSM for 4th BPE ========================== //
    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        state_4th <= 0;
      end else begin
        state_4th <= state_4th_next;
      end
    end

    always@(*)begin
      case(state_4th)
        IDLE_4th: begin
          if(ss_vld_4th) state_4th_next = FILL_FIFO0_4th;
          else state_4th_next = IDLE_4th;
        end
        FILL_FIFO0_4th: begin
          if(&in_cnt_4th[1:0]) state_4th_next = CAL0_4th;
          else state_4th_next = FILL_FIFO0_4th;
        end
        CAL0_4th: begin
          if(&in_cnt_4th) state_4th_next = WAIT_FIFO1_4th;
          else state_4th_next = CAL0_4th;
        end
        WAIT_FIFO1_4th: begin
          if(counter_MUL_DELAY_4th == (MUL_DELAY-2-3)) state_4th_next = FILL_FIFO1_4th;
          else state_4th_next = WAIT_FIFO1_4th;
        end
        FILL_FIFO1_4th: begin
          if(&bpe_out_cnt_4th[1:0]) state_4th_next = CAL1_4th;
          else state_4th_next = FILL_FIFO1_4th;
        end
        CAL1_4th: begin
          if(&bpe_in_cnt_4th) state_4th_next = WAIT_FIFO2_4th;
          else state_4th_next = CAL1_4th;
        end
        WAIT_FIFO2_4th: begin
          if(counter_MUL_DELAY_4th == (MUL_DELAY-2-3)) state_4th_next = FILL_FIFO2_4th;
          else state_4th_next = WAIT_FIFO2_4th;
        end
        FILL_FIFO2_4th: begin
          if(&out_cnt_4th) state_4th_next = FINISH_4th;
          else state_4th_next = FILL_FIFO2_4th;
        end
        default: begin
          state_4th_next = IDLE_4th;
        end
      endcase
    end
    // =========================== coefficient register ========================== //
    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        COEF0_4th <= 0;
        COEF1_4th <= 0;
        COEF2_4th <= 0;
      end else begin
        COEF0_4th <= COEF0_4th_next;
        COEF1_4th <= COEF1_4th_next;  
        COEF2_4th <= COEF2_4th_next;
      end
    end
    // Coefficient 0
    always @(*) begin
      case(coef_cnt_4th)
        0: COEF0_4th_next = (coef_4th_vld & coef_4th_rdy) ? coef_dat : COEF0_4th;
        default: begin
          COEF0_4th_next = COEF0_4th;
        end
      endcase
    end
    // Coefficient 1
    always @(*) begin
      case(coef_cnt_4th)
        1: COEF1_4th_next = (coef_4th_vld & coef_4th_rdy) ? coef_dat : COEF1_4th;
        default: begin
          COEF1_4th_next = COEF1_4th;
        end
      endcase
    end
    // Coefficient 2
    always @(*) begin
      case(coef_cnt_4th)
        2: COEF2_4th_next = (coef_4th_vld & coef_4th_rdy) ? coef_dat : COEF2_4th;
        default: begin
          COEF2_4th_next = COEF2_4th;
        end
      endcase
    end
    // =========================== data reg ========================== //
    integer i, j, k;
    // FIFO 0    
    always @(posedge clk or negedge rstn) begin // reg uses regular clk instead of 2x clk
      if (~rstn) begin
        for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0[i] <= 0;
        for (i = 0; i < 2; i = i + 1) data_reg_4th_ram1[i] <= 0;
        for (i = 0; i < 2; i = i + 1) data_reg_4th_ram2[i] <= 0;
      end else begin
        for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0[i] <= data_reg_4th_ram0_next[i];
        for (i = 0; i < 2; i = i + 1) data_reg_4th_ram1[i] <= data_reg_4th_ram1_next[i];
        for (i = 0; i < 2; i = i + 1) data_reg_4th_ram2[i] <= data_reg_4th_ram2_next[i];
      end
    end
    always @(*)begin
      case(state_4th)
        FILL_FIFO0_4th: begin
          if(ss_rdy_4th & ss_vld_4th) begin
            data_reg_4th_ram0_next[0] = ld_dat_4th[127:0];
            for (i = 1; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i-1];
          end else begin
            for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i];
          end
        end
        CAL0_4th: begin
          if(!filled)begin
            data_reg_4th_ram0_next[0] = 0;
            for (i = 1; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i-1];            
          end else begin
            for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i];
          end
        end
        FILL_FIFO1_4th: begin
          if(BPE4_o_vld & BPE4_o_rdy) begin
            data_reg_4th_ram0_next[0] = BPE4_bout;
            for (i = 1; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i-1];
          end else begin
            for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i];
          end
        end
        CAL1_4th: begin
          if(!filled)begin
            data_reg_4th_ram0_next[0] = 0;
            for (i = 1; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i-1];            
          end else begin
            for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i];
          end
        end
        FINISH_4th: begin
          for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = 0;
        end
        default: begin
          for (i = 0; i < 4; i = i + 1) begin
            data_reg_4th_ram0_next[i] = 0;
          end
        end
      endcase
    end
    // FIFO 1
    always @(*)begin
      case(state_4th)
        FILL_FIFO1_4th: begin
          if(BPE4_o_vld & BPE4_o_rdy) begin
            data_reg_4th_ram1_next[0] = BPE4_aout;
            for (i = 1; i < 2; i = i + 1) data_reg_4th_ram1_next[i] = data_reg_4th_ram1[i-1];
          end else begin
            data_reg_4th_ram1_next[0] = 0;
            for (i = 1; i < 2; i = i + 1) data_reg_4th_ram1_next[i] = data_reg_4th_ram1[i-1];
          end
        end
        FILL_FIFO2_4th: begin
          if(BPE4_o_vld & BPE4_o_rdy)begin
            data_reg_4th_ram1_next[0] = BPE4_bout;
            for (i = 1; i < 2; i = i + 1) data_reg_4th_ram1_next[i] = data_reg_4th_ram1[i-1];            
          end else begin
            data_reg_4th_ram1_next[0] = 0;
            for (i = 1; i < 2; i = i + 1) data_reg_4th_ram1_next[i] = data_reg_4th_ram1[i-1];
          end
        end
        FINISH_4th: begin
          for (i = 0; i < 2; i = i + 1) data_reg_4th_ram1_next[i] = 0;
        end
        default: begin
          for (i = 0; i < 2; i = i + 1) begin
            data_reg_4th_ram1_next[i] = 0;
          end
        end
      endcase
    end
    // FIFO 2
    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        bpe_out_cnt_4th <= 0;
      end else begin
        bpe_out_cnt_4th <= bpe_out_cnt_4th_next;
      end
    end

    always @(*)begin
      case(state_4th)
        FILL_FIFO1_4th: begin
          if(bpe_out_cnt_4th > 1) data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          else data_reg_4th_ram2_next[0] = 0;
        end
        FILL_FIFO2_4th: begin
          if(bpe_out_cnt_4th > 5 | (~bpe_out_cnt_4th)) data_reg_4th_ram2_next[0] = 0;
          else data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
        end
        FINISH_4th: begin
          for (i = 0; i < 2; i = i + 1) data_reg_4th_ram2_next[i] = 0;
        end
        default: begin
          for (i = 0; i < 2; i = i + 1) begin
            data_reg_4th_ram2_next[i] = 0;
          end
        end
      endcase
    end
endmodule

module BPE_5th_module #(
    parameter pDATA_WIDTH = 128,
    parameter MUL_DELAY = 27, // delay of butterfly
    parameter INPUT_DELAY = 4 
)(
    input  wire                     clk, 
    input  wire                     rstn,

    input  wire                     ss_vld_5th,
    output wire                     ss_rdy_5th, // ready to receive data from 4th BPE
    output wire                     sm_vld_5th, 
    input  wire                     sm_rdy_5th,
    input  wire [(pDATA_WIDTH-1):0] ld_dat_5th, // input data
    output wire [(pDATA_WIDTH-1):0] nxt_dat_5th,

    input  wire                     coef_5th_vld,
    output wire                     coef_5th_rdy,
    input  wire [(pDATA_WIDTH-1):0] coef_dat, 

    input  wire [7:0]               mode_state, 
    output wire                     bpe_act
);

    /*===============================================================================================
    #                                       5th BPE                                                 #
    ================================================================================================*/
    localparam IDLE_5th = 0;
    localparam FILL_FIFO0_5th = 1;
    localparam CAL0_5th = 2;
    localparam WAIT_FIFO1_5th = 3;
    localparam FILL_FIFO1_5th = 4;
    localparam FINISH_5th = 5;
  
    // ================================== Declaration ================================== //
    // AXI signal
    reg  ss_rdy_5th_r;
    wire ss_rdy_5th_next;
    reg  sm_vld_5th_r;
    wire sm_vld_5th_next;

    // input counter
    reg [2:0] in_cnt_5th;
    wire[2:0] in_cnt_5th_next;

    // output counter
    reg [2:0] out_cnt_5th;
    
    //Coefficient counter
    reg [1:0] coef_cnt_5th;
    
    // FSM signal
    reg [2:0] state_5th, state_5th_next;
    reg [pDATA_WIDTH-1:0] data_reg_5th_ram0, data_reg_5th_ram0_next;

    // Coefficient Register
    reg [127:0] COEF0_5th, COEF0_5th_next;
    reg [127:0] COEF1_5th, COEF1_5th_next;
    reg [127:0] COEF2_5th, COEF2_5th_next;
    reg [127:0] COEF3_5th, COEF3_5th_next;

    // BPE5 signal
    reg [127:0] BPE5_ain;
    reg [127:0] BPE5_bin;
    reg  BPE5_i_vld;
    reg  BPE5_i_vld_next;
    wire BPE5_i_rdy;
    wire [127:0] BPE5_aout;
    wire [127:0] BPE5_bout;
    reg  BPE5_o_vld;
    reg  BPE5_o_vld_next;
    wire BPE5_o_rdy;
    reg [127:0] BPE5_coef;

    // counter_MUL_DELAY
    reg [4:0] counter_MUL_DELAY_5th;

        
    butterfly BPE5 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (mode_state),
        .i_vld (BPE5_i_vld),
        .i_rdy (BPE5_i_rdy),
        .o_vld (BPE5_o_vld),
        .o_rdy (BPE5_o_rdy),
        .ai    (BPE5_ain),
        .bi    (BPE5_bin),
        .gm    (BPE5_coef),
        .ao    (BPE5_aout),
        .bo    (BPE5_bout)
    );
    assign nxt_dat_5th = (out_cnt_5th[0]) ? data_reg_5th_ram0 : BPE5_aout; // 0, 2, 4, 6 cycle get data from BPE5_aout
    assign bpe_act = (state_5th == IDLE_5th) & ss_vld_5th; // 5th BPE activated when input successfully get
    // ============================ control signal ========================== //
    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        ss_rdy_5th_r <= 0;
        sm_vld_5th_r <= 0;
        BPE5_i_vld <= 0;
        BPE5_o_vld <= 0;
      end else begin
        ss_rdy_5th_r <= ss_rdy_5th_next;
        sm_vld_5th_r <= sm_vld_5th_next;
        BPE5_i_vld <= BPE5_i_vld_next;
        BPE5_o_vld <= BPE5_o_vld_next;
      end
    end
    always@(*)begin
      case(state_5th)
        IDLE_5th: ss_rdy_5th_next = 1;
        CAL0_5th: ss_rdy_5th_next = (state_5th_next != WAIT_FIFO1_5th);
        default:  ss_rdy_5th_next = 0;
      endcase
    end 
    always@(*)begin
      case(state_5th)
        FILL_FIFO1_5th: sm_vld_5th_next = (state_5th_next != FINISH_5th);
        default: sm_vld_5th_next = 0;
      endcase
    end

    always@(*)begin
      case(state_5th)
        CAL0_5th: BPE5_i_vld_next = !in_cnt_5th[0]; // even cycle in CAL0_5th send ain, bin
        default: BPE5_i_vld_next = 0;
      endcase
    end
    always@(*)begin
      case(state_5th)
        WAIT_FIFO1_5th: BPE5_o_vld_next = (state_5th_next == FILL_FIFO1_5th);
        FILL_FIFO1_5th: BPE5_o_vld_next = (state_5th_next != FINISH_5th);
        default: BPE5_o_vld_next = 0;
      endcase
    end

    // ============================ FSM logic ========================== //
    always@(posedge clk or negedge rstn) begin
      if (~rstn) state_5th <= IDLE_5th;
      else state_5th <= state_5th_next;
    end

    always@(*)begin
      case(state_5th)
        IDLE_5th: begin
          if(ss_vld_5th) state_5th_next = CAL0_5th;
          else state_5th_next = IDLE_5th;
        end
        CAL0_5th: begin
          if(&in_cnt_5th) state_5th_next = WAIT_FIFO1_5th;
          else state_5th_next = CAL0_5th;
        end
        WAIT_FIFO1_5th: begin
          if(counter_MUL_DELAY_5th == (MUL_DELAY-2-3)) state_5th_next = FILL_FIFO1_5th;
          else state_5th_next = WAIT_FIFO1_5th;
        end
        FILL_FIFO1_5th: begin
          if(&out_cnt_5th) state_5th_next = FINISH_5th;
          else state_5th_next = FILL_FIFO1_5th;
        end
        FINISH_5th: state_5th_next = IDLE_5th;
        default: state_5th_next = IDLE_5th;
      endcase
    end

    // ============================ BPE5 input/output ========================== //

    always@(*)begin
      BPE5_ain = data_reg_5th_ram0;
      BPE5_bin = ld_dat_5th;
    end
    always@(*)begin // 1, 3, 5, 7 cycle get coefficient
      if(&in_cnt_5th[2:1]) BPE5_coef = COEF3_5th; 
      else if(in_cnt_5th[2]) BPE5_coef = COEF2_5th;
      else if(in_cnt_5th[1]) BPE5_coef = COEF1_5th;
      else BPE5_coef = COEF0_5th;
    end

    
    // =========================== counters for input and output ========================== //
    assign in_cnt_5th_next = (ss_vld_5th & ss_rdy_5th) ? in_cnt_5th + 1 : in_cnt_5th;
    assign out_cnt_5th_next = (sm_vld_5th & sm_rdy_5th) ? out_cnt_5th + 1 : out_cnt_5th;
    assign counter_MUL_DELAY_5th_next = ((state_5th == WAIT_FIFO1_5th)|(state_5th == WAIT_FIFO2_5th)) ?   //WAIT_FIFO2_5th need modify
                                        (counter_MUL_DELAY_5th + 1) : 0;
    assign coef_cnt_5th_next = (coef_5th_vld & coef_5th_rdy) ? coef_cnt_5th + 1 : coef_cnt_5th;


    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        in_cnt_5th <= 0;
        out_cnt_5th <= 0;
        counter_MUL_DELAY_5th <= 0;
        coef_cnt_5th <= 0;
      end else begin
        in_cnt_5th <= in_cnt_5th_next;
        out_cnt_5th <= out_cnt_5th_next;
        counter_MUL_DELAY_5th <= counter_MUL_DELAY_5th_next;
        coef_cnt_5th <= coef_cnt_5th_next;
      end
    end

    // =========================== coefficient register ========================== //
    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        COEF0_5th <= 0;
        COEF1_5th <= 0;
        COEF2_5th <= 0;
        COEF3_5th <= 0;
      end else begin
        COEF0_5th <= COEF0_5th_next;
        COEF1_5th <= COEF1_5th_next;  
        COEF2_5th <= COEF2_5th_next;
        COEF3_5th <= COEF3_5th_next;
      end
    end
    // Coefficient 0
    always @(*) begin
      case(coef_cnt_5th)
        0: COEF0_5th_next = (coef_5th_vld & coef_5th_rdy) ? coef_dat : COEF0_5th;
        default: begin
          COEF0_5th_next = COEF0_5th;
        end
      endcase
    end
    // Coefficient 1
    always @(*) begin
      case(coef_cnt_5th)
        1: COEF1_5th_next = (coef_5th_vld & coef_5th_rdy) ? coef_dat : COEF1_5th;
        default: begin
          COEF1_5th_next = COEF1_5th;
        end
      endcase
    end
    // Coefficient 2
    always @(*) begin
      case(coef_cnt_5th)
        2: COEF2_5th_next = (coef_5th_vld & coef_5th_rdy) ? coef_dat : COEF2_5th;
        default: begin
          COEF2_5th_next = COEF2_5th;
        end
      endcase
    end
    // Coefficient 3
    always @(*) begin
      case(coef_cnt_5th)
        3: COEF3_5th_next = (coef_5th_vld & coef_5th_rdy) ? coef_dat : COEF3_5th;
        default: begin
          COEF3_5th_next = COEF3_5th;
        end
      endcase
    end
    // ============================ data reg ========================== //
    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        data_reg_5th_ram0 <= 0;
      end else begin
        data_reg_5th_ram0 <= data_reg_5th_ram0_next;
      end
    end

    always@(*)begin
      case(state_5th)
        CAL0_5th: begin
          if(ss_rdy_5th & ss_vld_5th) data_reg_5th_ram0_next = (in_cnt_5th[0]) ? ld_dat_5th[127:0] : 0; // only even input will fill the reg
          else data_reg_5th_ram0_next = data_reg_5th_ram0;
        end
        FILL_FIFO1_5th: begin
          if(BPE5_o_vld & BPE5_o_rdy) data_reg_5th_ram0_next = BPE5_bout;
          else data_reg_5th_ram0_next = 0;
        end
        FINISH_5th: data_reg_5th_ram0_next = 0;
        default: data_reg_5th_ram0_next = 0;
      endcase
    end

endmodule
