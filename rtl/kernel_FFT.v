module kernel_FFT #(
    parameter pDATA_WIDTH = 128
)
(
    input wire clk,
    input wire clk_2x,
    input wire rstn,
    input wire ld_vld,
    output wire ld_rdy,
    input wire [(pDATA_WIDTH - 1):0] ld_dat,
    output wire sw_vld,
    input wire sw_rdy,
    output wire [(pDATA_WIDTH - 1):0] sw_dat,
    input wire [4:0]  coef_vld,
    output wire [4:0] coef_rdy,
    input wire [(pDATA_WIDTH - 1):0] coef_dat,
    output wire [4:0] bpe_act,
    input wire [7:0] mode,
    input wire decode,
    output wire sw_lst,

    output reg  [(pDATA_WIDTH - 1):0] BPE1_ain,
    output reg  [(pDATA_WIDTH - 1):0] BPE1_bin,
    output reg  [(pDATA_WIDTH - 1):0] BPE1_coef,
    output reg  BPE1_i_vld,
    output reg  BPE1_o_rdy,
    input  wire [(pDATA_WIDTH - 1):0] BPE1_aout,
    input  wire [(pDATA_WIDTH - 1):0] BPE1_bout,
    input  wire BPE1_i_rdy,
    input  wire BPE1_o_vld,

    output reg  [(pDATA_WIDTH - 1):0] BPE2_ain,
    output reg  [(pDATA_WIDTH - 1):0] BPE2_bin,
    output reg  [(pDATA_WIDTH - 1):0] BPE2_coef,
    output reg  BPE2_i_vld,
    output reg  BPE2_o_rdy,
    input  wire [(pDATA_WIDTH - 1):0] BPE2_aout,
    input  wire [(pDATA_WIDTH - 1):0] BPE2_bout,
    input  wire BPE2_i_rdy,
    input  wire BPE2_o_vld,

    output reg  [(pDATA_WIDTH - 1):0] BPE3_ain,
    output reg  [(pDATA_WIDTH - 1):0] BPE3_bin,
    output reg  [(pDATA_WIDTH - 1):0] BPE3_coef,
    output reg  BPE3_i_vld,
    output reg  BPE3_o_rdy,
    input  wire [(pDATA_WIDTH - 1):0] BPE3_aout,
    input  wire [(pDATA_WIDTH - 1):0] BPE3_bout,
    input  wire BPE3_i_rdy,
    input  wire BPE3_o_vld,

    output wire [(pDATA_WIDTH - 1):0] BPE4_ain,
    output wire [(pDATA_WIDTH - 1):0] BPE4_bin,
    output wire [(pDATA_WIDTH - 1):0] BPE4_coef,
    output wire BPE4_i_vld,
    output wire BPE4_o_rdy,
    input  wire [(pDATA_WIDTH - 1):0] BPE4_aout,
    input  wire [(pDATA_WIDTH - 1):0] BPE4_bout,
    input  wire BPE4_i_rdy,
    input  wire BPE4_o_vld,

    output wire [3:0] WE_512,
    output reg  sram_en_512,
    output wire [(pDATA_WIDTH - 1):0] sram_din_512,
    input  wire [(pDATA_WIDTH - 1):0] sram_dout_512,
    output wire [12:0] sram_addr_512,

    output wire [3:0] WE_128,
    output reg  sram_en_128,
    output wire [(pDATA_WIDTH - 1):0] sram_din_128,
    input  wire [(pDATA_WIDTH - 1):0] sram_dout_128,
    output wire [12:0] sram_addr_128,

    output wire [3:0] WE_32,
    output reg  sram_en_32,
    output wire [(pDATA_WIDTH - 1):0] sram_din_32,
    input  wire [(pDATA_WIDTH - 1):0] sram_dout_32,
    output wire [12:0] sram_addr_32
);

reg phase;
wire phase_next;

always @(posedge clk_2x or negedge rstn) begin
  if (~rstn) begin
    phase <= 0;
  end else begin
    phase <= phase_next;
  end
end

assign phase_next = ~phase;

// ============================= BPE1 ============================== //
localparam IDLE = 4'b0000;
localparam RECEIVE = 4'b0001;
localparam RECEIVE_CAL1 = 4'b0010;
localparam RECEIVE_CAL2 = 4'b0011;
localparam RECEIVE_CAL3 = 4'b0100;
localparam RECEIVE_CAL_OUTPUT = 4'b0101;
localparam CAL_OUTPUT = 4'b0110;
localparam CAL1 = 4'b0111;
localparam CAL2 = 4'b1000;
localparam SAVE = 4'b1001;
localparam TRANSFER = 4'b1010;
localparam DONE = 4'b1011;


// state
reg [3:0] state_1st;
reg [3:0] state_1st_next;

// coef
wire coef_done_1st;
reg [(pDATA_WIDTH - 1):0] coef_reg_0;
reg [(pDATA_WIDTH - 1):0] coef_reg_1;
reg [(pDATA_WIDTH - 1):0] coef_reg_2;
wire [(pDATA_WIDTH - 1):0] coef_reg_0_next;
wire [(pDATA_WIDTH - 1):0] coef_reg_1_next;
wire [(pDATA_WIDTH - 1):0] coef_reg_2_next;
reg [1:0] coef_count;
wire [1:0] coef_count_next;

// counter_1st
reg [15:0] counter_1st;
reg [15:0] counter_1st_delay;
reg [15:0] counter_1st_delay_buffer;
reg [15:0] counter_1st_adv;
reg [15:0] stage2_counter;
reg [15:0] stage2_counter_buffer;
reg [15:0] stage2_counter_delay;
reg counting_1st;
reg trigger_once;

wire [15:0] counter_1st_next;
wire [15:0] counter_1st_delay_next;
wire [15:0] counter_1st_adv_next;
wire [15:0] stage2_counter_next;
wire [15:0] stage2_counter_delay_next;
wire counting_1st_next;
wire trigger_once_next;

// sram signal
reg sram_we_512;
wire sram_we_512_buffer;
reg [255:0] data_to_sram;
reg [25:0]  sram_addr_one_cycle;

// BPE signal
reg [(pDATA_WIDTH - 1):0] BPE1_bout_buffer;
reg [(pDATA_WIDTH - 1):0] BPE1_ain_buffer;
wire [(pDATA_WIDTH - 1):0] BPE1_ain_buffer_next;




// =============================BPE 2========================== //

reg ld_vld_2nd;
reg [(pDATA_WIDTH - 1):0] ld_dat_2nd;
reg data_rdy_3rd;
reg data_output_en_2nd;
wire input_done_2nd;
wire output_done_2nd;

// state
reg [3:0] state_2nd;
reg [3:0] state_2nd_next;

// coef
wire coef_done_2nd;
reg [(pDATA_WIDTH - 1):0] coef_reg_0_2nd;
reg [(pDATA_WIDTH - 1):0] coef_reg_1_2nd;
reg [(pDATA_WIDTH - 1):0] coef_reg_2_2nd;
wire [(pDATA_WIDTH - 1):0] coef_reg_0_2nd_next;
wire [(pDATA_WIDTH - 1):0] coef_reg_1_2nd_next;
wire [(pDATA_WIDTH - 1):0] coef_reg_2_2nd_next;
reg [1:0] coef_count_2nd;
wire [1:0] coef_count_2nd_next;

// counter_2nd
reg [15:0] counter_2nd;
reg [15:0] counter_2nd_delay;
reg [15:0] counter_2nd_delay_buffer;
reg [15:0] counter_2nd_adv;
reg [15:0] stage2_counter_2nd;
reg [15:0] stage2_counter_2nd_buffer;
reg [15:0] stage2_counter_2nd_delay;
reg [15:0] stage2_counter_2nd_delay_buffer;
reg counting_2nd;
reg trigger_once_2nd;

wire [15:0] counter_2nd_next;
wire [15:0] counter_2nd_delay_next;
wire [15:0] counter_2nd_adv_next;
wire [15:0] stage2_counter_2nd_next;
wire [15:0] stage2_counter_delay_2nd_next;
wire counting_2nd_next;
wire trigger_once_2nd_next;

// sram signal
reg sram_we_128;
wire sram_we_128_buffer;
reg [255:0] data_to_sram_2nd;
reg [25:0]  sram_addr_one_cycle_2nd;

// BPE signal
reg [(pDATA_WIDTH - 1):0] BPE2_bout_buffer;
reg [(pDATA_WIDTH - 1):0] BPE2_ain_buffer;
wire [(pDATA_WIDTH - 1):0] BPE2_ain_buffer_next;


// Input Signal
wire [13:0] bpe2_input_addr;
reg [8:0] bpe2_input_counter;
wire [8:0] bpe2_input_counter_next;


// Output Signal
wire [13:0] bpe2_output_addr;
reg [8:0] bpe2_output_counter;
wire [8:0] bpe2_output_counter_next;



// =============================BPE 3=========================== //
reg ld_vld_3rd;
reg [(pDATA_WIDTH - 1):0] ld_dat_3rd;
reg data_rdy_4th;
reg data_output_en_3rd;
wire input_done_3rd;
wire output_done_3rd;
reg [(pDATA_WIDTH - 1):0] data_4th_reg0;
reg [(pDATA_WIDTH - 1):0] data_4th_reg1;
wire [(pDATA_WIDTH - 1):0] data_4th_reg0_next;
wire [(pDATA_WIDTH - 1):0] data_4th_reg1_next;

// state
reg [3:0] state_3rd;
reg [3:0] state_3rd_next;

// coef
wire coef_done_3rd;
reg [(pDATA_WIDTH - 1):0] coef_reg_0_3rd;
reg [(pDATA_WIDTH - 1):0] coef_reg_1_3rd;
reg [(pDATA_WIDTH - 1):0] coef_reg_2_3rd;
wire [(pDATA_WIDTH - 1):0] coef_reg_0_3rd_next;
wire [(pDATA_WIDTH - 1):0] coef_reg_1_3rd_next;
wire [(pDATA_WIDTH - 1):0] coef_reg_2_3rd_next;
reg [1:0] coef_count_3rd;
wire [1:0] coef_count_3rd_next;

// counter_3rd
reg [15:0] counter_3rd;
reg [15:0] counter_3rd_delay;
reg [15:0] counter_3rd_delay_buffer;
reg [15:0] counter_3rd_adv;
reg [15:0] stage2_counter_3rd;
reg [15:0] stage2_counter_3rd_buffer;
reg [15:0] stage2_counter_3rd_delay;
reg [15:0] stage2_counter_3rd_delay_buffer;
reg counting_3rd;
reg trigger_once_3rd;

wire [15:0] counter_3rd_next;
wire [15:0] counter_3rd_delay_next;
wire [15:0] counter_3rd_adv_next;
wire [15:0] stage2_counter_3rd_next;
wire [15:0] stage2_counter_delay_3rd_next;
wire counting_3rd_next;
wire trigger_once_3rd_next;

// sram signal
reg sram_we_32;
wire sram_we_32_buffer;
reg [255:0] data_to_sram_3rd;
reg [25:0]  sram_addr_one_cycle_3rd;

// BPE signal
reg [(pDATA_WIDTH - 1):0] BPE3_bout_buffer;
reg [(pDATA_WIDTH - 1):0] BPE3_ain_buffer;
wire [(pDATA_WIDTH - 1):0] BPE3_ain_buffer_next;


// Input Signal
wire [13:0] bpe3_input_addr;
reg  [8:0] bpe3_input_counter;
wire [8:0] bpe3_input_counter_next;
wire bpe3_can_input;


// Output Signal
wire enable_output_3rd;
wire [(pDATA_WIDTH - 1):0] ld_dat_4th;
wire ld_vld_4th;
reg BPE3_out_done;

reg [4:0] counter_3rd_output;
wire [4:0] counter_3rd_output_next;
wire BPE3_out_done_next; 



// =============================BPE 4=========================== //

wire ld_rdy_4th;
assign ld_rdy_4th = 1; // for test








// ld_rdy
assign ld_rdy = (counter_1st[1:0] == 2'b00);

//coef_done
assign coef_done_1st = (coef_count == 2'b11);
assign bpe_act[0] = (state_1st == 4'b0) & ld_vld;

always @(posedge clk or negedge rstn) begin
  if (~rstn | decode) begin
    coef_count <= 0;
  end else begin
    coef_count <= coef_count_next;
  end
end

always @(posedge clk or negedge rstn) begin
  if (~rstn | decode) begin
    coef_reg_0 <= 0;
    coef_reg_1 <= 0;
    coef_reg_2 <= 0;
  end else begin
    coef_reg_0 <= coef_reg_0_next;
    coef_reg_1 <= coef_reg_1_next;
    coef_reg_2 <= coef_reg_2_next;
  end
end

assign coef_count_next = (coef_vld[0]) ? coef_count + 1 : coef_count;
assign coef_reg_0_next = (coef_vld[0]) & (coef_count[1:0] == 2'b00) ? coef_dat : coef_reg_0;
assign coef_reg_1_next = (coef_vld[0]) & (coef_count[1:0] == 2'b01) ? coef_dat : coef_reg_1;
assign coef_reg_2_next = (coef_vld[0]) & (coef_count[1:0] == 2'b10) ? coef_dat : coef_reg_2;

// State
always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    state_1st <= 0;
  end else begin
    state_1st <= state_1st_next;
  end
end

always @(*) begin
  case (state_1st)
    IDLE: begin
      state_1st_next = (ld_vld) ? RECEIVE : IDLE; 
    end
    RECEIVE: begin
      state_1st_next = (counter_1st == 1022) ? RECEIVE_CAL1 : RECEIVE;
    end
    RECEIVE_CAL1: begin
      state_1st_next = (counter_1st == 1050) ? RECEIVE_CAL2 : RECEIVE_CAL1;
    end
    RECEIVE_CAL2: begin
      state_1st_next = (counter_1st == 1563) ? RECEIVE_CAL3 : RECEIVE_CAL2;
    end
    RECEIVE_CAL3: begin
      state_1st_next = (counter_1st == 1591) ? RECEIVE_CAL_OUTPUT : RECEIVE_CAL3;
    end
    RECEIVE_CAL_OUTPUT: begin
      state_1st_next = (counter_1st == 2046) ? CAL_OUTPUT : RECEIVE_CAL_OUTPUT;
    end 
    CAL_OUTPUT: begin
      state_1st_next = (counter_1st == 2075) ? CAL1 : CAL_OUTPUT;
    end
    CAL1: begin
      state_1st_next = (counter_1st == 2103) ? CAL2 : CAL1;
    end
    CAL2: begin
      state_1st_next = (counter_1st == 2556) ? SAVE : CAL2;
    end
    SAVE: begin
      state_1st_next = (counter_1st == 2584) ? TRANSFER : SAVE;
    end
    TRANSFER: begin
      state_1st_next = (sw_lst) ? IDLE : TRANSFER;
    end
    default: begin
      state_1st_next = 0;
    end
  endcase
end


// Counter
wire wait_ld;
wire coef_not_ready;
assign coef_not_ready = (counter_1st == 1022) & (~coef_done_1st);
assign wait_ld = (state_1st >= 4'd1 && state_1st <= 4'd5) && (counter_1st[1:0] == 2'b00);
assign trigger_once_next  = trigger_once | ld_vld;
assign counting_1st_next  = (ld_vld && !trigger_once) ? 1'b1 : counting_1st;
assign counter_1st_next = 
    (ld_vld && !trigger_once) ? 16'd1 :
    (counting_1st && !wait_ld && !coef_not_ready) ? counter_1st + 1 :
    (counting_1st && wait_ld && ld_vld && !coef_not_ready) ? counter_1st + 1 :
                                                             counter_1st;

assign counter_1st_delay_next = counter_1st - 27;
assign counter_1st_adv_next   = counter_1st + 2;
assign stage2_counter_next    = counter_1st - 540;
assign stage2_counter_delay_next = stage2_counter - 28;

always @(posedge clk or negedge rstn) begin
  if (~rstn | decode) begin
    counter_1st              <= 16'd0;
    counting_1st             <= 1'b0;
    trigger_once             <= 1'b0;
    counter_1st_delay        <= 16'd0;
    counter_1st_delay_buffer <= 16'd0;
    counter_1st_adv          <= 16'd0;
    stage2_counter           <= 16'd0;
    stage2_counter_delay     <= 16'd0;
    stage2_counter_buffer    <= 16'd0;
  end else begin
    counter_1st              <= counter_1st_next;
    counting_1st             <= counting_1st_next;
    trigger_once             <= trigger_once_next;
    counter_1st_delay        <= counter_1st_delay_next;
    counter_1st_delay_buffer <= counter_1st_delay;
    counter_1st_adv          <= counter_1st_adv_next;
    stage2_counter           <= stage2_counter_next;
    stage2_counter_delay     <= stage2_counter_delay_next;
    stage2_counter_buffer    <= stage2_counter;
  end
end


//Sram Control Signal

//sram enable 
always @(*) begin
  case (state_1st)
    IDLE: begin
      sram_en_512 = ld_vld;
    end
    RECEIVE: begin
      sram_en_512 = ld_vld;
    end
    RECEIVE_CAL1: begin
      sram_en_512 = ld_vld;
    end
    RECEIVE_CAL2: begin
      sram_en_512 = (counter_1st[1:0] == 2'b00) ? ld_vld : (counter_1st[1:0] == 2'b01);
    end
    RECEIVE_CAL3: begin
      sram_en_512 = (counter_1st[1:0] == 2'b00) ? ld_vld : ~(counter_1st[1:0] == 2'b11);
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_en_512 = (counter_1st[1:0] == 2'b00) ? ld_vld : ~(counter_1st[1:0] == 2'b11);
    end
    CAL_OUTPUT: begin
      sram_en_512 = 1;
    end
    CAL1: begin
      sram_en_512 = 1;
    end
    CAL2: begin
      sram_en_512 = ~(counter_1st[1:0] == 2'b10);
    end
    SAVE: begin
      sram_en_512 = (counter_1st[1:0] == 2'b00);
    end
    TRANSFER: begin
      sram_en_512 = 1;
    end
    default: begin
      sram_en_512 = 0;
    end
  endcase
end

// sram_we
always @(*) begin
  case (state_1st)
    IDLE: begin
      sram_we_512 = ld_vld & (~phase);
    end
    RECEIVE: begin
      sram_we_512 = ld_vld & (~phase);
    end
    RECEIVE_CAL1: begin
      sram_we_512 = 0;
    end
    RECEIVE_CAL2: begin
      sram_we_512 = (counter_1st[1:0] == 2'b00) ? (ld_vld & phase) : 
                    (counter_1st[1:0] == 2'b01) & (phase); 
    end
    RECEIVE_CAL3: begin
      sram_we_512 = (counter_1st[1:0] == 2'b00) ? (ld_vld & phase) : 
                    (counter_1st[1:0] == 2'b01) & (phase);  
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_we_512 = (counter_1st[1:0] == 2'b00) ? (ld_vld & phase) : 
                    ~(counter_1st[1:0] == 2'b11) & (phase);
    end
    CAL_OUTPUT: begin
      sram_we_512 = ~(counter_1st[1:0] == 2'b11) & (phase);
    end
    CAL1: begin
      sram_we_512 = (counter_1st[1:0] == 2'b11) ? 0 : (counter_1st[1:0] == 2'b10) | (phase);
    end
    CAL2: begin
      sram_we_512 = ~(counter_1st[1]) & (phase);
    end
    SAVE: begin
      sram_we_512 = (counter_1st[1:0] == 2'b00);
    end
    TRANSFER: begin
      sram_we_512 = sram_we_512_buffer;
    end
    default: begin
      sram_we_512 = 0;
    end
  endcase
end

assign sram_we_512_buffer = (phase) & ((counter_1st[1:0] == 2'b00) & (ld_sram_512_vld)); 
assign WE_512 = {4{sram_we_512}};


//data_to_sram
always @(*) begin
  case (state_1st)
    IDLE: begin
      data_to_sram = {128'b0, ld_dat[127:0]};
    end
    RECEIVE: begin
      data_to_sram = {128'b0, ld_dat[127:0]};
    end
    RECEIVE_CAL1: begin
      data_to_sram = 0;
    end
    RECEIVE_CAL2: begin
      data_to_sram = (counter_1st[1:0] == 2'b00) ? {BPE1_aout[127:0], 128'b0} : {BPE1_bout_buffer[127:0], 128'b0};
    end
    RECEIVE_CAL3: begin
      data_to_sram = (counter_1st[1:0] == 2'b00) ? {BPE1_aout[127:0], 128'b0} : {BPE1_bout_buffer[127:0], 128'b0};
    end
    RECEIVE_CAL_OUTPUT: begin
      data_to_sram = (counter_1st[1:0] == 2'b00) ? {BPE1_aout[127:0], 128'b0} :
                     (counter_1st[1:0] == 2'b01) ? {BPE1_bout_buffer[127:0], 128'b0} :
                                                   {BPE1_bout[127:0], 128'b0};
    end
    CAL_OUTPUT: begin
      data_to_sram = (counter_1st[1:0] == 2'b00) ? {BPE1_aout[127:0], 128'b0} :
                     (counter_1st[1:0] == 2'b01) ? {BPE1_bout_buffer[127:0], 128'b0} :
                                                   {BPE1_bout[127:0], 128'b0}; 
    end
    CAL1: begin
      data_to_sram = (counter_1st[1:0] == 2'b00) ? {BPE1_aout[127:0], 128'b0} :
                     (counter_1st[1:0] == 2'b01) ? {BPE1_bout_buffer[127:0], 128'b0} :
                                                   {BPE1_bout[127:0], BPE1_aout[127:0]}; 
    end
    CAL2: begin
      data_to_sram = (counter_1st[1:0] == 2'b00) ? {BPE1_aout[127:0], 128'b0} : {BPE1_bout_buffer[127:0], 128'b0}; 
    end
    SAVE: begin
      data_to_sram = {BPE1_bout[127:0], BPE1_aout[127:0]};
    end
    TRANSFER: begin
      data_to_sram = (counter_1st[1:0] == 2'b00) ? {sram_dout_128[127:0], 128'b0} : {sram_dout_32[127:0], 128'b0};
    end
    default: begin
      data_to_sram = 0;
    end
  endcase
end

assign sram_din_512 = (phase) ? data_to_sram[255:128] : data_to_sram[127:0];
assign sram_addr_512 = (phase) ? sram_addr_one_cycle[25:13] : sram_addr_one_cycle[12:0];



// sram_addr
always @(*) begin
  case (state_1st)
    IDLE: begin 
      sram_addr_one_cycle = {13'b0, 3'b0, counter_1st[9:0]};
    end
    RECEIVE: begin // 0
      sram_addr_one_cycle = {13'b0, 3'b0, counter_1st[9:0]};
    end
    RECEIVE_CAL1: begin // 1
      sram_addr_one_cycle = {13'b0, 3'b0, counter_1st[9:0]};
    end
    RECEIVE_CAL2: begin // 2
      sram_addr_one_cycle = (counter_1st[1:0] == 2'b00) ? {3'b0, counter_1st_delay[9:0] ,3'b0, counter_1st[9:0]} : 
                                                          {3'b001, counter_1st_delay_buffer[9:0], 13'b0};
    end
    RECEIVE_CAL3: begin // 3
      sram_addr_one_cycle = (counter_1st[1:0] == 2'b00) ? {3'b0, counter_1st_delay[9:0] ,3'b0, counter_1st[9:0]} :
                            (counter_1st[1:0] == 2'b01) ? {3'b001, counter_1st_delay_buffer[9:0], 4'b0, stage2_counter[8:0]} :
                                                          {13'b0, 4'b0001, stage2_counter_buffer[8:0]};
    end
    RECEIVE_CAL_OUTPUT: begin // 4
      sram_addr_one_cycle = (counter_1st[1:0] == 2'b00) ? {3'b0, counter_1st_delay[9:0] ,3'b0, counter_1st[9:0]} :
                            (counter_1st[1:0] == 2'b01) ? {3'b001, counter_1st_delay_buffer[9:0], 4'b0, stage2_counter[8:0]} :
                                                          {4'b0001, stage2_counter_delay[8:0], 4'b0001, stage2_counter_buffer[8:0]};
    end
    CAL_OUTPUT: begin // 5
      sram_addr_one_cycle = (counter_1st[1:0] == 2'b00) ? {3'b0, counter_1st_delay[9:0], 4'b0011, counter_1st[8:0]} :
                            (counter_1st[1:0] == 2'b01) ? {3'b001, counter_1st_delay_buffer[9:0], 4'b0, stage2_counter[8:0]} :
                            (counter_1st[1:0] == 2'b10) ? {4'b0001, stage2_counter_delay[8:0], 4'b0001, stage2_counter_buffer[8:0]} :
                                                          {13'b0, 4'b0010, counter_1st_adv[8:0]};
    end
    CAL1: begin // 6
      sram_addr_one_cycle = (counter_1st[1:0] == 2'b00) ? {4'b0010, counter_1st_delay[8:0], 4'b0011, counter_1st[8:0]} :
                            (counter_1st[1:0] == 2'b01) ? {4'b0011, counter_1st_delay_buffer[8:0], 13'b0} :
                            (counter_1st[1:0] == 2'b10) ? {4'b0001, stage2_counter_delay[8:0], 13'b0} :
                                                          {13'b0, 4'b0010, counter_1st_adv[8:0]}; 
    end
    CAL2: begin // 7
      sram_addr_one_cycle = (counter_1st[1:0] == 2'b00) ? {4'b0010, counter_1st_delay[8:0], 4'b0011, counter_1st[8:0]} :
                            (counter_1st[1:0] == 2'b01) ? {4'b0011, counter_1st_delay_buffer[8:0], 13'b0} :
                                                          {13'b0, 4'b0010, counter_1st_adv[8:0]};  
    end
    SAVE: begin // 8
      sram_addr_one_cycle = {4'b0010, counter_1st_delay[8:0], 4'b0011, counter_1st_delay[8:0]};
    end
    TRANSFER: begin
      sram_addr_one_cycle = (counter_1st[1:0] == 2'b00) ? {bpe2_output_addr[12:0], bpe2_input_addr[12:0]} :
                                                          {13'b0, bpe3_input_addr[12:0]};
    end
    default: begin
      sram_addr_one_cycle = 0;
    end
  endcase
end

//BPE1
// BPEinA
always @(*) begin
  case (state_1st)
    RECEIVE_CAL1: begin
      BPE1_ain = sram_dout_512;
    end
    RECEIVE_CAL2: begin
      BPE1_ain = sram_dout_512;
    end
    RECEIVE_CAL3: begin
      BPE1_ain = (counter_1st[1:0] == 2'b0) ? sram_dout_512 : BPE1_ain_buffer;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE1_ain = (counter_1st[1:0] == 2'b0) ? sram_dout_512 : BPE1_ain_buffer;
    end
    CAL_OUTPUT: begin
      BPE1_ain = BPE1_ain_buffer;
    end
    CAL1: begin
      BPE1_ain = BPE1_ain_buffer;
    end
    CAL2: begin
      BPE1_ain = BPE1_ain_buffer;
    end
    default: begin
      BPE1_ain = 0;
    end
  endcase 
end

always @(*) begin
  case (state_1st)
    RECEIVE_CAL1: begin
      BPE1_bin = ld_dat;
    end
    RECEIVE_CAL2: begin
      BPE1_bin = ld_dat;
    end
    RECEIVE_CAL3: begin
      BPE1_bin = (counter_1st[1]) ? sram_dout_512 : ld_dat;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE1_bin = (counter_1st[1]) ? sram_dout_512 : ld_dat;
    end
    CAL_OUTPUT: begin
      BPE1_bin = sram_dout_512;
    end
    CAL1: begin
      BPE1_bin = sram_dout_512;
    end
    CAL2: begin
      BPE1_bin = sram_dout_512;
    end
    default: begin
      BPE1_bin = 0;
    end
  endcase
end

assign BPE1_ain_buffer_next = (counter_1st[1:0] == 2'b00) ? BPE1_ain_buffer : sram_din_512;

//BPEinPreBuffer
always @(posedge clk) begin
  BPE1_ain_buffer <= BPE1_ain_buffer_next;
end

always @(*) begin
  case (state_1st)
    RECEIVE_CAL1: begin
      BPE1_i_vld = ld_vld;
    end
    RECEIVE_CAL2: begin
      BPE1_i_vld = ld_vld;
    end
    RECEIVE_CAL3: begin
      BPE1_i_vld = (counter_1st[1:0] == 2'b10) | ld_vld;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE1_i_vld = (counter_1st[1:0] == 2'b10) | ld_vld;
    end
    CAL_OUTPUT: begin
      BPE1_i_vld = ~(counter_1st[0]);
    end
    CAL1: begin
      BPE1_i_vld = (counter_1st[1:0] == 2'b00);
    end
    CAL2: begin
      BPE1_i_vld = (counter_1st[1:0] == 2'b00);
    end
    default: begin
      BPE1_i_vld = 0;
    end
  endcase
end

always @(*) begin
  case (state_1st)
    RECEIVE_CAL2: begin
      BPE1_o_rdy = ld_vld;
    end
    RECEIVE_CAL3: begin
      BPE1_o_rdy = ld_vld;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE1_o_rdy = (counter_1st[1:0] == 2'b10) | ld_vld;
    end
    CAL_OUTPUT: begin
      BPE1_o_rdy = ~(counter_1st[0]);
    end
    CAL1: begin
      BPE1_o_rdy = ~(counter_1st[0]);
    end
    CAL2: begin
      BPE1_o_rdy = (counter_1st[1:0] == 2'b00);
    end
    SAVE: begin
      BPE1_o_rdy = (counter_1st[1:0] == 2'b00);
    end
    default: begin
      BPE1_o_rdy = 0;
    end
  endcase
end

always @(posedge clk) begin
  BPE1_bout_buffer <= BPE1_bout;
end

always @(*) begin
  case (state_1st)
    RECEIVE_CAL1: begin
      BPE1_coef = coef_reg_0;
    end
    RECEIVE_CAL2: begin
      BPE1_coef = coef_reg_0;
    end
    RECEIVE_CAL3: begin
      BPE1_coef = coef_reg_0;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE1_coef = (counter_1st[1]) ? coef_reg_1 : coef_reg_0;
    end
    CAL_OUTPUT: begin
      BPE1_coef = (counter_1st[1]) ? coef_reg_1 : coef_reg_2;
    end
    CAL1: begin
      BPE1_coef = coef_reg_2;
    end
    CAL2: begin
      BPE1_coef = coef_reg_2;
    end
    default: begin
      BPE1_coef = 0;
    end
  endcase
end

// ====================================BPE2、BPE3 I/O Control ============================= //

always @(*) begin
  case (state_1st)
    RECEIVE_CAL_OUTPUT: begin
      ld_vld_2nd = (counter_1st == 2'b10);
      ld_dat_2nd = BPE1_aout;
    end
    CAL_OUTPUT: begin
      ld_vld_2nd = (counter_1st == 2'b10);
      ld_dat_2nd = BPE1_aout;
    end
    CAL1: begin
      ld_vld_2nd = (counter_1st == 2'b10);
      ld_dat_2nd = BPE1_aout;
    end
    TRANSFER: begin
      ld_vld_2nd = (counter_1st == 2'b00) & (state_io_2nd == INPUT);
      ld_dat_2nd = sram_dout_512;
    end
    default: begin
      ld_vld_2nd = 0;
      ld_dat_2nd = 0;
    end
  endcase
end

always @(*) begin
  case (state_1st)
    TRANSFER: begin
      ld_vld_3rd = (counter_1st == 2'b01) & (state_i_3rd == INPUT);
      ld_dat_3rd = sram_dout_512;
    end
    default: begin
      ld_vld_3rd = 0;
      ld_dat_3rd = 0;
    end
  endcase
end

reg [1:0] state_io_2nd;
reg [1:0] state_io_2nd_next;

reg [1:0] state_i_3rd;
reg [1:0] state_i_3rd_next;

localparam WAIT = 2'b00;
localparam INPUT = 2'b01;
localparam OUTPUT = 2'b10;

always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    state_io_2nd <= WAIT;
  end else begin
    state_io_2nd <= state_io_2nd_next;
  end
end

always @(*) begin
  case (state_io_2nd)
    WAIT: begin
      state_io_2nd_next = ~(state_1st == TRANSFER) ? WAIT : 
                           (state_2nd == TRANSFER) ? OUTPUT : 
                           (state_2nd == IDLE) ? INPUT : WAIT;
    end
    INPUT: begin
      state_io_2nd_next = (input_done_2nd) ? WAIT : INPUT;
    end
    OUTPUT: begin
      state_io_2nd_next = (output_done_2nd) ? WAIT : OUTPUT;
    end
    default: begin
      state_io_2nd_next = WAIT;
    end
  endcase
end

always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    state_i_3rd <= WAIT;
  end else begin
    state_i_3rd <= state_i_3rd_next;
  end
end

always @(*) begin
  case (state_i_3rd)
    WAIT: begin
      state_i_3rd_next =  ~(state_1st == TRANSFER) ? WAIT :
                           (state_3rd == IDLE) & (bpe3_can_input) ? INPUT : WAIT;
    end
    INPUT: begin
      state_i_3rd_next = (input_done_3rd) ? WAIT : INPUT;
    end
    default: begin
      state_i_3rd_next = WAIT;
    end
  endcase
end

// BPE2 input address
/*wire [13:0] bpe2_input_addr;
reg [8:0] bpe2_input_counter;
wire [8:0] bpe2_input_counter_next;*/

always @(posedge clk or negedge rstn) begin
  if (~rstn | decode) begin
    bpe2_input_counter <= 128;
  end else begin
    bpe2_input_counter <= bpe2_input_counter_next;
  end
end
assign bpe2_input_counter_next = (ld_vld_2nd) ? bpe2_input_counter + 1 : bpe2_input_counter;
assign bpe2_input_addr = {2'b0, bpe2_input_counter[8:0], 2'b0};
assign input_done_2nd = &bpe2_input_counter[6:0] & ld_vld_2nd;

// BPE2 output address
/*wire [13:0] bpe2_output_addr;
reg [8:0] bpe2_output_counter;
wire [8:0] bpe2_output_counter_next;*/

always @(posedge clk or negedge rstn) begin
  if (~rstn | decode) begin
    bpe2_output_counter <= 0;
  end else begin
    bpe2_output_counter <= bpe2_output_counter_next;
  end
end

// ld_sram_512_vld
assign bpe2_output_counter_next = (ld_sram_512_vld) ? bpe2_output_counter + 1 : bpe2_output_counter;
assign bpe2_output_addr = {2'b0, bpe2_output_counter[8:0], 2'b0};
assign output_done_2nd = &bpe2_output_counter[6:0] & ld_sram_512_vld;


// BPE3 input address
/*wire [13:0] bpe3_input_addr;
reg  [8:0] bpe3_input_counter;
wire [8:0] bpe3_input_counter_next;
wire bpe3_can_input;*/

assign bpe3_can_input = bpe2_output_counter > bpe3_input_counter;

always @(posedge clk or negedge rstn) begin
  if (~rstn | decode) begin
    bpe3_input_counter <= 0;
  end else begin
    bpe3_input_counter <= bpe3_input_counter_next;
  end
end

assign bpe3_input_counter_next = (ld_vld_3rd) ? bpe3_input_counter + 1 : bpe3_input_counter;
assign bpe3_input_addr = {2'b0, bpe3_input_counter[8:0], 2'b0}; 
assign input_done_3rd = &bpe3_input_counter[4:0] & ld_vld_3rd;

// =======================================BPE2================================== //

assign ld_sram_512_vld = (state_2nd == TRANSFER) & (counter_1st[1:0] == 2'b0) & (state_io_2nd == OUTPUT);

// ld_rdy
assign ld_rdy_2nd = (counter_2nd[1:0] == 2'b00);

//coef_done
assign coef_done_2nd = (coef_count_2nd == 2'b11);
assign bpe_act[1] = (state_2nd == 4'b0) & ld_vld_2nd;

always @(posedge clk or negedge rstn) begin
  if (~rstn | bpe_act[1]) begin
    coef_count_2nd <= 0;
  end else begin
    coef_count_2nd <= coef_count_2nd_next;
  end
end

always @(posedge clk or negedge rstn) begin
  if (~rstn | bpe_act[1]) begin
    coef_reg_0_2nd <= 0;
    coef_reg_1_2nd <= 0;
    coef_reg_2_2nd <= 0;
  end else begin
    coef_reg_0_2nd <= coef_reg_0_2nd_next;
    coef_reg_1_2nd <= coef_reg_1_2nd_next;
    coef_reg_2_2nd <= coef_reg_2_2nd_next;
  end
end

assign coef_count_2nd_next = (coef_vld[1]) ? coef_count_2nd + 1 : coef_count_2nd;
assign coef_reg_0_2nd_next = (coef_vld[1]) & (coef_count_2nd[1:0] == 2'b00) ? coef_dat : coef_reg_0_2nd;
assign coef_reg_1_2nd_next = (coef_vld[1]) & (coef_count_2nd[1:0] == 2'b01) ? coef_dat : coef_reg_1_2nd;
assign coef_reg_2_2nd_next = (coef_vld[1]) & (coef_count_2nd[1:0] == 2'b10) ? coef_dat : coef_reg_2_2nd;

// State
always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    state_2nd <= 0;
  end else begin
    state_2nd <= state_2nd_next;
  end
end

always @(*) begin
  case (state_2nd)
    IDLE: begin
      state_2nd_next = (ld_vld_2nd) ? RECEIVE : IDLE; 
    end
    RECEIVE: begin
      state_2nd_next = (counter_2nd == 254) ? RECEIVE_CAL1 : RECEIVE;
    end
    RECEIVE_CAL1: begin
      state_2nd_next = (counter_2nd == 283) ? RECEIVE_CAL2 : RECEIVE_CAL1;
    end
    RECEIVE_CAL2: begin
      state_2nd_next = (counter_2nd == 411) ? RECEIVE_CAL3 : RECEIVE_CAL2;
    end
    RECEIVE_CAL3: begin
      state_2nd_next = (counter_2nd == 439) ? RECEIVE_CAL_OUTPUT : RECEIVE_CAL3;
    end
    RECEIVE_CAL_OUTPUT: begin
      state_2nd_next = (counter_2nd == 509) ? CAL_OUTPUT : RECEIVE_CAL_OUTPUT;
    end 
    CAL_OUTPUT: begin
      state_2nd_next = (counter_2nd == 539) ? CAL1 : CAL_OUTPUT;
    end
    CAL1: begin
      state_2nd_next = (counter_2nd == 567) ? CAL2 : CAL1;
    end
    CAL2: begin
      state_2nd_next = (counter_2nd == 637) ? SAVE : CAL2;
    end
    SAVE: begin
      state_2nd_next = (counter_2nd == 664) ? TRANSFER : SAVE;
    end
    TRANSFER: begin
      state_2nd_next = (output_done_2nd) ? IDLE : TRANSFER;
    end
  endcase
end

// Counter
wire wait_ld_2nd;
wire coef_not_ready_2nd;
assign coef_not_ready_2nd = (counter_2nd == 254) & (~coef_done_2nd);
assign wait_ld_2nd = (state_2nd >= 4'd1 && state_2nd <= 4'd5) && (counter_2nd[1:0] == 2'b00);
assign trigger_once_2nd_next  = trigger_once_2nd | ld_vld_2nd;
assign counting_2nd_next  = (ld_vld_2nd && !trigger_once_2nd) ? 1'b1 : counting_2nd;
assign counter_2nd_next = 
    (ld_vld_2nd && !trigger_once_2nd) ? 16'd1 :
    (counting_2nd && !wait_ld_2nd && !coef_not_ready_2nd) ? counter_2nd + 1 :
    (counting_2nd && wait_ld_2nd && ld_vld_2nd && !coef_not_ready_2nd) ? counter_2nd + 1 :
                                                             counter_2nd;


assign counter_2nd_delay_next = counter_2nd - 27;
assign counter_2nd_adv_next   = counter_2nd + 2;
assign stage2_counter_2nd_next    = counter_2nd - 182;
assign stage2_counter_2nd_delay_next = stage2_counter_2nd - 28;

always @(posedge clk or negedge rstn) begin
  if (~rstn | output_done_2nd) begin
    counter_2nd              <= 16'd0;
    counting_2nd             <= 1'b0;
    trigger_once_2nd         <= 1'b0;
    counter_2nd_delay        <= 16'd0;
    counter_2nd_delay_buffer <= 16'd0;
    counter_2nd_adv          <= 16'd0;
    stage2_counter_2nd           <= 16'd0;
    stage2_counter_2nd_delay     <= 16'd0;
    stage2_counter_2nd_buffer    <= 16'd0;
    stage2_counter_2nd_delay_buffer <= 16'd0;
  end else begin
    counter_2nd              <= counter_2nd_next;
    counting_2nd             <= counting_2nd_next;
    trigger_once_2nd         <= trigger_once_2nd_next;
    counter_2nd_delay        <= counter_2nd_delay_next;
    counter_2nd_delay_buffer <= counter_2nd_delay;
    counter_2nd_adv          <= counter_2nd_adv_next;
    stage2_counter_2nd           <= stage2_counter_2nd_next;
    stage2_counter_2nd_delay     <= stage2_counter_2nd_delay_next;
    stage2_counter_2nd_buffer    <= stage2_counter_2nd;
    stage2_counter_2nd_delay_buffer <= stage2_counter_2nd_delay;
  end
end


//Sram Control Signal

//sram enable 
always @(*) begin
  case (state_2nd)
    IDLE: begin
      sram_en_128 = ld_vld_2nd;
    end
    RECEIVE: begin
      sram_en_128 = ld_vld_2nd;
    end
    RECEIVE_CAL1: begin
      sram_en_128 = ld_vld_2nd;
    end
    RECEIVE_CAL2: begin
      sram_en_128 = (counter_2nd[1:0] == 2'b00) ? ld_vld_2nd : (counter_2nd[1:0] == 2'b01);
    end
    RECEIVE_CAL3: begin
      sram_en_128 = (counter_2nd[1:0] == 2'b00) ? ld_vld_2nd : ~(counter_2nd[1:0] == 2'b11);
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_en_128 = ~(counter_2nd[1:0] == 2'b00) | ld_vld_2nd;
    end
    CAL_OUTPUT: begin
      sram_en_128 = 1;
    end
    CAL1: begin
      sram_en_128 = 1;
    end
    CAL2: begin
      sram_en_128 = ~(counter_2nd[1:0] == 2'b10);
    end
    SAVE: begin
      sram_en_128 = (counter_2nd[1:0] == 2'b00);
    end
    TRANSFER: begin
      sram_en_128 = 1;
    end
    default: begin
      sram_en_128 = 0;
    end
  endcase
end

// sram_we
always @(*) begin
  case (state_2nd)
    IDLE: begin
      sram_we_128 = ld_vld_2nd & (phase);
    end
    RECEIVE: begin
      sram_we_128 = ld_vld_2nd & (phase);
    end
    RECEIVE_CAL1: begin
      sram_we_128 = 0;
    end
    RECEIVE_CAL2: begin
      sram_we_128 = (counter_1st[1:0] == 2'b00) ? (ld_vld & phase) : 
                    (counter_1st[1:0] == 2'b01) & (phase); 
    end
    RECEIVE_CAL3: begin
      sram_we_128 = (counter_1st[1:0] == 2'b00) ? (ld_vld & phase) : 
                    (counter_1st[1:0] == 2'b01) & (phase);  
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_we_128 = (counter_1st[1:0] == 2'b00) ? (ld_vld & phase) : (phase);
    end
    CAL_OUTPUT: begin
      sram_we_128 = (phase);
    end
    CAL1: begin
      sram_we_128 = (counter_1st[1:0] == 2'b11) ? 0 : (counter_1st[1:0] == 2'b10) | (phase);
    end
    CAL2: begin
      sram_we_128 = ~(counter_1st[1]) & (phase);
    end
    SAVE: begin
      sram_we_128 = (counter_1st[1:0] == 2'b00);
    end
    TRANSFER: begin
      sram_we_128 = 0;
    end
    default: begin
      sram_we_128 = 0;
    end
  endcase
end

assign WE_128 = {4{sram_we_128}};


//data_to_sram
always @(*) begin
  case (state_2nd)
    IDLE: begin
      data_to_sram_2nd = {ld_dat_2nd[127:0], 128'b0};
    end
    RECEIVE: begin
      data_to_sram_2nd = {ld_dat_2nd[127:0], 128'b0};
    end
    RECEIVE_CAL1: begin
      data_to_sram_2nd = 0;
    end
    RECEIVE_CAL2: begin
      data_to_sram_2nd = (counter_2nd[1:0] == 2'b00) ? {BPE2_aout[127:0], 128'b0} : {BPE2_bout_buffer[127:0], 128'b0};
    end
    RECEIVE_CAL3: begin
      data_to_sram_2nd = (counter_2nd[1:0] == 2'b00) ? {BPE2_aout[127:0], 128'b0} : {BPE2_bout_buffer[127:0], 128'b0};
    end
    RECEIVE_CAL_OUTPUT: begin
      data_to_sram_2nd = (counter_2nd[0]) ? {BPE2_bout_buffer[127:0], 128'b0} : {BPE2_aout[127:0], 128'b0};
    end
    CAL_OUTPUT: begin
      data_to_sram_2nd = (counter_2nd[0]) ? {BPE2_bout_buffer[127:0], 128'b0} : {BPE2_aout[127:0], 128'b0};
    end
    CAL1: begin
      data_to_sram_2nd = (counter_2nd[1:0] == 2'b00) ? {BPE2_aout[127:0], 128'b0} :
                     (counter_2nd[1:0] == 2'b01) ? {BPE2_bout_buffer[127:0], 128'b0} :
                                                   {BPE2_bout[127:0], BPE2_aout[127:0]}; 
    end
    CAL2: begin
      data_to_sram_2nd = (counter_2nd[1:0] == 2'b00) ? {BPE2_aout[127:0], 128'b0} : {BPE2_bout_buffer[127:0], 128'b0}; 
    end
    SAVE: begin
      data_to_sram_2nd = {BPE2_bout[127:0], BPE2_aout[127:0]};
    end
    TRANSFER: begin
      data_to_sram_2nd = 0;
    end
    default: begin
      data_to_sram_2nd = 0;
    end
  endcase
end

assign sram_din_128 = (phase) ? data_to_sram_2nd[255:128] : data_to_sram_2nd[127:0];
assign sram_addr_128 = (phase) ? sram_addr_one_cycle_2nd[25:13] : sram_addr_one_cycle_2nd[12:0];



// sram_addr
always @(*) begin
  case (state_2nd)
    IDLE: begin 
      sram_addr_one_cycle_2nd = {5'b0, counter_2nd[7:0], 13'b0};
    end
    RECEIVE: begin // 0
      sram_addr_one_cycle_2nd = {5'b0, counter_2nd[7:0], 13'b0};
    end
    RECEIVE_CAL1: begin // 1
      sram_addr_one_cycle_2nd = {13'B0, 5'b0, counter_2nd[7:0]};
    end
    RECEIVE_CAL2: begin // 2
      sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b00) ? {5'b0, counter_2nd_delay[7:0] ,5'b0, counter_2nd[7:0]} : 
                                                          {5'b00001, counter_2nd_delay_buffer[7:0], 13'b0};
    end
    RECEIVE_CAL3: begin // 3
      sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b00) ? {5'b0, counter_2nd_delay[7:0] ,5'b0, counter_2nd[7:0]} :
                            (counter_2nd[1:0] == 2'b01) ? {5'b00001, counter_2nd_delay_buffer[7:0], 6'b0, stage2_counter_2nd[6:0]} :
                                                          {13'b0, 6'b000001, stage2_counter_2nd_buffer[6:0]};
    end
    RECEIVE_CAL_OUTPUT: begin // 4
      sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b00) ? {5'b0, counter_2nd_delay[7:0] ,5'b0, counter_2nd[7:0]} :
                            (counter_2nd[1:0] == 2'b01) ? {5'b00001, counter_2nd_delay_buffer[7:0], 6'b0, stage2_counter_2nd[6:0]} :
                            (counter_2nd[1:0] == 2'b10) ? {6'b0, stage2_counter_2nd_delay[6:0], 6'b000001, stage2_counter_2nd_buffer[6:0]} :
                                                          {6'b000001, stage2_counter_2nd_delay_buffer[6:0], 13'b0};
    end
    CAL_OUTPUT: begin // 5
      sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b00) ? {5'b0, counter_2nd_delay[7:0] ,6'b000011, counter_2nd[6:0]} :
                            (counter_2nd[1:0] == 2'b01) ? {5'b00001, counter_2nd_delay_buffer[7:0], 6'b0, stage2_counter_2nd[6:0]} :
                            (counter_2nd[1:0] == 2'b10) ? {6'b0, stage2_counter_2nd_delay[6:0], 6'b000001, stage2_counter_2nd_buffer[6:0]} :
                                                          {6'b000001, stage2_counter_2nd_delay_buffer[6:0], 6'b000010, counter_2nd_adv[6:0]};
    end
    CAL1: begin // 6
      sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b00) ? {6'b000010, counter_2nd_delay[6:0] ,6'b000011, counter_2nd[6:0]} :
                            (counter_2nd[1:0] == 2'b01) ? {6'b000011, counter_2nd_delay_buffer[6:0], 13'b0} :
                            (counter_2nd[1:0] == 2'b10) ? {6'b000001, stage2_counter_2nd_delay[6:0], 6'b0, stage2_counter_2nd_delay[6:0]} :
                                                          {13'b0, 6'b000010, counter_2nd_adv[6:0]}; 
    end
    CAL2: begin // 7
      sram_addr_one_cycle_2nd = (counter_2nd[1:0] == 2'b00) ? {6'b000010, counter_2nd_delay[6:0] ,6'b000011, counter_2nd[6:0]} :
                            (counter_2nd[1:0] == 2'b01) ? {6'b000011, counter_2nd_delay_buffer[6:0], 13'b0} :
                                                          {13'b0, 6'b000010, counter_2nd_adv[6:0]}; 
    end
    SAVE: begin // 8
      sram_addr_one_cycle_2nd = {6'b000011, counter_2nd_delay[6:0], 6'b000010, counter_2nd_delay[6:0]};
    end
    TRANSFER: begin
      sram_addr_one_cycle_2nd = (state_io_2nd == OUTPUT) ? {13'b0, 4'b0, bpe2_output_counter[6:0], 2'b0} : 0;
    end
    default: begin
      sram_addr_one_cycle = 0;
    end
  endcase
end

//BPE1
// BPEinA
always @(*) begin
  case (state_2nd)
    RECEIVE_CAL1: begin
      BPE2_ain = sram_dout_128;
    end
    RECEIVE_CAL2: begin
      BPE2_ain = sram_dout_128;
    end
    RECEIVE_CAL3: begin
      BPE2_ain = (counter_2nd[1:0] == 2'b0) ? sram_dout_128 : BPE2_ain_buffer;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE2_ain = (counter_2nd[1:0] == 2'b0) ? sram_dout_128 : BPE2_ain_buffer;
    end
    CAL_OUTPUT: begin
      BPE2_ain = BPE2_ain_buffer;
    end
    CAL1: begin
      BPE2_ain = BPE2_ain_buffer;
    end
    CAL2: begin
      BPE2_ain = BPE2_ain_buffer;
    end
    default: begin
      BPE2_ain = 0;
    end
  endcase 
end

always @(*) begin
  case (state_2nd)
    RECEIVE_CAL1: begin
      BPE2_bin = ld_dat_2nd;
    end
    RECEIVE_CAL2: begin
      BPE2_bin = ld_dat_2nd;
    end
    RECEIVE_CAL3: begin
      BPE2_bin = (counter_2nd[1]) ? sram_dout_128 : ld_dat_2nd;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE2_bin = (counter_2nd[1]) ? sram_dout_128 : ld_dat_2nd;
    end
    CAL_OUTPUT: begin
      BPE2_bin = sram_dout_128;
    end
    CAL1: begin
      BPE2_bin = sram_dout_128;
    end
    CAL2: begin
      BPE2_bin = sram_dout_128;
    end
    default: begin
      BPE2_bin = 0;
    end
  endcase
end

assign BPE2_ain_buffer_next = (counter_2nd[1:0] == 2'b00) ? BPE2_ain_buffer : sram_din_128;

//BPEinPreBuffer
always @(posedge clk) begin
  BPE2_ain_buffer <= BPE2_ain_buffer_next;
end

always @(*) begin
  case (state_2nd)
    RECEIVE_CAL1: begin
      BPE2_i_vld = ld_vld_2nd;
    end
    RECEIVE_CAL2: begin
      BPE2_i_vld = ld_vld_2nd;
    end
    RECEIVE_CAL3: begin
      BPE2_i_vld = (counter_2nd[1:0] == 2'b10) | ld_vld_2nd;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE2_i_vld = (counter_2nd[1:0] == 2'b10) | ld_vld_2nd;
    end
    CAL_OUTPUT: begin
      BPE2_i_vld = ~(counter_2nd[0]);
    end
    CAL1: begin
      BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
    end
    CAL2: begin
      BPE2_i_vld = (counter_2nd[1:0] == 2'b00);
    end
    default: begin
      BPE2_i_vld = 0;
    end
  endcase
end

always @(*) begin
  case (state_2nd)
    RECEIVE_CAL2: begin
      BPE2_o_rdy = ld_vld_2nd;
    end
    RECEIVE_CAL3: begin
      BPE2_o_rdy = ld_vld_2nd;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE2_o_rdy = (counter_2nd[1:0] == 2'b10) | ld_vld_2nd;
    end
    CAL_OUTPUT: begin
      BPE2_o_rdy = ~(counter_2nd[0]);
    end
    CAL1: begin
      BPE2_o_rdy = ~(counter_2nd[0]);
    end
    CAL2: begin
      BPE2_o_rdy = (counter_2nd[1:0] == 2'b00);
    end
    SAVE: begin
      BPE2_o_rdy = (counter_2nd[1:0] == 2'b00);
    end
    default: begin
      BPE2_o_rdy = 0;
    end
  endcase
end

always @(posedge clk) begin
  BPE2_bout_buffer <= BPE2_bout;
end

always @(*) begin
  case (state_2nd)
    RECEIVE_CAL1: begin
      BPE2_coef = coef_reg_0_2nd;
    end
    RECEIVE_CAL2: begin
      BPE2_coef = coef_reg_0_2nd;
    end
    RECEIVE_CAL3: begin
      BPE2_coef = coef_reg_0_2nd;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE2_coef = (counter_2nd[1]) ? coef_reg_1_2nd : coef_reg_0_2nd;
    end
    CAL_OUTPUT: begin
      BPE2_coef = (counter_2nd[1]) ? coef_reg_1_2nd : coef_reg_2_2nd;
    end
    CAL1: begin
      BPE2_coef = coef_reg_2_2nd;
    end
    CAL2: begin
      BPE2_coef = coef_reg_2_2nd;
    end
    default: begin
      BPE2_coef = 0;
    end
  endcase
end





// ======================================BPE3=================================== //

// ld_rdy
assign ld_rdy_3rd = (counter_3rd[1:0] == 2'b00);

//coef_done
assign coef_done_3rd = (coef_count_3rd == 2'b11);
assign bpe_act[2] = (state_3rd == 4'b0) & ld_vld_3rd;

always @(posedge clk or negedge rstn) begin
  if (~rstn | bpe_act[2]) begin
    coef_count_3rd <= 0;
  end else begin
    coef_count_3rd <= coef_count_3rd_next;
  end
end

always @(posedge clk or negedge rstn) begin
  if (~rstn | bpe_act[2]) begin
    coef_reg_0_3rd <= 0;
    coef_reg_1_3rd <= 0;
    coef_reg_2_3rd <= 0;
  end else begin
    coef_reg_0_3rd <= coef_reg_0_3rd_next;
    coef_reg_1_3rd <= coef_reg_1_3rd_next;
    coef_reg_2_3rd <= coef_reg_2_3rd_next;
  end
end

assign coef_count_3rd_next = (coef_vld[2]) ? coef_count_3rd + 1 : coef_count_3rd;
assign coef_reg_0_3rd_next = (coef_vld[2]) & (coef_count_3rd[1:0] == 2'b00) ? coef_dat : coef_reg_0_3rd;
assign coef_reg_1_3rd_next = (coef_vld[2]) & (coef_count_3rd[1:0] == 2'b01) ? coef_dat : coef_reg_1_3rd;
assign coef_reg_2_3rd_next = (coef_vld[2]) & (coef_count_3rd[1:0] == 2'b10) ? coef_dat : coef_reg_2_3rd;

// State
always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    state_3rd <= 0;
  end else begin
    state_3rd <= state_3rd_next;
  end
end

always @(*) begin
  case (state_3rd)
    IDLE: begin
      state_3rd_next = (ld_vld_3rd) ? RECEIVE : IDLE; 
    end
    RECEIVE: begin
      state_3rd_next = (counter_3rd == 62) ? RECEIVE_CAL1 : RECEIVE;
    end
    RECEIVE_CAL1: begin
      state_3rd_next = (counter_3rd == 91) ? RECEIVE_CAL2 : RECEIVE_CAL1;
    end
    RECEIVE_CAL2: begin
      state_3rd_next = (counter_3rd == 124) ? RECEIVE_CAL3 : RECEIVE_CAL2;
    end
    RECEIVE_CAL3: begin
      state_3rd_next = (counter_3rd == 153) ? RECEIVE_CAL_OUTPUT : RECEIVE_CAL3;
    end
    RECEIVE_CAL_OUTPUT: begin
      state_3rd_next = (counter_3rd == 156) ? SAVE : RECEIVE_CAL_OUTPUT;
    end 
    SAVE: begin
      state_3rd_next = (counter_3rd == 664) ? TRANSFER : SAVE;
    end
    TRANSFER: begin
      state_3rd_next = (output_done_3rd) ? IDLE : TRANSFER;
    end
    default: begin
      state_3rd_next = IDLE;
    end
  endcase
end

// Counter
wire wait_ld_3rd;
wire coef_not_ready_3rd;
assign coef_not_ready_3rd = (counter_3rd == 62) & (~coef_done_3rd);
assign wait_ld_3rd = (state_3rd >= 4'd1 && state_3rd <= 4'd4) && (counter_3rd[1:0] == 2'b00);
assign trigger_once_3rd_next  = trigger_once_3rd | ld_vld_3rd;
assign counting_3rd_next  = (ld_vld_3rd && !trigger_once_3rd) ? 1'b1 : counting_3rd;
assign counter_3rd_next = 
    (ld_vld_3rd && !trigger_once_3rd) ? 16'd1 :
    (counting_3rd && !wait_ld_3rd && !coef_not_ready_3rd) ? counter_3rd + 1 :
    (counting_3rd && wait_ld_3rd && ld_vld_3rd && !coef_not_ready_3rd) ? counter_3rd + 1 :
                                                             counter_3rd;


assign counter_3rd_delay_next = counter_3rd - 27;
assign counter_3rd_adv_next   = counter_3rd + 2;
assign stage2_counter_3rd_next    = counter_3rd + 3;
assign stage2_counter_3rd_delay_next = stage2_counter_3rd - 28;

always @(posedge clk or negedge rstn) begin
  if (~rstn | output_done_3rd) begin
    counter_3rd              <= 16'd0;
    counting_3rd             <= 1'b0;
    trigger_once_3rd         <= 1'b0;
    counter_3rd_delay        <= 16'd0;
    counter_3rd_delay_buffer <= 16'd0;
    counter_3rd_adv          <= 16'd0;
    stage2_counter_3rd           <= 16'd0;
    stage2_counter_3rd_delay     <= 16'd0;
    stage2_counter_3rd_buffer    <= 16'd0;
    stage2_counter_3rd_delay_buffer <= 16'd0;
  end else begin
    counter_3rd              <= counter_3rd_next;
    counting_3rd             <= counting_3rd_next;
    trigger_once_3rd         <= trigger_once_3rd_next;
    counter_3rd_delay        <= counter_3rd_delay_next;
    counter_3rd_delay_buffer <= counter_3rd_delay;
    counter_3rd_adv          <= counter_3rd_adv_next;
    stage2_counter_3rd           <= stage2_counter_3rd_next;
    stage2_counter_3rd_delay     <= stage2_counter_3rd_delay_next;
    stage2_counter_3rd_buffer    <= stage2_counter_3rd;
    stage2_counter_3rd_delay_buffer <= stage2_counter_3rd_delay;
  end
end


//Sram Control Signal

//sram enable 
always @(*) begin
  case (state_3rd)
    IDLE: begin
      sram_en_32 = ld_vld_3rd;
    end
    RECEIVE: begin
      sram_en_32 = ld_vld_3rd;
    end
    RECEIVE_CAL1: begin
      sram_en_32 = ld_vld_3rd;
    end
    RECEIVE_CAL2: begin
      sram_en_32 = (counter_3rd[1:0] == 2'b00) ? ld_vld_3rd : (counter_3rd[1:0] == 2'b01);
    end
    RECEIVE_CAL3: begin
      sram_en_32 = 1;
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_en_32 = 1;
    end
    SAVE: begin
      sram_en_32 = ~(counter_3rd[0]);
    end
    TRANSFER: begin
      sram_en_32 = 1;
    end
    default: begin
      sram_en_32 = 0;
    end
  endcase
end

// sram_we
always @(*) begin
  case (state_3rd)
    IDLE: begin
      sram_we_32 = ld_vld_2nd & (phase);
    end
    RECEIVE: begin
      sram_we_32 = ld_vld_2nd & (phase);
    end
    RECEIVE_CAL1: begin
      sram_we_32 = 0;
    end
    RECEIVE_CAL2: begin
      sram_we_32 = (counter_1st[1:0] == 2'b00) ? (ld_vld & phase) : 
                    (counter_1st[1:0] == 2'b01) & (phase); 
    end
    RECEIVE_CAL3: begin
      sram_we_32 = ~(counter_1st[1]) & (phase);
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_we_32 = phase;
    end
    SAVE: begin
      sram_we_32 = ~(counter_1st[0]);
    end
    TRANSFER: begin
      sram_we_32 = 0;
    end
    default: begin
      sram_we_32 = 0;
    end
  endcase
end

assign WE_32 = {4{sram_we_32}};


//data_to_sram
always @(*) begin
  case (state_3rd)
    IDLE: begin
      data_to_sram_3rd = {ld_dat_3rd[127:0], 128'b0};
    end
    RECEIVE: begin
      data_to_sram_3rd = {ld_dat_3rd[127:0], 128'b0};
    end
    RECEIVE_CAL1: begin
      data_to_sram_3rd = 0;
    end
    RECEIVE_CAL2: begin
      data_to_sram_3rd = (counter_3rd[1:0] == 2'b00) ? {BPE3_aout[127:0], 128'b0} : {BPE3_bout_buffer[127:0], 128'b0};
    end
    RECEIVE_CAL3: begin
      data_to_sram_3rd = (counter_3rd[1:0] == 2'b00) ? {BPE3_aout[127:0], 128'b0} : {BPE3_bout_buffer[127:0], 128'b0};
    end
    RECEIVE_CAL_OUTPUT: begin
      data_to_sram_3rd = (counter_3rd[0]) ? {BPE3_bout_buffer[127:0], 128'b0} : {BPE3_aout[127:0], 128'b0};
    end
    SAVE: begin
      data_to_sram_3rd = {BPE3_bout[127:0], BPE3_aout[127:0]};
    end
    TRANSFER: begin
      data_to_sram_3rd = 0;
    end
    default: begin
      data_to_sram_3rd = 0;
    end
  endcase
end

assign sram_din_32 = (phase) ? data_to_sram_3rd[255:128] : data_to_sram_3rd[127:0];
assign sram_addr_32 = (phase) ? sram_addr_one_cycle_3rd[25:13] : sram_addr_one_cycle_3rd[12:0];



// sram_addr
always @(*) begin
  case (state_3rd)
    IDLE: begin 
      sram_addr_one_cycle_3rd = {7'b0, counter_3rd[5:0], 13'b0}; 
    end
    RECEIVE: begin // 0
      sram_addr_one_cycle_3rd = {7'b0, counter_3rd[5:0], 13'b0}; 
    end
    RECEIVE_CAL1: begin // 1
      sram_addr_one_cycle_3rd = {13'b0, 7'b0, counter_3rd[5:0]};  
    end
    RECEIVE_CAL2: begin // 2
      sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b00) ? {7'b0, counter_3rd_delay[5:0] ,7'b0, counter_3rd[5:0]} : 
                                                          {7'b0000001, counter_3rd_delay_buffer[7:0], 13'b0};
    end
    RECEIVE_CAL3: begin // 3
      sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b00) ? {7'b0, counter_3rd_delay[5:0] ,8'b00000011, counter_3rd[4:0]} :
                            (counter_3rd[1:0] == 2'b01) ? {7'b0000001, counter_3rd_delay_buffer[7:0], 8'b0, stage2_counter_3rd[4:0]} :
                            (counter_3rd[1:0] == 2'b10) ? {13'b0, 8'b00000001, stage2_counter_3rd_buffer[4:0]} :
                                                          {13'b0, 8'b00000010, counter_3rd_adv[4:0]};
    end
    RECEIVE_CAL_OUTPUT: begin // 4
      sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b00) ? {8'b00000010, counter_3rd_delay[4:0] , 8'b00000011, counter_3rd[4:0]} :
                            (counter_3rd[1:0] == 2'b01) ? {8'b00000011, counter_3rd_delay_buffer[4:0], 8'b0, stage2_counter_3rd[4:0]} :
                            (counter_3rd[1:0] == 2'b10) ? {8'b0, stage2_counter_3rd_delay[4:0], 8'b00000001, stage2_counter_3rd_buffer[4:0]} :
                                                          {8'b00000001, stage2_counter_3rd_delay_buffer[4:0], 8'b00000010, counter_3rd_adv[4:0]};
    end
    SAVE: begin // 5
      sram_addr_one_cycle_3rd = (counter_3rd[1]) ? {8'b00000001, stage2_counter_3rd_delay[4:0], 8'b0, stage2_counter_3rd_delay[4:0]} :
                                                   {8'b00000011, counter_3rd_delay[4:0], 8'b00000010, counter_3rd_delay[4:0]};
    end
    TRANSFER: begin
      sram_addr_one_cycle_3rd = {13'b0, 6'b0, counter_3rd_output[4:0], 2'b0};
    end
    default: begin
      sram_addr_one_cycle = 0;
    end
  endcase
end

//BPE3
// BPEinA
always @(*) begin
  case (state_3rd)
    RECEIVE_CAL1: begin
      BPE3_ain = sram_dout_32;
    end
    RECEIVE_CAL2: begin
      BPE3_ain = sram_dout_32;
    end
    RECEIVE_CAL3: begin
      BPE3_ain = BPE3_ain_buffer;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE3_ain = BPE3_ain_buffer;
    end
    default: begin
      BPE3_ain = 0;
    end
  endcase 
end



always @(*) begin
  case (state_3rd)
    RECEIVE_CAL1: begin
      BPE3_bin = ld_dat_3rd;
    end
    RECEIVE_CAL2: begin
      BPE3_bin = ld_dat_3rd;
    end
    RECEIVE_CAL3: begin
      BPE3_bin = sram_dout_128;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE3_bin = sram_dout_128;
    end
    default: begin
      BPE3_bin = 0;
    end
  endcase
end

assign BPE3_ain_buffer_next = (counter_3rd[1:0] == 2'b00) ? BPE3_ain_buffer : sram_din_32;

//BPEinPreBuffer
always @(posedge clk) begin
  BPE3_ain_buffer <= BPE3_ain_buffer_next;
end

always @(*) begin
  case (state_3rd)
    RECEIVE_CAL1: begin
      BPE3_i_vld = ld_vld_3rd;
    end
    RECEIVE_CAL2: begin
      BPE3_i_vld = ld_vld_3rd;
    end
    RECEIVE_CAL3: begin
      BPE3_i_vld = ~(counter_3rd[0]);
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE3_i_vld = ~(counter_3rd[0]);
    end
    default: begin
      BPE3_i_vld = 0;
    end
  endcase
end

always @(*) begin
  case (state_3rd)
    RECEIVE_CAL2: begin
      BPE3_o_rdy = ld_vld_3rd;
    end
    RECEIVE_CAL3: begin
      BPE3_o_rdy = (counter_3rd[1:0] == 2'b00);
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE3_o_rdy = ~(counter_3rd[0]);
    end
    SAVE: begin
      BPE3_o_rdy = ~(counter_3rd[0]);
    end
    default: begin
      BPE3_o_rdy = 0;
    end
  endcase
end

always @(posedge clk) begin
  BPE2_bout_buffer <= BPE2_bout;
end

always @(*) begin
  case (state_3rd)
    RECEIVE_CAL1: begin
      BPE3_coef = coef_reg_0_3rd;
    end
    RECEIVE_CAL2: begin
      BPE3_coef = coef_reg_0_3rd;
    end
    RECEIVE_CAL3: begin
      BPE3_coef = (counter_3rd[1]) ? coef_reg_1_3rd : coef_reg_2_3rd;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE3_coef = (counter_3rd[1]) ? coef_reg_1_3rd : coef_reg_2_3rd;
    end
    default: begin
      BPE3_coef = 0;
    end
  endcase
end

// ====================================BPE3 -> BPE4=============================== //

assign enable_output_3rd = (state_3rd == TRANSFER) & ld_rdy_4th;
always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    counter_3rd_output <= 0;
  end else begin
    counter_3rd_output <= counter_3rd_output_next;
  end
end

assign counter_3rd_output_next = (enable_output_3rd) ? counter_3rd_output + 1 : 0;

assign output_done_3rd = &counter_3rd_output[4:0];

assign ld_vld_4th = enable_output_3rd;
assign ld_dat_4th = (enable_output_3rd) ? sram_dout_32 : 0;


// ==========================================BPE4 、 BPE5 ==================================//

// 外面給你的訊號只會有ld_vld_4th和ld_dat_4th，你的BPE4在可收的時候ld_rdy_4th就要先拉著才能正常運作












endmodule