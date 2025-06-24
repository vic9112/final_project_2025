// `include "CLA_8.v"
/////////////////////////////////
//        ADDER 107 bit        //
/////////////////////////////////
    module add_107 (
        input [106:0] in_A,
        input [106:0] in_B,
        output[106:0] result
    );
    wire[111:0]     result_expand;
    wire[111:0]     in_A_expand;
    wire[111:0]     in_B_expand;
    wire[7:0]       part_A[0:13];
    wire[7:0]       part_B[0:13];
    wire[8:0]       result_predict_zero[0:13];
    wire[8:0]       result_predict_one [0:13];
    wire            logic_one;
    wire            logic_zero;
    wire[8:0]       r[0:13];            

    assign logic_one   = 1'b1;
    assign logic_zero  = 1'b0;
    assign in_A_expand = {5'd0 ,in_A};
    assign in_B_expand = {5'd0 ,in_B};

    genvar i;
    generate
        for(i=0 ; i<14 ; i=i+1)begin : GEN_PART
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
        for(j=1 ; j<14 ; j=j+1)begin : GEN_CLA8
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
        for(k=1 ; k<14 ; k=k+1)begin : GEN_result
            assign r[k] = (r[k-1][8])? result_predict_one[k] : result_predict_zero[k];
        end
    endgenerate

    assign result_expand    = {r[13][7:0] , r[12][7:0] , r[11][7:0] , r[10][7:0],
                            r[9][7:0]  , r[8][7:0]  , r[7][7:0]  , r[6][7:0],
                            r[5][7:0]  , r[4][7:0]  , r[3][7:0]  , r[2][7:0],
                            r[1][7:0]  , r[0][7:0]  };
    assign result           = result_expand[106:0];

    endmodule
