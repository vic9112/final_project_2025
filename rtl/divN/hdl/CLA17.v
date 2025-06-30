//----- 16bit sign addition-----//
// to do 16bit sign addition, we need 17 bit to add sign bit //
module CLA17 (
    input clk,
    input rst_n,
    input  wire Cin,
    input  wire [16:0]  A,
    input  wire [16:0]  B,
    input               in_valid,
    output reg          out_valid,
    output wire [17:0]  result
);

localparam pCLA8_WIDTH = 8;
localparam one = 1'b1;
localparam zero = 1'b0;



//----- stage 0 -----//
reg [(pCLA8_WIDTH*2):0]     stage0_in_A;
reg [(pCLA8_WIDTH*2):0]     stage0_in_B;
reg                         stage0_Cin;
reg                         stage0_invalid;
wire [(pCLA8_WIDTH-1):0]    in_A[1:0];
wire [(pCLA8_WIDTH-1):0]    in_B[1:0];
wire [(pCLA8_WIDTH):0]      stage0_result[2:0];   
wire [1:0]                  stage0_fa_r[1:0];
//----- stage 0 -----//
//----- stage 1 -----//
reg  [(pCLA8_WIDTH):0]      stage1_in[2:0];
reg  [1:0]                  stage1_in_fa[1:0];
wire [(pCLA8_WIDTH):0]      stage1_result[1:0];
wire [1:0]                  stage1_result_fa;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stage0_Cin <= 0;
        stage0_in_A <= {(pCLA8_WIDTH*2+1){1'b0}};
        stage0_in_B <= {(pCLA8_WIDTH*2+1){1'b0}};
        stage0_invalid <= 0;
    end else begin
        stage0_Cin <= Cin;
        stage0_in_A <= A;
        stage0_in_B <= B;
        stage0_invalid <= in_valid;
    end
end

assign in_A[0] = stage0_in_A[(pCLA8_WIDTH-1):0];
assign in_A[1] = stage0_in_A[(pCLA8_WIDTH*2-1):(pCLA8_WIDTH)];
assign in_B[0] = stage0_in_B[(pCLA8_WIDTH-1):0];
assign in_B[1] = stage0_in_B[(pCLA8_WIDTH*2-1):(pCLA8_WIDTH)];

CLA_8 CLA1(.Cin(zero), .A(in_A[0]), .B(in_B[0]), .result(stage0_result[0]));

CLA_8 CLA2(.Cin(zero), .A(in_A[1]), .B(in_B[1]), .result(stage0_result[1]));
CLA_8 CLA3(.Cin(one) , .A(in_A[1]), .B(in_B[1]), .result(stage0_result[2]));

FA FA1(.A(stage0_in_A[(pCLA8_WIDTH*2)]), .B(stage0_in_B[(pCLA8_WIDTH*2)]), .Cin(zero), .Cout(stage0_fa_r[0][1]), .Sum(stage0_fa_r[0][0]));
FA FA2(.A(stage0_in_A[(pCLA8_WIDTH*2)]), .B(stage0_in_B[(pCLA8_WIDTH*2)]), .Cin(one), .Cout(stage0_fa_r[1][1]), .Sum(stage0_fa_r[1][0]));

integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        for (i=0; i<3; i=i+1) begin
            stage1_in[i] <= {(pCLA8_WIDTH+1){1'b0}};
        end
        for (i=0; i<2; i=i+1) begin
          stage1_in_fa[i] <= {2'b0};
        end
    end else begin
        out_valid <= stage0_invalid;
        for (i=0; i<3; i=i+1) begin
            stage1_in[i] <= stage0_result[i];
        end
        for (i=0; i<2; i=i+1) begin
          stage1_in_fa[i] <= stage0_fa_r[i];
        end
    end
end

assign stage1_result[0] = stage1_in[0][(pCLA8_WIDTH):0];
assign stage1_result[1] = (stage1_result[0][(pCLA8_WIDTH)] == 1'b0)? stage1_in[1][(pCLA8_WIDTH):0]:stage1_in[2][(pCLA8_WIDTH):0];
assign stage1_result_fa = (stage1_result[1][(pCLA8_WIDTH)] == 1'b0)? stage1_in_fa[0]:stage1_in_fa[1];
assign result = {stage1_result_fa, stage1_result[1][(pCLA8_WIDTH-1):0], stage1_result[0][(pCLA8_WIDTH-1):0]};

endmodule //CLA17


module FA  (
    input  wire A,    
    input  wire B,     
    input  wire Cin,   
    output wire Sum,  
    output wire Cout   
);
    assign {Cout ,Sum } = A + B + Cin;
endmodule