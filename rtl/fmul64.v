module fmul64
#(  
    parameter pDATA_WIDTH = 64 // double-precision multiplication
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    output  wire [(pDATA_WIDTH-1):0] bo

);

endmodule

