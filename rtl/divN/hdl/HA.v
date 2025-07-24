module HA  (
    input  wire A,    
    input  wire B,        
    output wire Sum,  
    output wire Cout   
);
    assign {Cout ,Sum } = A + B ;
endmodule
