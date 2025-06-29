module kernel_top
#(  
    parameter pDATA_WIDTH = 128 
)
(
    input  wire                     clk,
    input  wire                     clk_2x,     // for dataRAM (double-speed)
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

    output wire               [4:0] bpe_act,     // for bpe1 to bpe5 activate

    input  wire               [7:0] mode,        // iNTT(11)/NTT(10)/iFFT(01)/FFT(00)
    input  wire                     decode,
    output wire                     sw_lst       // set when handshake
);


// =============== mode constants =============== //
    localparam MODE_FFT  = 2'b00;
    localparam MODE_IFFT = 2'b01;
    localparam MODE_NTT  = 2'h10;
    localparam MODE_INTT = 2'h11;

// =============== mode selection =============== //
    reg [7:0] mode_state;
    wire use_ntt, use_fft;

// ================= BPE Wires ================= //
    // BPE1
    wire [127:0] BPE1_ain, BPE1_bin, BPE1_coef;
    wire [127:0] BPE1_aout, BPE1_bout;
    wire BPE1_i_vld, BPE1_i_rdy, BPE1_o_vld, BPE1_o_rdy;

    // BPE2
    wire [127:0] BPE2_ain, BPE2_bin, BPE2_coef;
    wire [127:0] BPE2_aout, BPE2_bout;
    wire BPE2_i_vld, BPE2_i_rdy, BPE2_o_vld, BPE2_o_rdy;

    // BPE3
    wire [127:0] BPE3_ain, BPE3_bin, BPE3_coef;
    wire [127:0] BPE3_aout, BPE3_bout;
    wire BPE3_i_vld, BPE3_i_rdy, BPE3_o_vld, BPE3_o_rdy;

    // BPE4
    wire [127:0] BPE4_ain, BPE4_bin, BPE4_coef;
    wire [127:0] BPE4_aout, BPE4_bout;
    wire BPE4_i_vld, BPE4_i_rdy, BPE4_o_vld, BPE4_o_rdy;

// ================= SRAM Wires ================= //
    // SRAM1 512x128
    wire [3:0]   WE_512;
    wire         sram_en_512;
    wire [127:0] sram_din_512, sram_dout_512;
    wire [8:0]   sram_addr_512;

    // SRAM2 128x128
    wire         WE_128;
    wire         sram_en_128;
    wire [127:0] sram_din_128, sram_dout_128;
    wire [6:0]   sram_addr_128;

    // SRAM3 32x128
    wire         WE_32;
    wire         sram_en_32;
    wire [127:0] sram_din_32, sram_dout_32;
    wire [4:0]   sram_addr_32;

// =============== I/O Between FFT / NTT =============== //
    wire ld_rdy_ntt, coef_rdy_ntt, sw_vld_ntt, sw_lst_ntt;
    wire ld_rdy_fft, coef_rdy_fft, sw_vld_fft, sw_lst_fft;
    wire [(pDATA_WIDTH-1):0] sw_dat_ntt, sw_dat_fft;
    wire [4:0] bpe_act_ntt, bpe_act_fft;

// =============== kernel mode control=============== //
    
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            mode_state <= 0;
        end else begin
            mode_state <= (decode) ? mode : mode_state;
        end
    end

    assign use_ntt = (mode_state == MODE_NTT) || (mode_state == MODE_INTT);
    assign use_fft = (mode_state == MODE_FFT) || (mode_state == MODE_IFFT);


// =============== Module Instantiation =============== //
    kernel_NTT NTT (
        .clk      (clk),
        .clk_2x   (clk_2x),
        .rstn     (rstn),
        .ld_vld   (ld_vld & use_ntt),
        .ld_rdy   (ld_rdy_ntt),
        .ld_dat   (ld_dat),
        .sw_vld   (sw_vld_ntt),
        .sw_rdy   (sw_rdy),
        .sw_dat   (sw_dat_ntt),
        .coef_vld (coef_vld & use_ntt),
        .coef_rdy (coef_rdy_ntt),
        .coef_dat (coef_dat),
        .bpe_act  (bpe_act_ntt),
        .mode     (mode_state),
        .decode   (decode),
        .sw_lst   (sw_lst_ntt),
        .BPE1_ain  (BPE1_ain),
        .BPE1_bin  (BPE1_bin),
        .BPE1_coef (BPE1_coef),
        .BPE1_aout (BPE1_aout),
        .BPE1_bout (BPE1_bout),
        .BPE1_i_vld(BPE1_i_vld),
        .BPE1_i_rdy(BPE1_i_rdy),
        .BPE1_o_vld(BPE1_o_vld),
        .BPE1_o_rdy(BPE1_o_rdy),
        .BPE2_ain  (BPE2_ain),
        .BPE2_bin  (BPE2_bin),
        .BPE2_coef (BPE2_coef),
        .BPE2_aout (BPE2_aout),
        .BPE2_bout (BPE2_bout),
        .BPE2_i_vld(BPE2_i_vld),
        .BPE2_i_rdy(BPE2_i_rdy),
        .BPE2_o_vld(BPE2_o_vld),
        .BPE2_o_rdy(BPE2_o_rdy),
        .BPE3_ain  (BPE3_ain),
        .BPE3_bin  (BPE3_bin),
        .BPE3_coef (BPE3_coef),
        .BPE3_aout (BPE3_aout),
        .BPE3_bout (BPE3_bout),
        .BPE3_i_vld(BPE3_i_vld),
        .BPE3_i_rdy(BPE3_i_rdy),
        .BPE3_o_vld(BPE3_o_vld),
        .BPE3_o_rdy(BPE3_o_rdy),
        .BPE4_ain  (BPE4_ain),
        .BPE4_bin  (BPE4_bin),
        .BPE4_coef (BPE4_coef),
        .BPE4_aout (BPE4_aout),
        .BPE4_bout (BPE4_bout),
        .BPE4_i_vld(BPE4_i_vld),
        .BPE4_i_rdy(BPE4_i_rdy),
        .BPE4_o_vld(BPE4_o_vld),
        .BPE4_o_rdy(BPE4_o_rdy),
        .WE_512(WE_512),
        .sram_en_512(sram_en_512),
        .sram_din_512(sram_din_512),
        .sram_dout_512(sram_dout_512),
        .sram_addr_512(sram_addr_512),
        .WE_128(WE_128),
        .sram_en_128(sram_en_128),
        .sram_din_128(sram_din_128),
        .sram_dout_128(sram_dout_128),
        .sram_addr_128(sram_addr_128),
        .WE_32(WE_32),
        .sram_en_32(sram_en_32),
        .sram_din_32(sram_din_32),
        .sram_dout_32(sram_dout_32),
        .sram_addr_32(sram_addr_32)
    );

    kernel_FFT FFT (
        .clk      (clk),
        .clk_2x   (clk_2x),
        .rstn     (rstn),
        .ld_vld   (ld_vld & use_fft),
        .ld_rdy   (ld_rdy_fft),
        .ld_dat   (ld_dat),
        .sw_vld   (sw_vld_fft),
        .sw_rdy   (sw_rdy),
        .sw_dat   (sw_dat_fft),
        .coef_vld (coef_vld & use_fft),
        .coef_rdy (coef_rdy_fft),
        .coef_dat (coef_dat),
        .bpe_act  (bpe_act_fft),
        .mode     (mode_state),
        .decode   (decode),
        .sw_lst   (sw_lst_fft),
        .BPE1_ain  (BPE1_ain),
        .BPE1_bin  (BPE1_bin),
        .BPE1_coef (BPE1_coef),
        .BPE1_aout (BPE1_aout),
        .BPE1_bout (BPE1_bout),
        .BPE1_i_vld(BPE1_i_vld),
        .BPE1_i_rdy(BPE1_i_rdy),
        .BPE1_o_vld(BPE1_o_vld),
        .BPE1_o_rdy(BPE1_o_rdy),
        .BPE2_ain  (BPE2_ain),
        .BPE2_bin  (BPE2_bin),
        .BPE2_coef (BPE2_coef),
        .BPE2_aout (BPE2_aout),
        .BPE2_bout (BPE2_bout),
        .BPE2_i_vld(BPE2_i_vld),
        .BPE2_i_rdy(BPE2_i_rdy),
        .BPE2_o_vld(BPE2_o_vld),
        .BPE2_o_rdy(BPE2_o_rdy),
        .BPE3_ain  (BPE3_ain),
        .BPE3_bin  (BPE3_bin),
        .BPE3_coef (BPE3_coef),
        .BPE3_aout (BPE3_aout),
        .BPE3_bout (BPE3_bout),
        .BPE3_i_vld(BPE3_i_vld),
        .BPE3_i_rdy(BPE3_i_rdy),
        .BPE3_o_vld(BPE3_o_vld),
        .BPE3_o_rdy(BPE3_o_rdy),
        .BPE4_ain  (BPE4_ain),
        .BPE4_bin  (BPE4_bin),
        .BPE4_coef (BPE4_coef),
        .BPE4_aout (BPE4_aout),
        .BPE4_bout (BPE4_bout),
        .BPE4_i_vld(BPE4_i_vld),
        .BPE4_i_rdy(BPE4_i_rdy),
        .BPE4_o_vld(BPE4_o_vld),
        .BPE4_o_rdy(BPE4_o_rdy),
        .WE_512(WE_512),
        .sram_en_512(sram_en_512),
        .sram_din_512(sram_din_512),
        .sram_dout_512(sram_dout_512),
        .sram_addr_512(sram_addr_512),
        .WE_128(WE_128),
        .sram_en_128(sram_en_128),
        .sram_din_128(sram_din_128),
        .sram_dout_128(sram_dout_128),
        .sram_addr_128(sram_addr_128),
        .WE_32(WE_32),
        .sram_en_32(sram_en_32),
        .sram_din_32(sram_din_32),
        .sram_dout_32(sram_dout_32),
        .sram_addr_32(sram_addr_32),
    );

// =============== BPE Instance =============== //
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


// =============== SRAM Instance =============== //
    bram512x128 SRAM1 (
        .CLK(clk_2x),
        .WE(WE_512),
        .EN(sram_en_512),
        .Di(sram_din_512),
        .Do(sram_dout_512),
        .A(sram_addr_512)
    );

    bram128x128 SRAM2 (
        .CLK(clk_2x),
        .WE(WE_128),
        .EN(sram_en_128),
        .Di(sram_din_128),
        .Do(sram_dout_128),
        .A(sram_addr_128)
    );

    bram32x128 SRAM3 (
        .CLK(clk_2x),
        .WE(WE_32),
        .EN(sram_en_32),
        .Di(sram_din_32),
        .Do(sram_dout_32),
        .A(sram_addr_32)
    );


// =============== mux =============== //
    assign ld_rdy   = use_ntt ? ld_rdy_ntt   : use_fft ? ld_rdy_fft   : 1'b0;
    assign coef_rdy = use_ntt ? coef_rdy_ntt : use_fft ? coef_rdy_fft : 1'b0;
    assign sw_vld   = use_ntt ? sw_vld_ntt   : use_fft ? sw_vld_fft   : 1'b0;
    assign sw_dat   = use_ntt ? sw_dat_ntt   : use_fft ? sw_dat_fft   : {pDATA_WIDTH{1'b0}};
    assign sw_lst   = use_ntt ? sw_lst_ntt   : use_fft ? sw_lst_fft   : 1'b0;
    assign bpe_act  = use_ntt ? bpe_act_ntt  : use_fft ? bpe_act_fft  : 5'd0;
endmodule