module kernel_FFT #(
    parameter pDATA_WIDTH = 128,
    parameter MUL_DELAY = 28
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

    output wire [(pDATA_WIDTH - 1):0] BPE5_ain,
    output wire [(pDATA_WIDTH - 1):0] BPE5_bin,
    output wire [(pDATA_WIDTH - 1):0] BPE5_coef,
    output wire BPE5_i_vld,
    output wire BPE5_o_rdy,
    input  wire [(pDATA_WIDTH - 1):0] BPE5_aout,
    input  wire [(pDATA_WIDTH - 1):0] BPE5_bout,
    input  wire BPE5_i_rdy,
    input  wire BPE5_o_vld,

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
// Parameters for FSM 
localparam IDLE_4th = 0;     // 000000
localparam WAIT_COEF_4th = 1;
localparam FILL0_0_4th = 2;  // 000001
localparam FILL0_1_4th = 3;  // 000010
localparam CALC0_0_4th = 4;  // 000011
localparam CALC0_1_4th = 5;  // 000100
localparam FILL1_0_4th = 6;  // 000101
localparam FILL1_1_4th = 7;  // 000110
localparam CALC1_0_4th = 8;  // 000111
localparam CALC1_1_4th = 9;  // 001000
localparam FILL2_0_4th = 10;  // 001001
localparam FILL2_1_4th = 11; // 001010
localparam CALC2_0_4th = 12; // 001011
localparam CALC2_1_4th = 13; // 001100
localparam FILL3_0_4th = 14; // 001101
localparam FILL3_1_4th = 15; // 001110
localparam CALC3_0_4th = 16; // 001111
localparam CALC3_1_4th = 17; // 010000
localparam BPE_O_0_4th = 18; // 010001
localparam BPE_O_1_4th = 19; // 010010
localparam BPE_I_0_4th = 20; // 010011
localparam BPE_I_1_4th = 21; // 010100
localparam BPE_O_2_4th = 22; // 010101
localparam BPE_O_3_4th = 23; // 010110
localparam BPE_I_2_4th = 24; // 010111
localparam BPE_I_3_4th = 25; // 011000
localparam BPE_O_4_4th = 26; // 011001
localparam BPE_O_5_4th = 27; // 011010
localparam BPE_I_4_4th = 28; // 011011
localparam BPE_I_5_4th = 29; // 011100
localparam BPE_O_6_4th = 30; // 011101
localparam BPE_O_7_4th = 31; // 011110
localparam BPE_I_6_4th = 32; // 011111
localparam BPE_I_7_4th = 33; // 100000
localparam TRAN_0_4th = 34; // 100001
localparam TRAN_1_4th = 35; // 100010
localparam TRAN_2_4th = 36; // 100011
localparam TRAN_3_4th = 37; // 100100
localparam TRAN_4_4th = 38; // 100101
localparam TRAN_5_4th = 39; // 100110
localparam TRAN_6_4th = 40; // 100111
localparam TRAN_7_4th = 41; // 101000
localparam TRAN_8_4th = 42; // 101001
localparam TRAN_9_4th = 43; // 101010
localparam TRAN_10_4th = 44; // 101011
localparam TRAN_11_4th = 45; // 101100
localparam TRAN_12_4th = 46; // 101101
localparam TRAN_13_4th = 47; // 101110
localparam TRAN_14_4th = 48; // 101111
localparam TRAN_15_4th = 49; // 110000
localparam FINISH_4th = 50;  // 100001
// parameters for BPE5
localparam DATA_LENGTH = 512;
localparam IDLE_5th = 0;
localparam BPE_I0_5th = 1;
localparam BPE_I1_5th = 2;
localparam BPE_I2_5th = 3;
localparam BPE_I3_5th = 4;
localparam BPE_O0_5th = 5;
localparam BPE_O1_5th = 6;
localparam BPE_O2_5th = 7;
localparam BPE_O3_5th = 8;
localparam FINISH_5th = 9;
localparam WAIT_COEF_5th = 10;

integer i, j, k;
reg phase;
wire phase_next;

always @(posedge clk_2x or negedge rstn) begin
  if (~rstn) begin
    phase <= 1;
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
wire [15:0] stage2_counter_2nd_delay_next;
wire [15:0] stage2_counter_2nd_next;
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
wire ld_sram_512_vld;


reg [1:0] state_io_2nd;
reg [1:0] state_io_2nd_next;




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
wire [15:0] stage2_counter_3rd_delay_next;
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


reg [1:0] state_i_3rd;
reg [1:0] state_i_3rd_next;



// =============================BPE 4=========================== //

wire ld_rdy_4th;

// registers for output signals
wire sm_rdy_4th;
reg coef_rdy_4th;
reg ss_rdy_4th_r, sm_vld_4th_r;
reg [pDATA_WIDTH-1:0] BPE4_coef_r, BPE4_ain_r, BPE4_bin_r;
reg BPE4_i_vld_r, BPE4_o_rdy_r;
reg bpe_act_4th;
// fsm state registers
reg [5:0] state_4th;
reg [5:0] state_4th_next;

// Counters 4th BPE
reg [$clog2(DATA_LENGTH)-1:0] in_cnt_4th, out_cnt_4th, bpe_in_cnt_4th, bpe_out_cnt_4th, coef_cnt_4th;
wire[$clog2(DATA_LENGTH)-1:0] in_cnt_4th_next, out_cnt_4th_next, bpe_in_cnt_4th_next, bpe_out_cnt_4th_next, coef_cnt_4th_next;

// Coefficients for 4th BPE
reg [pDATA_WIDTH-1:0] COE0_0_4th, COE0_1_4th, COE0_2_4th;
reg [pDATA_WIDTH-1:0] COE1_0_4th, COE1_1_4th, COE1_2_4th;
reg [pDATA_WIDTH-1:0] COE2_0_4th, COE2_1_4th, COE2_2_4th;
reg [pDATA_WIDTH-1:0] COE3_0_4th, COE3_1_4th, COE3_2_4th;
wire [pDATA_WIDTH-1:0] COE0_0_4th_tmp, COE0_1_4th_tmp, COE0_2_4th_tmp;
wire [pDATA_WIDTH-1:0] COE1_0_4th_tmp, COE1_1_4th_tmp, COE1_2_4th_tmp;
wire [pDATA_WIDTH-1:0] COE2_0_4th_tmp, COE2_1_4th_tmp, COE2_2_4th_tmp;
wire [pDATA_WIDTH-1:0] COE3_0_4th_tmp, COE3_1_4th_tmp, COE3_2_4th_tmp;

// FIFOs for 4th BPE
// reg [3:0] data_reg_4th_ram0[0:pDATA_WIDTH-1];
// reg [3:0] data_reg_4th_ram0_next[0:pDATA_WIDTH-1];
// reg [1:0] data_reg_4th_ram1[0:pDATA_WIDTH-1];
// reg [1:0] data_reg_4th_ram1_next[0:pDATA_WIDTH-1];
// reg [1:0] data_reg_4th_ram2[0:pDATA_WIDTH-1];
// reg [1:0] data_reg_4th_ram2_next[0:pDATA_WIDTH-1];
reg [0:pDATA_WIDTH-1] data_reg_4th_ram0     [3:0];
reg [0:pDATA_WIDTH-1] data_reg_4th_ram0_next[3:0];
reg [0:pDATA_WIDTH-1] data_reg_4th_ram1     [1:0];
reg [0:pDATA_WIDTH-1] data_reg_4th_ram1_next[1:0];
reg [0:pDATA_WIDTH-1] data_reg_4th_ram2     [1:0];
reg [0:pDATA_WIDTH-1] data_reg_4th_ram2_next[1:0];

reg [(pDATA_WIDTH-1):0] data_789;
// ==============================BPE 5=========================== //

//
reg decoded, decoded_r;
wire [(pDATA_WIDTH-1):0] ld_dat_5th;
// BPE5 output interface
reg BPE5_i_vld_r, BPE5_o_rdy_r; 
reg BPE5_act; // BPE5 active signal
reg [pDATA_WIDTH-1:0] bpe5_coef;

// fsm state registers
reg [3:0] state_5th, state_5th_next;

// AXI signals
wire ss_vld_5th, sm_rdy_5th;
reg ss_rdy_5th, sm_vld_5th;
wire coef_5th_rdy;

reg l;
always @ (posedge clk) l <= 1;
assign coef_5th_rdy = l;

// BPE5 data output
reg [pDATA_WIDTH-1:0] BPE5_dout;//438

// Counters for BPE5
reg [$clog2(DATA_LENGTH)-1:0] in_cnt_5th, out_cnt_5th;
wire[$clog2(DATA_LENGTH)-1:0] in_cnt_5th_next, out_cnt_5th_next;
reg [4:0] coef_cnt_5th; 
wire[4:0] coef_cnt_5th_next;
reg [3:0] bpe_in_cnt_5th; // 4 bits to support 16 outputs
wire[3:0] bpe_in_cnt_5th_next;
reg [3:0] bpe_out_cnt_5th; // 4 bits to support 16 outputs
wire[3:0] bpe_out_cnt_5th_next;

// Data register for 5th BPE
reg [pDATA_WIDTH-1:0] data_reg_5th_ram0, data_reg_5th_ram0_next;
reg [pDATA_WIDTH-1:0] delay_aout_5th [1:0];
reg [pDATA_WIDTH-1:0] delay_aout_5th_next [1:0];
reg [pDATA_WIDTH-1:0] delay_bout_5th_next [1:0];
reg [pDATA_WIDTH-1:0] delay_bout_5th [1:0];

// Coefficient for 5th BPE
reg [pDATA_WIDTH-1:0] COEF0_0_5th, COEF0_1_5th, COEF0_2_5th, COEF0_3_5th;
reg [pDATA_WIDTH-1:0] COEF1_0_5th, COEF1_1_5th, COEF1_2_5th, COEF1_3_5th;
reg [pDATA_WIDTH-1:0] COEF2_0_5th, COEF2_1_5th, COEF2_2_5th, COEF2_3_5th;
reg [pDATA_WIDTH-1:0] COEF3_0_5th, COEF3_1_5th, COEF3_2_5th, COEF3_3_5th;

reg [pDATA_WIDTH-1:0] COEF0_0_5th_next, COEF0_1_5th_next, COEF0_2_5th_next, COEF0_3_5th_next;
reg [pDATA_WIDTH-1:0] COEF1_0_5th_next, COEF1_1_5th_next, COEF1_2_5th_next, COEF1_3_5th_next;
reg [pDATA_WIDTH-1:0] COEF2_0_5th_next, COEF2_1_5th_next, COEF2_2_5th_next, COEF2_3_5th_next;
reg [pDATA_WIDTH-1:0] COEF3_0_5th_next, COEF3_1_5th_next, COEF3_2_5th_next, COEF3_3_5th_next;

//==============================OUTPUT BUFFER=========================== //
// output buffer for 5th BPE
reg [pDATA_WIDTH:0] output_buffer_w[0:255];
reg [pDATA_WIDTH:0] output_buffer[0:255]; //
reg [$clog2(DATA_LENGTH)-1:0] output_buf_in_cnt_r; 
wire[$clog2(DATA_LENGTH)-1:0] output_buf_in_cnt_w; // input counter for output buffer
//reg [pDATA_WIDTH-1:0] BPE5_dout;

// counters
reg [$clog2(DATA_LENGTH)-1:0] kern_out_cnt_r; // output counter for kernel
wire [$clog2(DATA_LENGTH)-1:0] kern_out_cnt_w;

// =================================================================================END OF DECLARATIONS ================================================================================== //
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

assign coef_rdy[2:0] = 3'b111;
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
      state_1st_next = (counter_1st == 2557) ? SAVE : CAL2;
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
      sram_addr_one_cycle = {4'b0011, counter_1st_delay[8:0], 4'b0010, counter_1st_delay[8:0]};
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

assign BPE1_ain_buffer_next = (counter_1st[1:0] == 2'b00) ? BPE1_ain_buffer : sram_dout_512;

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
      BPE1_coef = (counter_1st[1]) ? coef_reg_1 : coef_reg_0;
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
localparam WAIT = 2'b00;
localparam INPUT = 2'b01;
localparam OUTPUT = 2'b10;



always @(*) begin
  case (state_1st)
    RECEIVE_CAL_OUTPUT: begin
      ld_vld_2nd = (counter_1st[1:0] == 2'b10);
      ld_dat_2nd = BPE1_aout;
    end
    CAL_OUTPUT: begin
      ld_vld_2nd = (counter_1st[1:0] == 2'b10);
      ld_dat_2nd = BPE1_aout;
    end
    CAL1: begin
      ld_vld_2nd = (counter_1st[1:0] == 2'b10);
      ld_dat_2nd = BPE1_aout;
    end
    TRANSFER: begin
      ld_vld_2nd = (counter_1st[1:0] == 2'b00) & (state_io_2nd == INPUT);
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
      ld_vld_3rd = (counter_1st[1:0] == 2'b01) & (state_i_3rd == INPUT);
      ld_dat_3rd = sram_dout_512;
    end
    default: begin
      ld_vld_3rd = 0;
      ld_dat_3rd = 0;
    end
  endcase
end

/*reg [1:0] state_io_2nd;
reg [1:0] state_io_2nd_next;

reg [1:0] state_i_3rd;
reg [1:0] state_i_3rd_next;*/

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
      state_io_2nd_next =  &bpe2_output_counter[8:0] & (output_done_2nd) ? 2'b11 :
                           (output_done_2nd) ? WAIT : OUTPUT;
    end
    2'b11: begin
      state_io_2nd_next = (decode) ? WAIT : 2'b11;
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
      state_i_3rd_next = &bpe3_input_counter[8:0] & (input_done_3rd) ? 2'b11 : 
                         (input_done_3rd) ? WAIT : INPUT;
    end
    2'b11: begin
      state_i_3rd_next = (decode) ? WAIT : 2'b11;
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
    bpe2_input_counter <= 0;
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

assign bpe3_can_input = (bpe2_output_counter > bpe3_input_counter) | (~(|bpe2_output_counter[8:0]) & (|bpe3_input_counter[8:0]));

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
assign coef_done_2nd = coef_count_2nd[1:0] == 2'b11; 
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
    default : begin
      state_2nd_next = 0;
    end
  endcase
end

// Counter
wire wait_ld_2nd;
wire coef_not_ready_2nd;
assign coef_not_ready_2nd = (counter_2nd == 252) & (~coef_done_2nd);
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
assign stage2_counter_2nd_next  = counter_2nd - 156;
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
    stage2_counter_2nd_buffer    <= 16'd0;
  end else begin
    counter_2nd              <= counter_2nd_next;
    counting_2nd             <= counting_2nd_next;
    trigger_once_2nd         <= trigger_once_2nd_next;
    counter_2nd_delay        <= counter_2nd_delay_next;
    counter_2nd_delay_buffer <= counter_2nd_delay;
    counter_2nd_adv          <= counter_2nd_adv_next;
    stage2_counter_2nd           <= stage2_counter_2nd_next;
    stage2_counter_2nd_buffer    <= stage2_counter_2nd;
  end
end

always @(posedge clk) begin
  stage2_counter_2nd_delay <= stage2_counter_2nd_delay_next;
  stage2_counter_2nd_delay_buffer <= stage2_counter_2nd_delay;
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
      sram_we_128 = (counter_2nd[1:0] == 2'b00) ? (ld_vld_2nd & phase) : 
                    (counter_2nd[1:0] == 2'b01) & (phase); 
    end
    RECEIVE_CAL3: begin
      sram_we_128 = (counter_2nd[1:0] == 2'b00) ? (ld_vld_2nd & phase) : 
                    (counter_2nd[1:0] == 2'b01) & (phase);  
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_we_128 = (counter_2nd[1:0] == 2'b00) ? (ld_vld_2nd & phase) : (phase);
    end
    CAL_OUTPUT: begin
      sram_we_128 = (phase);
    end
    CAL1: begin
      sram_we_128 = (counter_2nd[1:0] == 2'b11) ? 0 : (counter_2nd[1:0] == 2'b10) | (phase);
    end
    CAL2: begin
      sram_we_128 = ~(counter_2nd[1]) & (phase);
    end
    SAVE: begin
      sram_we_128 = (counter_2nd[1:0] == 2'b00);
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
      sram_addr_one_cycle_2nd = {13'b0, 5'b0, counter_2nd[7:0]};
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

assign BPE2_ain_buffer_next = (counter_2nd[1:0] == 2'b00) ? BPE2_ain_buffer : sram_dout_128;

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
      BPE2_coef = (counter_2nd[1]) ? coef_reg_1_2nd : coef_reg_0_2nd;
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
      state_3rd_next = (counter_3rd == 157) ? SAVE : RECEIVE_CAL_OUTPUT;
    end 
    SAVE: begin
      state_3rd_next = (counter_3rd == 184) ? TRANSFER : SAVE;
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
assign coef_not_ready_3rd = (counter_3rd == 60) & (~coef_done_3rd);
assign wait_ld_3rd = (state_3rd >= 4'd1 && state_3rd <= 4'd3) && (counter_3rd[1:0] == 2'b00);
assign trigger_once_3rd_next  = trigger_once_3rd | ld_vld_3rd;
assign counting_3rd_next  = (ld_vld_3rd && !trigger_once_3rd) ? 1'b1 : counting_3rd;
assign counter_3rd_next = 
    (ld_vld_3rd && !trigger_once_3rd) ? 16'd1 :
    (counting_3rd && !wait_ld_3rd && !coef_not_ready_3rd) ? counter_3rd + 1 :
    (counting_3rd && wait_ld_3rd && ld_vld_3rd && !coef_not_ready_3rd) ? counter_3rd + 1 :
                                                             counter_3rd;


assign counter_3rd_delay_next = counter_3rd - 27;
assign counter_3rd_adv_next   = counter_3rd + 2;
assign stage2_counter_3rd_next    = counter_3rd + 4;
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
      sram_we_32 = ld_vld_3rd & (phase);
    end
    RECEIVE: begin
      sram_we_32 = ld_vld_3rd & (phase);
    end
    RECEIVE_CAL1: begin
      sram_we_32 = 0;
    end
    RECEIVE_CAL2: begin
      sram_we_32 = (counter_3rd[1:0] == 2'b00) ? (ld_vld_3rd & phase) : 
                    (counter_3rd[1:0] == 2'b01) & (phase); 
    end
    RECEIVE_CAL3: begin
      sram_we_32 = ~(counter_3rd[1]) & (phase);
    end
    RECEIVE_CAL_OUTPUT: begin
      sram_we_32 = phase;
    end
    SAVE: begin
      sram_we_32 = ~(counter_3rd[0]);
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
                                                          {7'b0000001, counter_3rd_delay_buffer[5:0], 13'b0};
    end
    RECEIVE_CAL3: begin // 3
      sram_addr_one_cycle_3rd = (counter_3rd[1:0] == 2'b00) ? {7'b0, counter_3rd_delay[5:0] ,8'b00000011, counter_3rd[4:0]} :
                            (counter_3rd[1:0] == 2'b01) ? {7'b0000001, counter_3rd_delay_buffer[5:0], 8'b0, stage2_counter_3rd[4:0]} :
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
      BPE3_bin = sram_dout_32;
    end
    RECEIVE_CAL_OUTPUT: begin
      BPE3_bin = sram_dout_32;
    end
    default: begin
      BPE3_bin = 0;
    end
  endcase
end

assign BPE3_ain_buffer_next = (counter_3rd[1:0] == 2'b00) ? BPE3_ain_buffer : sram_dout_32;

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
  BPE3_bout_buffer <= BPE3_bout;
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

assign enable_output_3rd = (state_3rd == TRANSFER);
always @(posedge clk or negedge rstn) begin
  if (~rstn | output_done_3rd) begin
    counter_3rd_output <= 0;
  end else begin
    counter_3rd_output <= counter_3rd_output_next;
  end
end

assign counter_3rd_output_next = (enable_output_3rd) & ld_rdy_4th ? counter_3rd_output + 1 : counter_3rd_output;

assign output_done_3rd = &counter_3rd_output[4:0] & ld_rdy_4th;

assign ld_vld_4th = enable_output_3rd;
assign ld_dat_4th = (enable_output_3rd) ? sram_dout_32 : 0;


// ==========================================BPE4 、 BPE5 ==================================//
    // registers for output signals
    // reg ss_rdy_4th_r, sm_vld_4th_r;
    // reg [pDATA_WIDTH-1:0] BPE4_coef_r, BPE4_ain_r, BPE4_bin_r;
    // reg BPE4_i_vld_r, BPE4_o_rdy_r;
    // reg bpe_act_4th;

    assign ld_rdy_4th = ss_rdy_4th_r;
    assign BPE4_idle = ss_rdy_4th_r;

    /*===============================================================================================
    #                                       4th BPE                                                 #
    ================================================================================================*/

    // ==================== Output connection  ===================//
    assign sm_vld_4th = sm_vld_4th_r;
    assign BPE4_coef = BPE4_coef_r;
    assign BPE4_ain = BPE4_ain_r;
    assign BPE4_bin = BPE4_bin_r;
    assign BPE4_i_vld = BPE4_i_vld_r;
    assign BPE4_o_rdy = BPE4_o_rdy_r;
    assign bpe_act[3] = bpe_act_4th;
    assign coef_rdy[3] = 1;
    //===================FSM for 4th BPE===================//
    // ================ Parameters for FSM ================//
    // localparam IDLE_4th = 0;     // 000000
      //  localparam WAIT_COEF_4th = 34;
    // localparam FILL0_0_4th = 1;  // 000001
    // localparam FILL0_1_4th = 2;  // 000010
    // localparam CALC0_0_4th = 3;  // 000011
    // localparam CALC0_1_4th = 4;  // 000100
    // localparam FILL1_0_4th = 5;  // 000101
    // localparam FILL1_1_4th = 6;  // 000110
    // localparam CALC1_0_4th = 7;  // 000111
    // localparam CALC1_1_4th = 8;  // 001000
    // localparam FILL2_0_4th = 9;  // 001001
    // localparam FILL2_1_4th = 10; // 001010
    // localparam CALC2_0_4th = 11; // 001011
    // localparam CALC2_1_4th = 12; // 001100
    // localparam FILL3_0_4th = 13; // 001101
    // localparam FILL3_1_4th = 14; // 001110
    // localparam CALC3_0_4th = 15; // 001111
    // localparam CALC3_1_4th = 16; // 010000
    // localparam BPE_O_0_4th = 17; // 010001
    // localparam BPE_O_1_4th = 18; // 010010
    // localparam BPE_I_0_4th = 19; // 010011
    // localparam BPE_I_1_4th = 20; // 010100
    // localparam BPE_O_2_4th = 21; // 010101
    // localparam BPE_O_3_4th = 22; // 010110
    // localparam BPE_I_2_4th = 23; // 010111
    // localparam BPE_I_3_4th = 24; // 011000
    // localparam BPE_O_4_4th = 25; // 011001
    // localparam BPE_O_5_4th = 26; // 011010
    // localparam BPE_I_4_4th = 27; // 011011
    // localparam BPE_I_5_4th = 28; // 011100
    // localparam BPE_O_6_4th = 29; // 011101
    // localparam BPE_O_7_4th = 30; // 011110
    // localparam BPE_I_6_4th = 31; // 011111
    // localparam BPE_I_7_4th = 32; // 100000
    // localparam FINISH_4th = 33;  // 100001

    // fsm state registers
    // reg [5:0] state_4th;
    // reg [5:0] state_4th_next;

    wire coef_done_4th;

    assign coef_done_4th = coef_cnt_4th == 12;

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            state_4th <= 0;
        end else begin
            state_4th <= state_4th_next;
        end
    end

    always@(*)begin
      case(state_4th)
        IDLE_4th:       state_4th_next = ld_vld_4th ? WAIT_COEF_4th : IDLE_4th;
        WAIT_COEF_4th:  state_4th_next = coef_done_4th ? FILL0_0_4th : WAIT_COEF_4th;
        FILL0_0_4th:    state_4th_next = (in_cnt_4th[0] ?      FILL0_1_4th : FILL0_0_4th);
        FILL0_1_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC0_0_4th : FILL0_1_4th);
        CALC0_0_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC0_1_4th : CALC0_0_4th);
        CALC0_1_4th:    state_4th_next = (in_cnt_4th[0] ?      FILL1_0_4th : CALC0_1_4th);
        FILL1_0_4th:    state_4th_next = (in_cnt_4th[0] ?      FILL1_1_4th : FILL1_0_4th);
        FILL1_1_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC1_0_4th : FILL1_1_4th);
        CALC1_0_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC1_1_4th : CALC1_0_4th);
        CALC1_1_4th:    state_4th_next = (in_cnt_4th[0] ?      FILL2_0_4th : CALC1_1_4th);
        FILL2_0_4th:    state_4th_next = (in_cnt_4th[0] ?      FILL2_1_4th : FILL2_0_4th);
        FILL2_1_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC2_0_4th : FILL2_1_4th);
        CALC2_0_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC2_1_4th : CALC2_0_4th);
        CALC2_1_4th:    state_4th_next = (in_cnt_4th[0] ?      FILL3_0_4th : CALC2_1_4th);
        FILL3_0_4th:    state_4th_next = (in_cnt_4th[0] ?      FILL3_1_4th : FILL3_0_4th);
        FILL3_1_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC3_0_4th : FILL3_1_4th);
        CALC3_0_4th:    state_4th_next = (in_cnt_4th[0] ?      CALC3_1_4th : CALC3_0_4th);
        CALC3_1_4th:    state_4th_next = (in_cnt_4th[0] ?      BPE_O_0_4th : CALC3_1_4th);
        BPE_O_0_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_O_1_4th : BPE_O_0_4th);
        BPE_O_1_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_I_0_4th : BPE_O_1_4th);
        BPE_I_0_4th:    state_4th_next = (bpe_in_cnt_4th[0] ?  BPE_I_1_4th : BPE_I_0_4th);
        BPE_I_1_4th:    state_4th_next = (bpe_in_cnt_4th[0] ?  BPE_O_2_4th : BPE_I_1_4th);
        BPE_O_2_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_O_3_4th : BPE_O_2_4th);
        BPE_O_3_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_I_2_4th : BPE_O_3_4th);
        BPE_I_2_4th:    state_4th_next = (bpe_in_cnt_4th[0] ?  BPE_I_3_4th : BPE_I_2_4th);
        BPE_I_3_4th:    state_4th_next = (bpe_in_cnt_4th[0] ?  BPE_O_4_4th : BPE_I_3_4th);
        BPE_O_4_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_O_5_4th : BPE_O_4_4th);
        BPE_O_5_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_I_4_4th : BPE_O_5_4th);
        BPE_I_4_4th:    state_4th_next = (bpe_in_cnt_4th[0] ?  BPE_I_5_4th : BPE_I_4_4th);
        BPE_I_5_4th:    state_4th_next = (bpe_in_cnt_4th[0] ?  BPE_O_6_4th : BPE_I_5_4th);
        BPE_O_6_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_O_7_4th : BPE_O_6_4th);
        BPE_O_7_4th:    state_4th_next = (bpe_out_cnt_4th[0] ? BPE_I_6_4th : BPE_O_7_4th);
        BPE_I_6_4th:    state_4th_next = (bpe_in_cnt_4th[0] ?  BPE_I_7_4th : BPE_I_6_4th);
        BPE_I_7_4th:    state_4th_next = (bpe_in_cnt_4th[0] ? TRAN_0_4th : BPE_I_7_4th);
        TRAN_0_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_1_4th : TRAN_0_4th);
        TRAN_1_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_2_4th : TRAN_1_4th);
        TRAN_2_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_3_4th : TRAN_2_4th);
        TRAN_3_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_4_4th : TRAN_3_4th);
        TRAN_4_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_5_4th : TRAN_4_4th);
        TRAN_5_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_6_4th : TRAN_5_4th);
        TRAN_6_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_7_4th : TRAN_6_4th);
        TRAN_7_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_8_4th : TRAN_7_4th);
        TRAN_8_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_9_4th : TRAN_8_4th);
        TRAN_9_4th:     state_4th_next = (out_cnt_4th[0] ? TRAN_10_4th : TRAN_9_4th);
        TRAN_10_4th:    state_4th_next = (out_cnt_4th[0] ? TRAN_11_4th : TRAN_10_4th);
        TRAN_11_4th:    state_4th_next = (out_cnt_4th[0] ? TRAN_12_4th : TRAN_11_4th);
        TRAN_12_4th:    state_4th_next = (out_cnt_4th[0] ? TRAN_13_4th : TRAN_12_4th);
        TRAN_13_4th:    state_4th_next = (out_cnt_4th[0] ? TRAN_14_4th : TRAN_13_4th);
        TRAN_14_4th:    state_4th_next = (out_cnt_4th[0] ? TRAN_15_4th : TRAN_14_4th);
        TRAN_15_4th:    state_4th_next = (out_cnt_4th[0] ? FINISH_4th : TRAN_15_4th);
        FINISH_4th:     state_4th_next = IDLE_4th;
        default:        state_4th_next = IDLE_4th;
      endcase
    end
    //===================Output Logic for 4th BPE===================//
    // reg ss_rdy_4th_r, sm_vld_4th_r;
    // reg [pDATA_WIDTH-1:0] BPE4_coef_r, BPE4_ain_r, BPE4_bin_r;
    // reg BPE4_i_vld_r, BPE4_o_rdy_r;
    // reg bpe_act_4th;
    

    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     ss_rdy_4th_r <= 0;
    //   end else begin
    //     ss_rdy_4th_r <= 0;
    //     if(state_4th < 17 & (|state_4th))begin // Former half states can accept input
    //       ss_rdy_4th_r <= 1;
    //     end
    //   end
    // end
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) sm_vld_4th_r <= 0;
    //   else begin
    //     sm_vld_4th_r <= 0;
    //     if(state_4th < 17 && (|bpe_out_cnt_4th)) sm_vld_4th_r <= 1; 
    //   end
    // end
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) data_789 <= 0;
    //   else begin
    //     data_789 <= 0;
    //     if(state_4th < 17)begin
    //       case(state_4th)
    //         FILL0_0_4th: data_789 <= BPE4_aout;
    //         FILL0_1_4th: data_789 <= data_reg_4th_ram1[1];
    //         CALC0_0_4th: data_789 <= data_reg_4th_ram2[1];
    //         CALC0_1_4th: data_789 <= data_reg_4th_ram2[1];
    //         FILL1_0_4th: data_789 <= BPE4_aout;
    //         FILL1_1_4th: data_789 <= data_reg_4th_ram1[1];
    //         CALC1_0_4th: data_789 <= data_reg_4th_ram2[1];
    //         CALC1_1_4th: data_789 <= data_reg_4th_ram2[1];
    //         FILL2_0_4th: data_789 <= BPE4_aout;
    //         FILL2_1_4th: data_789 <= data_reg_4th_ram1[1];
    //         CALC2_0_4th: data_789 <= data_reg_4th_ram2[1];
    //         CALC2_1_4th: data_789 <= data_reg_4th_ram2[1];
    //         FILL3_0_4th: data_789 <= BPE4_aout;
    //         FILL3_1_4th: data_789 <= data_reg_4th_ram1[1];
    //         CALC3_0_4th: data_789 <= data_reg_4th_ram2[1];
    //         CALC3_1_4th: data_789 <= data_reg_4th_ram2[1];
    //       endcase
    //     end
    //   end
    // end
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     coef_rdy_4th <= 0;
    //   end else begin
    //     coef_rdy_4th <= 0;
    //     if(coef_cnt_4th < 12 && state_4th != FILL0_0_4th) begin // Exclude FILL0_0_4th state in order to reset coefficients(counters)
    //       coef_rdy_4th <= 1; 
    //     end
    //   end
    // end

    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     bpe_act_4th <= 0;
    //   end else begin
    //     bpe_act_4th <= 0;
    //     if(state_4th_next == WAIT_COEF_4th && state_4th == IDLE_4th)      bpe_act_4th <= 1; 
    //     else if(state_4th_next == BPE_I_7_4th && state_4th == BPE_I_6_4th)   bpe_act_4th <= 1;
    //   end
    // end
    // // coefficient to BPE4
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     BPE4_coef_r <= 0;
    //   end else begin
    //     case(state_4th)
    //       CALC0_0_4th: BPE4_coef_r <= COE0_0_4th;
    //       CALC0_1_4th: BPE4_coef_r <= COE0_0_4th;
    //       CALC1_0_4th: BPE4_coef_r <= COE1_0_4th;
    //       CALC1_1_4th: BPE4_coef_r <= COE1_0_4th;
    //       CALC2_0_4th: BPE4_coef_r <= COE2_0_4th;
    //       CALC2_1_4th: BPE4_coef_r <= COE2_0_4th;
    //       CALC3_0_4th: BPE4_coef_r <= COE3_0_4th;
    //       CALC3_1_4th: BPE4_coef_r <= COE3_0_4th;

    //       BPE_I_0_4th: BPE4_coef_r <= COE0_1_4th;
    //       BPE_I_1_4th: BPE4_coef_r <= COE0_2_4th;
    //       BPE_I_2_4th: BPE4_coef_r <= COE1_1_4th;
    //       BPE_I_3_4th: BPE4_coef_r <= COE1_2_4th;
    //       BPE_I_4_4th: BPE4_coef_r <= COE2_1_4th;
    //       BPE_I_5_4th: BPE4_coef_r <= COE2_2_4th;
    //       BPE_I_6_4th: BPE4_coef_r <= COE3_1_4th;
    //       BPE_I_7_4th: BPE4_coef_r <= COE3_2_4th;
    //       default: BPE4_coef_r <= 0;
    //     endcase
    //   end
    // end
    // // BPE4 input
    // always@(posedge clk or negedge rstn) begin 
    //   if (~rstn) begin
    //     BPE4_ain_r <= 0;
    //   end else begin
    //     case(state_4th)
    //       CALC0_0_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       CALC0_1_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       CALC1_0_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       CALC1_1_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       CALC2_0_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       CALC2_1_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       CALC3_0_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       CALC3_1_4th: BPE4_ain_r <= data_reg_4th_ram0[3];
    //       BPE_I_0_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       BPE_I_1_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       BPE_I_2_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       BPE_I_3_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       BPE_I_4_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       BPE_I_5_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       BPE_I_6_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       BPE_I_7_4th: BPE4_ain_r <= data_reg_4th_ram2[1];
    //       default: BPE4_ain_r <= 0;
    //     endcase
    //   end
    // end
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     BPE4_bin_r <= 0;
    //   end else begin
    //     case(state_4th)
    //       CALC0_0_4th: BPE4_bin_r <= ld_dat_4th;
    //       CALC0_1_4th: BPE4_bin_r <= ld_dat_4th;
    //       CALC1_0_4th: BPE4_bin_r <= ld_dat_4th;
    //       CALC1_1_4th: BPE4_bin_r <= ld_dat_4th;
    //       CALC2_0_4th: BPE4_bin_r <= ld_dat_4th;
    //       CALC2_1_4th: BPE4_bin_r <= ld_dat_4th;
    //       CALC3_0_4th: BPE4_bin_r <= ld_dat_4th;
    //       CALC3_1_4th: BPE4_bin_r <= ld_dat_4th;
    //       BPE_I_0_4th: BPE4_bin_r <= data_reg_4th_ram1[1];
    //       BPE_I_1_4th: BPE4_bin_r <= data_reg_4th_ram0[3];
    //       BPE_I_2_4th: BPE4_bin_r <= data_reg_4th_ram1[1];
    //       BPE_I_3_4th: BPE4_bin_r <= data_reg_4th_ram0[3];
    //       BPE_I_4_4th: BPE4_bin_r <= data_reg_4th_ram1[1];
    //       BPE_I_5_4th: BPE4_bin_r <= data_reg_4th_ram0[3];
    //       BPE_I_6_4th: BPE4_bin_r <= data_reg_4th_ram1[1];
    //       BPE_I_7_4th: BPE4_bin_r <= data_reg_4th_ram0[3];
    //       default: BPE4_bin_r <= 0;
    //     endcase
    //   end
    // end

    // // BPE4 control signals
    // always@(posedge clk or negedge rstn) begin
    //   if(~rstn) begin
    //     BPE4_i_vld_r <= 0;
    //     BPE4_o_rdy_r <= 0;
    //   end else begin
    //     BPE4_i_vld_r <= (state_4th == CALC0_0_4th || state_4th == CALC0_1_4th || state_4th == CALC1_0_4th || state_4th == CALC1_1_4th ||
    //                    state_4th == CALC2_0_4th || state_4th == CALC2_1_4th || state_4th == CALC3_0_4th || state_4th == CALC3_1_4th ||
    //                    state_4th == BPE_I_0_4th || state_4th == BPE_I_1_4th || state_4th == BPE_I_2_4th || state_4th == BPE_I_3_4th ||
    //                    state_4th == BPE_I_4_4th || state_4th == BPE_I_5_4th || state_4th == BPE_I_6_4th || state_4th == BPE_I_7_4th);
    //     BPE4_o_rdy_r <= (state_4th == FILL0_0_4th || state_4th == FILL0_1_4th || state_4th == FILL1_0_4th || state_4th == FILL1_1_4th ||
    //                    state_4th == FILL2_0_4th || state_4th == FILL2_1_4th || state_4th == FILL3_0_4th || state_4th == FILL3_1_4th ||
    //                    state_4th == BPE_O_0_4th || state_4th == BPE_O_1_4th || state_4th == BPE_O_2_4th || state_4th == BPE_O_3_4th ||
    //                    state_4th == BPE_O_4_4th || state_4th == BPE_O_5_4th || state_4th == BPE_O_6_4th || state_4th == BPE_O_7_4th);
    //   end
    // end
    
    always@(*) begin
      if(state_4th < BPE_O_0_4th & (state_4th > WAIT_COEF_4th))begin
        ss_rdy_4th_r = 1;
      end else begin
        ss_rdy_4th_r = 0;
      end
    end
    always@(*) begin
      if(state_4th >= TRAN_0_4th && (state_4th != FINISH_4th)) begin
        sm_vld_4th_r = 1;
      end else begin
        sm_vld_4th_r = 0;
      end 
    end
    always@(*) begin
        // if(state_4th < 17)begin
          case(state_4th)
            TRAN_0_4th: data_789 = BPE4_aout;
            TRAN_1_4th: data_789 = data_reg_4th_ram1[1];
            TRAN_2_4th: data_789 = data_reg_4th_ram2[1];
            TRAN_3_4th: data_789 = data_reg_4th_ram2[1];
            TRAN_4_4th: data_789 = BPE4_aout;
            TRAN_5_4th: data_789 = data_reg_4th_ram1[1];
            TRAN_6_4th: data_789 = data_reg_4th_ram2[1];
            TRAN_7_4th: data_789 = data_reg_4th_ram2[1];
            TRAN_8_4th: data_789 = BPE4_aout;
            TRAN_9_4th: data_789 = data_reg_4th_ram1[1];
            TRAN_10_4th: data_789 = data_reg_4th_ram2[1];
            TRAN_11_4th: data_789 = data_reg_4th_ram2[1];
            TRAN_12_4th: data_789 = BPE4_aout;
            TRAN_13_4th: data_789 = data_reg_4th_ram1[1];
            TRAN_14_4th: data_789 = data_reg_4th_ram2[1];
            TRAN_15_4th: data_789 = data_reg_4th_ram2[1];
            default: data_789 = 0;
          endcase
        // end
      end
    always@(*) begin
      if(coef_cnt_4th < 12 && state_4th != FILL0_0_4th) begin // Exclude FILL0_0_4th state in order to reset coefficients(counters)
        coef_rdy_4th = 1; 
      end else begin
        coef_rdy_4th = 0;
      end
    end

    always@(*) begin
      if(state_4th_next == WAIT_COEF_4th && state_4th == IDLE_4th) begin
        bpe_act_4th = 1; 
      end else begin
        bpe_act_4th = 0;
      end
    end
    // coefficient to BPE4
    always@(*) begin
        case(state_4th)
          CALC0_0_4th: BPE4_coef_r = COE0_0_4th;
          CALC0_1_4th: BPE4_coef_r = COE0_0_4th;
          CALC1_0_4th: BPE4_coef_r = COE1_0_4th;
          CALC1_1_4th: BPE4_coef_r = COE1_0_4th;
          CALC2_0_4th: BPE4_coef_r = COE2_0_4th;
          CALC2_1_4th: BPE4_coef_r = COE2_0_4th;
          CALC3_0_4th: BPE4_coef_r = COE3_0_4th;
          CALC3_1_4th: BPE4_coef_r = COE3_0_4th;

          BPE_I_0_4th: BPE4_coef_r = COE0_1_4th;
          BPE_I_1_4th: BPE4_coef_r = COE0_2_4th;
          BPE_I_2_4th: BPE4_coef_r = COE1_1_4th;
          BPE_I_3_4th: BPE4_coef_r = COE1_2_4th;
          BPE_I_4_4th: BPE4_coef_r = COE2_1_4th;
          BPE_I_5_4th: BPE4_coef_r = COE2_2_4th;
          BPE_I_6_4th: BPE4_coef_r = COE3_1_4th;
          BPE_I_7_4th: BPE4_coef_r = COE3_2_4th;
          default: BPE4_coef_r = 0;
        endcase
    end
    // BPE4 input
    always@(*) begin 
        case(state_4th)
          CALC0_0_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          CALC0_1_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          CALC1_0_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          CALC1_1_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          CALC2_0_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          CALC2_1_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          CALC3_0_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          CALC3_1_4th: BPE4_ain_r = data_reg_4th_ram0[3];
          BPE_I_0_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          BPE_I_1_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          BPE_I_2_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          BPE_I_3_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          BPE_I_4_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          BPE_I_5_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          BPE_I_6_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          BPE_I_7_4th: BPE4_ain_r = data_reg_4th_ram2[1];
          default: BPE4_ain_r = 0;
        endcase
    end
    always@(*) begin
        case(state_4th)
          CALC0_0_4th: BPE4_bin_r = ld_dat_4th;
          CALC0_1_4th: BPE4_bin_r = ld_dat_4th;
          CALC1_0_4th: BPE4_bin_r = ld_dat_4th;
          CALC1_1_4th: BPE4_bin_r = ld_dat_4th;
          CALC2_0_4th: BPE4_bin_r = ld_dat_4th;
          CALC2_1_4th: BPE4_bin_r = ld_dat_4th;
          CALC3_0_4th: BPE4_bin_r = ld_dat_4th;
          CALC3_1_4th: BPE4_bin_r = ld_dat_4th;
          BPE_I_0_4th: BPE4_bin_r = data_reg_4th_ram1[1];
          BPE_I_1_4th: BPE4_bin_r = data_reg_4th_ram0[3];
          BPE_I_2_4th: BPE4_bin_r = data_reg_4th_ram1[1];
          BPE_I_3_4th: BPE4_bin_r = data_reg_4th_ram0[3];
          BPE_I_4_4th: BPE4_bin_r = data_reg_4th_ram1[1];
          BPE_I_5_4th: BPE4_bin_r = data_reg_4th_ram0[3];
          BPE_I_6_4th: BPE4_bin_r = data_reg_4th_ram1[1];
          BPE_I_7_4th: BPE4_bin_r = data_reg_4th_ram0[3];
          default: BPE4_bin_r = 0;
        endcase
    end

    // BPE4 control signals
    always@(*) begin
        BPE4_o_rdy_r = (state_4th == BPE_O_0_4th || state_4th == BPE_O_1_4th || state_4th == BPE_O_2_4th || state_4th == BPE_O_3_4th ||
                        state_4th == BPE_O_4_4th || state_4th == BPE_O_5_4th || state_4th == BPE_O_6_4th || state_4th == BPE_O_7_4th ||
                        state_4th == TRAN_0_4th || state_4th == TRAN_1_4th || state_4th == TRAN_2_4th || state_4th == TRAN_3_4th ||
                        state_4th == TRAN_4_4th || state_4th == TRAN_5_4th || state_4th == TRAN_6_4th || state_4th == TRAN_7_4th ||
                        state_4th == TRAN_8_4th || state_4th == TRAN_9_4th || state_4th == TRAN_10_4th || state_4th == TRAN_11_4th ||
                        state_4th == TRAN_12_4th || state_4th == TRAN_13_4th || state_4th == TRAN_14_4th || state_4th == TRAN_15_4th);
        BPE4_i_vld_r = (state_4th == CALC0_0_4th || state_4th == CALC0_1_4th || state_4th == CALC1_0_4th || state_4th == CALC1_1_4th ||
                       state_4th == CALC2_0_4th || state_4th == CALC2_1_4th || state_4th == CALC3_0_4th || state_4th == CALC3_1_4th ||
                       state_4th == BPE_I_0_4th || state_4th == BPE_I_1_4th || state_4th == BPE_I_2_4th || state_4th == BPE_I_3_4th ||
                       state_4th == BPE_I_4_4th || state_4th == BPE_I_5_4th || state_4th == BPE_I_6_4th || state_4th == BPE_I_7_4th);
    end


    
    //==================== counters for 4th BPE ====================//
    // in, out, bpe_in, bpe_out, coef, 
    // Counters 4th BPE
    // reg [$clog2(DATA_LENGTH)-1:0] in_cnt_4th, out_cnt_4th, bpe_in_cnt_4th, bpe_out_cnt_4th, coef_cnt_4th;
    // wire[$clog2(DATA_LENGTH)-1:0] in_cnt_4th_next, out_cnt_4th_next, bpe_in_cnt_4th_next, bpe_out_cnt_4th_next, coef_cnt_4th_next;

    assign in_cnt_4th_next = (ld_vld_4th && ss_rdy_4th_r) ? in_cnt_4th + 1 : in_cnt_4th;
    assign out_cnt_4th_next = (sm_vld_4th && sm_rdy_4th) ? out_cnt_4th + 1 : out_cnt_4th;
    assign bpe_in_cnt_4th_next = (BPE4_i_vld && BPE4_i_rdy) ? bpe_in_cnt_4th + 1 : bpe_in_cnt_4th;
    assign bpe_out_cnt_4th_next = (BPE4_o_vld && BPE4_o_rdy) ? bpe_out_cnt_4th + 1 : bpe_out_cnt_4th;
    assign coef_cnt_4th_next = (coef_vld[3] && coef_rdy[3]) ? coef_cnt_4th + 1 :
                               (state_4th == BPE_I_7_4th) ? 0 : coef_cnt_4th;

    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        in_cnt_4th <= 0;
        out_cnt_4th <= 0;
        bpe_in_cnt_4th <= 0;
        bpe_out_cnt_4th <= 0;
        coef_cnt_4th <= 0;
      end else begin
        in_cnt_4th <= in_cnt_4th_next;
        out_cnt_4th <= out_cnt_4th_next;
        bpe_in_cnt_4th <= bpe_in_cnt_4th_next;
        bpe_out_cnt_4th <= bpe_out_cnt_4th_next;
        coef_cnt_4th <= coef_cnt_4th_next;
      end
    end
    //==================== Coefficient ====================//

    // // Coefficients for 4th BPE
    // reg [pDATA_WIDTH-1:0] COE0_0_4th, COE0_1_4th, COE0_2_4th;
    // reg [pDATA_WIDTH-1:0] COE1_0_4th, COE1_1_4th, COE1_2_4th;
    // reg [pDATA_WIDTH-1:0] COE2_0_4th, COE2_1_4th, COE2_2_4th;
    // reg [pDATA_WIDTH-1:0] COE3_0_4th, COE3_1_4th, COE3_2_4th;

    // wire [pDATA_WIDTH-1:0] COE0_0_4th_tmp, COE0_1_4th_tmp, COE0_2_4th_tmp;
    // wire [pDATA_WIDTH-1:0] COE1_0_4th_tmp, COE1_1_4th_tmp, COE1_2_4th_tmp;
    // wire [pDATA_WIDTH-1:0] COE2_0_4th_tmp, COE2_1_4th_tmp, COE2_2_4th_tmp;
    // wire [pDATA_WIDTH-1:0] COE3_0_4th_tmp, COE3_1_4th_tmp, COE3_2_4th_tmp;

    assign COE0_0_4th_tmp = (coef_cnt_4th == 0 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE0_0_4th; // No need to reset
    assign COE0_1_4th_tmp = (coef_cnt_4th == 1 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE0_1_4th;
    assign COE0_2_4th_tmp = (coef_cnt_4th == 2 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE0_2_4th;

    assign COE1_0_4th_tmp = (coef_cnt_4th == 3 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE1_0_4th;
    assign COE1_1_4th_tmp = (coef_cnt_4th == 4 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE1_1_4th;
    assign COE1_2_4th_tmp = (coef_cnt_4th == 5 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE1_2_4th;

    assign COE2_0_4th_tmp = (coef_cnt_4th == 6 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE2_0_4th;
    assign COE2_1_4th_tmp = (coef_cnt_4th == 7 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE2_1_4th;
    assign COE2_2_4th_tmp = (coef_cnt_4th == 8 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE2_2_4th;

    assign COE3_0_4th_tmp = (coef_cnt_4th == 9 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE3_0_4th;
    assign COE3_1_4th_tmp = (coef_cnt_4th == 10 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE3_1_4th;
    assign COE3_2_4th_tmp = (coef_cnt_4th == 11 && (coef_vld[3] && coef_rdy_4th)) ? coef_dat : COE3_2_4th;

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        COE0_0_4th <= 0;
        COE0_1_4th <= 0;
        COE0_2_4th <= 0;
        COE1_0_4th <= 0;
        COE1_1_4th <= 0;
        COE1_2_4th <= 0;
        COE2_0_4th <= 0;
        COE2_1_4th <= 0;
        COE2_2_4th <= 0;
        COE3_0_4th <= 0;
        COE3_1_4th <= 0;
        COE3_2_4th <= 0;
      end else begin
        COE0_0_4th <= COE0_0_4th_tmp;
        COE0_1_4th <= COE0_1_4th_tmp;
        COE0_2_4th <= COE0_2_4th_tmp;
        COE1_0_4th <= COE1_0_4th_tmp;
        COE1_1_4th <= COE1_1_4th_tmp;
        COE1_2_4th <= COE1_2_4th_tmp;
        COE2_0_4th <= COE2_0_4th_tmp;
        COE2_1_4th <= COE2_1_4th_tmp;
        COE2_2_4th <= COE2_2_4th_tmp;
        COE3_0_4th <= COE3_0_4th_tmp;
        COE3_1_4th <= COE3_1_4th_tmp;
        COE3_2_4th <= COE3_2_4th_tmp; 
      end
    end
    //==================== FIFOs for 4th BPE ====================//
    // // FIFOs for 4th BPE
    // reg [3:0] data_reg_4th_ram0[0:pDATA_WIDTH-1];
    // reg [3:0] data_reg_4th_ram0_next[0:pDATA_WIDTH-1];
    // reg [1:0] data_reg_4th_ram1[0:pDATA_WIDTH-1];
    // reg [1:0] data_reg_4th_ram1_next[0:pDATA_WIDTH-1];
    // reg [1:0] data_reg_4th_ram2[0:pDATA_WIDTH-1];
    // reg [1:0] data_reg_4th_ram2_next[0:pDATA_WIDTH-1];

    always @(posedge clk or negedge rstn) begin // reg uses regular clk instead of 2x clk
      if (~rstn) begin
        for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0[i] <= 0;
        for (j = 0; j < 2; j = j + 1) data_reg_4th_ram1[j] <= 0;
        for (k = 0; k < 2; k = k + 1) data_reg_4th_ram2[k] <= 0;
      end else begin
        for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0[i] <= data_reg_4th_ram0_next[i];
        for (j = 0; j < 2; j = j + 1) data_reg_4th_ram1[j] <= data_reg_4th_ram1_next[j];
        for (k = 0; k < 2; k = k + 1) data_reg_4th_ram2[k] <= data_reg_4th_ram2_next[k];
      end
    end
    // FIFO 0    
    always @(*)begin
      // if(ld_vld_4th && ss_rdy_4th_r) begin
        for (i = 1; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i-1];
        case(state_4th)
          FILL0_0_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          FILL0_1_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          FILL1_0_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          FILL1_1_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          FILL2_0_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          FILL2_1_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          FILL3_0_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          FILL3_1_4th: data_reg_4th_ram0_next[0] = ld_dat_4th;
          BPE_O_0_4th: data_reg_4th_ram0_next[0] = BPE4_bout;
          BPE_O_1_4th: data_reg_4th_ram0_next[0] = BPE4_bout;
          BPE_O_2_4th: data_reg_4th_ram0_next[0] = BPE4_bout;
          BPE_O_3_4th: data_reg_4th_ram0_next[0] = BPE4_bout;
          BPE_O_4_4th: data_reg_4th_ram0_next[0] = BPE4_bout;
          BPE_O_5_4th: data_reg_4th_ram0_next[0] = BPE4_bout;
          BPE_O_6_4th: data_reg_4th_ram0_next[0] = BPE4_bout;
          BPE_O_7_4th: data_reg_4th_ram0_next[0] = BPE4_bout;

          default:     data_reg_4th_ram0_next[0] = 0;
        endcase
      // end else begin
      //   for (i = 0; i < 4; i = i + 1) data_reg_4th_ram0_next[i] = data_reg_4th_ram0[i];
      // end
    end
    // FIFO 1
    always @(*)begin
      // if(ld_vld_4th && ss_rdy_4th_r) begin
        data_reg_4th_ram1_next[1] = data_reg_4th_ram1[0];
        case(state_4th)
          BPE_O_0_4th: data_reg_4th_ram1_next[0] = BPE4_aout;
          BPE_O_1_4th: data_reg_4th_ram1_next[0] = BPE4_aout; 
          BPE_O_2_4th: data_reg_4th_ram1_next[0] = BPE4_aout;
          BPE_O_3_4th: data_reg_4th_ram1_next[0] = BPE4_aout;
          BPE_O_4_4th: data_reg_4th_ram1_next[0] = BPE4_aout;
          BPE_O_5_4th: data_reg_4th_ram1_next[0] = BPE4_aout;
          BPE_O_6_4th: data_reg_4th_ram1_next[0] = BPE4_aout;
          BPE_O_7_4th: data_reg_4th_ram1_next[0] = BPE4_aout;
          TRAN_0_4th:  data_reg_4th_ram1_next[0] = BPE4_bout;
          TRAN_1_4th:  data_reg_4th_ram1_next[0] = BPE4_bout;
          TRAN_4_4th:  data_reg_4th_ram1_next[0] = BPE4_bout;
          TRAN_5_4th:  data_reg_4th_ram1_next[0] = BPE4_bout;
          TRAN_8_4th:  data_reg_4th_ram1_next[0] = BPE4_bout;
          TRAN_9_4th:  data_reg_4th_ram1_next[0] = BPE4_bout;
          TRAN_12_4th: data_reg_4th_ram1_next[0] = BPE4_bout;
          TRAN_13_4th: data_reg_4th_ram1_next[0] = BPE4_bout;
          default:     data_reg_4th_ram1_next[0] = 0;
        endcase
      // end else begin
      //   data_reg_4th_ram1_next[0] = data_reg_4th_ram1[0];
      //   data_reg_4th_ram1_next[1] = data_reg_4th_ram1[1];
      // end
    end
    // FIFO 2
    always @(*)begin
      // if(ld_vld_4th && ss_rdy_4th_r) begin
        data_reg_4th_ram2_next[1] = data_reg_4th_ram2[0];
        case(state_4th)
          BPE_O_1_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          BPE_I_0_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram0[3];
          BPE_O_3_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          BPE_I_2_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram0[3];
          BPE_O_5_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          BPE_I_4_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram0[3];
          BPE_O_7_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          BPE_I_6_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram0[3];

          TRAN_1_4th: data_reg_4th_ram2_next[0] = BPE4_aout;
          TRAN_2_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          TRAN_5_4th: data_reg_4th_ram2_next[0] = BPE4_aout;
          TRAN_6_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          TRAN_9_4th: data_reg_4th_ram2_next[0] = BPE4_aout;
          TRAN_10_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          TRAN_13_4th: data_reg_4th_ram2_next[0] = BPE4_aout;
          TRAN_14_4th: data_reg_4th_ram2_next[0] = data_reg_4th_ram1[1];
          default:     data_reg_4th_ram2_next[0] = 0;
        endcase
      // end else begin
      //   data_reg_4th_ram2_next[0] = data_reg_4th_ram2[0];
      //   data_reg_4th_ram2_next[1] = data_reg_4th_ram2[1];
      // end
    end
    //====================Connection with 5th BPE ====================//
    assign ss_vld_5th = sm_vld_4th;
    assign sm_rdy_4th = ss_rdy_5th;
    assign ld_dat_5th = data_789;
    /*===============================================================================================
    #                                       5th BPE                                                 #
    ================================================================================================*/
    // ==================== Output Interface for 5th BPE ====================//
    // // BPE5 output interface
    // reg BPE5_i_vld_r, BPE5_o_rdy_r; 
    assign BPE5_ain = data_reg_5th_ram0;
    assign BPE5_bin = ld_dat_5th;
    assign BPE5_coef = bpe5_coef;
    assign BPE5_i_vld = BPE5_i_vld_r;
    assign BPE5_o_rdy = BPE5_o_rdy_r;
    assign coef_rdy[4] = 1;
    assign bpe_act[4] = BPE5_act;
    // ==================== State Machine for 5th BPE ====================//
    // localparam DATA_LENGTH = 1024;

    // localparam IDLE_5th = 0;
    // localparam WAIT_COEF_5th = 10;
    // localparam BPE_I0_5th = 1;
    // localparam BPE_I1_5th = 2;
    // localparam BPE_I2_5th = 3;
    // localparam BPE_I3_5th = 4;
    // localparam BPE_O0_5th = 5;
    // localparam BPE_O1_5th = 6;
    // localparam BPE_O2_5th = 7;
    // localparam BPE_O3_5th = 8;
    // localparam FINISH_5th = 9;

    // reg [3:0] state_5th, state_5th_next;
    wire coef_done_5th;
    assign coef_done_5th = (coef_cnt_5th == 16);

    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        decoded_r <= 0;
      end else begin
        decoded_r <= decoded;
      end
    end

    always@(*) begin
      if(sw_lst) decoded = 0;
      else if(decoded | decode) decoded = 1;
      else decoded = 0;
    end

    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        state_5th <= IDLE_5th;
      end else begin
        state_5th <= state_5th_next;
      end
    end

    always@(*)begin// =================================================================================================加入coef done?=========================================================
      case(state_5th)
        IDLE_5th:        state_5th_next = decoded_r ? WAIT_COEF_5th : IDLE_5th;
        WAIT_COEF_5th:   state_5th_next = coef_done_5th ? BPE_I0_5th : WAIT_COEF_5th;
        BPE_I0_5th:      state_5th_next = & in_cnt_5th[2:0] ? BPE_I1_5th : BPE_I0_5th;
        BPE_I1_5th:      state_5th_next = & in_cnt_5th[2:0] ? BPE_I2_5th : BPE_I1_5th;
        BPE_I2_5th:      state_5th_next = & in_cnt_5th[2:0] ? BPE_I3_5th : BPE_I2_5th;
        BPE_I3_5th:      state_5th_next = & in_cnt_5th[2:0] ? BPE_O0_5th : BPE_I3_5th;
        BPE_O0_5th:      state_5th_next = &out_cnt_5th[2:0] ? BPE_O1_5th : BPE_O0_5th;
        BPE_O1_5th:      state_5th_next = &out_cnt_5th[2:0] ? BPE_O2_5th : BPE_O1_5th;
        BPE_O2_5th:      state_5th_next = &out_cnt_5th[2:0] ? BPE_O3_5th : BPE_O2_5th;
        BPE_O3_5th:      state_5th_next = &out_cnt_5th[2:0] ? FINISH_5th : BPE_O3_5th;
        FINISH_5th:  state_5th_next = IDLE_5th;
        default:     state_5th_next = IDLE_5th;
      endcase
    end
    // ==================== Output Logic for 5th BPE ====================//
    // // AXI signals
    // reg ss_rdy_5th, sm_vld_5th;
    // reg coef_5th_rdy;
    // // BPE5 data output
    // reg [pDATA_WIDTH-1:0] BPE5_dout;

    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     ss_rdy_5th <= 0;
    //   end else begin
    //     ss_rdy_5th <= 0;
    //     if(state_5th == BPE_I0_5th || state_5th == BPE_I1_5th || state_5th == BPE_I2_5th || 
    //        state_5th == BPE_I3_5th & (|state_5th)) begin // IDLE_5th should not accept data
    //       ss_rdy_5th <= 1;
    //     end
    //   end
    // end
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     sm_vld_5th <= 0;
    //     BPE5_dout <= 0;
    //   end else begin
    //     sm_vld_5th <= 0;
    //     if(state_5th == BPE_O0_5th || state_5th == BPE_O1_5th || state_5th == BPE_O2_5th || state_5th == BPE_O3_5th) begin
    //       sm_vld_5th <= 1; 
    //       BPE5_dout <= ~out_cnt_5th[0] ? delay_aout_5th[3] : data_reg_5th_ram0;
    //     end
    //   end
    // end
    // // bpe_in_vld and bpe_out_rdy
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     BPE5_i_vld_r <= 0;
    //     BPE5_o_rdy_r <= 0;
    //   end else begin
    //     BPE5_i_vld_r <= (state_5th == BPE_I0_5th || state_5th == BPE_I1_5th || state_5th == BPE_I2_5th || state_5th == BPE_I3_5th) & in_cnt_5th[0] ;
    //     // BPE5_o_rdy <= (state_5th == BPE_O0_5th || state_5th == BPE_O1_5th || state_5th == BPE_O2_5th || state_5th == BPE_O3_5th) & (~bpe_out_cnt_5th[0]);
    //     BPE5_o_rdy_r <= 1;
    //   end
    // end
    // // bpe activation
    // always@(posedge clk or negedge rstn) begin
    //   if (~rstn) begin
    //     BPE5_act <= 0;
    //   end else begin
    //     BPE5_act <= 0;
    //     if(state_5th == IDLE_5th && ss_vld_5th) begin
    //       BPE5_act <= 1;
    //     end else if(state_5th_next == BPE_O0_5th & state_5th == BPE_I3_5th) begin
    //       BPE5_act <= 1;
    //     end
    //   end
    // end

    // always@(*) begin
    //     ss_rdy_5th = 0;
    //     if((state_5th == BPE_I0_5th || state_5th == BPE_I1_5th || state_5th == BPE_I2_5th || 
    //        state_5th == BPE_I3_5th) & (|state_5th)) begin // IDLE_5th should not accept data
    //       ss_rdy_5th = 1;
    
    //     end
    // end

    always@(*) begin
        ss_rdy_5th = (state_5th == BPE_I0_5th || state_5th == BPE_I1_5th || state_5th == BPE_I2_5th || 
                      state_5th == BPE_I3_5th); // IDLE_5th should not accept data
    end
    always@(*) begin
        sm_vld_5th = 0;
        BPE5_dout = 0;
        if(state_5th == BPE_O0_5th || state_5th == BPE_O1_5th || state_5th == BPE_O2_5th || state_5th == BPE_O3_5th) begin
          sm_vld_5th = 1;
          BPE5_dout = ~out_cnt_5th[0] ? delay_aout_5th[1] : data_reg_5th_ram0;
        end
    end
    // bpe_in_vld and bpe_out_rdy
    always@(*) begin
        BPE5_i_vld_r = (state_5th == BPE_I0_5th || state_5th == BPE_I1_5th || state_5th == BPE_I2_5th || state_5th == BPE_I3_5th) & in_cnt_5th[0] ;
        // BPE5_o_rdy <= (state_5th == BPE_O0_5th || state_5th == BPE_O1_5th || state_5th == BPE_O2_5th || state_5th == BPE_O3_5th) & (~bpe_out_cnt_5th[0]);
        BPE5_o_rdy_r = (state_5th_next != IDLE_5th);
    end
    // bpe activation
    // always@(*) begin
    //     BPE5_act = 0;
    //     if(state_5th == IDLE_5th) begin
    //       BPE5_act = 1;
    //     end else begin
    //       BPE5_act = 0;
    //     end
    // end
    always@(*) begin
      BPE5_act = (state_5th == IDLE_5th && state_5th_next == WAIT_COEF_5th);
    end


    always@(*) begin
      case(bpe_in_cnt_5th[1:0])
        2'b00: bpe5_coef = (state_5th == BPE_I0_5th) ? COEF0_0_5th :
                           (state_5th == BPE_I1_5th) ? COEF1_0_5th :
                           (state_5th == BPE_I2_5th) ? COEF2_0_5th : 
                           (state_5th == BPE_I3_5th) ? COEF3_0_5th : 0;
        2'b01: bpe5_coef = (state_5th == BPE_I0_5th) ? COEF0_1_5th :
                           (state_5th == BPE_I1_5th) ? COEF1_1_5th :
                           (state_5th == BPE_I2_5th) ? COEF2_1_5th : 
                           (state_5th == BPE_I3_5th) ? COEF3_1_5th : 0;
        2'b10: bpe5_coef = (state_5th == BPE_I0_5th) ? COEF0_2_5th :
                           (state_5th == BPE_I1_5th) ? COEF1_2_5th :
                           (state_5th == BPE_I2_5th) ? COEF2_2_5th :
                           (state_5th == BPE_I3_5th) ? COEF3_2_5th : 0;
        2'b11: bpe5_coef = (state_5th == BPE_I0_5th) ? COEF0_3_5th :
                           (state_5th == BPE_I1_5th) ? COEF1_3_5th :
                           (state_5th == BPE_I2_5th) ? COEF2_3_5th :
                           (state_5th == BPE_I3_5th) ? COEF3_3_5th : 0;
        default: bpe5_coef = 0;
      endcase
    end

    // ================ Counters for 5th BPE ====================//
    // // Counters for 5th BPE
    // reg [$clog2(DATA_LENGTH)-1:0] in_cnt_5th, out_cnt_5th;
    // wire[$clog2(DATA_LENGTH)-1:0] in_cnt_5th_next, out_cnt_5th_next;
    // reg [3:0] coef_cnt_5th; 
    // wire[1:0] coef_cnt_5th_next;
    // reg [3:0] bpe_out_cnt_5th; // 4 bits to support 16 outputs
    // wire[3:0] bpe_out_cnt_5th_next;

    assign in_cnt_5th_next = (ss_vld_5th && ss_rdy_5th) ? in_cnt_5th + 1 : in_cnt_5th;
    assign out_cnt_5th_next = (sm_vld_5th && sm_rdy_5th) ? out_cnt_5th + 1 : out_cnt_5th;
    assign bpe_in_cnt_5th_next = (BPE5_i_vld && BPE5_i_rdy) ? bpe_in_cnt_5th + 1 : bpe_in_cnt_5th;
    assign bpe_out_cnt_5th_next = (BPE5_o_vld && BPE5_o_rdy) ? bpe_out_cnt_5th + 1 : bpe_out_cnt_5th;
    assign coef_cnt_5th_next = (state_5th == FINISH_5th) ? 0 : ((coef_vld[4] && coef_5th_rdy) ? coef_cnt_5th + 1 : coef_cnt_5th);

    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        in_cnt_5th <= 0;
        out_cnt_5th <= 0;
        bpe_in_cnt_5th <= 0;
        bpe_out_cnt_5th <= 0;
        coef_cnt_5th <= 0;
      end else begin
        in_cnt_5th <= in_cnt_5th_next;
        out_cnt_5th <= out_cnt_5th_next;
        bpe_in_cnt_5th <= bpe_in_cnt_5th_next;
        bpe_out_cnt_5th <= bpe_out_cnt_5th_next;
        coef_cnt_5th <= coef_cnt_5th_next;
      end
    end

    // ================= data register for 5th BPE ====================//
    // // // Data register for 5th BPE
    // reg [pDATA_WIDTH-1:0] data_reg_5th_ram0, data_reg_5th_ram0_next;
    // reg [pDATA_WIDTH-1:0] delay_aout_5th [3:0];
    // reg [pDATA_WIDTH-1:0] delay_aout_5th_next [3:0];

    // reg [pDATA_WIDTH-1:0] delay_bout_5th_next [3:0];
    // reg [pDATA_WIDTH-1:0] delay_bout_5th [3:0];

    always@(*)begin  
      if(BPE5_o_vld && BPE5_o_rdy) begin
        delay_aout_5th_next[0] = BPE5_aout;
        delay_bout_5th_next[0] = BPE5_bout;
        for (i = 1; i < 2; i = i + 1) begin
          delay_aout_5th_next[i] = delay_aout_5th[i-1];
          delay_bout_5th_next[i] = delay_bout_5th[i-1];
        end
      end else if(out_cnt_5th[0+:5] == MUL_DELAY)begin
          delay_aout_5th_next[0] = 0;
          delay_bout_5th_next[0] = 0;
          for (i = 1; i < 2; i = i + 1) begin
            delay_aout_5th_next[i] = delay_aout_5th[i-1];
            delay_bout_5th_next[i] = delay_bout_5th[i-1];
          end
        end else begin
          for(i = 0; i < 2; i = i + 1) begin
            delay_aout_5th_next[i] = delay_aout_5th[i];
            delay_bout_5th_next[i] = delay_bout_5th[i];
          end
      end
    end
    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        for (i = 0; i < 2; i = i + 1) begin
          delay_aout_5th[i] <= 0;
          delay_bout_5th[i] <= 0;
        end
      end else begin
        for (i = 0; i < 2; i = i + 1) begin
          delay_aout_5th[i] <= delay_aout_5th_next[i];
          delay_bout_5th[i] <= delay_bout_5th_next[i];
        end
      end
    end

    always@(*)begin
      case(state_5th)
        BPE_I0_5th: data_reg_5th_ram0_next = (~in_cnt_5th[0]) ? ld_dat_5th : data_reg_5th_ram0;
        BPE_I1_5th: data_reg_5th_ram0_next = (~in_cnt_5th[0]) ? ld_dat_5th : data_reg_5th_ram0; 
        BPE_I2_5th: data_reg_5th_ram0_next = (~in_cnt_5th[0]) ? ld_dat_5th : data_reg_5th_ram0;
        BPE_I3_5th: data_reg_5th_ram0_next = (~in_cnt_5th[0]) ? ld_dat_5th : data_reg_5th_ram0;
        BPE_O0_5th: data_reg_5th_ram0_next = delay_bout_5th[1];
        BPE_O1_5th: data_reg_5th_ram0_next = delay_bout_5th[1];
        BPE_O2_5th: data_reg_5th_ram0_next = delay_bout_5th[1];
        BPE_O3_5th: data_reg_5th_ram0_next = delay_bout_5th[1];
        default: data_reg_5th_ram0_next = data_reg_5th_ram0;
      endcase
    end

    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        data_reg_5th_ram0 <= 0;
      end else begin
        data_reg_5th_ram0 <= data_reg_5th_ram0_next;
      end
    end

    // =================== Coefficient for 5th BPE ====================//
    // // Coefficient for 5th BPE
    // reg [pDATA_WIDTH-1:0] COEF_5th [0:3];
    // reg [pDATA_WIDTH-1:0] COEF_5th_next [0:3];
    // // coefficient FIFOs for 5th BPE
    // reg [pDATA_WIDTH-1:0] COEF0_0_5th, COEF0_1_5th, COEF0_2_5th, COEF0_3_5th;
    // reg [pDATA_WIDTH-1:0] COEF1_0_5th, COEF1_1_5th, COEF1_2_5th, COEF1_3_5th;
    // reg [pDATA_WIDTH-1:0] COEF2_0_5th, COEF2_1_5th, COEF2_2_5th, COEF2_3_5th;
    // reg [pDATA_WIDTH-1:0] COEF3_0_5th, COEF3_1_5th, COEF3_2_5th, COEF3_3_5th;

    // reg [pDATA_WIDTH-1:0] COEF0_0_5th_next, COEF0_1_5th_next, COEF0_2_5th_next, COEF0_3_5th_next;
    // reg [pDATA_WIDTH-1:0] COEF1_0_5th_next, COEF1_1_5th_next, COEF1_2_5th_next, COEF1_3_5th_next;
    // reg [pDATA_WIDTH-1:0] COEF2_0_5th_next, COEF2_1_5th_next, COEF2_2_5th_next, COEF2_3_5th_next;
    // reg [pDATA_WIDTH-1:0] COEF3_0_5th_next, COEF3_1_5th_next, COEF3_2_5th_next, COEF3_3_5th_next;

    always@(*)begin
      COEF0_0_5th_next = (coef_cnt_5th == 0 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF0_0_5th;
      COEF0_1_5th_next = (coef_cnt_5th == 1 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF0_1_5th;
      COEF0_2_5th_next = (coef_cnt_5th == 2 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF0_2_5th;
      COEF0_3_5th_next = (coef_cnt_5th == 3 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF0_3_5th;

      COEF1_0_5th_next = (coef_cnt_5th == 4 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF1_0_5th;
      COEF1_1_5th_next = (coef_cnt_5th == 5 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF1_1_5th;
      COEF1_2_5th_next = (coef_cnt_5th == 6 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF1_2_5th;
      COEF1_3_5th_next = (coef_cnt_5th == 7 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF1_3_5th;

      COEF2_0_5th_next = (coef_cnt_5th == 8 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF2_0_5th;
      COEF2_1_5th_next = (coef_cnt_5th == 9 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF2_1_5th;
      COEF2_2_5th_next = (coef_cnt_5th == 10 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF2_2_5th;
      COEF2_3_5th_next = (coef_cnt_5th == 11 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF2_3_5th;

      COEF3_0_5th_next = (coef_cnt_5th == 12 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF3_0_5th;
      COEF3_1_5th_next = (coef_cnt_5th == 13 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF3_1_5th;
      COEF3_2_5th_next = (coef_cnt_5th == 14 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF3_2_5th;
      COEF3_3_5th_next = (coef_cnt_5th == 15 && (coef_vld[4] && coef_5th_rdy)) ? coef_dat : COEF3_3_5th;
    end

    always@(posedge clk or negedge rstn) begin
      if (~rstn) begin
        COEF0_0_5th <= 0; COEF0_1_5th <= 0; COEF0_2_5th <= 0; COEF0_3_5th <= 0;
        COEF1_0_5th <= 0; COEF1_1_5th <= 0; COEF1_2_5th <= 0; COEF1_3_5th <= 0;
        COEF2_0_5th <= 0; COEF2_1_5th <= 0; COEF2_2_5th <= 0; COEF2_3_5th <= 0;
        COEF3_0_5th <= 0; COEF3_1_5th <= 0; COEF3_2_5th <= 0; COEF3_3_5th <= 0;
      end else begin
        COEF0_0_5th <= COEF0_0_5th_next; COEF0_1_5th <= COEF0_1_5th_next; 
        COEF0_2_5th <= COEF0_2_5th_next; COEF0_3_5th <= COEF0_3_5th_next;
        COEF1_0_5th <= COEF1_0_5th_next; COEF1_1_5th <= COEF1_1_5th_next; 
        COEF1_2_5th <= COEF1_2_5th_next; COEF1_3_5th <= COEF1_3_5th_next;
        COEF2_0_5th <= COEF2_0_5th_next; COEF2_1_5th <= COEF2_1_5th_next; 
        COEF2_2_5th <= COEF2_2_5th_next; COEF2_3_5th <= COEF2_3_5th_next;
        COEF3_0_5th <= COEF3_0_5th_next; COEF3_1_5th <= COEF3_1_5th_next; 
        COEF3_2_5th <= COEF3_2_5th_next; COEF3_3_5th <= COEF3_3_5th_next;
      end
    end
    
    // ==================== Data for BPE5 ====================//

    // ==================== Connection to output buffer ====================//
    

    /*===============================================================================================
    #                                       OUTPUT BUFFER                                           #
    ================================================================================================*/
    // // output buffer for 5th BPE
    // reg [pDATA_WIDTH:0] output_buffer_w[0:31];
    // reg [pDATA_WIDTH:0] output_buffer[0:31]; //
    // reg [$clog2(pDATA_WIDTH)-1:0] output_buf_in_cnt_r; 
    // reg [$clog2(pDATA_WIDTH)-1:0] output_buf_in_cnt_w; // input counter for output buffer
    // reg [pDATA_WIDTH-1:0] BPE5_dout;
    
    // // counters
    // reg [$clog2(pDATA_WIDTH)-1:0] kern_out_cnt_r; // output counter for kernel
    // wire [$clog2(pDATA_WIDTH)-1:0] kern_out_cnt_w;

    always@(posedge clk or negedge rstn) begin
        if (~rstn) begin
          for (i = 0; i < 256; i = i + 1) begin//
            output_buffer[i] <= 0;
          end
        end else begin
          for (i = 0; i < 256; i = i + 1) begin//
            output_buffer[i] <= output_buffer_w[i];
          end
        end
    end
    // ====================================================================================== output buffer ============================================================================================
    integer idx;
    always@(*)begin
      for (idx = 0; idx < 256; idx = idx + 1)begin//
        if(sm_vld_5th & sm_rdy_5th & output_buf_in_cnt_r[0+:8] == idx) output_buffer_w[idx] = {1'b1, BPE5_dout};//
        else if(sw_vld && sw_rdy && (kern_out_cnt_r[0+:8] == idx)) output_buffer_w[idx] = output_buffer[idx] >> 1;//
        else output_buffer_w[idx] = output_buffer[idx];
      end
    end
      
    
    // always@(*)begin // output buffer for 128 bit BW
    //   for (i = 0; i < 32; i = i + 1) output_buffer_w[i] = output_buffer[i];
    //   case(output_buf_in_cnt_r[0+:5]) // valid pulled down when output finished
    //     5'd0: output_buffer_w[0]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd0))  ? output_buffer[0]>>1  : output_buffer[0]);
    //     5'd1: output_buffer_w[1]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd1))  ? output_buffer[1]>>1  : output_buffer[1]);
    //     5'd2: output_buffer_w[2]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd2))  ? output_buffer[2]>>1  : output_buffer[2]);
    //     5'd3: output_buffer_w[3]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd3))  ? output_buffer[3]>>1  : output_buffer[3]);
    //     5'd4: output_buffer_w[4]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd4))  ? output_buffer[4]>>1  : output_buffer[4]);
    //     5'd5: output_buffer_w[5]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd5))  ? output_buffer[5]>>1  : output_buffer[5]);
    //     5'd6: output_buffer_w[6]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd6))  ? output_buffer[6]>>1  : output_buffer[6]);
    //     5'd7: output_buffer_w[7]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd7))  ? output_buffer[7]>>1  : output_buffer[7]);
    //     5'd8: output_buffer_w[8]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd8))  ? output_buffer[8]>>1  : output_buffer[8]);
    //     5'd9: output_buffer_w[9]   = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd9))  ? output_buffer[9]>>1  : output_buffer[9]);
    //     5'd10: output_buffer_w[10] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd10)) ? output_buffer[10]>>1 : output_buffer[10]);
    //     5'd11: output_buffer_w[11] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd11)) ? output_buffer[11]>>1 : output_buffer[11]);
    //     5'd12: output_buffer_w[12] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd12)) ? output_buffer[12]>>1 : output_buffer[12]);
    //     5'd13: output_buffer_w[13] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd13)) ? output_buffer[13]>>1 : output_buffer[13]);
    //     5'd14: output_buffer_w[14] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd14)) ? output_buffer[14]>>1 : output_buffer[14]);
    //     5'd15: output_buffer_w[15] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd15)) ? output_buffer[15]>>1 : output_buffer[15]);
    //     5'd16: output_buffer_w[16] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd16)) ? output_buffer[16]>>1 : output_buffer[16]);
    //     5'd17: output_buffer_w[17] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd17)) ? output_buffer[17]>>1 : output_buffer[17]);
    //     5'd18: output_buffer_w[18] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd18)) ? output_buffer[18]>>1 : output_buffer[18]);
    //     5'd19: output_buffer_w[19] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd19)) ? output_buffer[19]>>1 : output_buffer[19]);
    //     5'd20: output_buffer_w[20] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd20)) ? output_buffer[20]>>1 : output_buffer[20]);
    //     5'd21: output_buffer_w[21] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd21)) ? output_buffer[21]>>1 : output_buffer[21]);
    //     5'd22: output_buffer_w[22] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd22)) ? output_buffer[22]>>1 : output_buffer[22]);
    //     5'd23: output_buffer_w[23] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd23)) ? output_buffer[23]>>1 : output_buffer[23]);
    //     5'd24: output_buffer_w[24] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd24)) ? output_buffer[24]>>1 : output_buffer[24]);
    //     5'd25: output_buffer_w[25] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd25)) ? output_buffer[25]>>1 : output_buffer[25]);
    //     5'd26: output_buffer_w[26] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd26)) ? output_buffer[26]>>1 : output_buffer[26]);
    //     5'd27: output_buffer_w[27] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd27)) ? output_buffer[27]>>1 : output_buffer[27]);
    //     5'd28: output_buffer_w[28] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd28)) ? output_buffer[28]>>1 : output_buffer[28]);
    //     5'd29: output_buffer_w[29] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd29)) ? output_buffer[29]>>1 : output_buffer[29]);
    //     5'd30: output_buffer_w[30] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd30)) ? output_buffer[30]>>1 : output_buffer[30]);
    //     5'd31: output_buffer_w[31] = (sm_vld_5th & sm_rdy_5th) ? {1'b1, BPE5_dout} : ((sw_vld && sw_rdy & (kern_out_cnt_r[0+:5] == 5'd31)) ? output_buffer[31]>>1 : output_buffer[31]);
                                     
    //     default: begin
    //       for (i = 0; i < 32; i = i + 1) begin
    //         output_buffer_w[i] = output_buffer[i];
    //       end
    //     end
    //   endcase
    // end

    assign output_buf_in_cnt_w = sw_lst ? 0 : ((sm_vld_5th & sm_rdy_5th) ? output_buf_in_cnt_r + 1 : output_buf_in_cnt_r);
    // assign out_byte_cnt_w = (sw_vld & sw_rdy) ? out_byte_cnt_r + 1 : out_byte_cnt_r;
    assign kern_out_cnt_w = (sw_vld & sw_rdy) ? kern_out_cnt_r + 1 : kern_out_cnt_r;           
    assign sw_vld = output_buffer[kern_out_cnt_r[0+:8]][pDATA_WIDTH];
    // assign sm_rdy_5th = !output_buffer[output_buf_in_cnt_r[0+:8]][pDATA_WIDTH]; // ready to receive data when empty
    assign sw_lst = & kern_out_cnt_r;
    assign sw_dat = output_buffer[kern_out_cnt_r[0+:8]][0+:pDATA_WIDTH]; // 128 bit data

    reg o, q;
    always @ (posedge clk) o<=0;
    always @ (posedge clk) q<=1;
    // assign sw_lst = o;
    assign sm_rdy_5th = q;

    always @(posedge clk or negedge rstn) begin
      if (~rstn) begin
        kern_out_cnt_r <= 0;
        output_buf_in_cnt_r <= 0;
      end else begin
        kern_out_cnt_r <= kern_out_cnt_w;
        output_buf_in_cnt_r <= output_buf_in_cnt_w;
      end
    end


endmodule
