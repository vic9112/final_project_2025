// `include "CLA_8.v"
// `include "FA.v"
// `include "HA.v"

`timescale 1ns/1ps
// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : mul_16 、 FA 、HA 、CLA_8
// Author : Hsuan Jung,Lo
// Create Date: 5/2025
// Features & Functions:
// . To do 16bit multiplication.(use 4 cycles)
// .
// ============================================================================================================================================================================
// Revision History:
// Date         by      Version     Change Description
//  
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//==================================================================================================================================================================================
//
// * Asserted in_valid high to feed valid data ,and return valid result with out_valid
//
// * Waveform：    
//      clk       >|      |      |      |      |      |      |      |
//      in_valid  >________/-------------\______________________________
//      in_a      >|  xx  |  a0  |  a1  |             xx
//      in_b      >|  xx  |  b0  |  b1  |             xx
//      out_valid >___________________________________/--------------\__
//      result    >|             xx                   |  r0  |  r1  |  xx
//
//===================================================================================================================================================================================

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
//============================================================================ Wallace tree adder ====================================================================================//
    reg [(pDATA_WIDTH-1) : 0]   product[0 : (pDATA_WIDTH-1)] ;
    wire[10:0]                  wallace_lv1[0 : (pDATA_WIDTH*2-2)];
    wire[7:0]                   wallace_lv2[0 : (pDATA_WIDTH*2-1)];
    wire[5:0]                   wallace_lv3[0 : (pDATA_WIDTH*2-1)];
    wire[3:0]                   wallace_lv4[0 : (pDATA_WIDTH*2)];
    wire[2:0]                   wallace_lv5[0 : (pDATA_WIDTH*2)];
    wire[1:0]                   wallace_lv6[0 : (pDATA_WIDTH*2 + 1)];
//========================================================================== CLA process after wallace tree ==========================================================================//
    wire[33:0]                  last_lv_A;
    wire[33:0]                  last_lv_B;
    wire                        logic_one;
    wire                        logic_zero;
    wire[8:0]                   result_15_7;
    wire[8:0]                   result_23_15_one;
    wire[8:0]                   result_23_15_zero;
    wire[8:0]                   result_31_23_one;
    wire[8:0]                   result_31_23_zero;
    wire[1:0]                   result_32_31_zero ;
    wire[1:0]                   result_32_31_one ; 

    wire[6:0]                   r0;
    wire[8:0]                   r1;
    wire[8:0]                   r2;
    wire[8:0]                   r3;
    wire[1:0]                   r4;
//======================================================================= Pipeline stag1 =============================================================================================//
    reg                         stage_1_0;
    reg                         stage_1_1;
    reg                         stage_1_2;
    reg [1:0]                   stage_1_3;
    reg [1:0]                   stage_1_4;
    reg [2:0]                   stage_1_5;
    reg [2:0]                   stage_1_6;
    reg [3:0]                   stage_1_7;
    reg [3:0]                   stage_1_8;
    reg [4:0]                   stage_1_9;
    reg [4:0]                   stage_1_10;
    reg [4:0]                   stage_1_11;
    reg [5:0]                   stage_1_12;
    reg [5:0]                   stage_1_13;
    reg [6:0]                   stage_1_14;
    reg [6:0]                   stage_1_15;
    reg [7:0]                   stage_1_16;
    reg [6:0]                   stage_1_17;
    reg [6:0]                   stage_1_18;
    reg [5:0]                   stage_1_19;
    reg [5:0]                   stage_1_20;
    reg [5:0]                   stage_1_21;
    reg [4:0]                   stage_1_22;
    reg [3:0]                   stage_1_23;
    reg [3:0]                   stage_1_24;
    reg [3:0]                   stage_1_25;
    reg [2:0]                   stage_1_26;
    reg [2:0]                   stage_1_27;
    reg [1:0]                   stage_1_28;
    reg [1:0]                   stage_1_29;
    reg [1:0]                   stage_1_30;
    reg                         stage_1_31;
    reg                         stage_1_v;
    wire[7:0]                   stage_1_array[0:(pDATA_WIDTH*2 - 1)];
//======================================================================= Pipeline stage2 =============================================================================================//
    reg                         stage_2_0;
    reg                         stage_2_1;
    reg                         stage_2_2;
    reg                         stage_2_3;
    reg                         stage_2_4;
    reg [1:0]                   stage_2_5;
    reg [1:0]                   stage_2_6;
    reg [1:0]                   stage_2_7;
    reg [1:0]                   stage_2_8;
    reg [1:0]                   stage_2_9;
    reg [2:0]                   stage_2_10;
    reg [2:0]                   stage_2_11;
    reg [2:0]                   stage_2_12;
    reg [2:0]                   stage_2_13;
    reg [2:0]                   stage_2_14;
    reg [3:0]                   stage_2_15;
    reg [3:0]                   stage_2_16;
    reg [3:0]                   stage_2_17;
    reg [3:0]                   stage_2_18;
    reg [3:0]                   stage_2_19;
    reg [2:0]                   stage_2_20;
    reg [2:0]                   stage_2_21;
    reg [2:0]                   stage_2_22;
    reg [2:0]                   stage_2_23;
    reg [1:0]                   stage_2_24;
    reg [1:0]                   stage_2_25;
    reg [1:0]                   stage_2_26;
    reg [1:0]                   stage_2_27;
    reg [1:0]                   stage_2_28;
    reg [1:0]                   stage_2_29;
    reg [1:0]                   stage_2_30;
    reg [1:0]                   stage_2_31;
    reg                         stage_2_32;
    reg                         stage_2_v; 
    wire[3:0]                   stage_2_array[0 : (pDATA_WIDTH*2)];
//======================================================================= Pipeline stage3 =============================================================================================//
    reg                         stage_3_0 ;
    reg                         stage_3_1 ;
    reg                         stage_3_2 ;
    reg                         stage_3_3 ;
    reg                         stage_3_4 ;
    reg                         stage_3_5 ;
    reg                         stage_3_6 ;
    reg[1:0]                    stage_3_7 ;
    reg[1:0]                    stage_3_8 ;
    reg[1:0]                    stage_3_9 ;
    reg[1:0]                    stage_3_10 ;
    reg[1:0]                    stage_3_11 ;
    reg[1:0]                    stage_3_12 ;
    reg[1:0]                    stage_3_13 ;
    reg[1:0]                    stage_3_14 ;
    reg[1:0]                    stage_3_15 ;
    reg[1:0]                    stage_3_16 ;
    reg[1:0]                    stage_3_17 ;
    reg[1:0]                    stage_3_18 ;
    reg[1:0]                    stage_3_19 ;
    reg[1:0]                    stage_3_20 ;
    reg[1:0]                    stage_3_21 ;
    reg[1:0]                    stage_3_22 ;
    reg[1:0]                    stage_3_23 ;
    reg[1:0]                    stage_3_24 ;
    reg[1:0]                    stage_3_25 ;
    reg[1:0]                    stage_3_26 ;
    reg[1:0]                    stage_3_27 ;
    reg[1:0]                    stage_3_28 ;
    reg[1:0]                    stage_3_29 ;
    reg[1:0]                    stage_3_30 ;
    reg[1:0]                    stage_3_31 ;
    reg[1:0]                    stage_3_32 ;
    reg                         stage_3_33 ;
    reg                         stage_3_v;
//======================================================================= Pipeline stage4 =============================================================================================//
    reg [6:0]                   stage_4_0      ;
    reg [8:0]                   stage_4_1      ;
    reg [8:0]                   stage_4_2_zero ;
    reg [8:0]                   stage_4_2_one  ;
    reg [8:0]                   stage_4_3_zero ;
    reg [8:0]                   stage_4_3_one  ;
    reg [1:0]                   stage_4_4_zero ;
    reg [1:0]                   stage_4_4_one  ;
    reg                         stage_4_v;



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                        Partial product                                                                                           //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    integer i,j;
    always @(*) begin
        // i for localye of row (ex: product[0][j] as row 0)
        for(i=0 ; i<pDATA_WIDTH ; i=i+1)begin
            for(j=0 ; j<pDATA_WIDTH ; j=j+1)begin
                product[i][j] = (in_a[j] & in_b[i]) ;
            end
        end
    end
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                     LV1 of Wallace tree                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    genvar a ,b;
    generate
        for(a=0 ; a < 14 ; a=a+1)begin : gen_wallace_tree_lv1_FA_0
            // * generate rigth half of first level wallace tree 
            if(a > 10)begin : gen_wallace_lv1_00
                
                FA FA_lv1_00 (.A(product[0][a+2]) , .B(product[1][a+1] )  , .Cin(product[2][a] ) , .Cout( wallace_lv1[a+3][0] ) , .Sum( wallace_lv1[a+2][1] ));            
            
            end else if(a > 7) begin : gen_wallace_lv1_01
                
                FA FA_lv1_01 (.A(product[0][a+2]) , .B(product[1][a+1] )  , .Cin(product[2][a] ) , .Cout( wallace_lv1[a+3][0] ) , .Sum( wallace_lv1[a+2][1] ));
                FA FA_lv1_03 (.A(product[3][a+2]) , .B(product[4][a+1] )  , .Cin(product[5][a] ) , .Cout( wallace_lv1[a+6][2] ) , .Sum( wallace_lv1[a+5][3] ));
                
            end else if(a > 4)begin : gen_wallace_lv1_02
                
                FA FA_lv1_02 (.A(product[0][a+2]) , .B(product[1][a+1] )  , .Cin(product[2][a] ) , .Cout( wallace_lv1[a+3][0] ) , .Sum( wallace_lv1[a+2][1] ));
                FA FA_lv1_1 (.A(product[3][a+2]) , .B(product[4][a+1] )  , .Cin(product[5][a] ) , .Cout( wallace_lv1[a+6][2] ) , .Sum( wallace_lv1[a+5][3] ));
                FA FA_lv1_2 (.A(product[6][a+2]) , .B(product[7][a+1] )  , .Cin(product[8][a] ) , .Cout( wallace_lv1[a+9][4] ) , .Sum( wallace_lv1[a+8][5] ));

            end else if(a > 1)begin : gen_wallace_lv1_03
                
                FA FA_lv1_3 (.A(product[0][a+2]) , .B(product[1][a+1] )  , .Cin(product[2][a] ) , .Cout( wallace_lv1[a+3][0] ) , .Sum( wallace_lv1[a+2][1] ));
                FA FA_lv1_4 (.A(product[3][a+2]) , .B(product[4][a+1] )  , .Cin(product[5][a] ) , .Cout( wallace_lv1[a+6][2] ) , .Sum( wallace_lv1[a+5][3] ));
                FA FA_lv1_5 (.A(product[6][a+2]) , .B(product[7][a+1] )  , .Cin(product[8][a] ) , .Cout( wallace_lv1[a+9][4] ) , .Sum( wallace_lv1[a+8][5] ));
                FA FA_lv1_6 (.A(product[9][a+2]) , .B(product[10][a+1] )  , .Cin(product[11][a] ) , .Cout( wallace_lv1[a+12][6] ) , .Sum( wallace_lv1[a+11][7] ));
            
            end else begin : gen_wallace_lv1_03
                
                FA FA_lv1_7 (.A(product[0][a+2]) , .B(product[1][a+1] )  , .Cin(product[2][a] ) , .Cout( wallace_lv1[a+3][0] ) , .Sum( wallace_lv1[a+2][1] ));
                FA FA_lv1_8 (.A(product[3][a+2]) , .B(product[4][a+1] )  , .Cin(product[5][a] ) , .Cout( wallace_lv1[a+6][2] ) , .Sum( wallace_lv1[a+5][3] ));
                FA FA_lv1_9 (.A(product[6][a+2]) , .B(product[7][a+1] )  , .Cin(product[8][a] ) , .Cout( wallace_lv1[a+9][4] ) , .Sum( wallace_lv1[a+8][5] ));
                FA FA_lv1_10 (.A(product[9][a+2]) , .B(product[10][a+1] )  , .Cin(product[11][a] ) , .Cout( wallace_lv1[a+12][6] ) , .Sum( wallace_lv1[a+11][7] ));
                FA FA_lv1_11 (.A(product[12][a+2]) , .B(product[13][a+1] ) , .Cin(product[14][a] ) , .Cout( wallace_lv1[a+15][8] ) , .Sum( wallace_lv1[a+14][9] ));
            
            end
        end
    endgenerate

    generate
        for(b=1 ; b <14  ; b=b+1)begin : gen_wallace_tree_lv1_FA_1
            // * generate left half of first level wallace tree
            if(b < 4)begin : gen_wallace_lv1_04
            
                FA FA_lv1_12 (.A(product[13][b+2]) , .B(product[14][b+1] )  , .Cin(product[15][b] ) , .Cout( wallace_lv1[b+16][0] ) , .Sum( wallace_lv1[b+15][1] ));
            
            end else if(b < 7) begin : gen_wallace_lv1_05
                            
                FA FA_lv1_13 (.A(product[10][b+2]) , .B(product[11][b+1] )  , .Cin(product[12][b] ) , .Cout( wallace_lv1[b+13][2] ) , .Sum( wallace_lv1[b+12][3] ));
                FA FA_lv1_14 (.A(product[13][b+2]) , .B(product[14][b+1] )  , .Cin(product[15][b] ) , .Cout( wallace_lv1[b+16][0] ) , .Sum( wallace_lv1[b+15][1] ));
            
            end else if (b <10)begin : gen_wallace_lv1_06
            
                FA FA_lv1_15 (.A(product[7][b+2]) , .B(product[8][b+1] )  , .Cin(product[9][b] ) , .Cout( wallace_lv1[b+10][4] )    , .Sum( wallace_lv1[b+9][5] ));
                FA FA_lv1_16 (.A(product[10][b+2]) , .B(product[11][b+1] )  , .Cin(product[12][b] ) , .Cout( wallace_lv1[b+13][2] ) , .Sum( wallace_lv1[b+12][3] ));
                FA FA_lv1_17 (.A(product[13][b+2]) , .B(product[14][b+1] )  , .Cin(product[15][b] ) , .Cout( wallace_lv1[b+16][0] ) , .Sum( wallace_lv1[b+15][1] ));
            
            end else if(b < 13)begin : gen_wallace_lv1_07
            
                FA FA_lv1_18 (.A(product[4][b+2]) , .B(product[5][b+1] )  , .Cin(product[6][b] ) , .Cout( wallace_lv1[b+7][6] )    , .Sum( wallace_lv1[b+6][7] ));
                FA FA_lv1_19 (.A(product[7][b+2]) , .B(product[8][b+1] )  , .Cin(product[9][b] ) , .Cout( wallace_lv1[b+10][4] )    , .Sum( wallace_lv1[b+9][5] ));
                FA FA_lv1_20 (.A(product[10][b+2]) , .B(product[11][b+1] )  , .Cin(product[12][b] ) , .Cout( wallace_lv1[b+13][2] ) , .Sum( wallace_lv1[b+12][3] ));
                FA FA_lv1_21 (.A(product[13][b+2]) , .B(product[14][b+1] )  , .Cin(product[15][b] ) , .Cout( wallace_lv1[b+16][0] ) , .Sum( wallace_lv1[b+15][1] ));
            
            end else begin  : gen_wallace_lv1_08

                FA FA_lv1_22 (.A(product[1][b+2]) , .B(product[2][b+1] )  , .Cin(product[3][b] ) , .Cout( wallace_lv1[b+4][8] )    , .Sum( wallace_lv1[b+3][9] ));
                FA FA_lv1_23 (.A(product[4][b+2]) , .B(product[5][b+1] )  , .Cin(product[6][b] ) , .Cout( wallace_lv1[b+7][6] )    , .Sum( wallace_lv1[b+6][7] ));
                FA FA_lv1_24 (.A(product[7][b+2]) , .B(product[8][b+1] )  , .Cin(product[9][b] ) , .Cout( wallace_lv1[b+10][4] )    , .Sum( wallace_lv1[b+9][5] ));
                FA FA_lv1_25 (.A(product[10][b+2]) , .B(product[11][b+1] )  , .Cin(product[12][b] ) , .Cout( wallace_lv1[b+13][2] ) , .Sum( wallace_lv1[b+12][3] ));
                FA FA_lv1_26 (.A(product[13][b+2]) , .B(product[14][b+1] )  , .Cin(product[15][b] ) , .Cout( wallace_lv1[b+16][0] ) , .Sum( wallace_lv1[b+15][1] ));
            end
        end
    endgenerate
    // Half adder in level 1 adder tree
    HA HA_lv1_0 (.A(product[0][1] ) , .B( product[1][0] )  , .Cout( wallace_lv1[2][0] ) , .Sum( wallace_lv1[1][0] ));
    HA HA_lv1_1 (.A(product[3][1] ) , .B( product[4][0] )  , .Cout( wallace_lv1[5][2] ) , .Sum( wallace_lv1[4][2] ));
    HA HA_lv1_2 (.A(product[6][1] ) , .B( product[7][0] )  , .Cout( wallace_lv1[8][4] ) , .Sum( wallace_lv1[7][4] ));
    HA HA_lv1_3 (.A(product[9][1] ) , .B( product[10][0] ) , .Cout( wallace_lv1[11][6] ) , .Sum( wallace_lv1[10][6] ));
    HA HA_lv1_4 (.A(product[12][1] ) , .B( product[13][0] ) , .Cout( wallace_lv1[14][8] ) , .Sum( wallace_lv1[13][8] ));

    HA HA_lv1_5 (.A(product[2][15] ) , .B( product[3][14] ) , .Cout( wallace_lv1[18][8] ) , .Sum( wallace_lv1[17][9] ));
    HA HA_lv1_6 (.A(product[5][15] ) , .B( product[6][14] ) , .Cout( wallace_lv1[21][6] ) , .Sum( wallace_lv1[20][7] ));
    HA HA_lv1_7 (.A(product[8][15] ) , .B( product[9][14] ) , .Cout( wallace_lv1[24][4] ) , .Sum( wallace_lv1[23][5] ));
    HA HA_lv1_8 (.A(product[11][15] ) , .B( product[12][14] ) , .Cout( wallace_lv1[27][2] ) , .Sum( wallace_lv1[26][3] ));
    HA HA_lv1_9 (.A(product[14][15] ) , .B( product[15][14] ) , .Cout( wallace_lv1[30][0] ) , .Sum( wallace_lv1[29][1] ));
    
    assign wallace_lv1[0][0]   = product[0][0];
    assign wallace_lv1[3][2]   = product[3][0];
    assign wallace_lv1[6][4]   = product[6][0];
    assign wallace_lv1[9][6]   = product[9][0];
    assign wallace_lv1[12][8]  = product[12][0]; 
    assign wallace_lv1[15][10] = product[15][0];
    assign wallace_lv1[18][9]  = product[3][15];
    assign wallace_lv1[21][7]  = product[6][15];
    assign wallace_lv1[24][5]  = product[9][15];
    assign wallace_lv1[27][3]  = product[12][15];
    assign wallace_lv1[30][1]  = product[15][15];

    

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                     LV2 of Wallace tree                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    genvar c,d,e;

    generate
        for(c=3 ; c < 28 ; c = c+1)begin : gen_wallace_tree_lv2_FA_0
            FA FA_lv2_0(.A(wallace_lv1[c][0]) , .B(wallace_lv1[c][1] )  , .Cin(wallace_lv1[c][2] ) , .Cout( wallace_lv2[c+1][0] )    , .Sum( wallace_lv2[c][1] ));
        end
    endgenerate

    generate
        for(d=8 ; d < 25 ; d = d+1)begin : gen_wallace_tree_lv2_FA_1
            FA FA_lv2_1(.A(wallace_lv1[d][3]) , .B(wallace_lv1[d][4] )  , .Cin(wallace_lv1[d][5] ) , .Cout( wallace_lv2[d+1][2] )    , .Sum( wallace_lv2[d][3] ));
        end
    endgenerate

    generate
        for(e=12 ; e < 19 ; e = e+1)begin : gen_wallace_tree_lv2_FA_2
            FA FA_lv2_2(.A(wallace_lv1[e][6]) , .B(wallace_lv1[e][7] )  , .Cin(wallace_lv1[e][8] ) , .Cout( wallace_lv2[e+1][4] )    , .Sum( wallace_lv2[e][5] ));
        end
    endgenerate

    HA HA_lv2_0 (.A(wallace_lv1[2][0] ) , .B( wallace_lv1[2][1] )  , .Cout( wallace_lv2[3][0] ) , .Sum( wallace_lv2[2][0] ));
    HA HA_lv2_1 (.A(wallace_lv1[6][3] ) , .B( wallace_lv1[6][4] )  , .Cout( wallace_lv2[7][2] ) , .Sum( wallace_lv2[6][2] ));
    HA HA_lv2_2 (.A(wallace_lv1[7][3] ) , .B( wallace_lv1[7][4] )  , .Cout( wallace_lv2[8][2] ) , .Sum( wallace_lv2[7][3] ));
    HA HA_lv2_3 (.A(wallace_lv1[11][6] ) , .B( wallace_lv1[11][7] )  , .Cout( wallace_lv2[12][4] ) , .Sum( wallace_lv2[11][4] ));
    HA HA_lv2_4 (.A(wallace_lv1[15][9] ) , .B( wallace_lv1[15][10] )  , .Cout( wallace_lv2[16][6] ) , .Sum( wallace_lv2[15][6] ));

    HA HA_lv2_5 (.A(wallace_lv1[19][6] ) , .B( wallace_lv1[19][7] )  , .Cout( wallace_lv2[20][4] ) , .Sum( wallace_lv2[19][5] ));
    HA HA_lv2_6 (.A(wallace_lv1[20][6] ) , .B( wallace_lv1[20][7] )  , .Cout( wallace_lv2[21][4] ) , .Sum( wallace_lv2[20][5] ));
    HA HA_lv2_7 (.A(wallace_lv1[21][6] ) , .B( wallace_lv1[21][7] )  , .Cout( wallace_lv2[22][4] ) , .Sum( wallace_lv2[21][5] ));
    HA HA_lv2_8 (.A(wallace_lv1[28][0] ) , .B( wallace_lv1[28][1] )  , .Cout( wallace_lv2[29][0] ) , .Sum( wallace_lv2[28][1] ));
    HA HA_lv2_9 (.A(wallace_lv1[29][0] ) , .B( wallace_lv1[29][1] )  , .Cout( wallace_lv2[30][0] ) , .Sum( wallace_lv2[29][1] ));
    HA HA_lv2_10(.A(wallace_lv1[30][0] ) , .B( wallace_lv1[30][1] )  , .Cout( wallace_lv2[31][0] ) , .Sum( wallace_lv2[30][1] ));

    assign wallace_lv2[0][0]  = wallace_lv1[0][0];
    assign wallace_lv2[1][0]  = wallace_lv1[1][0];
    
    assign wallace_lv2[5][2]  = wallace_lv1[5][3];
    
    assign wallace_lv2[9][4]  = wallace_lv1[9][6];
    
    assign wallace_lv2[10][4] = wallace_lv1[10][6];
    
    assign wallace_lv2[14][6] = wallace_lv1[14][9];
    
    assign wallace_lv2[16][7] = wallace_lv1[16][9];
    assign wallace_lv2[17][6] = wallace_lv1[17][9];
    assign wallace_lv2[18][6] = wallace_lv1[18][9];

    assign wallace_lv2[25][3] = wallace_lv1[25][3];
    assign wallace_lv2[26][2] = wallace_lv1[26][3];
    assign wallace_lv2[27][2] = wallace_lv1[27][3];

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                        pipe line stage_1                                                                                         //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            stage_1_0  <=  zero;
            stage_1_1  <=  zero;
            stage_1_2  <=  zero;
            stage_1_3  <=  zero;
            stage_1_4  <=  zero;
            stage_1_5  <=  zero;
            stage_1_6  <=  zero;
            stage_1_7  <=  zero;
            stage_1_8  <=  zero;
            stage_1_9  <=  zero;
            stage_1_10  <=  zero;
            stage_1_11  <=  zero;
            stage_1_12  <=  zero;
            stage_1_13  <=  zero;
            stage_1_14  <=  zero;
            stage_1_15  <=  zero;
            stage_1_16  <=  zero;
            stage_1_17  <=  zero;
            stage_1_18  <=  zero;
            stage_1_19  <=  zero;
            stage_1_20  <=  zero;
            stage_1_21  <=  zero;
            stage_1_22  <=  zero;
            stage_1_23  <=  zero;
            stage_1_24  <=  zero;
            stage_1_25  <=  zero;
            stage_1_26  <=  zero;
            stage_1_27  <=  zero;
            stage_1_28  <=  zero;
            stage_1_29  <=  zero;
            stage_1_30  <=  zero;
            stage_1_31  <=  zero;
            stage_1_v   <=  zero;
        end else begin
            stage_1_0  <=  wallace_lv2[0][0];
            stage_1_1  <=  wallace_lv2[1][0];
            stage_1_2  <=  wallace_lv2[2][0];
            stage_1_3  <=  wallace_lv2[3][1:0];
            stage_1_4  <=  wallace_lv2[4][1:0];
            stage_1_5  <=  wallace_lv2[5][2:0];
            stage_1_6  <=  wallace_lv2[6][2:0];
            stage_1_7  <=  wallace_lv2[7][3:0];
            stage_1_8  <=  wallace_lv2[8][3:0];
            stage_1_9  <=  wallace_lv2[9][4:0];
            stage_1_10  <=  wallace_lv2[10][4:0];
            stage_1_11  <=  wallace_lv2[11][4:0];
            stage_1_12  <=  wallace_lv2[12][5:0];
            stage_1_13  <=  wallace_lv2[13][5:0];
            stage_1_14  <=  wallace_lv2[14][6:0];
            stage_1_15  <=  wallace_lv2[15][6:0];
            stage_1_16  <=  wallace_lv2[16][7:0];
            stage_1_17  <=  wallace_lv2[17][6:0];
            stage_1_18  <=  wallace_lv2[18][6:0];
            stage_1_19  <=  wallace_lv2[19][5:0];
            stage_1_20  <=  wallace_lv2[20][5:0];
            stage_1_21  <=  wallace_lv2[21][5:0];
            stage_1_22  <=  wallace_lv2[22][4:0];
            stage_1_23  <=  wallace_lv2[23][3:0];
            stage_1_24  <=  wallace_lv2[24][3:0];
            stage_1_25  <=  wallace_lv2[25][3:0];
            stage_1_26  <=  wallace_lv2[26][2:0];
            stage_1_27  <=  wallace_lv2[27][2:0];
            stage_1_28  <=  wallace_lv2[28][1:0];
            stage_1_29  <=  wallace_lv2[29][1:0];
            stage_1_30  <=  wallace_lv2[30][1:0];
            stage_1_31  <=  wallace_lv2[31][0];
            stage_1_v   <=  in_valid;
        end 
    end 
    
    assign stage_1_array[0][0]    = stage_1_0;
    assign stage_1_array[1][0]    = stage_1_1;
    assign stage_1_array[2][0]    = stage_1_2;
    assign stage_1_array[3][1:0]  = stage_1_3;
    assign stage_1_array[4][1:0]  = stage_1_4;
    assign stage_1_array[5][2:0]  = stage_1_5;
    assign stage_1_array[6][2:0]  = stage_1_6;
    assign stage_1_array[7][3:0]  = stage_1_7;
    assign stage_1_array[8][3:0]  = stage_1_8;
    assign stage_1_array[9][4:0]  = stage_1_9;
    assign stage_1_array[10][4:0] = stage_1_10;
    assign stage_1_array[11][4:0] = stage_1_11;
    assign stage_1_array[12][5:0] = stage_1_12;
    assign stage_1_array[13][5:0] = stage_1_13;
    assign stage_1_array[14][6:0] = stage_1_14;
    assign stage_1_array[15][6:0] = stage_1_15;
    assign stage_1_array[16][7:0] = stage_1_16;
    assign stage_1_array[17][6:0] = stage_1_17;
    assign stage_1_array[18][6:0] = stage_1_18;
    assign stage_1_array[19][5:0] = stage_1_19;
    assign stage_1_array[20][5:0] = stage_1_20;
    assign stage_1_array[21][5:0] = stage_1_21;
    assign stage_1_array[22][4:0] = stage_1_22;
    assign stage_1_array[23][3:0] = stage_1_23;
    assign stage_1_array[24][3:0] = stage_1_24;
    assign stage_1_array[25][3:0] = stage_1_25;
    assign stage_1_array[26][2:0] = stage_1_26;
    assign stage_1_array[27][2:0] = stage_1_27;
    assign stage_1_array[28][1:0] = stage_1_28;
    assign stage_1_array[29][1:0] = stage_1_29;
    assign stage_1_array[30][1:0] = stage_1_30;
    assign stage_1_array[31][0]   = stage_1_31;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                       pipe line stage_1                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    genvar f , g , h , k;    

    generate
        for(f = 5 ; f < 28 ; f = f+1)begin : gen_wallace_tree_lv3_FA_0
            FA FA_lv3_0(.A( stage_1_array[f][0] ) , .B( stage_1_array[f][1] ) , .Cin( stage_1_array[f][2] ) , .Cout( wallace_lv3[f+1][0] ) , .Sum( wallace_lv3[f][1]));
        end
    endgenerate

    generate
        for(g = 12 ; g < 22 ; g = g+1)begin : gen_wallace_tree_lv3_FA_1
            FA FA_lv3_1(.A( stage_1_array[g][3] ) , .B( stage_1_array[g][4] ) , .Cin( stage_1_array[g][5] ) , .Cout( wallace_lv3[g+1][2] ) , .Sum( wallace_lv3[g][3]));
        end
    endgenerate

    generate
        for(h = 10 ; h < 12 ; h = h+1)begin : gen_wallace_tree_lv3_HA_0
            HA HA_lv3_0(.A( stage_1_array[h][3] ) , .B( stage_1_array[h][4] ) , .Cout(wallace_lv3[h+1][2] ) , .Sum( wallace_lv3[h][3] ) );
        end
    endgenerate

    generate
        for(k = 28 ; k < 31 ; k = k+1)begin : gen_wallace_tree_lv3_HA_1
            HA HA_lv3_1(.A( stage_1_array[k][0] ) , .B( stage_1_array[k][1] ) , .Cout(wallace_lv3[k+1][0] ) , .Sum( wallace_lv3[k][1] ) );
        end
    endgenerate

    HA HA_lv3_2(.A( stage_1_array[9][3] ) , .B( stage_1_array[9][4] ) , .Cout(wallace_lv3[10][2]) , .Sum( wallace_lv3[9][2] ));
    
    HA HA_lv3_3(.A( stage_1_array[22][3]) , .B( stage_1_array[22][4]) , .Cout(wallace_lv3[23][2]) , .Sum( wallace_lv3[22][3] ));

    HA HA_lv3_4(.A( stage_1_array[4][0] ) , .B( stage_1_array[4][1] ) , .Cout(wallace_lv3[5][0] ) , .Sum( wallace_lv3[4][1] ));
    HA HA_lv3_5(.A( stage_1_array[3][0] ) , .B( stage_1_array[3][1] ) , .Cout(wallace_lv3[4][0] ) , .Sum( wallace_lv3[3][0] ));
    HA HA_lv3_6(.A( stage_1_array[16][6]) , .B( stage_1_array[16][7]) , .Cout(wallace_lv3[17][4] ) , .Sum( wallace_lv3[16][4] ));

    assign wallace_lv3[0][0] = stage_1_array[0][0];
    assign wallace_lv3[1][0] = stage_1_array[1][0];
    assign wallace_lv3[2][0] = stage_1_array[2][0];

    assign wallace_lv3[7][2]  = stage_1_array[7][3];
    assign wallace_lv3[8][2]  = stage_1_array[8][3];

    assign wallace_lv3[14][4] = stage_1_array[14][6];
    assign wallace_lv3[15][4] = stage_1_array[15][6];

    assign wallace_lv3[17][5] = stage_1_array[17][6];
    
    assign wallace_lv3[18][4] = stage_1_array[18][6];
    
    assign wallace_lv3[23][3] = stage_1_array[23][3];
    
    assign wallace_lv3[24][2] = stage_1_array[24][3];
    assign wallace_lv3[25][2] = stage_1_array[25][3];
    
    assign wallace_lv3[31][1] = stage_1_array[31][0];

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                     LV4 of Wallace tree                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    genvar L , m , n;
    generate
        for(L=7 ; L<26 ; L = L+1 )begin : gen_wallace_tree_lv4_FA_0
            FA FA_lv4_0(.A(wallace_lv3[L][0] ) , .B(wallace_lv3[L][1] ) , .Cin(wallace_lv3[L][2] ) , .Cout( wallace_lv4[L+1][0] ) , .Sum( wallace_lv4[L][1] ));
        end
    endgenerate

    generate
        for(m=26 ; m < 32 ; m = m+1)begin : gen_wallace_tree_lv4_HA_0
            HA HA_lv4_0(.A(wallace_lv3[m][0]) , .B(wallace_lv3[m][1] ) , .Cout(wallace_lv4[m+1][0] ) , .Sum(wallace_lv4[m][1]));
        end
    endgenerate

    FA FA_lv4_1(.A(wallace_lv3[17][3] ) , .B(wallace_lv3[17][4] ) , .Cin(wallace_lv3[17][5] ) , .Cout( wallace_lv4[18][2] ) , .Sum( wallace_lv4[17][3] ));

    HA HA_lv4_1(.A(wallace_lv3[4][0]) , .B(wallace_lv3[4][1] ) , .Cout(wallace_lv4[5][0] ) , .Sum(wallace_lv4[4][0]));
    HA HA_lv4_2(.A(wallace_lv3[5][0]) , .B(wallace_lv3[5][1] ) , .Cout(wallace_lv4[6][0] ) , .Sum(wallace_lv4[5][1]));
    HA HA_lv4_3(.A(wallace_lv3[6][0]) , .B(wallace_lv3[6][1] ) , .Cout(wallace_lv4[7][0] ) , .Sum(wallace_lv4[6][1]));

    HA HA_lv4_4(.A(wallace_lv3[14][3]) , .B(wallace_lv3[14][4] ) , .Cout(wallace_lv4[15][2] ) , .Sum(wallace_lv4[14][2]));
    HA HA_lv4_5(.A(wallace_lv3[15][3]) , .B(wallace_lv3[15][4] ) , .Cout(wallace_lv4[16][2] ) , .Sum(wallace_lv4[15][3]));
    HA HA_lv4_6(.A(wallace_lv3[16][3]) , .B(wallace_lv3[16][4] ) , .Cout(wallace_lv4[17][2] ) , .Sum(wallace_lv4[16][3]));

    HA HA_lv4_7(.A(wallace_lv3[18][3]) , .B(wallace_lv3[18][4] ) , .Cout(wallace_lv4[19][2] ) , .Sum(wallace_lv4[18][3]));

    assign wallace_lv4[0][0]  = wallace_lv3[0][0];
    assign wallace_lv4[1][0]  = wallace_lv3[1][0];
    assign wallace_lv4[2][0]  = wallace_lv3[2][0];
    assign wallace_lv4[3][0]  = wallace_lv3[3][0];

    assign wallace_lv4[10][2] = wallace_lv3[10][3];
    assign wallace_lv4[11][2] = wallace_lv3[11][3];
    assign wallace_lv4[12][2] = wallace_lv3[12][3];
    assign wallace_lv4[13][2] = wallace_lv3[13][3];

    assign wallace_lv4[19][3] = wallace_lv3[19][3];
    assign wallace_lv4[20][2] = wallace_lv3[20][3];
    assign wallace_lv4[21][2] = wallace_lv3[21][3];
    assign wallace_lv4[22][2] = wallace_lv3[22][3];
    assign wallace_lv4[23][2] = wallace_lv3[23][3];

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                       pipe line stage_2                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign stage_2_array[0][0]    = stage_2_0 ;
    assign stage_2_array[1][0]    = stage_2_1 ;
    assign stage_2_array[2][0]    = stage_2_2 ;
    assign stage_2_array[3][0]    = stage_2_3 ;
    assign stage_2_array[4][0]    = stage_2_4 ;
    
    assign stage_2_array[5][1:0]  = stage_2_5[1:0] ;
    assign stage_2_array[6][1:0]  = stage_2_6[1:0] ;
    assign stage_2_array[7][1:0]  = stage_2_7[1:0] ;
    assign stage_2_array[8][1:0]  = stage_2_8[1:0] ;
    assign stage_2_array[9][1:0]  = stage_2_9[1:0] ;

    assign stage_2_array[10][2:0] = stage_2_10[2:0] ;
    assign stage_2_array[11][2:0] = stage_2_11[2:0] ;
    assign stage_2_array[12][2:0] = stage_2_12[2:0] ;
    assign stage_2_array[13][2:0] = stage_2_13[2:0] ;
    assign stage_2_array[14][2:0] = stage_2_14[2:0] ;
    
    assign stage_2_array[15][3:0] = stage_2_15[3:0] ;
    assign stage_2_array[16][3:0] = stage_2_16[3:0] ;
    assign stage_2_array[17][3:0] = stage_2_17[3:0] ;
    assign stage_2_array[18][3:0] = stage_2_18[3:0] ;
    assign stage_2_array[19][3:0] = stage_2_19[3:0] ;

    assign stage_2_array[20][2:0] = stage_2_20[2:0] ;
    assign stage_2_array[21][2:0] = stage_2_21[2:0] ;
    assign stage_2_array[22][2:0] = stage_2_22[2:0] ;
    assign stage_2_array[23][2:0] = stage_2_23[2:0] ;

    assign stage_2_array[24][1:0] = stage_2_24[1:0] ;
    assign stage_2_array[25][1:0] = stage_2_25[1:0] ;
    assign stage_2_array[26][1:0] = stage_2_26[1:0] ;
    assign stage_2_array[27][1:0] = stage_2_27[1:0] ;
    assign stage_2_array[28][1:0] = stage_2_28[1:0] ;
    assign stage_2_array[29][1:0] = stage_2_29[1:0] ;
    assign stage_2_array[30][1:0] = stage_2_30[1:0] ;
    assign stage_2_array[31][1:0] = stage_2_31[1:0] ;

    assign stage_2_array[32][0]   = stage_2_32 ;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            stage_2_0    <=  zero;
            stage_2_1    <=  zero;
            stage_2_2    <=  zero;
            stage_2_3    <=  zero;
            stage_2_4    <=  zero;
            stage_2_5    <=  zero;
            stage_2_6    <=  zero;
            stage_2_7    <=  zero;
            stage_2_8    <=  zero;
            stage_2_9    <=  zero;
            stage_2_10   <=  zero;
            stage_2_11   <=  zero;
            stage_2_12   <=  zero;
            stage_2_13   <=  zero;
            stage_2_14   <=  zero;
            stage_2_15   <=  zero;
            stage_2_16   <=  zero;
            stage_2_17   <=  zero;
            stage_2_18   <=  zero;
            stage_2_19   <=  zero;
            stage_2_20   <=  zero;
            stage_2_21   <=  zero;
            stage_2_22   <=  zero;
            stage_2_23   <=  zero;
            stage_2_24   <=  zero;
            stage_2_25   <=  zero;
            stage_2_26   <=  zero;
            stage_2_27   <=  zero;
            stage_2_28   <=  zero;
            stage_2_29   <=  zero;
            stage_2_30   <=  zero;
            stage_2_31   <=  zero;
            stage_2_32   <=  zero;
            stage_2_v    <=  zero;
        end else begin
            stage_2_0    <=  wallace_lv4[0][0];
            stage_2_1    <=  wallace_lv4[1][0];
            stage_2_2    <=  wallace_lv4[2][0];
            stage_2_3    <=  wallace_lv4[3][0];
            stage_2_4    <=  wallace_lv4[4][0];
            
            stage_2_5    <=  wallace_lv4[5][1:0];
            stage_2_6    <=  wallace_lv4[6][1:0];
            stage_2_7    <=  wallace_lv4[7][1:0];
            stage_2_8    <=  wallace_lv4[8][1:0];
            stage_2_9    <=  wallace_lv4[9][1:0];
            
            stage_2_10   <=  wallace_lv4[10][2:0];
            stage_2_11   <=  wallace_lv4[11][2:0];
            stage_2_12   <=  wallace_lv4[12][2:0];
            stage_2_13   <=  wallace_lv4[13][2:0];
            stage_2_14   <=  wallace_lv4[14][2:0];
            
            stage_2_15   <=  wallace_lv4[15][3:0];
            stage_2_16   <=  wallace_lv4[16][3:0];
            stage_2_17   <=  wallace_lv4[17][3:0];
            stage_2_18   <=  wallace_lv4[18][3:0];
            stage_2_19   <=  wallace_lv4[19][3:0];
            
            stage_2_20   <=  wallace_lv4[20][2:0];
            stage_2_21   <=  wallace_lv4[21][2:0];
            stage_2_22   <=  wallace_lv4[22][2:0];
            stage_2_23   <=  wallace_lv4[23][2:0];
            
            stage_2_24   <=  wallace_lv4[24][1:0];
            stage_2_25   <=  wallace_lv4[25][1:0];
            stage_2_26   <=  wallace_lv4[26][1:0];
            stage_2_27   <=  wallace_lv4[27][1:0];
            stage_2_28   <=  wallace_lv4[28][1:0];
            stage_2_29   <=  wallace_lv4[29][1:0];
            stage_2_30   <=  wallace_lv4[30][1:0];
            stage_2_31   <=  wallace_lv4[31][1:0];
            
            stage_2_32   <=  wallace_lv4[32][0];
            stage_2_v    <=  stage_1_v;
        end
    end


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                     LV5 of Wallace tree                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    genvar x , y , z;

    generate
        for(x=10 ; x < 24 ; x=x+1)begin : gen_wallace_tree_lv5_FA_0
            FA FA_lv5(.A(stage_2_array[x][0]) , .B(stage_2_array[x][1]) , .Cin(stage_2_array[x][2]) , .Cout(wallace_lv5[x+1][0]) , .Sum(wallace_lv5[x][1]));
        end
    endgenerate

    generate
        for(y=6 ; y<10 ; y=y+1)begin : gen_wallace_tree_lv5_HA_0
            HA HA_lv5_0(.A(stage_2_array[y][0]) , .B(stage_2_array[y][1]) , .Cout(wallace_lv5[y+1][0] ) , .Sum(wallace_lv5[y][1]));
        end
    endgenerate

    generate
        for(z=24 ; z<32 ; z=z+1)begin : gen_wallace_tree_lv5_HA_1
            HA HA_lv5_1(.A(stage_2_array[z][0]) , .B(stage_2_array[z][1]) , .Cout(wallace_lv5[z+1][0] ) , .Sum(wallace_lv5[z][1]));
        end
    endgenerate

    HA HA_lv5_2(.A(stage_2_array[5][0]) , .B(stage_2_array[5][1]) , .Cout(wallace_lv5[6][0] ) , .Sum(wallace_lv5[5][0]));

    assign wallace_lv5[32][1] = stage_2_array[32][0];

    assign wallace_lv5[19][2] = stage_2_array[19][3];
    assign wallace_lv5[18][2] = stage_2_array[18][3];
    assign wallace_lv5[17][2] = stage_2_array[17][3];
    assign wallace_lv5[16][2] = stage_2_array[16][3];
    assign wallace_lv5[15][2] = stage_2_array[15][3];

    assign wallace_lv5[0][0] = stage_2_array[0][0];
    assign wallace_lv5[1][0] = stage_2_array[1][0];
    assign wallace_lv5[2][0] = stage_2_array[2][0];
    assign wallace_lv5[3][0] = stage_2_array[3][0];
    assign wallace_lv5[4][0] = stage_2_array[4][0];
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                     LV6 of Wallace tree                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    genvar  Q , P ,T;    

    generate
        for(Q=6 ; Q <15 ; Q = Q+1)begin : gen_wallace_tree_lv6_HA_0
            HA HA_lv6_0( .A(wallace_lv5[Q][0] ) , .B(wallace_lv5[Q][1] ) , .Cout( wallace_lv6[Q+1][0]) , .Sum( wallace_lv6[Q][1]));
        end
    endgenerate

    generate
        for(P=15 ; P<20 ; P=P+1)begin : gen_wallace_tree_lv6_FA_0
            FA FA_lv6_0(.A(wallace_lv5[P][0]) , .B(wallace_lv5[P][1]) , .Cin(wallace_lv5[P][2]) , .Cout(wallace_lv6[P+1][0]) , .Sum(wallace_lv6[P][1]));
        end
    endgenerate

    generate
        for(T=20 ; T<33 ; T=T+1)begin : gen_wallace_tree_lv6_HA_1
            HA HA_lv6_1(.A(wallace_lv5[T][0]) , .B(wallace_lv5[T][1]) ,  .Cout(wallace_lv6[T+1][0]) , .Sum(wallace_lv6[T][1]));
        end
    endgenerate

    assign wallace_lv6[0][0] = wallace_lv5[0][0] ;
    assign wallace_lv6[1][0] = wallace_lv5[1][0] ;
    assign wallace_lv6[2][0] = wallace_lv5[2][0] ;
    assign wallace_lv6[3][0] = wallace_lv5[3][0] ;
    assign wallace_lv6[4][0] = wallace_lv5[4][0] ;
    assign wallace_lv6[5][0] = wallace_lv5[5][0] ;

    assign wallace_lv6[6][0] = wallace_lv6[6][1];
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                       pipe line stage_3                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            stage_3_0   <=  zero;
            stage_3_1   <=  zero;
            stage_3_2   <=  zero;
            stage_3_3   <=  zero;
            stage_3_4   <=  zero;
            stage_3_5   <=  zero;
            stage_3_6   <=  zero;
            stage_3_7   <=  zero;
            stage_3_8   <=  zero;
            stage_3_9   <=  zero;
            stage_3_10  <=  zero;
            stage_3_11  <=  zero;
            stage_3_12  <=  zero;
            stage_3_13  <=  zero;
            stage_3_14  <=  zero;
            stage_3_15  <=  zero;
            stage_3_16  <=  zero;
            stage_3_17  <=  zero;
            stage_3_18  <=  zero;
            stage_3_19  <=  zero;
            stage_3_20  <=  zero;
            stage_3_21  <=  zero;
            stage_3_22  <=  zero;
            stage_3_23  <=  zero;
            stage_3_24  <=  zero;
            stage_3_25  <=  zero;
            stage_3_26  <=  zero;
            stage_3_27  <=  zero;
            stage_3_28  <=  zero;
            stage_3_29  <=  zero;
            stage_3_30  <=  zero;
            stage_3_31  <=  zero;
            stage_3_32  <=  zero;
            stage_3_33  <=  zero;
            stage_3_v   <=  zero;
        end else begin
            stage_3_0   <=  wallace_lv6[0][0];
            stage_3_1   <=  wallace_lv6[1][0];
            stage_3_2   <=  wallace_lv6[2][0];
            stage_3_3   <=  wallace_lv6[3][0];
            stage_3_4   <=  wallace_lv6[4][0];
            stage_3_5   <=  wallace_lv6[5][0];
            stage_3_6   <=  wallace_lv6[6][1];
            stage_3_7   <=  wallace_lv6[7][1:0];
            stage_3_8   <=  wallace_lv6[8][1:0];
            stage_3_9   <=  wallace_lv6[9][1:0];
            stage_3_10  <=  wallace_lv6[10][1:0];
            stage_3_11  <=  wallace_lv6[11][1:0];
            stage_3_12  <=  wallace_lv6[12][1:0];
            stage_3_13  <=  wallace_lv6[13][1:0];
            stage_3_14  <=  wallace_lv6[14][1:0];
            stage_3_15  <=  wallace_lv6[15][1:0];
            stage_3_16  <=  wallace_lv6[16][1:0];
            stage_3_17  <=  wallace_lv6[17][1:0];
            stage_3_18  <=  wallace_lv6[18][1:0];
            stage_3_19  <=  wallace_lv6[19][1:0];
            stage_3_20  <=  wallace_lv6[20][1:0];
            stage_3_21  <=  wallace_lv6[21][1:0];
            stage_3_22  <=  wallace_lv6[22][1:0];
            stage_3_23  <=  wallace_lv6[23][1:0];
            stage_3_24  <=  wallace_lv6[24][1:0];
            stage_3_25  <=  wallace_lv6[25][1:0];
            stage_3_26  <=  wallace_lv6[26][1:0];
            stage_3_27  <=  wallace_lv6[27][1:0];
            stage_3_28  <=  wallace_lv6[28][1:0];
            stage_3_29  <=  wallace_lv6[29][1:0];
            stage_3_30  <=  wallace_lv6[30][1:0];
            stage_3_31  <=  wallace_lv6[31][1:0];
            stage_3_32  <=  wallace_lv6[32][1:0];
            stage_3_33  <=  wallace_lv6[33][0];
            stage_3_v   <=  stage_2_v;
        end
    end
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                             Use carry lookahead to calculate result (prediiction)                                                                //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign logic_one       = 1'b1;
    assign logic_zero      = 1'b0;
    
    assign last_lv_A = { stage_3_33,
                stage_3_32[0],
                stage_3_31[0],
                stage_3_30[0],
                stage_3_29[0],
                stage_3_28[0],
                stage_3_27[0],
                stage_3_26[0],
                stage_3_25[0],
                stage_3_24[0],
                stage_3_23[0],
                stage_3_22[0],
                stage_3_21[0],
                stage_3_20[0],
                stage_3_19[0],
                stage_3_18[0],
                stage_3_17[0],
                stage_3_16[0],
                stage_3_15[0],
                stage_3_14[0],
                stage_3_13[0],
                stage_3_12[0],
                stage_3_11[0],
                stage_3_10[0],
                stage_3_9[0],
                stage_3_8[0],
                stage_3_7[0],
                stage_3_6,
                stage_3_5,
                stage_3_4,
                stage_3_3,
                stage_3_2,
                stage_3_1,
                stage_3_0
                };

    assign last_lv_B ={ 1'b0,
                stage_3_32[1],
                stage_3_31[1],
                stage_3_30[1],
                stage_3_29[1],
                stage_3_28[1],
                stage_3_27[1],
                stage_3_26[1],
                stage_3_25[1],
                stage_3_24[1],
                stage_3_23[1],
                stage_3_22[1],
                stage_3_21[1],
                stage_3_20[1],
                stage_3_19[1],
                stage_3_18[1],
                stage_3_17[1],
                stage_3_16[1],
                stage_3_15[1],
                stage_3_14[1],
                stage_3_13[1],
                stage_3_12[1],
                stage_3_11[1],
                stage_3_10[1],
                stage_3_9[1],
                stage_3_8[1],
                stage_3_7[1],
                7'd0
                };

        CLA_8 CLA1(
                    .Cin(logic_zero),
                    .A  (last_lv_A[14:7]),
                    .B  (last_lv_B[14:7]),
                    .result(result_15_7));

        CLA_8 CLA2(
                    .Cin(logic_zero),
                    .A  (last_lv_A[22:15]),
                    .B  (last_lv_B[22:15]),
                    .result(result_23_15_zero));
        CLA_8 CLA3(
                    .Cin(logic_one),
                    .A  (last_lv_A[22:15]),
                    .B  (last_lv_B[22:15]),
                    .result(result_23_15_one));

        CLA_8 CLA4(
                    .Cin(logic_zero),
                    .A  (last_lv_A[30:23]),
                    .B  (last_lv_B[30:23]),
                    .result(result_31_23_zero));
        CLA_8 CLA5(
                    .Cin(logic_one),
                    .A  (last_lv_A[30:23]),
                    .B  (last_lv_B[30:23]),
                    .result(result_31_23_one));

        assign result_32_31_one  = last_lv_A[32:31] + last_lv_B[32:31] + 2'd1;
        assign result_32_31_zero = last_lv_A[32:31] + last_lv_B[32:31] + 2'd0;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                       pipe line stage_4                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////      

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                stage_4_0       <= 7'd0;
                stage_4_1       <= 9'd0;
                stage_4_2_zero  <= 9'd0;
                stage_4_2_one   <= 9'd0;
                stage_4_3_zero  <= 9'd0;
                stage_4_3_one   <= 9'd0;
                stage_4_4_zero  <= 2'd0;
                stage_4_4_one   <= 2'd0;
                stage_4_v       <= zero;
            end else begin
                stage_4_0       <= last_lv_A[6:0];
                stage_4_1       <= result_15_7;
                
                stage_4_2_zero  <= result_23_15_zero;
                stage_4_2_one   <= result_23_15_one;
                
                stage_4_3_zero  <= result_31_23_zero;
                stage_4_3_one   <= result_31_23_one;

                stage_4_4_zero  <= result_32_31_zero;
                stage_4_4_one   <= result_32_31_one;
                stage_4_v       <= stage_3_v;
            end
        end                                      
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                            result select                                                                                         //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    
        assign r0         = stage_4_0[6:0];                                     // * [6:0]   of result
        assign r1         = stage_4_1[8:0];                                     // * [14:7]  of result        
        assign r2         = (r1[8])?          stage_4_2_one : stage_4_2_zero;   // * [22:15] of result
        assign r3         = (r2[8])?          stage_4_3_one : stage_4_3_zero;   // * [30:23] of result
        assign r4         = (r3[8])?          stage_4_4_one : stage_4_4_zero;   // * [32:31] of result
        assign result     = {r4[1:0] , r3[7:0] , r2[7:0] , r1[7:0] , r0[6:0]};
        assign out_valid  = stage_4_v;

endmodule





