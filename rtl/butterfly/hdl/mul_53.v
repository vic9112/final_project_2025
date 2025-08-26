module mul_53#(
    parameter pDATA_WIDTH = 53 
)
(      
    input [(pDATA_WIDTH-1)   : 0]   in_A,
    input [(pDATA_WIDTH-1)   : 0]   in_B,
    input                           in_valid ,
    output                          out_valid  ,
    output[(pDATA_WIDTH*2-1) : 0]   result,
    input                           clk,
    input                           rst_n
);


wire [(pDATA_WIDTH*2-1)      :0]    mul_result  ;
reg  [(pDATA_WIDTH*2-1)      :0]    pip1_result ;
reg                                 pip1_v      ;


assign mul_result = in_A*in_B ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
            pip1_v      <= 1'b0 ;
            pip1_result <= {(pDATA_WIDTH*2){1'b0}} ;
    end else begin
            pip1_v      <= in_valid   ;
            pip1_result <= mul_result ;
    end
end

assign out_valid    = pip1_v        ;
assign result       = pip1_result   ;

endmodule