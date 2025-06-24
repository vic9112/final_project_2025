// `include "CLA_8.v"
/////////////////////////////////
//        ADDER 53 bit        //
/////////////////////////////////
    module add_53 (
        input [52:0] in_A,
        input [52:0] in_B,
        output[52:0] result
    );
    wire[55:0]     result_expand;
    wire[55:0]     in_A_expand;
    wire[55:0]     in_B_expand;
    wire[7:0]       part_A[0:6];
    wire[7:0]       part_B[0:6];
    wire[8:0]       result_predict_zero[0:6];
    wire[8:0]       result_predict_one [0:6];
    wire            logic_one;
    wire            logic_zero;
    wire[8:0]       r[0:6];            

    assign logic_one   = 1'b1;
    assign logic_zero  = 1'b0;
    assign in_A_expand = {4'd0 ,in_A};
    assign in_B_expand = {4'd0 ,in_B};

    genvar i;
    generate
        for(i=0 ; i<7 ; i=i+1)begin : GEN_PART
            assign part_A[i] = in_A_expand[(8*i+7):(8*i)] ;
            assign part_B[i] = in_B_expand[(8*i+7):(8*i)] ;
        end
    endgenerate
        
        CLA_8 CLA8_zero(
            .Cin(logic_zero),
            .A( part_A[0] ),
            .B( part_B[0] ),
            .result(result_predict_zero[0])
        );

    genvar j;
    generate
        for(j=1 ; j<7 ; j=j+1)begin : GEN_CLA8
            CLA_8 CLA8_0(
                    .Cin(logic_zero),
                    .A( part_A[j] ),
                    .B( part_B[j] ),
                    .result(result_predict_zero[j])
            );
            CLA_8 CLA8_1(
                    .Cin(logic_one),
                    .A( part_A[j] ),
                    .B( part_B[j] ),
                    .result(result_predict_one[j])
            );
        end
    endgenerate


    assign r[0] = result_predict_zero[0];

    genvar k ;
    generate 
        for(k=1 ; k<7 ; k=k+1)begin : GEN_result
            assign r[k] = (r[k-1][8])? result_predict_one[k] : result_predict_zero[k];
        end
    endgenerate

    assign result_expand    = { r[6][7:0], r[5][7:0]  , r[4][7:0]  , r[3][7:0]  , r[2][7:0], r[1][7:0]  , r[0][7:0]  };
    assign result           = result_expand[52:0];

    endmodule
