
module kernel 
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers
)
(

    input  wire                     ld_vld,
    output wire                     ld_rdy,
    input  wire [(pDATA_WIDTH-1):0] ld_d,

    output wire                     sw_vld,
    input  wire                     sw_rdy,
    output wire [(pDATA_WIDTH-1):0] sw_d
);


    /*================================================================================================
    #                                       Address Generation                                       #
    ================================================================================================*/
    
    butterfly BPE1 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
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

    butterfly BPE2 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
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
        .mode  (),
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
        .mode  (),
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

    butterfly BPE5 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
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

endmodule

