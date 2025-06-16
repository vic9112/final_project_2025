module butterfly
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers represent real & imaginary part
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [1:0] mode, // FFT/iFFT/NTT/iNTT

    input   wire i_vld,
    output  wire i_rdy,
    
    output  wire o_vld,
    input   wire o_rdy,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    input   wire [(pDATA_WIDTH-1):0] gm, // constant
    output  wire [(pDATA_WIDTH-1):0] ao,
    output  wire [(pDATA_WIDTH-1):0] bo

);
    //only for FFT (we want a+bwn, a-bwn)
    //============================================================================//
    wire [(pDATA_WIDTH-1):0] bwn; //bwn = bi * omega(n)
    wire [63:0] bwn_r, bwn_i;
    wire [(pDATA_WIDTH-1):0] negative_bwn;
    wire [63:0] negative_bwn_r, negative_bwn_i;
    //============================================================================//
    assign bwn_r = bwn[127:64];
    assign bwn_i = bwn[63:0];

    assign negative_bwn_r = {~bwn_r[63], bwn_r[62:0]};
    assign negative_bwn_i = {~bwn_i[63], bwn_i[62:0]};
    assign negative_bwn = {negative_bwn_r,negative_bwn_i};

    //bwn
    cmul C1( 
        .num1(bi),//Xr(64bit) + jXi(64bit)
        .num2(gm),//Yr(64bit) + jYi(64bit)
        .clk(clk),
        .rstn(rstn),
        .result(bwn),
        .valid(),
        .ready()
    );

    //Re{a+bwn}
    fadd A1_r(
        .num1(ai[127:64]),
        .num2(bwn_r),
        .clk(clk),
        .rstn(rstn),
        .result(ao[127:64]),
        .valid(),
        .ready()
    );
    //Im{a+bwn}
    fadd A1_i(
        .num1(ai[63:0]),
        .num2(bwn_i),
        .clk(clk),
        .rstn(rstn),
        .result(ao[63:0]),
        .valid(),
        .ready()
    );

    //Re{a-bwn}
    fadd A2_r(
        .num1(ai[127:64]),
        .num2(negative_bwn_r),
        .clk(clk),
        .rstn(rstn),
        .result(bo[127:64]),
        .valid(),
        .ready()
    );
    //Im{a-bwn}
    fadd A2_i(
        .num1(ai[63:0]),
        .num2(negative_bwn_i),
        .clk(clk),
        .rstn(rstn),
        .result(bo[63:0]),
        .valid(),
        .ready()
    );



    // complex mul & add & sub for FFT/iFFT

    // Complex Multiplication:
    // y_re = (a_re * b_re) - (a_im * b_im)
    // y_im = (a_re * b_im) + (a_im * b_re)
    // Rewrite as:
    // y_re = a_re * (b_re - b_im) + b_im * (a_re - a_im)
    // y_im = a_im * (b_re + b_im) + b_im * (a_re - a_im)
    // It will reduce the mul usage from 4 to 3 since we reuse [b_im * (a_re - a_im)]

    // montgomery mul & add & sub for NTT/iNTT

endmodule

