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

    output wire               [3:0] bpe_act,//for bpe1 to bpe4 counter 

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

    assign bpe_act[0] = decode;

 
    // ====================================counter_1st===================================== //

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
    wire enable_output_1st = 
    (state_1st == 4'b1001 || 
     state_1st == 4'b1011 || 
     state_1st == 4'b1101 || 
     state_1st == 4'b1111);

    wire [127:0] ld_dat_2nd;
    wire ld_vld_2nd;
    reg BPE1_out_done;

    reg [11:0] counter_1st_output;
    wire [11:0] counter_1st_output_next;
    wire BPE1_out_done_next; 

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
   
    reg  [255:0] data_to_sram;      
    wire [127:0] sram_din;
    reg          sram_we;
    reg          sram_en;
    reg  [25:0]  sram_addr_one_cycle;
    wire  [12:0] sram_addr;
    reg          phase;     // 在 clk_2 切兩次送或切兩次讀
    wire         wr_phase_next;
    reg  [127:0] sram_dout;



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
          sram_we = (~phase) & (counter_1st[1:0] == 2'b00); 
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
          data_to_sram = {64'b0, ld_dat[63:0]}; 
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

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        state_2nd <= 0;
      end else begin
        state_2nd <= state_2nd_next;
      end
    end

    always @(*) begin
      case (state_1st)
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
    wire enable_output_2nd = 
    (state_2nd == 4'b1001 || 
     state_2nd == 4'b1011 || 
     state_2nd == 4'b1101 || 
     state_2nd == 4'b1111);

    wire [127:0] ld_dat_3rd;
    wire ld_vld_3rd;
    reg BPE2_out_done;

    reg [11:0] counter_2nd_output;
    wire [11:0] counter_2nd_output_next;
    wire BPE2_out_done_next; 

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
   
    reg  [255:0] data_to_sram_2nd;      
    wire [127:0] sram_din_2nd;
    reg          sram_we_2nd;
    reg          sram_en_2nd;
    reg  [25:0]  sram_addr_one_cycle_2nd;
    wire  [12:0] sram_addr_2nd;
    reg  [127:0] sram_dout_2nd;

    assign sram_din_2nd = (phase) ? data_to_sram_2nd[255:128] : data_to_sram_2nd[127:0];
    assign sram_addr_2nd = (phase) ? sram_addr_one_cycle_2nd[25:13] : sram_addr_one_cycle_2nd[12:0];

    // SRAM_WE
    always @(*) begin
      case (state_2nd)
        4'b0000: begin
          sram_we_2nd = (~phase) & (counter_2nd[1:0] == 2'b00); 
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
          data_to_sram_2nd = {64'b0, ld_dat_2nd[63:0]}; 
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
        4'b1000: begin
          data_to_sram_2nd = 0;
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
          sram_addr_one_cycle_2nd = {13'b0, 3'b0, counter_2nd[9:0]}; 
        end
        4'b0001: begin
          sram_addr_one_cycle_2nd = {13'b0, 3'b0, counter_2nd[9:0]};                                                                                   
        end
        4'b0010: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {3'b001, counter_2nd_delay[9:0], 3'b0, counter_2nd_delay[9:0]} : {13'b0, 3'b0, counter_2nd[9:0]};
        end
        4'b0011: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {3'b001, counter_2nd_delay[9:0], 3'b0, counter_2nd_delay[9:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 4'b0, counter_2nd[8:0]} : {13'b0, 4'b0001, counter_2nd_adv[8:0]};
        end
        4'b0100: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {4'b0001, counter_2nd_delay[9:0], 4'b0, counter_2nd_delay[9:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 4'b0, counter_2nd[8:0]} : {13'b0, 4'b0001, counter_2nd_adv[8:0]};
        end
        4'b0101: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {4'b0001, counter_2nd_delay[9:0], 4'b0, counter_2nd_delay[9:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 4'b0010, counter_2nd[8:0]} : {13'b0, 4'b0011, counter_2nd_adv[8:0]};
        end
        4'b0110: begin
          sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b11) ? {4'b0011, counter_2nd_delay[9:0], 4'b0010, counter_2nd_delay[9:0]} :
                                (counter_2nd[1:0] == 2'b00) ? {13'b0, 4'b0010, counter_2nd[8:0]} : {13'b0, 4'b0011, counter_2nd_adv[8:0]};
        end
        4'b0111: begin
          sram_addr_one_cycle_2nd = {4'b0011, counter_2nd_delay[9:0], 4'b0010, counter_2nd_delay[9:0]};
        end
        4'b1001: begin
          sram_addr_one_cycle_2nd = {13'b0, 4'b0, counter_2nd_output[8:0]};
        end
        4'b1011: begin
          sram_addr_one_cycle_2nd = {13'b0, 4'b0001, counter_2nd_output[8:0]};
        end
        4'b1101: begin
          sram_addr_one_cycle_2nd = {13'b0, 4'b0010, counter_2nd_output[8:0]};
        end
        4'b1111: begin
          sram_addr_one_cycle_2nd = {13'b0, 4'b0011, counter_2nd_output[8:0]};
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
        .i_vld (),
        .i_rdy (),
        .o_vld (),
        .o_rdy (),
        .ai    (),
        .bi    (),
        .gm    (),
        .ao    (),
        .bo    ()
    );

    butterfly BPE4 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (mode_state),
        .i_vld (),
        .i_rdy (),
        .o_vld (),
        .o_rdy (),
        .ai    (),
        .bi    (),
        .gm    (),
        .ao    (),
        .bo    ()
    );


    bram512x128 SRAM1 (
        .CLK(),
        .WE(),
        .EN(),
        .Di(),
        .Do(),
        .A()
    );

endmodule

