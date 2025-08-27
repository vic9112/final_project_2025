module kernel
#(  
    parameter pDATA_WIDTH = 128,
    parameter pDATA_WIDTH_2x = 256 
)
(
    input  wire                     clk,
    input  wire                     clk_2x,     // for dataRAM (double-speed)
    input  wire                     rstn,

    input  wire               [1:0] mode,
    input  wire                     decode,
    output reg                     sw_lst,       // set when handshake

    //======================data ram======================//
    //============SRAM1 512x128============//
    output reg [3:0]    WE_512_1,
    output reg sram_en_512_1,
    output reg[(pDATA_WIDTH-1):0] sram_din_512_1,
    input wire [(pDATA_WIDTH-1):0] sram_dout_512_1,
    output reg[12:0]   sram_addr_512_1,

    //============SRAM2 512x128============//
    output reg [3:0]    WE_512_2,
    output         reg sram_en_512_2,
    output reg[(pDATA_WIDTH-1):0] sram_din_512_2,
    input wire [(pDATA_WIDTH-1):0] sram_dout_512_2,
    output reg[12:0]   sram_addr_512_2,

    //======================coef ram======================//
    //============fft/ifft 512x128============//
    output wire [3:0]    coef_WE_512,
    output wire  coef_sram_en_512,
    output wire[(pDATA_WIDTH-1):0] coef_sram_din_512,
    input wire [(pDATA_WIDTH-1):0] coef_sram_dout_512,
    output reg[12:0]   coef_sram_addr_512,

    //============ntt 128x128============//
    output wire [3:0]    coef_WE_ntt,
    output wire coef_sram_en_ntt,
    output wire[(pDATA_WIDTH-1):0] coef_sram_din_ntt,
    input wire [(pDATA_WIDTH-1):0] coef_sram_dout_ntt,
    output reg[12:0]   coef_sram_addr_ntt,

    //============intt 128x128============//
    output wire [3:0]    coef_WE_intt,
    output wire coef_sram_en_intt,
    output wire[(pDATA_WIDTH-1):0] coef_sram_din_intt,
    input wire [(pDATA_WIDTH-1):0] coef_sram_dout_intt,
    output reg[12:0]   coef_sram_addr_intt
);

//============BPE============//
    reg  [(pDATA_WIDTH-1):0] BPE_ain;
    reg  [(pDATA_WIDTH-1):0] BPE_bin;
    reg  [(pDATA_WIDTH-1):0] BPE_coef;
    wire [(pDATA_WIDTH-1):0] BPE_aout;
    wire [(pDATA_WIDTH-1):0] BPE_bout;
    reg  [2:0] mode_state;
    reg  BPE_i_vld;
    wire BPE_i_rdy;
    wire BPE_o_vld;
    reg  BPE_o_rdy;

    butterfly BPE (
        .clk   (clk),
        .rst_n (rstn),
        .mode  (mode_state),
        .i_vld (BPE_i_vld),
        .i_rdy (BPE_i_rdy),
        .o_vld (BPE_o_vld),
        .o_rdy (BPE_o_rdy),
        .ai    (BPE_ain),
        .bi    (BPE_bin),
        .gm    (BPE_coef),
        .ao    (BPE_aout),
        .bo    (BPE_bout)
    );

//==================================== DECLARATION ===================================//
//===============PHASE=============== //
reg phase;
wire phase_next;
//============BPE MODE=============== //
localparam MODE_FFT  = 2'b00;
localparam MODE_IFFT = 2'b01;
localparam MODE_NTT  = 2'b10;
localparam MODE_INTT = 2'b11;
//============FSM STATE=============== //

localparam IDLE = 4'b0000;  // 0
localparam MS_1 = 4'b0001;  // 1
localparam NTM  = 4'b0010;  // 2
localparam MS_2 = 4'b0011;  // 3
localparam S1   = 4'b0100;  // 4
localparam S2   = 4'b0101;  // 5
localparam S3   = 4'b0110;  // 6
localparam S4   = 4'b0111;  // 7
localparam S5   = 4'b1000;  // 8
localparam S6   = 4'b1001;  // 9
localparam S7   = 4'b1010;  // 10
localparam S8   = 4'b1011;  // 11
localparam S9   = 4'b1100;  // 12
localparam S10  = 4'b1101;  // 13
localparam MS_3 = 4'b1110;  // 14
localparam MTN  = 4'b1111;  // 15

reg [3:0] stage;
reg [3:0] stage_next;

//===========counter_1=================//

wire counter_reset;
reg [15:0] counter_1;
reg [15:0] counter_1_next;
reg [15:0] counter_1_prv;

//===========counter_2=================//

reg [15:0] counter_2;
reg [15:0] counter_2_next;


//===========BPE_i_vld=================//
wire in_range;

//===========BPE_ain=================//
reg [(pDATA_WIDTH-1):0] BPE_reg;
reg [(pDATA_WIDTH-1):0] sram_dout_512_1_prv, sram_dout_512_2_prv;

//===========BPE_coef=================//
reg [(pDATA_WIDTH-1):0] BPE_coef_reg;
wire [(pDATA_WIDTH-1):0] BPE_coef_fft_ifft;

//===========SRAM_ADDR=================//
reg [21:0] data_ram_addr_1;
reg [21:0] data_ram_addr_2;


//===========COEF_RAM=================//
wire [7:0] out8;
wire [6:0] out7;
wire [5:0] out6;
wire [4:0] out5;
wire [3:0] out4;
wire [2:0] out3;
wire [1:0] out2;
wire out1;


//===========DATA PERMUTE=================//
reg [(pDATA_WIDTH-1):0] sram_dout_reorder;
reg [(pDATA_WIDTH-1):0] BPE_ain_tmp;
reg [(pDATA_WIDTH-1):0] BPE_bin_tmp;


//==================================== FSM ===================================//
//============= fsm control==============// 

reg [4:0] cnt_vld, nxt_cnt_vld;
// state update
always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    stage <= 0;
    cnt_vld <= 0;
  end else begin
    stage <= stage_next;
    cnt_vld <= nxt_cnt_vld;
  end
end

// mode switch : vld == 1 timing
// data flow
    always @(*) begin
        case (stage)
            // notification for mode switch and store s1 data in sram 512
            IDLE: begin
              BPE_i_vld = 0;
              BPE_o_rdy = 0;
              BPE_ain = 0;
              BPE_bin = 0;
              BPE_coef = 0;
              mode_state = 0;

              sram_en_512_1 = 0;
              WE_512_1 = 0;
              sram_addr_512_1 = 0;
              sram_din_512_1 = 0;
   
              sram_en_512_2 = 0;
              WE_512_2 = 0;
              sram_addr_512_2 = 0;
              sram_din_512_2 = 0;

              coef_sram_addr_512 = 0; 
              coef_sram_addr_ntt = 0;
              coef_sram_addr_intt = 0;

              nxt_cnt_vld = 0;
              stage_next = (decode) ? MS_1 : IDLE;
              sw_lst = 0;
            end
            MS_1: begin // FFT -> current mode (latency == 11)
              BPE_i_vld = (cnt_vld == 1 || cnt_vld == 12);
              BPE_o_rdy = 1;
              BPE_ain = 0;
              BPE_bin = 0;
              BPE_coef = 0;
              mode_state = (mode[1]) ? 3'b100 : {1'b0, mode[1:0]};

              sram_en_512_1 = 0;
              WE_512_1 = 0;
              sram_addr_512_1 = 0;
              sram_din_512_1 = 0;
   
              sram_en_512_2 = 0;
              WE_512_2 = 0;
              sram_addr_512_2 = 0;
              sram_din_512_2 = 0;

              coef_sram_addr_512 = 0; 
              coef_sram_addr_ntt = 0;
              coef_sram_addr_intt = 0;

              nxt_cnt_vld = cnt_vld + 1;
              
              stage_next = (cnt_vld == 23) ? ((mode[1]) ? NTM : S2) : MS_1;  //可改cnt_vld
              sw_lst = 0;
            end
            NTM: begin 
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = in_range ? sram_dout_512_1 : 0; // 之後改成0
              BPE_bin = in_range ? sram_dout_512_1 : 0; // 之後改成0
              BPE_coef = in_range ? sram_dout_512_1 : 0;
              mode_state = 3'b100;

              sram_en_512_1 = 1;
              WE_512_1 = 0;
              sram_addr_512_1 = {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = 0;
   
              sram_en_512_2 = 1;
              WE_512_2 = {4{BPE_o_vld & BPE_o_rdy}};
              sram_addr_512_2 = {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = BPE_aout;

              coef_sram_addr_512 = 0; 
              coef_sram_addr_ntt = 0;
              coef_sram_addr_intt = 0;

              nxt_cnt_vld = 0;

              stage_next = counter_2[7] ? MS_2 : NTM;  
              sw_lst = 0;
            end
            MS_2: begin  // NTM -> NTT/iNTT (latency == 7)
              BPE_i_vld = (cnt_vld == 1 || cnt_vld == 8);
              BPE_o_rdy = 1;
              BPE_ain = 0;
              BPE_bin = 0;
              BPE_coef = 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 0;
              WE_512_1 = 0;
              sram_addr_512_1 = 0;
              sram_din_512_1 = 0;
   
              sram_en_512_2 = 0;
              WE_512_2 = 0;
              sram_addr_512_2 = 0;
              sram_din_512_2 = 0;

              coef_sram_addr_512 = 0; 
              coef_sram_addr_ntt = 0;
              coef_sram_addr_intt = 0;

              nxt_cnt_vld = cnt_vld + 1;
              stage_next = (cnt_vld == 23) ? S1 : stage; //可改cnt_vld
              sw_lst = 0;
            end
            S1: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = BPE_reg;
              BPE_bin = sram_dout_512_2;
              BPE_coef = (in_range) ? ((mode[0]) ? coef_sram_dout_intt : BPE_coef_reg) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;
   
              sram_en_512_2 = 1;
              WE_512_2 = 0;
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = 0;

              coef_sram_addr_512 = 0; 
              coef_sram_addr_ntt = 13'b0;
              coef_sram_addr_intt = (~phase) ? {4'b0, 1'b0, counter_1[5:0], 2'b0} : coef_sram_addr_intt;

              
              nxt_cnt_vld = 0;

              stage_next = (counter_2[6] ? S2 : S1);
              sw_lst = 0;
            end
            S2: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = BPE_reg;
              BPE_bin = sram_dout_512_1;
              BPE_coef = (in_range) ? ((mode[1]) ?  ((mode[0]) ? coef_sram_dout_intt : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = 0;
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;

    
              sram_en_512_2 = 1;
              WE_512_2 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {2'b0, 1'b1, out8[7:0], 2'b0} : {10'b0 ,1'b1, 2'b0};
              coef_sram_addr_ntt = 13'b0;
              coef_sram_addr_intt = (~phase) ? {4'b0, 2'b10, counter_1[4:0], 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S3 : S2) :
                               (counter_2[8] ? S3 : S2);
              sw_lst = 0;                 
            end
            S3: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = BPE_reg;
              BPE_bin = sram_dout_512_2;
              BPE_coef = (in_range) ? ((mode[1]) ?  ((mode[0]) ? coef_sram_dout_intt : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;

              sram_en_512_2 = 1;
              WE_512_2 = 0;
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {3'b0, 1'b1, out7[6:0], 2'b0} : {9'b0, 1'b1, counter_1[7], 2'b0};
              coef_sram_addr_ntt = 13'b0;
              coef_sram_addr_intt = (~phase) ? {4'b0, 3'b110, counter_1[3:0], 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S4 : S3) :
                               (counter_2[8] ? S4 : S3); 
              sw_lst = 0;                
            end
            S4: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = BPE_reg;
              BPE_bin = sram_dout_512_1;
              BPE_coef = in_range ? ((mode[1]) ?  ((mode[0]) ? coef_sram_dout_intt : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = 0;
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;
   
              sram_en_512_2 = 1;
              WE_512_2 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {4'b0, 1'b1, out6[5:0], 2'b0} : {8'b0, 1'b1, counter_1[7:6], 2'b0};
              coef_sram_addr_ntt = {10'b0, 1'b1, 2'b0};
              coef_sram_addr_intt = (~phase) ? {4'b0, 4'b1110, counter_1[2:0], 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S5 : S4) :
                               (counter_2[8] ? S5 : S4);
              sw_lst = 0;                 
            end
            S5: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = BPE_reg;
              BPE_bin = sram_dout_512_2;
              BPE_coef = (in_range) ? ((mode[1]) ?  ((mode[0]) ? coef_sram_dout_intt : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;

              sram_en_512_2 = 1;
              WE_512_2 = 0;
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {5'b0, 1'b1, out5[4:0], 2'b0} : {7'b0, 1'b1, counter_1[7:5], 2'b0};
              coef_sram_addr_ntt = {9'b0, 1'b1, counter_1[5], 2'b0};
              coef_sram_addr_intt = (~phase) ? {4'b0, 5'b11110, counter_1[1:0], 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S6 : S5) :
                               (counter_2[8] ? S6 : S5);
              sw_lst = 0;                 
            end
            S6: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = BPE_reg;
              BPE_bin = sram_dout_512_1;
              BPE_coef = in_range ? ((mode[1]) ?  ((mode[0]) ? coef_sram_dout_intt : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = 0;
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;
   
              sram_en_512_2 = 1;
              WE_512_2 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {6'b0, 1'b1, out4[3:0], 2'b0} : {6'b0, 1'b1, counter_1[7:4], 2'b0};
              coef_sram_addr_ntt = {8'b0, 1'b1, counter_1[5:4], 2'b0};
              coef_sram_addr_intt = (~phase) ? {4'b0, 6'b111110, counter_1[0], 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S7 : S6) :
                               (counter_2[8] ? S7 : S6);
              sw_lst = 0;                 
            end
            S7: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = BPE_reg;
              BPE_bin = sram_dout_512_2;
              BPE_coef = (in_range) ? (mode[1]) ?  ((mode[0]) ? coef_sram_dout_intt : BPE_coef_reg) : 
                              BPE_coef_fft_ifft : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;

              sram_en_512_2 = 1;
              WE_512_2 = 0;
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {7'b0, 1'b1, out3[2:0], 2'b0} : {5'b0, 1'b1, counter_1[7:3], 2'b0};
              coef_sram_addr_ntt = {7'b0, 1'b1, counter_1[5:3], 2'b0};
              coef_sram_addr_intt = (~phase) ? {4'b0, 7'b1111110, 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S8 : S7) :
                               (counter_2[8] ? S8 : S7);
              sw_lst = 0;                 
            end
            S8: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = (mode[1]) ? ((phase) ? {sram_dout_512_1[63:0], sram_dout_512_1_prv[63:0]} : BPE_ain): BPE_reg;
              BPE_bin = (mode[1]) ? ((phase) ? {sram_dout_512_1[127:64], sram_dout_512_1_prv[127:64]} : BPE_bin) : sram_dout_512_1;

              BPE_coef = in_range ? ((mode[1]) ?  ((mode[0]) ? {2{coef_sram_dout_intt[63:0]}} : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = 0;
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = 0;
   
              sram_en_512_2 = 1;
              WE_512_2 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {8'b0, 1'b1, out2[1:0], 2'b0} : {6'b0, 1'b1, counter_1[7:2], 2'b0};
              coef_sram_addr_ntt = {6'b0, 1'b1, counter_1[5:2], 2'b0};
              coef_sram_addr_intt = (~phase) ? {4'b0, 7'b1111111, 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S9 : S8) :
                               (counter_2[8] ? S9 : S8);
              sw_lst = 0;               
            end
            S9: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = (mode[1]) ? ((phase) ? {sram_dout_512_2[95:64], sram_dout_512_2_prv[95:64], sram_dout_512_2[31:0], sram_dout_512_2_prv[31:0]} : BPE_ain): BPE_reg;
              BPE_bin = (mode[1]) ? ((phase) ? {sram_dout_512_2[127:96], sram_dout_512_2_prv[127:96], sram_dout_512_2[63:32], sram_dout_512_2_prv[63:32]} : BPE_bin) : sram_dout_512_2;

              BPE_coef = in_range ? ((mode[1]) ?  ((mode[0]) ? {4{coef_sram_dout_intt[95:64]}} : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) : 0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;
   
              sram_en_512_2 = 1;
              WE_512_2 = 0;
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {9'b0, 1'b1, out1, 2'b0} : {5'b0, 1'b1, counter_1[7:1], 2'b0};
              coef_sram_addr_ntt = {5'b0, 1'b1, counter_1[5:1], 2'b0};
              coef_sram_addr_intt = (~phase) ? {4'b0, 7'b1111111, 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? S10 : S9) :
                               (counter_2[8] ? S10 : S9);
              sw_lst = 0;
            end
            S10: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = (mode[1]) ? ((phase) ? {sram_dout_512_1[111:96], sram_dout_512_1_prv[111:96],  sram_dout_512_1[79:64], sram_dout_512_1_prv[79:64], sram_dout_512_1[47:32], sram_dout_512_1_prv[47:32],  sram_dout_512_1[15:0], sram_dout_512_1_prv[15:0]} : BPE_ain): BPE_reg;
              BPE_bin = (mode[1]) ? ((phase) ? {sram_dout_512_1[127:112], sram_dout_512_1_prv[127:112],  sram_dout_512_1[95:80], sram_dout_512_1_prv[95:80], sram_dout_512_1[63:48], sram_dout_512_1_prv[63:48],  sram_dout_512_1[31:16], sram_dout_512_1_prv[31:16]} : BPE_bin) : sram_dout_512_1;

              BPE_coef = in_range ? ((mode[1]) ?  ((mode[0]) ? {8{coef_sram_dout_intt[111:96]}}  : BPE_coef_reg) : 
                              BPE_coef_fft_ifft) :0;
              mode_state = {1'b0, mode[1:0]};

              sram_en_512_1 = 1;
              WE_512_1 = 0;
              sram_addr_512_1 = (~phase) ? {data_ram_addr_1[21:11], 2'b0} : {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = (~phase) ? BPE_bout : BPE_aout;
   
              sram_en_512_2 = 1;
              WE_512_2 = {4{BPE_o_rdy & BPE_o_vld}};
              sram_addr_512_2 = (~phase) ? {data_ram_addr_2[21:11], 2'b0} : {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = (~phase) ? BPE_bout : BPE_aout;

              coef_sram_addr_512 = (mode[0]) ? {9'b0, 1'b0, 1'b1, 2'b0} : {5'b0, 1'b1, counter_1[7:0], 2'b0};
              coef_sram_addr_ntt = {4'b0, 1'b1, counter_1[5:0], 2'b0};
              coef_sram_addr_intt = (~phase) ? {4'b0, 7'b1111111, 2'b0} : coef_sram_addr_intt;

              stage_next = (mode[1]) ? (counter_2[6] ? MS_3 : S10) :
                               (counter_2[8] ? IDLE : S10);
              sw_lst = (mode[1] == 0 && counter_2[8]);
            end
            MS_3: begin  // NTT/iNTT -> MTN (latency == 9)
              BPE_i_vld = (cnt_vld == 1 || cnt_vld == 10);
              BPE_o_rdy =1;
              BPE_ain = 0;
              BPE_bin = 0;
              BPE_coef = 0;
              mode_state = (mode[0]) ? 3'b110 : 3'b101;

              sram_en_512_1 = 0;
              WE_512_1 = 0;
              sram_addr_512_1 = 0;
              sram_din_512_1 = 0;
   
              sram_en_512_2 = 0;
              WE_512_2 = 0;
              sram_addr_512_2 = 0;
              sram_din_512_2 = 0;

              coef_sram_addr_512 = 0; 
              coef_sram_addr_ntt = 0;
              coef_sram_addr_intt = 0;

              nxt_cnt_vld = cnt_vld + 1;
              stage_next = (cnt_vld == 23) ? MTN : MS_3;
              sw_lst = 0;
            end
            MTN: begin
              BPE_i_vld = in_range;
              BPE_o_rdy = 1;
              BPE_ain = in_range ? sram_dout_512_2 : 0; // 之後改成0
              BPE_bin = in_range ? sram_dout_512_2 : 0; // 之後改成0
              BPE_coef = in_range ? sram_dout_512_2 : 0;
              mode_state = (mode[0]) ? 3'b110 : 3'b101;

              sram_en_512_1 = 1;
              WE_512_1 = {4{BPE_o_vld && BPE_o_rdy}};
              sram_addr_512_1 = {data_ram_addr_1[10:0], 2'b0};
              sram_din_512_1 = BPE_aout;
   
              sram_en_512_2 = 1;
              WE_512_2 = 0;
              sram_addr_512_2 = {data_ram_addr_2[10:0], 2'b0};
              sram_din_512_2 = 0;

              coef_sram_addr_512 = 0; 
              coef_sram_addr_ntt = 0;
              coef_sram_addr_intt = 0;

              nxt_cnt_vld = 0;

              stage_next = counter_2[7] ? IDLE : MTN; 
              sw_lst = (mode[1] && counter_2[7]) ? 1 : 0;
            end
            
        endcase
    end

//==================================== PHASE ===================================//

always @(posedge clk_2x or negedge rstn) begin
  if (~rstn) begin
    phase <= 0;
  end else begin
    phase <= phase_next;
  end
end

assign phase_next = ~phase;



//==================================== counter_1, counter_2===================================//

///////////////////////////////////////////////////////////////////////////////////////
// 當切state時，counter會同步reset，在切換完的第一個Cycle傳給外面的COEF_RAM這個Stage     //
// 第一個要用的coef的位址，並在下半週期傳BPE_in_a需要的Data位址給外面，下個Cycle後即可恢復 //
// 正常，上半週期給當個週期要用的BPE_in_b需要的Data位址，下半週期給BPE_in_a的位址，僅有    //
// BPE_in_a的data需要先存在一個Reg裡，BPE_in_b可以直接接到sram_do。                     //
////////////////////////////////////////////////////////////////////////////////////////

// counter_reset
assign counter_reset = (stage_next != stage);

// counter_1 
always @(posedge clk or negedge rstn) begin
  if (~rstn) begin
    counter_1 <= 0;
    counter_1_prv <= 0;
    counter_2 <= 0;
  end else begin
    counter_1 <= (counter_reset) ? 0 : counter_1_next;
    counter_1_prv <= (counter_reset) ? 0 : counter_1;
    counter_2 <= (counter_reset) ? 0 : counter_2_next;
  end
end


// counter_1_next 
always @(*) begin
  case (stage)
    NTM: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S1: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S2: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S3: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S4: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S5: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S6: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S7: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S8: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S9: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    S10: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    MTN: begin
      counter_1_next = (BPE_i_rdy) ? counter_1 + 1 : counter_1;
      counter_2_next = (BPE_o_vld & BPE_o_rdy) ? counter_2 + 1 : counter_2;
    end
    default: begin
      counter_1_next = 0;
      counter_2_next = 0;
    end
  endcase
end




//==================================== BPE_i_vld ===================================//

// mode[1] == 1 --> NTT/INTT, mode[1] == 0 --> FFT/IFFT

assign in_range =  (mode[1]) ? ((stage == NTM || stage == MTN) ?  ~(|counter_1[15:7]) : ((|counter_1[5:0]) & ~(|counter_1[15:6])) | (~(|counter_1[5:0]) & counter_1[6] & ~(|counter_1[15:7]))) :
                            ((|counter_1[7:0]) & ~(|counter_1[15:8])) | (~(|counter_1[7:0]) & counter_1[8] & ~(|counter_1[15:9])) ; // 1~256

                                                
always @(posedge clk_2x) begin
  BPE_reg <= BPE_bin;
  sram_dout_512_1_prv <= sram_dout_512_1;
  sram_dout_512_2_prv <= sram_dout_512_2;
end

//==================================== BPE_coef ===================================//

assign BPE_coef_fft_ifft = (phase) ? ((mode[0]) ? {coef_sram_dout_512[127:64], ~coef_sram_dout_512[63], coef_sram_dout_512[62:0]} : coef_sram_dout_512) : BPE_coef_fft_ifft; 

always @(*) begin
  case (stage)
    S1: begin
      BPE_coef_reg = phase ? {8{coef_sram_dout_ntt[31:16]}} : BPE_coef_reg;
    end
    S2: begin                     
      BPE_coef_reg = phase ? (counter_1_prv[5]) ? {8{coef_sram_dout_ntt[63:48]}} : {8{coef_sram_dout_ntt[47:32]}} : BPE_coef_reg;
    end
    S3: begin
      BPE_coef_reg = phase ? (counter_1_prv[5]) ? ((counter_1_prv[4]) ? {8{coef_sram_dout_ntt[127:112]}} : {8{coef_sram_dout_ntt[111:96]}}) : 
                                      ((counter_1_prv[4]) ? {8{coef_sram_dout_ntt[95:80]}} : {8{coef_sram_dout_ntt[79:64]}}) : BPE_coef_reg;
    end
    S4: begin
      BPE_coef_reg = phase ? (counter_1_prv[5]) ? ((counter_1_prv[4]) ? ((counter_1_prv[3]) ? {8{coef_sram_dout_ntt[127:112]}} : {8{coef_sram_dout_ntt[111:96]}}) :
                                                            ((counter_1_prv[3]) ? {8{coef_sram_dout_ntt[95:80]}} : {8{coef_sram_dout_ntt[79:64]}}))   :
                                      ((counter_1_prv[4]) ? ((counter_1_prv[3]) ? {8{coef_sram_dout_ntt[63:48]}} : {8{coef_sram_dout_ntt[47:32]}}) :
                                                            ((counter_1_prv[3]) ? {8{coef_sram_dout_ntt[31:16]}} : {8{coef_sram_dout_ntt[15:0]}})) : BPE_coef_reg; 
    end                                                
    S5: begin
      BPE_coef_reg = phase ? ((counter_1_prv[4]) ? ((counter_1_prv[3]) ? ((counter_1_prv[2]) ? {8{coef_sram_dout_ntt[127:112]}} : {8{coef_sram_dout_ntt[111:96]}}) :
                                                                ((counter_1_prv[2]) ? {8{coef_sram_dout_ntt[95:80]}}   : {8{coef_sram_dout_ntt[79:64]}}))   :
                                          ((counter_1_prv[3]) ? ((counter_1_prv[2]) ? {8{coef_sram_dout_ntt[63:48]}}   : {8{coef_sram_dout_ntt[47:32]}}) :
                                                                ((counter_1_prv[2]) ? {8{coef_sram_dout_ntt[31:16]}}   : {8{coef_sram_dout_ntt[15:0]}}))) : BPE_coef_reg;   
    end
    S6: begin
      BPE_coef_reg = phase ?(counter_1_prv[3]) ? ((counter_1_prv[2]) ? ((counter_1_prv[1]) ? {8{coef_sram_dout_ntt[127:112]}} : {8{coef_sram_dout_ntt[111:96]}}) :
                                                            ((counter_1_prv[1]) ? {8{coef_sram_dout_ntt[95:80]}} : {8{coef_sram_dout_ntt[79:64]}}))   :
                                      ((counter_1_prv[2]) ? ((counter_1_prv[1]) ? {8{coef_sram_dout_ntt[63:48]}} : {8{coef_sram_dout_ntt[47:32]}}) :
                                                            ((counter_1_prv[1]) ? {8{coef_sram_dout_ntt[31:16]}} : {8{coef_sram_dout_ntt[15:0]}})) : BPE_coef_reg; 
    end
    S7: begin
      BPE_coef_reg = phase ?(counter_1_prv[2]) ? ((counter_1_prv[1]) ? ((counter_1_prv[0]) ? {8{coef_sram_dout_ntt[127:112]}} : {8{coef_sram_dout_ntt[111:96]}}) :
                                                                       ((counter_1_prv[0]) ? {8{coef_sram_dout_ntt[95:80]}} : {8{coef_sram_dout_ntt[79:64]}}))   :
                                                 ((counter_1_prv[1]) ? ((counter_1_prv[0]) ? {8{coef_sram_dout_ntt[63:48]}} : {8{coef_sram_dout_ntt[47:32]}}) :
                                                                       ((counter_1_prv[0]) ? {8{coef_sram_dout_ntt[31:16]}} : {8{coef_sram_dout_ntt[15:0]}})) : BPE_coef_reg; 
    end
    S8: begin
      BPE_coef_reg = phase ? (counter_1_prv[1] ? (counter_1_prv[0] ? {{4{coef_sram_dout_ntt[127:112]}}, {4{coef_sram_dout_ntt[111:96]}}}: 
                                                                     {{4{coef_sram_dout_ntt[95:80]}}, {4{coef_sram_dout_ntt[79:64]}}}): 
                                                 (counter_1_prv[0] ? {{4{coef_sram_dout_ntt[63:48]}}, {4{coef_sram_dout_ntt[47:32]}}} :
                                                                     {{4{coef_sram_dout_ntt[31:16]}}, {4{coef_sram_dout_ntt[15:0]}}})) : BPE_coef_reg;

    end
    S9: begin
     BPE_coef_reg = phase ? (counter_1_prv[0] ? {{2{coef_sram_dout_ntt[127:112]}}, {2{coef_sram_dout_ntt[111:96]}}, {2{coef_sram_dout_ntt[95:80]}}, {2{coef_sram_dout_ntt[79:64]}}} : 
                                                {{2{coef_sram_dout_ntt[63:48]}},  {2{coef_sram_dout_ntt[47:32]}},  {2{coef_sram_dout_ntt[31:16]}}, {2{coef_sram_dout_ntt[15:0]}}}) : BPE_coef_reg;


    end
    S10: begin
     BPE_coef_reg = phase ?  coef_sram_dout_ntt : BPE_coef_reg;


    end
    default: begin
      //BPE_coef = 0;
      BPE_coef_reg = 0;
    end    
  endcase
end



//================================ sram_512_12 ===================================//
//data_ram_addr
always @(*) begin
  case (stage)
    NTM: begin // 1: BPE_input  2: BPE_output
      data_ram_addr_1 = (mode[1]) ? {11'b0, 4'b0000, counter_1[6:0]} : 0;
      data_ram_addr_2 = (mode[1]) ? {11'b0, 4'b0000, counter_2[6:0]} : 0;
    end
    S1: begin // 1: BPE_output  2: BPE_input
      data_ram_addr_1 = (mode[1]) ? {4'b0, counter_2[5], 1'b1, counter_2[4:0], 4'b0, counter_2[5], 1'b0, counter_2[4:0]} : 0;
      data_ram_addr_2 = (mode[1]) ? {5'b0, counter_1[5:0], 5'b00001, counter_1_prv[5:0]} : 0; 
    end
    S2: begin // 1: BPE_input  2: BPE_output
      data_ram_addr_1 = (mode[1]) ? {5'b0, counter_1[5:0], 5'b00001, counter_1_prv[5:0]} : {3'b0, counter_1[7:0], 3'b001, counter_1_prv[7:0]};
      data_ram_addr_2 = (mode[1]) ? {4'b0, counter_2[5], 1'b1, counter_2[4:0], 4'b0, counter_2[5], 1'b0, counter_2[4:0]} : 
                                    {3'b001, counter_2[7:0], 3'b0, counter_2[7:0]}; 
    end
    S3: begin // 1: BPE_output 2: BPE_input
      data_ram_addr_1 = (mode[1]) ? {4'b0 ,counter_2[5:4], 1'b1, counter_2[3:0], 4'b0 ,counter_2[5:4], 1'b0, counter_2[3:0]} : 
                                    {2'b0, counter_2[7], 1'b1, counter_2[6:0], 2'b0, counter_2[7], 1'b0, counter_2[6:0]};
      data_ram_addr_2 = (mode[1]) ? {4'b0 ,counter_1[5:4], 1'b0, counter_1[3:0], 4'b0 ,counter_1_prv[5:4], 1'b1, counter_1_prv[3:0]} :
                                    {2'b0, counter_1[7], 1'b0, counter_1[6:0], 2'b0, counter_1_prv[7], 1'b1, counter_1_prv[6:0]};
    end
    S4: begin // 1: BPE_input  2: BPE_output 
      data_ram_addr_1 = (mode[1]) ?  {4'b0, counter_1[5:3], 1'b0, counter_1[2:0], 4'b0, counter_1_prv[5:3], 1'b1, counter_1_prv[2:0]} :
                                     {2'b0, counter_1[7:6], 1'b0, counter_1[5:0], 2'b0, counter_1_prv[7:6], 1'b1, counter_1_prv[5:0]};
      data_ram_addr_2 = (mode[1]) ?  {4'b0, counter_2[5:3], 1'b1, counter_2[2:0], 4'b0, counter_2[5:3], 1'b0, counter_2[2:0]} :
                                     {2'b0, counter_2[7:6], 1'b1, counter_2[5:0], 2'b0, counter_2[7:6], 1'b0, counter_2[5:0]};
    end
    S5: begin // 1: BPE_output  2: BPE_input
      data_ram_addr_1 = (mode[1]) ? {4'b0, counter_2[5:2], 1'b1, counter_2[1:0], 4'b0, counter_2[5:2], 1'b0, counter_2[1:0]} :
                                    {2'b0, counter_2[7:5], 1'b1, counter_2[4:0], 2'b0, counter_2[7:5], 1'b0, counter_2[4:0]};
      data_ram_addr_2 = (mode[1]) ? {4'b0, counter_1[5:2], 1'b0, counter_1[1:0], 4'b0, counter_1_prv[5:2], 1'b1, counter_1_prv[1:0]} :
                                    {2'b0, counter_1[7:5], 1'b0, counter_1[4:0], 2'b0, counter_1_prv[7:5], 1'b1, counter_1_prv[4:0]};
    end
    S6: begin // 1: BPE_input  2: BPE_output 
      data_ram_addr_1 = (mode[1]) ?  {4'b0, counter_1[5:1], 1'b0, counter_1[0], 4'b0, counter_1_prv[5:1], 1'b1, counter_1_prv[0]} :
                                     {2'b0, counter_1[7:4], 1'b0, counter_1[3:0], 2'b0, counter_1_prv[7:4], 1'b1, counter_1_prv[3:0]};
      data_ram_addr_2 = (mode[1]) ?  {4'b0, counter_2[5:1], 1'b1, counter_2[0], 4'b0, counter_2[5:1], 1'b0, counter_2[0]} :
                                     {2'b0, counter_2[7:4], 1'b1, counter_2[3:0], 2'b0, counter_2[7:4], 1'b0, counter_2[3:0]};
    end 
    S7: begin // 1: BPE_output  2: BPE_input
      data_ram_addr_1 = (mode[1]) ? {4'b0, counter_2[5:0], 1'b1, 4'b0, counter_2[5:0], 1'b0} :
                                    {2'b0, counter_2[7:3], 1'b1, counter_2[2:0], 2'b0, counter_2[7:3], 1'b0, counter_2[2:0]};
      data_ram_addr_2 = (mode[1]) ? {4'b0, counter_1[5:0], 1'b0, 4'b0, counter_1_prv[5:0], 1'b1} :
                                    {2'b0, counter_1[7:3], 1'b0, counter_1[2:0], 2'b0, counter_1_prv[7:3], 1'b1, counter_1_prv[2:0]};
    end
    S8: begin // 1: BPE_input  2: BPE_output
      data_ram_addr_1 = (mode[1]) ? {{4'b0, counter_1[5:0], 1'b1}, {4'b0, counter_1[5:0], 1'b0}} :
                                    {2'b0, counter_1[7:2], 1'b0, counter_1[1:0], 2'b0, counter_1_prv[7:2], 1'b1, counter_1_prv[1:0]};

      data_ram_addr_2 = (mode[1]) ? {{4'b0, counter_2[5:0], 1'b1}, {4'b0, counter_2[5:0], 1'b0}} :
                                    {2'b0, counter_2[7:2], 1'b1, counter_2[1:0], 2'b0, counter_2[7:2], 1'b0, counter_2[1:0]};
    end
    S9: begin // 1: BPE_output  2: BPE_input
      data_ram_addr_1 = (mode[1]) ? {{4'b0, counter_2[5:0], 1'b1}, {4'b0, counter_2[5:0], 1'b0}}:
                                    {2'b0, counter_2[7:1], 1'b1, counter_2[0], 2'b0, counter_2[7:1], 1'b0, counter_2[0]};
      data_ram_addr_2 = (mode[1]) ? {{4'b0, counter_1[5:0], 1'b1}, {4'b0, counter_1[5:0], 1'b0}} :
                                    {2'b0, counter_1[7:1], 1'b0, counter_1[0], 2'b0, counter_1_prv[7:1], 1'b1, counter_1_prv[0]};
    end
    S10: begin // 1: BPE_input  2: BPE_output
      data_ram_addr_1 = (mode[1]) ? {{4'b0, counter_1[5:0], 1'b1}, {4'b0, counter_1[5:0], 1'b0}}:
                                    {2'b0, counter_1[7:0], 1'b0, 2'b0, counter_1_prv[7:0], 1'b1};
      data_ram_addr_2 = (mode[1]) ? {{4'b0, counter_2[5:0], 1'b1}, {4'b0, counter_2[5:0], 1'b0}} :
                                    {2'b0, counter_2[7:0], 1'b1, 2'b0, counter_2[7:0], 1'b0};
    end
    MTN:begin // 1: BPE_output  2: BPE_input
      data_ram_addr_1 = (mode[1]) ? {11'b0, 4'b0000, counter_2[6:0]} : 0;
      data_ram_addr_2 = (mode[1]) ? {11'b0, 4'b0000, counter_1[6:0]} : 0;
    end
    default: begin
      data_ram_addr_1 = 0;
      data_ram_addr_2 = 0;
    end
  endcase
end

//================================data reorder===================================//


//================================ coef_ram ===================================//

//coef_en
assign coef_sram_en_512 = ~mode[1];
assign coef_sram_en_ntt = mode[1] & ~mode[0];
assign coef_sram_en_intt = mode[1] & mode[0];

//coef_WE
assign coef_WE_512 = 0;
assign coef_WE_ntt = 0;
assign coef_WE_intt = 0;

//coef_din
assign coef_sram_din_512 = 0;
assign coef_sram_din_ntt = 0;
assign coef_sram_din_intt = 0;


bit_reverse #(.WIDTH(8)) b8 (.din(counter_1[7:0]),  .dout(out8));
bit_reverse #(.WIDTH(7)) b7 (.din(counter_1[6:0]),  .dout(out7));
bit_reverse #(.WIDTH(6)) b6 (.din(counter_1[5:0]),  .dout(out6));
bit_reverse #(.WIDTH(5)) b5 (.din(counter_1[4:0]),  .dout(out5));
bit_reverse #(.WIDTH(4)) b4 (.din(counter_1[3:0]),  .dout(out4));
bit_reverse #(.WIDTH(3)) b3 (.din(counter_1[2:0]),  .dout(out3));
bit_reverse #(.WIDTH(2)) b2 (.din(counter_1[1:0]),  .dout(out2));
bit_reverse #(.WIDTH(1)) b1 (.din(counter_1[0]),  .dout(out1));



endmodule

module bit_reverse #(
    parameter WIDTH = 8
)(
    input  [WIDTH - 1:0] din,
    output [WIDTH - 1:0] dout
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : reverse_bits
            assign dout[i] = din[WIDTH - 1 - i];
        end
    endgenerate
endmodule