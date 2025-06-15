
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

    // Coefficient Register
    reg [127:0] COE0_1st;
    reg [127:0] COE1_1st;
    reg [127:0] COE2_1st;

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
          state_1st_next = (counter_1st == 1022) ? state_1st : 4'b0001;
        end
        4'b0001: begin
          state_1st_next = (counter_1st == 1046) ? state_1st : 4'b0010;
        end
        4'b0010: begin
          state_1st_next = (counter_1st == 2045) ? state_1st : 4'b0011;
        end
        4'b0011: begin
          state_1st_next = (counter_1st == 2073) ? state_1st : 4'b0100;
        end
        4'b0100: begin
          state_1st_next = (counter_1st == 2557) ? state_1st : 4'b0101;
        end
        4'b0101: begin
          state_1st_next = (counter_1st == 2585) ? state_1st : 4'b0110;
        end
        4'b0110: begin
          state_1st_next = (counter_1st == 3070) ? state_1st : 4'b0111;
        end
        4'b0111: begin
          state_1st_next = (counter_1st == 3096) ? state_1st : 4'b1000;
        end
        4'b1000: begin
          state_1st_next = (~decode) ? state_1st : 4'b0000;
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
      if (~rstn | decode) begin
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

    // ====================================Data Ram Logic========================================= //
   
    reg  [255:0] data_to_sram; // 一個正常Cycle寫 128 bits       
    wire [127:0] sram_din;
    reg          sram_we;
    reg          sram_en;
    reg  [25:0]  sram_addr_one_cycle;
    wire  [12:0]  sram_addr;
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
        4'b1000: begin
          
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
        4'b1000: begin
          
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
        4'b1000: begin
          
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

