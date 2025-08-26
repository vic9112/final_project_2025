module mul_16 (      
    in_a,
    in_b,
    in_valid,
    out_valid,
    result,
    clk,
    rst_n
);
    localparam pDATA_WIDTH = 16;
    localparam zero = 0;
//=============================================================================== I/O pin ===========================================================================================//    
    input [15:0]                            in_a;
    input [15:0]                            in_b;
    input                                   in_valid;
    input                                   clk;
    input                                   rst_n;
    output                                  out_valid;
    output[31:0]                            result;

wire [31:0] mul_ab ;
reg  [31:0] pip1_result ;
reg         pip1_v      ;

assign mul_ab = in_a*in_b ;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip1_result <= 32'd0   ;
        pip1_v      <= 1'b0    ;
    end else begin
        pip1_result <= mul_ab   ;
        pip1_v      <= in_valid ;    
    end
end

assign out_valid = pip1_v     ;
assign result    = pip1_result ;

endmodule