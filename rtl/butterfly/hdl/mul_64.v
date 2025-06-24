`timescale 1ns/1ps
// ----------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : mul_64
// Author : Hsuan Jung,Lo
// Create Date: 5/2025
// Features & Functions:
// . mode:  0 for 53bit multiplication 、 1 for  16bit multiplication (4 pairs)
// .
// ============================================================================================================================================================================
// Revision History:
// Date         by      Version     Change Description
//  
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//==========================================================================================================================================================================//
//
//
//  * Use 8 cycles to finish both 16bit multiplication and 53bit multiplication.(With pipeline)
//  * Support Brust transfer.
//  * To do 16bit multiplication, you need to pack 4 pairs of 16bit data into a pair of 64 bit data (in_A and in_B).It will process the data parallelly. 
//  *  ex :  To do  a1 * b1  、 a2*b2 、 a3*b3 、a4*b4
//  *        You need to packed  above data as following type: 
//  *               in_A = {a1 , a2 , a3 , a4};
//  *               in_B = {b1 , b2 , b3 , b4};
//  *               (use mode 1)
//  
//  *  Waveform :
//
//     clk       >|    |     |     |     |     |     |     |     |     |     |     |     |     |     |    
//     in_valid  >______/-----\_____/-----------------\____________________________________________________-
//     mode      >______/-----\_____/-----\_____/-----\_____________________________________________________
//     in_A      >| xx |  A1 |  xx | A2  | A3  | A4  |                         xx                    |
//     in_B      >| xx |  B1 |  xx | B2  | B3  | B4  |                         xx                    |
//     out_valid >_______________________________________________/------\_____/------------------\__________
//     result    >|                     xx                       | r1  | xx  | r2  | r3  |  r4  |   xx 
//
//=========================================================================================================================================================================//

module mul_64 (
    mode,
    in_A,
    in_B,
    in_valid,
    out_valid,
    result,
    clk,
    rst_n
);
//==================================================================================//
    input [63:0]        in_A ;
    input [63:0]        in_B ;
    output[127:0]       result ;
    input               in_valid ;
    output              out_valid ;
    input               clk ;
    input               rst_n ;
    input               mode ;      // * mode=0 for 53bit * 53bit 、mode=1 for (16bit * 16bit)x4
//==================================================================================//
    wire                logic_zero;
    wire                logic_one;
    wire[107:0]         last_lv_A;
    wire[107:0]         last_lv_B;
    wire [8:0]          result_one [0 : 10];
    wire [8:0]          result_zero[0 : 10];
    wire[8:0]           r[0:10];
//==================================================================================//
    reg                 valid[1:4];    
//==================================================================================//
    reg [15:0]          A[0:3];
    reg [15:0]          B[0:3];
    wire[3:0]           valid_16[0:3];
    wire[31:0]          result_16_0[0:3];
    wire[31:0]          result_16_1[0:3];
    wire[31:0]          result_16_2[0:3];
    wire[31:0]          result_16_3[0:3];
//==================================================================================//
    wire[4:0]           wallace_lv1[0:112];
    wire[3:0]           wallace_lv2[0:108];
    wire[2:0]           wallace_lv3[0:108];
    wire[1:0]           wallace_lv4[0:108];
//===================================================================================//
    reg[31:0]           stage_1_0[0:3];
    reg[31:0]           stage_1_1[0:3];
    reg[31:0]           stage_1_2[0:3];
    reg[31:0]           stage_1_3[0:3];
//===================================================================================//
    wire[3:0]               stage_2_array[0:107];
    reg                     stage_2_0;
    reg                     stage_2_1;
    reg                     stage_2_2;
    reg                     stage_2_3;
    reg                     stage_2_4;
    reg                     stage_2_5;
    reg                     stage_2_6;
    reg                     stage_2_7;
    reg                     stage_2_8;
    reg                     stage_2_9;
    reg                     stage_2_10;
    reg                     stage_2_11;
    reg                     stage_2_12;
    reg                     stage_2_13;
    reg                     stage_2_14;
    reg                     stage_2_15;
    reg                     stage_2_16;
    reg                     stage_2_17;
    reg[1:0]                stage_2_18;
    reg[1:0]                stage_2_19;
    reg[1:0]                stage_2_20;
    reg[1:0]                stage_2_21;
    reg[1:0]                stage_2_22;
    reg[1:0]                stage_2_23;
    reg[1:0]                stage_2_24;
    reg[1:0]                stage_2_25;
    reg[1:0]                stage_2_26;
    reg[1:0]                stage_2_27;
    reg[1:0]                stage_2_28;
    reg[1:0]                stage_2_29;
    reg[1:0]                stage_2_30;
    reg[1:0]                stage_2_31;
    reg[1:0]                stage_2_32;
    reg[2:0]                stage_2_33;
    reg[2:0]                stage_2_34;
    reg[2:0]                stage_2_35;
    reg[2:0]                stage_2_36;
    reg[2:0]                stage_2_37;
    reg[2:0]                stage_2_38;
    reg[2:0]                stage_2_39;
    reg[2:0]                stage_2_40;
    reg[2:0]                stage_2_41;
    reg[2:0]                stage_2_42;
    reg[2:0]                stage_2_43;
    reg[2:0]                stage_2_44;
    reg[2:0]                stage_2_45;
    reg[2:0]                stage_2_46;
    reg[2:0]                stage_2_47;
    reg[2:0]                stage_2_48;
    reg[3:0]                stage_2_49;
    reg[3:0]                stage_2_50;
    reg[3:0]                stage_2_51;
    reg[3:0]                stage_2_52;
    reg[3:0]                stage_2_53;
    reg[3:0]                stage_2_54;
    reg[3:0]                stage_2_55;
    reg[3:0]                stage_2_56;
    reg[3:0]                stage_2_57;
    reg[3:0]                stage_2_58;
    reg[3:0]                stage_2_59;
    reg[3:0]                stage_2_60;
    reg[3:0]                stage_2_61;
    reg[3:0]                stage_2_62;
    reg[3:0]                stage_2_63;
    reg[3:0]                stage_2_64;
    reg[3:0]                stage_2_65;
    reg[3:0]                stage_2_66;
    reg[3:0]                stage_2_67;
    reg[3:0]                stage_2_68;
    reg[3:0]                stage_2_69;
    reg[3:0]                stage_2_70;
    reg[3:0]                stage_2_71;
    reg[3:0]                stage_2_72;
    reg[3:0]                stage_2_73;
    reg[3:0]                stage_2_74;
    reg[3:0]                stage_2_75;
    reg[3:0]                stage_2_76;
    reg[3:0]                stage_2_77;
    reg[3:0]                stage_2_78;
    reg[3:0]                stage_2_79;
    reg[3:0]                stage_2_80;
    reg[2:0]                stage_2_81;
    reg[2:0]                stage_2_82;
    reg[2:0]                stage_2_83;
    reg[2:0]                stage_2_84;
    reg[2:0]                stage_2_85;
    reg[2:0]                stage_2_86;
    reg[2:0]                stage_2_87;
    reg[2:0]                stage_2_88;
    reg[2:0]                stage_2_89;
    reg[2:0]                stage_2_90;
    reg[2:0]                stage_2_91;
    reg[2:0]                stage_2_92;
    reg[2:0]                stage_2_93;
    reg[2:0]                stage_2_94;
    reg[2:0]                stage_2_95;
    reg[1:0]                stage_2_96;
    reg[1:0]                stage_2_97;
    reg[1:0]                stage_2_98;
    reg[1:0]                stage_2_99;
    reg[1:0]                stage_2_100;
    reg[1:0]                stage_2_101;
    reg[1:0]                stage_2_102;
    reg[1:0]                stage_2_103;
    reg[1:0]                stage_2_104;
    reg[1:0]                stage_2_105;
    reg[1:0]                stage_2_106;
    reg[1:0]                stage_2_107;
//===================================================================================//
    wire[1:0]             stage_3_array[0:107];
    reg                   stage_3_0    ;
    reg                   stage_3_1    ;
    reg                   stage_3_2    ;
    reg                   stage_3_3    ;
    reg                   stage_3_4    ;
    reg                   stage_3_5    ;
    reg                   stage_3_6    ;
    reg                   stage_3_7    ;
    reg                   stage_3_8    ;
    reg                   stage_3_9    ;
    reg                   stage_3_10   ;
    reg                   stage_3_11   ;
    reg                   stage_3_12   ;
    reg                   stage_3_13   ;
    reg                   stage_3_14   ;
    reg                   stage_3_15   ;
    reg                   stage_3_16   ;
    reg                   stage_3_17   ;
    reg                   stage_3_18   ;
    reg [1:0]             stage_3_19   ;
    reg [1:0]             stage_3_20   ;
    reg [1:0]             stage_3_21   ;
    reg [1:0]             stage_3_22   ;
    reg [1:0]             stage_3_23   ;
    reg [1:0]             stage_3_24   ;
    reg [1:0]             stage_3_25   ;
    reg [1:0]             stage_3_26   ;
    reg [1:0]             stage_3_27   ;
    reg [1:0]             stage_3_28   ;
    reg [1:0]             stage_3_29   ;
    reg [1:0]             stage_3_30   ;
    reg [1:0]             stage_3_31   ;
    reg [1:0]             stage_3_32   ;
    reg [1:0]             stage_3_33   ;
    reg [1:0]             stage_3_34   ;
    reg [1:0]             stage_3_35   ;
    reg [1:0]             stage_3_36   ;
    reg [1:0]             stage_3_37   ;
    reg [1:0]             stage_3_38   ;
    reg [1:0]             stage_3_39   ;
    reg [1:0]             stage_3_40   ;
    reg [1:0]             stage_3_41   ;
    reg [1:0]             stage_3_42   ;
    reg [1:0]             stage_3_43   ;
    reg [1:0]             stage_3_44   ;
    reg [1:0]             stage_3_45   ;
    reg [1:0]             stage_3_46   ;
    reg [1:0]             stage_3_47   ;
    reg [1:0]             stage_3_48   ;
    reg                   stage_3_49   ;
    reg [1:0]             stage_3_50   ;
    reg [1:0]             stage_3_51   ;
    reg [1:0]             stage_3_52   ;
    reg [1:0]             stage_3_53   ;
    reg [1:0]             stage_3_54   ;
    reg [1:0]             stage_3_55   ;
    reg [1:0]             stage_3_56   ;
    reg [1:0]             stage_3_57   ;
    reg [1:0]             stage_3_58   ;
    reg [1:0]             stage_3_59   ;
    reg [1:0]             stage_3_60   ;
    reg [1:0]             stage_3_61   ;
    reg [1:0]             stage_3_62   ;
    reg [1:0]             stage_3_63   ;
    reg [1:0]             stage_3_64   ;
    reg [1:0]             stage_3_65   ;
    reg [1:0]             stage_3_66   ;
    reg [1:0]             stage_3_67   ;
    reg [1:0]             stage_3_68   ;
    reg [1:0]             stage_3_69   ;
    reg [1:0]             stage_3_70   ;
    reg [1:0]             stage_3_71   ;
    reg [1:0]             stage_3_72   ;
    reg [1:0]             stage_3_73   ;
    reg [1:0]             stage_3_74   ;
    reg [1:0]             stage_3_75   ;
    reg [1:0]             stage_3_76   ;
    reg [1:0]             stage_3_77   ;
    reg [1:0]             stage_3_78   ;
    reg [1:0]             stage_3_79   ;
    reg [1:0]             stage_3_80   ;
    reg [1:0]             stage_3_81   ;
    reg [1:0]             stage_3_82   ;
    reg [1:0]             stage_3_83   ;
    reg [1:0]             stage_3_84   ;
    reg [1:0]             stage_3_85   ;
    reg [1:0]             stage_3_86   ;
    reg [1:0]             stage_3_87   ;
    reg [1:0]             stage_3_88   ;
    reg [1:0]             stage_3_89   ;
    reg [1:0]             stage_3_90   ;
    reg [1:0]             stage_3_91   ;
    reg [1:0]             stage_3_92   ;
    reg [1:0]             stage_3_93   ;
    reg [1:0]             stage_3_94   ;
    reg [1:0]             stage_3_95   ;
    reg [1:0]             stage_3_96   ;
    reg [1:0]             stage_3_97   ;
    reg [1:0]             stage_3_98   ;
    reg [1:0]             stage_3_99   ;
    reg [1:0]             stage_3_100   ;
    reg [1:0]             stage_3_101   ;
    reg [1:0]             stage_3_102   ;
    reg [1:0]             stage_3_103   ;
    reg [1:0]             stage_3_104   ;
    reg [1:0]             stage_3_105   ;
    reg [1:0]             stage_3_106   ;
    reg [1:0]             stage_3_107   ;
//===================================================================================//
    reg  [8:0]          stage_4_zero[0:10];
    reg  [8:0]          stage_4_one [0:10];
    reg  [18:0]         stage_4 ;
//===================================================================================// 
    reg                 stage_mode[1:8];        
    reg [31:0]          stage_2_16bit[0:3];
    reg [31:0]          stage_3_16bit[0:3];
    reg [31:0]          stage_4_16bit[0:3];
//==================================================================================//
    wire[127:0]         result_16;
    wire[127:0]         result_53;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                        MODE in pipeline                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   integer i_mo;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            for(i_mo =1 ;i_mo<9 ; i_mo = i_mo+1 )begin
                stage_mode[i_mo] <= 1'd0;
            end
        end else begin
            stage_mode[1] <= mode;
            for(i_mo=2 ; i_mo<9 ; i_mo = i_mo+1)begin
                stage_mode[i_mo] <= stage_mode[i_mo-1];
            end
        end
    end
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                        16bit mul in pipeline                                                                                     //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
                stage_2_16bit[0] <= 32'd0;
                stage_2_16bit[1] <= 32'd0;
                stage_2_16bit[2] <= 32'd0;
                stage_2_16bit[3] <= 32'd0;
        end else begin
                stage_2_16bit[0] <= stage_1_0[0];
                stage_2_16bit[1] <= stage_1_1[1];
                stage_2_16bit[2] <= stage_1_2[2];
                stage_2_16bit[3] <= stage_1_3[3];
        end
    end

    integer i3;
        always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
                for(i3=0 ; i3<4 ;i3=i3+1)begin
                    stage_3_16bit[i3] <= 32'd0;
                end
        end else begin
                for(i3=0 ; i3<4 ;i3=i3+1)begin
                    stage_3_16bit[i3] <= stage_2_16bit[i3];
                end
        end
    end

    integer i4;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
                for(i4=0 ; i4<4 ;i4=i4+1)begin
                    stage_4_16bit[i4] <= 32'd0;
                end
        end else begin
                for(i4=0 ; i4<4 ;i4=i4+1)begin
                    stage_4_16bit[i4] <= stage_3_16bit[i4];
                end
        end
    end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      partial product                                                                                                  //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


genvar j;
generate
    for (j = 0; j < 4; j = j + 1) begin : GEN_A_ASSIGN
        always @(*) begin
            A[j] = in_A[(j*16 + 15) : (j*16)];
            B[j] = in_B[(j*16 + 15) : (j*16)];
        end
    end
endgenerate


    genvar i ,m, n ,L;
    generate
        for(i=0 ; i<4 ; i=i+1 )begin : GEN_MUL16_0
            mul_16 mul_16_0(
                .in_a( A[i] ),
                .in_b( B[0] ),
                .in_valid( in_valid ),
                .out_valid( valid_16[0][i] ),
                .result( result_16_0[i] ),
                .clk( clk ),
                .rst_n( rst_n )
            );
        end
    endgenerate

    generate
        for(m=0 ; m<4 ; m=m+1 )begin : GEN_MUL16_1
            mul_16 mul_16_1(
                .in_a( A[m] ),
                .in_b( B[1] ),
                .in_valid( in_valid ),
                .out_valid( valid_16[1][m] ),
                .result( result_16_1[m] ),
                .clk( clk ),
                .rst_n( rst_n )
            );
        end
    endgenerate

    generate
        for(n=0 ; n<4 ; n=n+1 )begin : GEN_MUL16_2
            mul_16 mul_16_2(
                .in_a( A[n] ),
                .in_b( B[2] ),
                .in_valid( in_valid ),
                .out_valid( valid_16[2][n] ),
                .result( result_16_2[n] ),
                .clk( clk ),
                .rst_n( rst_n )
            );
        end
    endgenerate

    generate
        for(L=0 ; L<4 ; L=L+1 )begin : GEN_MUL16_3
            mul_16 mul_16_3(
                .in_a( A[L] ),
                .in_b( B[3] ),
                .in_valid( in_valid ),
                .out_valid( valid_16[3][L] ),
                .result( result_16_3[L] ),
                .clk( clk ),
                .rst_n( rst_n )
            );
        end
    endgenerate

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      pipeline stage 1                                                                                                 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    integer a ,b;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            for(a=0 ; a<4 ; a=a+1)begin
                stage_1_0[a] <= 32'd0;
                stage_1_1[a] <= 32'd0;
                stage_1_2[a] <= 32'd0;
                stage_1_3[a] <= 32'd0;
            end
        end else begin
            for(b=0 ; b<4 ; b=b+1)begin
                stage_1_0[b] <= result_16_0[b];
                stage_1_1[b] <= result_16_1[b];
                stage_1_2[b] <= result_16_2[b];
                stage_1_3[b] <= result_16_3[b];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            valid[1] <= 1'b0;        
        end else begin
            valid[1] <= valid_16[1][1];
        end
    end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      Wallace tree lv1                                                                                                 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    genvar c;
    generate
        for(c=16 ; c<32 ; c=c+1)begin : GEN_WALLACE_LV1
            FA FA_lv1_0(.A(stage_1_0[0][c])     , .B(stage_1_0[1][c-16])    , .Cin(stage_1_1[0][c-16] ) , .Cout(wallace_lv1[c+1][0])   , .Sum(wallace_lv1[c][1]));
            // * lave (0,0)[15:0]
            FA FA_lv1_1(.A(stage_1_1[0][c])     , .B(stage_1_0[1][c])       , .Cin(stage_1_0[2][c-16] ) , .Cout(wallace_lv1[c+17][0])  , .Sum(wallace_lv1[c+16][1]));
            HA HA_lv1_0(.A(stage_1_2[0][c-16])  , .B(stage_1_1[1][c-16] )                               , .Cout(wallace_lv1[c+17][2] ) , .Sum(wallace_lv1[c+16][3])); 
            
            FA FA_lv1_2(.A(stage_1_0[2][c])     , .B(stage_1_2[0][c])       , .Cin(stage_1_1[1][c] )    , .Cout(wallace_lv1[c+33][0])  , .Sum(wallace_lv1[c+32][1]));
            FA FA_lv1_3(.A(stage_1_0[3][c-16])  , .B(stage_1_3[0][c-16])    , .Cin(stage_1_2[1][c-16])  , .Cout(wallace_lv1[c+33][2])  , .Sum(wallace_lv1[c+32][3]));
            // * lave (1,2)[15:0]

            FA FA_lv1_4(.A(stage_1_0[3][c])     , .B(stage_1_3[0][c])       , .Cin(stage_1_2[1][c])     , .Cout(wallace_lv1[c+49][0])  , .Sum(wallace_lv1[c+48][1]));
            FA FA_lv1_5(.A(stage_1_3[1][c-16])  , .B(stage_1_1[3][c-16])    , .Cin(stage_1_2[2][c-16])  , .Cout(wallace_lv1[c+49][2])  , .Sum(wallace_lv1[c+48][3]));
            //* lave (1,2)[31;16]

            FA FA_lv1_6(.A(stage_1_3[1][c])     , .B(stage_1_1[3][c])       , .Cin(stage_1_2[2][c])     , .Cout(wallace_lv1[c+65][0])  , .Sum(wallace_lv1[c+64][1]));
            HA HA_lv1_1(.A(stage_1_3[2][c-16])  , .B(stage_1_2[3][c-16])                                , .Cout(wallace_lv1[c+65][2])  , .Sum(wallace_lv1[c+64][3]));

            FA FA_lv1_7(.A(stage_1_3[2][c])     , .B(stage_1_2[3][c])       , .Cin(stage_1_3[3][c-16])  , .Cout(wallace_lv1[c+81][0])  , .Sum(wallace_lv1[c+80][1]));

            assign wallace_lv1[c-16][0] = stage_1_0[0][c-16];
            assign wallace_lv1[c+32][4] = stage_1_1[2][c-16];
            assign wallace_lv1[c+48][4] = stage_1_1[2][c]; 
        end
    endgenerate

    assign wallace_lv1[16][0] = wallace_lv1[16][1];
    assign wallace_lv1[32][2] = wallace_lv1[32][3];

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      wallace tree lv2                                                                                                 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    genvar d,e ,f ,g ,w;
    generate
        for(d=32 ; d<97 ; d=d+1)begin : GEN_WALLACE_LV2_0
            FA FA_lv2_0(.A(wallace_lv1[d][0])  , .B(wallace_lv1[d][1]) , .Cin(wallace_lv1[d][2]) , .Cout(wallace_lv2[d+1][0]) , .Sum(wallace_lv2[d][1]));  
        end
    endgenerate

    generate
        for(e=48 ; e<80 ; e=e+1)begin : GEN_WALLACE_LV2_1
            HA HA_lv2_0(.A(wallace_lv1[e][3]) , .B(wallace_lv1[e][4]  ) , .Cout( wallace_lv2[e+1][2] ) , .Sum( wallace_lv2[e][3]));
        end    
    endgenerate

    generate
        for(g=97 ; g<108 ; g=g+1)begin : GEN_WALLACE_LV2_2
            HA HA_lv2_1(.A(wallace_lv1[g][0] ) , .B( wallace_lv1[g][1] ) , .Cout( wallace_lv2[g+1][0] ) , .Sum( wallace_lv2[g][1] ));
        end
    endgenerate

    generate
        for(f=1 ; f<16 ; f=f+1)begin : GEN_WALLACE_LV2_3
            HA HA_lv2_2(.A(wallace_lv1[f+16][0]) , .B(wallace_lv1[f+16][1]) , .Cout(wallace_lv2[f+17][0]) , .Sum(wallace_lv2[f+16][1]));
            
            assign wallace_lv2[f+32][2]     = wallace_lv1[f+32][3];
            assign wallace_lv2[f+80][2]     = wallace_lv1[f+80][3];
        end    
    endgenerate

    generate
        for(w=0 ; w<17 ; w=w+1)begin : GEN_WALLACE_1_TO_2
            assign wallace_lv2[w][0] = wallace_lv1[w][0];
        end
    endgenerate

    assign wallace_lv2[17][0]       = wallace_lv2[17][1]; // * REPEAT WALLACE_LV2[17]
    
    assign wallace_lv2[48][2]       = wallace_lv2[48][3]; // * repeat wallace_lv2[48]
    assign wallace_lv2[80][3]       = wallace_lv1[80][3];

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      pipeline stage 2                                                                                                 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    always @(posedge clk ) begin
        if(!rst_n)begin
            valid[2]   <= 1'b0;
            stage_2_0  <= 1'd0;
            stage_2_1  <= 1'd0;
            stage_2_2  <= 1'd0;
            stage_2_3  <= 1'd0;
            stage_2_4  <= 1'd0;
            stage_2_5  <= 1'd0;
            stage_2_6  <= 1'd0;
            stage_2_7  <= 1'd0;
            stage_2_8  <= 1'd0;
            stage_2_9  <= 1'd0;
            stage_2_10  <= 1'd0;
            stage_2_11  <= 1'd0;
            stage_2_12  <= 1'd0;
            stage_2_13  <= 1'd0;
            stage_2_14  <= 1'd0;
            stage_2_15  <= 1'd0;
            stage_2_16  <= 1'd0;
            stage_2_17  <= 1'd0;
            stage_2_18  <= 2'd0;
            stage_2_19  <= 2'd0;
            stage_2_20  <= 2'd0;
            stage_2_21  <= 2'd0;
            stage_2_22  <= 2'd0;
            stage_2_23  <= 2'd0;
            stage_2_24  <= 2'd0;
            stage_2_25  <= 2'd0;
            stage_2_26  <= 2'd0;
            stage_2_27  <= 2'd0;
            stage_2_28  <= 2'd0;
            stage_2_29  <= 2'd0;
            stage_2_30  <= 2'd0;
            stage_2_31  <= 2'd0;
            stage_2_32  <= 2'd0; //
            stage_2_33  <= 3'd0;
            stage_2_34  <= 3'd0;
            stage_2_35  <= 3'd0;
            stage_2_36  <= 3'd0;
            stage_2_37  <= 3'd0;
            stage_2_38  <= 3'd0;
            stage_2_39  <= 3'd0;
            stage_2_40  <= 3'd0;
            stage_2_41  <= 3'd0;
            stage_2_42  <= 3'd0;
            stage_2_43  <= 3'd0;
            stage_2_44  <= 3'd0;
            stage_2_45  <= 3'd0;
            stage_2_46  <= 3'd0;
            stage_2_47  <= 3'd0;
            stage_2_48  <= 3'd0;
            stage_2_49  <= 4'd0;
            stage_2_50  <= 4'd0;
            stage_2_51  <= 4'd0;
            stage_2_52  <= 4'd0;
            stage_2_53  <= 4'd0;
            stage_2_54  <= 4'd0;
            stage_2_55  <= 4'd0;
            stage_2_56  <= 4'd0;
            stage_2_57  <= 4'd0;
            stage_2_58  <= 4'd0;
            stage_2_59  <= 4'd0;
            stage_2_60  <= 4'd0;
            stage_2_61  <= 4'd0;
            stage_2_62  <= 4'd0;
            stage_2_63  <= 4'd0;
            stage_2_64  <= 4'd0;
            stage_2_65  <= 4'd0;
            stage_2_66  <= 4'd0;
            stage_2_67  <= 4'd0;
            stage_2_68  <= 4'd0;
            stage_2_69  <= 4'd0;
            stage_2_70  <= 4'd0;
            stage_2_71  <= 4'd0;
            stage_2_72  <= 4'd0;
            stage_2_73  <= 4'd0;
            stage_2_74  <= 4'd0;
            stage_2_75  <= 4'd0;
            stage_2_76  <= 4'd0;
            stage_2_77  <= 4'd0;
            stage_2_78  <= 4'd0;
            stage_2_79  <= 4'd0;
            stage_2_80  <= 4'd0;
            stage_2_81  <= 3'd0;
            stage_2_82  <= 3'd0;
            stage_2_83  <= 3'd0;
            stage_2_84  <= 3'd0;
            stage_2_85  <= 3'd0;
            stage_2_86  <= 3'd0;
            stage_2_87  <= 3'd0;
            stage_2_88  <= 3'd0;
            stage_2_89  <= 3'd0;
            stage_2_90  <= 3'd0;
            stage_2_91  <= 3'd0;
            stage_2_92  <= 3'd0;
            stage_2_93  <= 3'd0;
            stage_2_94  <= 3'd0;
            stage_2_95  <= 3'd0;
            stage_2_96  <= 2'd0;
            stage_2_97  <= 2'd0;
            stage_2_98  <= 2'd0;
            stage_2_99  <= 2'd0;
            stage_2_100  <= 2'd0;
            stage_2_101  <= 2'd0;
            stage_2_102  <= 2'd0;
            stage_2_103  <= 2'd0;
            stage_2_104  <= 2'd0;
            stage_2_105  <= 2'd0;
            stage_2_106  <= 2'd0;
            stage_2_107  <= 2'd0;
        end else begin
            valid[2]   <= valid[1];
            stage_2_0  <= wallace_lv2[0][0];
            stage_2_1  <= wallace_lv2[1][0];
            stage_2_2  <= wallace_lv2[2][0];
            stage_2_3  <= wallace_lv2[3][0];
            stage_2_4  <= wallace_lv2[4][0];
            stage_2_5  <= wallace_lv2[5][0];
            stage_2_6  <= wallace_lv2[6][0];
            stage_2_7  <= wallace_lv2[7][0];
            stage_2_8  <= wallace_lv2[8][0];
            stage_2_9  <= wallace_lv2[9][0];
            stage_2_10  <= wallace_lv2[10][0];
            stage_2_11  <= wallace_lv2[11][0];
            stage_2_12  <= wallace_lv2[12][0];
            stage_2_13  <= wallace_lv2[13][0];
            stage_2_14  <= wallace_lv2[14][0];
            stage_2_15  <= wallace_lv2[15][0];
            stage_2_16  <= wallace_lv2[16][0];
            stage_2_17  <= wallace_lv2[17][0];
            stage_2_18  <= wallace_lv2[18][1:0];
            stage_2_19  <= wallace_lv2[19][1:0];
            stage_2_20  <= wallace_lv2[20][1:0];
            stage_2_21  <= wallace_lv2[21][1:0];
            stage_2_22  <= wallace_lv2[22][1:0];
            stage_2_23  <= wallace_lv2[23][1:0];
            stage_2_24  <= wallace_lv2[24][1:0];
            stage_2_25  <= wallace_lv2[25][1:0];
            stage_2_26  <= wallace_lv2[26][1:0];
            stage_2_27  <= wallace_lv2[27][1:0];
            stage_2_28  <= wallace_lv2[28][1:0];
            stage_2_29  <= wallace_lv2[29][1:0];
            stage_2_30  <= wallace_lv2[30][1:0];
            stage_2_31  <= wallace_lv2[31][1:0];
            stage_2_32  <= wallace_lv2[32][1:0];
            stage_2_33  <= wallace_lv2[33][2:0];
            stage_2_34  <= wallace_lv2[34][2:0];
            stage_2_35  <= wallace_lv2[35][2:0];
            stage_2_36  <= wallace_lv2[36][2:0];
            stage_2_37  <= wallace_lv2[37][2:0];
            stage_2_38  <= wallace_lv2[38][2:0];
            stage_2_39  <= wallace_lv2[39][2:0];
            stage_2_40  <= wallace_lv2[40][2:0];
            stage_2_41  <= wallace_lv2[41][2:0];
            stage_2_42  <= wallace_lv2[42][2:0];
            stage_2_43  <= wallace_lv2[43][2:0];
            stage_2_44  <= wallace_lv2[44][2:0];
            stage_2_45  <= wallace_lv2[45][2:0];
            stage_2_46  <= wallace_lv2[46][2:0];
            stage_2_47  <= wallace_lv2[47][2:0];
            stage_2_48  <= wallace_lv2[48][2:0];
            stage_2_49  <= wallace_lv2[49][3:0];
            stage_2_50  <= wallace_lv2[50][3:0];
            stage_2_51  <= wallace_lv2[51][3:0];
            stage_2_52  <= wallace_lv2[52][3:0];
            stage_2_53  <= wallace_lv2[53][3:0];
            stage_2_54  <= wallace_lv2[54][3:0];
            stage_2_55  <= wallace_lv2[55][3:0];
            stage_2_56  <= wallace_lv2[56][3:0];
            stage_2_57  <= wallace_lv2[57][3:0];
            stage_2_58  <= wallace_lv2[58][3:0];
            stage_2_59  <= wallace_lv2[59][3:0];
            stage_2_60  <= wallace_lv2[60][3:0];
            stage_2_61  <= wallace_lv2[61][3:0];
            stage_2_62  <= wallace_lv2[62][3:0];
            stage_2_63  <= wallace_lv2[63][3:0];
            stage_2_64  <= wallace_lv2[64][3:0];
            stage_2_65  <= wallace_lv2[65][3:0];
            stage_2_66  <= wallace_lv2[66][3:0];
            stage_2_67  <= wallace_lv2[67][3:0];
            stage_2_68  <= wallace_lv2[68][3:0];
            stage_2_69  <= wallace_lv2[69][3:0];
            stage_2_70  <= wallace_lv2[70][3:0];
            stage_2_71  <= wallace_lv2[71][3:0];
            stage_2_72  <= wallace_lv2[72][3:0];
            stage_2_73  <= wallace_lv2[73][3:0];
            stage_2_74  <= wallace_lv2[74][3:0];
            stage_2_75  <= wallace_lv2[75][3:0];
            stage_2_76  <= wallace_lv2[76][3:0];
            stage_2_77  <= wallace_lv2[77][3:0];
            stage_2_78  <= wallace_lv2[78][3:0];
            stage_2_79  <= wallace_lv2[79][3:0];
            stage_2_80  <= wallace_lv2[80][3:0];
            stage_2_81  <= wallace_lv2[81][2:0];
            stage_2_82  <= wallace_lv2[82][2:0];
            stage_2_83  <= wallace_lv2[83][2:0];
            stage_2_84  <= wallace_lv2[84][2:0];
            stage_2_85  <= wallace_lv2[85][2:0];
            stage_2_86  <= wallace_lv2[86][2:0];
            stage_2_87  <= wallace_lv2[87][2:0];
            stage_2_88  <= wallace_lv2[88][2:0];
            stage_2_89  <= wallace_lv2[89][2:0];
            stage_2_90  <= wallace_lv2[90][2:0];
            stage_2_91  <= wallace_lv2[91][2:0];
            stage_2_92  <= wallace_lv2[92][2:0];
            stage_2_93  <= wallace_lv2[93][2:0];
            stage_2_94  <= wallace_lv2[94][2:0];
            stage_2_95  <= wallace_lv2[95][2:0];
            stage_2_96  <= wallace_lv2[96][1:0];
            stage_2_97  <= wallace_lv2[97][1:0];
            stage_2_98  <= wallace_lv2[98][1:0];
            stage_2_99  <= wallace_lv2[99][1:0];
            stage_2_100  <= wallace_lv2[100][1:0];
            stage_2_101  <= wallace_lv2[101][1:0];
            stage_2_102  <= wallace_lv2[102][1:0];
            stage_2_103  <= wallace_lv2[103][1:0];
            stage_2_104  <= wallace_lv2[104][1:0];
            stage_2_105  <= wallace_lv2[105][1:0];
            stage_2_106  <= wallace_lv2[106][1:0];
            stage_2_107  <= wallace_lv2[107][1:0];
        end
    end

 

//================= stage_2 data set transform ============//
    assign stage_2_array[0][0]   = stage_2_0  ;
    assign stage_2_array[1][0]   = stage_2_1  ;
    assign stage_2_array[2][0]   = stage_2_2  ;
    assign stage_2_array[3][0]   = stage_2_3  ;
    assign stage_2_array[4][0]   = stage_2_4  ;
    assign stage_2_array[5][0]   = stage_2_5  ;
    assign stage_2_array[6][0]   = stage_2_6  ;
    assign stage_2_array[7][0]   = stage_2_7  ;
    assign stage_2_array[8][0]   = stage_2_8  ;
    assign stage_2_array[9][0]   = stage_2_9  ;
    assign stage_2_array[10][0]   = stage_2_10  ;
    assign stage_2_array[11][0]   = stage_2_11  ;
    assign stage_2_array[12][0]   = stage_2_12  ;
    assign stage_2_array[13][0]   = stage_2_13  ;
    assign stage_2_array[14][0]   = stage_2_14  ;
    assign stage_2_array[15][0]   = stage_2_15  ;
    assign stage_2_array[16][0]   = stage_2_16  ;
    assign stage_2_array[17][0]   = stage_2_17  ;
    assign stage_2_array[18][1:0] = stage_2_18  ;
    assign stage_2_array[19][1:0] = stage_2_19  ;
    assign stage_2_array[20][1:0] = stage_2_20  ;
    assign stage_2_array[21][1:0] = stage_2_21  ;
    assign stage_2_array[22][1:0] = stage_2_22  ;
    assign stage_2_array[23][1:0] = stage_2_23  ;
    assign stage_2_array[24][1:0] = stage_2_24  ;
    assign stage_2_array[25][1:0] = stage_2_25  ;
    assign stage_2_array[26][1:0] = stage_2_26  ;
    assign stage_2_array[27][1:0] = stage_2_27  ;
    assign stage_2_array[28][1:0] = stage_2_28  ;
    assign stage_2_array[29][1:0] = stage_2_29  ;
    assign stage_2_array[30][1:0] = stage_2_30  ;
    assign stage_2_array[31][1:0] = stage_2_31  ;
    assign stage_2_array[32][2:0] = stage_2_32  ;
    assign stage_2_array[33][2:0] = stage_2_33  ;
    assign stage_2_array[34][2:0] = stage_2_34  ;
    assign stage_2_array[35][2:0] = stage_2_35  ;
    assign stage_2_array[36][2:0] = stage_2_36  ;
    assign stage_2_array[37][2:0] = stage_2_37  ;
    assign stage_2_array[38][2:0] = stage_2_38  ;
    assign stage_2_array[39][2:0] = stage_2_39  ;
    assign stage_2_array[40][2:0] = stage_2_40  ;
    assign stage_2_array[41][2:0] = stage_2_41  ;
    assign stage_2_array[42][2:0] = stage_2_42  ;
    assign stage_2_array[43][2:0] = stage_2_43  ;
    assign stage_2_array[44][2:0] = stage_2_44  ;
    assign stage_2_array[45][2:0] = stage_2_45  ;
    assign stage_2_array[46][2:0] = stage_2_46  ;
    assign stage_2_array[47][2:0] = stage_2_47  ;
    assign stage_2_array[48][2:0] = stage_2_48  ;
    assign stage_2_array[49][3:0] = stage_2_49  ;
    assign stage_2_array[50][3:0] = stage_2_50  ;
    assign stage_2_array[51][3:0] = stage_2_51  ;
    assign stage_2_array[52][3:0] = stage_2_52  ;
    assign stage_2_array[53][3:0] = stage_2_53  ;
    assign stage_2_array[54][3:0] = stage_2_54  ;
    assign stage_2_array[55][3:0] = stage_2_55  ;
    assign stage_2_array[56][3:0] = stage_2_56  ;
    assign stage_2_array[57][3:0] = stage_2_57  ;
    assign stage_2_array[58][3:0] = stage_2_58  ;
    assign stage_2_array[59][3:0] = stage_2_59  ;
    assign stage_2_array[60][3:0] = stage_2_60  ;
    assign stage_2_array[61][3:0] = stage_2_61  ;
    assign stage_2_array[62][3:0] = stage_2_62  ;
    assign stage_2_array[63][3:0] = stage_2_63  ;
    assign stage_2_array[64][3:0] = stage_2_64  ;
    assign stage_2_array[65][3:0] = stage_2_65  ;
    assign stage_2_array[66][3:0] = stage_2_66  ;
    assign stage_2_array[67][3:0] = stage_2_67  ;
    assign stage_2_array[68][3:0] = stage_2_68  ;
    assign stage_2_array[69][3:0] = stage_2_69  ;
    assign stage_2_array[70][3:0] = stage_2_70  ;
    assign stage_2_array[71][3:0] = stage_2_71  ;
    assign stage_2_array[72][3:0] = stage_2_72  ;
    assign stage_2_array[73][3:0] = stage_2_73  ;
    assign stage_2_array[74][3:0] = stage_2_74  ;
    assign stage_2_array[75][3:0] = stage_2_75  ;
    assign stage_2_array[76][3:0] = stage_2_76  ;
    assign stage_2_array[77][3:0] = stage_2_77  ;
    assign stage_2_array[78][3:0] = stage_2_78  ;
    assign stage_2_array[79][3:0] = stage_2_79  ;
    assign stage_2_array[80][3:0] = stage_2_80  ;
    assign stage_2_array[81][2:0] = stage_2_81  ;
    assign stage_2_array[82][2:0] = stage_2_82  ;
    assign stage_2_array[83][2:0] = stage_2_83  ;
    assign stage_2_array[84][2:0] = stage_2_84  ;
    assign stage_2_array[85][2:0] = stage_2_85  ;
    assign stage_2_array[86][2:0] = stage_2_86  ;
    assign stage_2_array[87][2:0] = stage_2_87  ;
    assign stage_2_array[88][2:0] = stage_2_88  ;
    assign stage_2_array[89][2:0] = stage_2_89  ;
    assign stage_2_array[90][2:0] = stage_2_90  ;
    assign stage_2_array[91][2:0] = stage_2_91  ;
    assign stage_2_array[92][2:0] = stage_2_92  ;
    assign stage_2_array[93][2:0] = stage_2_93  ;
    assign stage_2_array[94][2:0] = stage_2_94  ;
    assign stage_2_array[95][2:0] = stage_2_95  ;
    assign stage_2_array[96][1:0] = stage_2_96  ;
    assign stage_2_array[97][1:0] = stage_2_97  ;
    assign stage_2_array[98][1:0] = stage_2_98  ;
    assign stage_2_array[99][1:0] = stage_2_99  ;
    assign stage_2_array[100][1:0] = stage_2_100  ;
    assign stage_2_array[101][1:0] = stage_2_101  ;
    assign stage_2_array[102][1:0] = stage_2_102  ;
    assign stage_2_array[103][1:0] = stage_2_103  ;
    assign stage_2_array[104][1:0] = stage_2_104  ;
    assign stage_2_array[105][1:0] = stage_2_105  ;
    assign stage_2_array[106][1:0] = stage_2_106  ;
    assign stage_2_array[107][1:0] = stage_2_107  ;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      wallace tree lv3                                                                                                 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    genvar h , k , p , q , Q;


    generate
        for(h=19 ; h<33 ; h=h+1)begin : GEN_WALLACE_LV3_0
            HA HA_lv3_0(.A(stage_2_array[h][0]) , .B(stage_2_array[h][1]) , .Cout( wallace_lv3[h+1][0] ) , .Sum( wallace_lv3[h][1] ));
        end
    endgenerate

    generate
        for(k=33 ; k<96 ; k=k+1)begin : GEN_WALLACE_LV3_1
            FA FA_lv3_0(.A(stage_2_array[k][2])  , .B(stage_2_array[k][1]) , .Cin(stage_2_array[k][0]) , .Cout(wallace_lv3[k+1][0]) , .Sum(wallace_lv3[k][1]));  
        end
    endgenerate

    generate
        for(p=96 ; p<108 ; p=p+1)begin : GEN_WALLACE_LV3_2
            HA HA_lv3_1(.A(stage_2_array[p][0]) , .B(stage_2_array[p][1]) , .Cout( wallace_lv3[p+1][0] ) , .Sum( wallace_lv3[p][1] ));
        end
    endgenerate

    generate
        for(q=49 ; q<81 ; q=q+1)begin : GEN_WALLACE_LV3_3
            assign wallace_lv3[q][2] = stage_2_array[q][3];
        end
    endgenerate

    generate
        for(Q=0 ; Q<18 ; Q=Q+1 )begin : GEN_WALLACE_LV3_4
            assign wallace_lv3[Q][0] = stage_2_array[Q][0];
        end
    endgenerate

    HA HA_lv3 (.A(stage_2_array[18][0]) , .B(stage_2_array[18][1]) , .Cout( wallace_lv3[19][0] ) , .Sum( wallace_lv3[18][0] ));

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                      wallace tree lv4                                                                                                 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    genvar r0 ,r1;
    generate
        for(r0=50 ; r0<108 ; r0=r0+1)begin : GEN_WALLACE_LV4
            if(r0<81)begin : GEN_WALLACE_LV4_00
                FA FA_lv4_0(.A(wallace_lv3[r0][2])  , .B(wallace_lv3[r0][1]) , .Cin(wallace_lv3[r0][0]) , .Cout(wallace_lv4[r0+1][0]) , .Sum(wallace_lv4[r0][1]));  
            end else begin : GEN_WALLACE_LV4_01
                HA HA_lv4_0(.A(wallace_lv3[r0][0])  , .B(wallace_lv3[r0][1]) , .Cout(wallace_lv4[r0+1][0] ) , .Sum(wallace_lv4[r0][1]));
            end
        end
    endgenerate

    generate
        for(r1=0 ; r1<49 ; r1 = r1+1)begin : GEN_WALLACE_LV4_0
            if(r1 < 19)begin : GEN_WALLACE_LV4_02
                assign wallace_lv4[r1][0]   = wallace_lv3[r1][0];
            end else begin  : GEN_WALLACE_LV4_03
                assign wallace_lv4[r1][1:0] = wallace_lv3[r1][1:0];
            end
        end
    endgenerate

    FA FA_lv4_1(.A(wallace_lv3[49][2])  , .B(wallace_lv3[49][1]) , .Cin(wallace_lv3[49][0]) , .Cout(wallace_lv4[50][0]) , .Sum(wallace_lv4[49][0]));  

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                        pipeline stage 3                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//=====================================================================//
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            valid[3]      <=  1'b0;
            stage_3_1     <=  1'd0 ;
            stage_3_2     <=  1'd0 ;
            stage_3_3     <=  1'd0 ;
            stage_3_4     <=  1'd0 ;
            stage_3_5     <=  1'd0 ;
            stage_3_6     <=  1'd0 ;
            stage_3_7     <=  1'd0 ;
            stage_3_8     <=  1'd0 ;
            stage_3_9     <=  1'd0 ;
            stage_3_10    <=  1'd0 ;
            stage_3_11    <=  1'd0 ;
            stage_3_12    <=  1'd0 ;
            stage_3_13    <=  1'd0 ;
            stage_3_14    <=  1'd0 ;
            stage_3_15    <=  1'd0 ;
            stage_3_16    <=  1'd0 ;
            stage_3_17    <=  1'd0 ;
            stage_3_18    <=  1'd0 ;
            stage_3_19    <=  2'd0 ;
            stage_3_20    <=  2'd0 ;
            stage_3_21    <=  2'd0 ;
            stage_3_22    <=  2'd0 ;
            stage_3_23    <=  2'd0 ;
            stage_3_24    <=  2'd0 ;
            stage_3_25    <=  2'd0 ;
            stage_3_26    <=  2'd0 ;
            stage_3_27    <=  2'd0 ;
            stage_3_28    <=  2'd0 ;
            stage_3_29    <=  2'd0 ;
            stage_3_30    <=  2'd0 ;
            stage_3_31    <=  2'd0 ;
            stage_3_32    <=  2'd0 ;
            stage_3_33    <=  2'd0 ;
            stage_3_34    <=  2'd0 ;
            stage_3_35    <=  2'd0 ;
            stage_3_36    <=  2'd0 ;
            stage_3_37    <=  2'd0 ;
            stage_3_38    <=  2'd0 ;
            stage_3_39    <=  2'd0 ;
            stage_3_40    <=  2'd0 ;
            stage_3_41    <=  2'd0 ;
            stage_3_42    <=  2'd0 ;
            stage_3_43    <=  2'd0 ;
            stage_3_44    <=  2'd0 ;
            stage_3_45    <=  2'd0 ;
            stage_3_46    <=  2'd0 ;
            stage_3_47    <=  2'd0 ;
            stage_3_48    <=  2'd0 ;
            stage_3_49    <=  1'd0 ;
            stage_3_50    <=  2'd0 ;
            stage_3_51    <=  2'd0 ;
            stage_3_52    <=  2'd0;
            stage_3_53    <=  2'd0;
            stage_3_54    <=  2'd0;
            stage_3_55    <=  2'd0;
            stage_3_56    <=  2'd0;
            stage_3_57    <=  2'd0;
            stage_3_58    <=  2'd0;
            stage_3_59    <=  2'd0;
            stage_3_60    <=  2'd0;
            stage_3_61    <=  2'd0;
            stage_3_62    <=  2'd0;
            stage_3_63    <=  2'd0;
            stage_3_64    <=  2'd0;
            stage_3_65    <=  2'd0;
            stage_3_66    <=  2'd0;
            stage_3_67    <=  2'd0;
            stage_3_68    <=  2'd0;
            stage_3_69    <=  2'd0;
            stage_3_70    <=  2'd0;
            stage_3_71    <=  2'd0;
            stage_3_72    <=  2'd0;
            stage_3_73    <=  2'd0;
            stage_3_74    <=  2'd0;
            stage_3_75    <=  2'd0;
            stage_3_76    <=  2'd0;
            stage_3_77    <=  2'd0;
            stage_3_78    <=  2'd0;
            stage_3_79    <=  2'd0;
            stage_3_80    <=  2'd0;
            stage_3_81    <=  2'd0;
            stage_3_82    <=  2'd0;
            stage_3_83    <=  2'd0;
            stage_3_84    <=  2'd0;
            stage_3_85    <=  2'd0;
            stage_3_86    <=  2'd0;
            stage_3_87    <=  2'd0;
            stage_3_88    <=  2'd0;
            stage_3_89    <=  2'd0;
            stage_3_90    <=  2'd0;
            stage_3_91    <=  2'd0;
            stage_3_92    <=  2'd0;
            stage_3_93    <=  2'd0;
            stage_3_94    <=  2'd0;
            stage_3_95    <=  2'd0;
            stage_3_96    <=  2'd0;
            stage_3_97    <=  2'd0;
            stage_3_98    <=  2'd0;
            stage_3_99    <=  2'd0;
            stage_3_100   <=  2'd0;
            stage_3_101   <=  2'd0;
            stage_3_102   <=  2'd0;
            stage_3_103   <=  2'd0;
            stage_3_104   <=  2'd0;
            stage_3_105   <=  2'd0;
            stage_3_106   <=  2'd0;
            stage_3_107   <=  2'd0;  
        end else begin
            valid[3]      <=  valid[2];
            stage_3_0     <=  wallace_lv4[0][0]   ;
            stage_3_1     <=  wallace_lv4[1][0]   ;
            stage_3_2     <=  wallace_lv4[2][0]   ;
            stage_3_3     <=  wallace_lv4[3][0]   ;
            stage_3_4     <=  wallace_lv4[4][0]   ;
            stage_3_5     <=  wallace_lv4[5][0]   ;
            stage_3_6     <=  wallace_lv4[6][0]   ;
            stage_3_7     <=  wallace_lv4[7][0]   ;
            stage_3_8     <=  wallace_lv4[8][0]   ;
            stage_3_9     <=  wallace_lv4[9][0]   ;
            stage_3_10    <=  wallace_lv4[10][0]  ;
            stage_3_11    <=  wallace_lv4[11][0]  ;
            stage_3_12    <=  wallace_lv4[12][0]  ;
            stage_3_13    <=  wallace_lv4[13][0]  ;
            stage_3_14    <=  wallace_lv4[14][0]  ;
            stage_3_15    <=  wallace_lv4[15][0]  ;
            stage_3_16    <=  wallace_lv4[16][0]  ;
            stage_3_17    <=  wallace_lv4[17][0]  ;
            stage_3_18    <=  wallace_lv4[18][0]  ;
            stage_3_19    <=  wallace_lv4[19][1:0];
            stage_3_20    <=  wallace_lv4[20][1:0];
            stage_3_21    <=  wallace_lv4[21][1:0];
            stage_3_22    <=  wallace_lv4[22][1:0];
            stage_3_23    <=  wallace_lv4[23][1:0];
            stage_3_24    <=  wallace_lv4[24][1:0];
            stage_3_25    <=  wallace_lv4[25][1:0];
            stage_3_26    <=  wallace_lv4[26][1:0];
            stage_3_27    <=  wallace_lv4[27][1:0];
            stage_3_28    <=  wallace_lv4[28][1:0];
            stage_3_29    <=  wallace_lv4[29][1:0];
            stage_3_30    <=  wallace_lv4[30][1:0];
            stage_3_31    <=  wallace_lv4[31][1:0];
            stage_3_32    <=  wallace_lv4[32][1:0];
            stage_3_33    <=  wallace_lv4[33][1:0];
            stage_3_34    <=  wallace_lv4[34][1:0];
            stage_3_35    <=  wallace_lv4[35][1:0];
            stage_3_36    <=  wallace_lv4[36][1:0];
            stage_3_37    <=  wallace_lv4[37][1:0];
            stage_3_38    <=  wallace_lv4[38][1:0];
            stage_3_39    <=  wallace_lv4[39][1:0];
            stage_3_40    <=  wallace_lv4[40][1:0];
            stage_3_41    <=  wallace_lv4[41][1:0];
            stage_3_42    <=  wallace_lv4[42][1:0];
            stage_3_43    <=  wallace_lv4[43][1:0];
            stage_3_44    <=  wallace_lv4[44][1:0];
            stage_3_45    <=  wallace_lv4[45][1:0];
            stage_3_46    <=  wallace_lv4[46][1:0];
            stage_3_47    <=  wallace_lv4[47][1:0];
            stage_3_48    <=  wallace_lv4[48][1:0];
            stage_3_49    <=  wallace_lv4[49][0]  ;
            stage_3_50    <=  wallace_lv4[50][1:0];
            stage_3_51    <=  wallace_lv4[51][1:0];
            stage_3_52    <=  wallace_lv4[52][1:0];
            stage_3_53    <=  wallace_lv4[53][1:0];
            stage_3_54    <=  wallace_lv4[54][1:0];
            stage_3_55    <=  wallace_lv4[55][1:0];
            stage_3_56    <=  wallace_lv4[56][1:0];
            stage_3_57    <=  wallace_lv4[57][1:0];
            stage_3_58    <=  wallace_lv4[58][1:0];
            stage_3_59    <=  wallace_lv4[59][1:0];
            stage_3_60    <=  wallace_lv4[60][1:0];
            stage_3_61    <=  wallace_lv4[61][1:0];
            stage_3_62    <=  wallace_lv4[62][1:0];
            stage_3_63    <=  wallace_lv4[63][1:0];
            stage_3_64    <=  wallace_lv4[64][1:0];
            stage_3_65    <=  wallace_lv4[65][1:0];
            stage_3_66    <=  wallace_lv4[66][1:0];
            stage_3_67    <=  wallace_lv4[67][1:0];
            stage_3_68    <=  wallace_lv4[68][1:0];
            stage_3_69    <=  wallace_lv4[69][1:0];
            stage_3_70    <=  wallace_lv4[70][1:0];
            stage_3_71    <=  wallace_lv4[71][1:0];
            stage_3_72    <=  wallace_lv4[72][1:0];
            stage_3_73    <=  wallace_lv4[73][1:0];
            stage_3_74    <=  wallace_lv4[74][1:0];
            stage_3_75    <=  wallace_lv4[75][1:0];
            stage_3_76    <=  wallace_lv4[76][1:0];
            stage_3_77    <=  wallace_lv4[77][1:0];
            stage_3_78    <=  wallace_lv4[78][1:0];
            stage_3_79    <=  wallace_lv4[79][1:0];
            stage_3_80    <=  wallace_lv4[80][1:0];
            stage_3_81    <=  wallace_lv4[81][1:0];
            stage_3_82    <=  wallace_lv4[82][1:0];
            stage_3_83    <=  wallace_lv4[83][1:0];
            stage_3_84    <=  wallace_lv4[84][1:0];
            stage_3_85    <=  wallace_lv4[85][1:0];
            stage_3_86    <=  wallace_lv4[86][1:0];
            stage_3_87    <=  wallace_lv4[87][1:0];
            stage_3_88    <=  wallace_lv4[88][1:0];
            stage_3_89    <=  wallace_lv4[89][1:0];
            stage_3_90    <=  wallace_lv4[90][1:0];
            stage_3_91    <=  wallace_lv4[91][1:0];
            stage_3_92    <=  wallace_lv4[92][1:0];
            stage_3_93    <=  wallace_lv4[93][1:0];
            stage_3_94    <=  wallace_lv4[94][1:0];
            stage_3_95    <=  wallace_lv4[95][1:0];
            stage_3_96    <=  wallace_lv4[96][1:0];
            stage_3_97    <=  wallace_lv4[97][1:0];
            stage_3_98    <=  wallace_lv4[98][1:0];
            stage_3_99    <=  wallace_lv4[99][1:0];
            stage_3_100    <=  wallace_lv4[100][1:0];
            stage_3_101    <=  wallace_lv4[101][1:0];
            stage_3_102    <=  wallace_lv4[102][1:0];
            stage_3_103    <=  wallace_lv4[103][1:0];
            stage_3_104    <=  wallace_lv4[104][1:0];
            stage_3_105    <=  wallace_lv4[105][1:0];
            stage_3_106    <=  wallace_lv4[106][1:0];
            stage_3_107    <=  wallace_lv4[107][1:0];
        end
    end

//=====================================================================//
    assign stage_3_array[0][0]      = stage_3_0      ;
    assign stage_3_array[1][0]      = stage_3_1      ;
    assign stage_3_array[2][0]      = stage_3_2      ;
    assign stage_3_array[3][0]      = stage_3_3      ;
    assign stage_3_array[4][0]      = stage_3_4      ;
    assign stage_3_array[5][0]      = stage_3_5      ;
    assign stage_3_array[6][0]      = stage_3_6      ;
    assign stage_3_array[7][0]      = stage_3_7      ;
    assign stage_3_array[8][0]      = stage_3_8      ;
    assign stage_3_array[9][0]      = stage_3_9      ;
    assign stage_3_array[10][0]     = stage_3_10      ;
    assign stage_3_array[11][0]     = stage_3_11      ;
    assign stage_3_array[12][0]     = stage_3_12      ;
    assign stage_3_array[13][0]     = stage_3_13      ;
    assign stage_3_array[14][0]     = stage_3_14      ;
    assign stage_3_array[15][0]     = stage_3_15      ;
    assign stage_3_array[16][0]     = stage_3_16      ;
    assign stage_3_array[17][0]     = stage_3_17      ;
    assign stage_3_array[18][0]     = stage_3_18      ;
    assign stage_3_array[19][1:0]   = stage_3_19[1:0] ;
    assign stage_3_array[20][1:0]   = stage_3_20[1:0] ;
    assign stage_3_array[21][1:0]   = stage_3_21[1:0] ;
    assign stage_3_array[22][1:0]   = stage_3_22[1:0] ;
    assign stage_3_array[23][1:0]   = stage_3_23[1:0] ;
    assign stage_3_array[24][1:0]   = stage_3_24[1:0] ;
    assign stage_3_array[25][1:0]   = stage_3_25[1:0] ;
    assign stage_3_array[26][1:0]   = stage_3_26[1:0] ;
    assign stage_3_array[27][1:0]   = stage_3_27[1:0] ;
    assign stage_3_array[28][1:0]   = stage_3_28[1:0] ;
    assign stage_3_array[29][1:0]   = stage_3_29[1:0] ;
    assign stage_3_array[30][1:0]   = stage_3_30[1:0] ;
    assign stage_3_array[31][1:0]   = stage_3_31[1:0] ;
    assign stage_3_array[32][1:0]   = stage_3_32[1:0] ;
    assign stage_3_array[33][1:0]   = stage_3_33[1:0] ;
    assign stage_3_array[34][1:0]   = stage_3_34[1:0] ;
    assign stage_3_array[35][1:0]   = stage_3_35[1:0] ;
    assign stage_3_array[36][1:0]   = stage_3_36[1:0] ;
    assign stage_3_array[37][1:0]   = stage_3_37[1:0] ;
    assign stage_3_array[38][1:0]   = stage_3_38[1:0] ;
    assign stage_3_array[39][1:0]   = stage_3_39[1:0] ;
    assign stage_3_array[40][1:0]   = stage_3_40[1:0] ;
    assign stage_3_array[41][1:0]   = stage_3_41[1:0] ;
    assign stage_3_array[42][1:0]   = stage_3_42[1:0] ;
    assign stage_3_array[43][1:0]   = stage_3_43[1:0] ;
    assign stage_3_array[44][1:0]   = stage_3_44[1:0] ;
    assign stage_3_array[45][1:0]   = stage_3_45[1:0] ;
    assign stage_3_array[46][1:0]   = stage_3_46[1:0] ;
    assign stage_3_array[47][1:0]   = stage_3_47[1:0] ;
    assign stage_3_array[48][1:0]   = stage_3_48[1:0] ;
    assign stage_3_array[49][0]     = stage_3_49      ;
    assign stage_3_array[50][1:0]   = stage_3_50[1:0] ;
    assign stage_3_array[51][1:0]   = stage_3_51[1:0] ;
    assign stage_3_array[52][1:0]   = stage_3_52[1:0] ;
    assign stage_3_array[53][1:0]   = stage_3_53[1:0] ;
    assign stage_3_array[54][1:0]   = stage_3_54[1:0] ;
    assign stage_3_array[55][1:0]   = stage_3_55[1:0] ;
    assign stage_3_array[56][1:0]   = stage_3_56[1:0] ;
    assign stage_3_array[57][1:0]   = stage_3_57[1:0] ;
    assign stage_3_array[58][1:0]   = stage_3_58[1:0] ;
    assign stage_3_array[59][1:0]   = stage_3_59[1:0] ;
    assign stage_3_array[60][1:0]   = stage_3_60[1:0] ;
    assign stage_3_array[61][1:0]   = stage_3_61[1:0] ;
    assign stage_3_array[62][1:0]   = stage_3_62[1:0] ;
    assign stage_3_array[63][1:0]   = stage_3_63[1:0] ;
    assign stage_3_array[64][1:0]   = stage_3_64[1:0] ;
    assign stage_3_array[65][1:0]   = stage_3_65[1:0] ;
    assign stage_3_array[66][1:0]   = stage_3_66[1:0] ;
    assign stage_3_array[67][1:0]   = stage_3_67[1:0] ;
    assign stage_3_array[68][1:0]   = stage_3_68[1:0] ;
    assign stage_3_array[69][1:0]   = stage_3_69[1:0] ;
    assign stage_3_array[70][1:0]   = stage_3_70[1:0] ;
    assign stage_3_array[71][1:0]   = stage_3_71[1:0] ;
    assign stage_3_array[72][1:0]   = stage_3_72[1:0] ;
    assign stage_3_array[73][1:0]   = stage_3_73[1:0] ;
    assign stage_3_array[74][1:0]   = stage_3_74[1:0] ;
    assign stage_3_array[75][1:0]   = stage_3_75[1:0] ;
    assign stage_3_array[76][1:0]   = stage_3_76[1:0] ;
    assign stage_3_array[77][1:0]   = stage_3_77[1:0] ;
    assign stage_3_array[78][1:0]   = stage_3_78[1:0] ;
    assign stage_3_array[79][1:0]   = stage_3_79[1:0] ;
    assign stage_3_array[80][1:0]   = stage_3_80[1:0] ;
    assign stage_3_array[81][1:0]   = stage_3_81[1:0] ;
    assign stage_3_array[82][1:0]   = stage_3_82[1:0] ;
    assign stage_3_array[83][1:0]   = stage_3_83[1:0] ;
    assign stage_3_array[84][1:0]   = stage_3_84[1:0] ;
    assign stage_3_array[85][1:0]   = stage_3_85[1:0] ;
    assign stage_3_array[86][1:0]   = stage_3_86[1:0] ;
    assign stage_3_array[87][1:0]   = stage_3_87[1:0] ;
    assign stage_3_array[88][1:0]   = stage_3_88[1:0] ;
    assign stage_3_array[89][1:0]   = stage_3_89[1:0] ;
    assign stage_3_array[90][1:0]   = stage_3_90[1:0] ;
    assign stage_3_array[91][1:0]   = stage_3_91[1:0] ;
    assign stage_3_array[92][1:0]   = stage_3_92[1:0] ;
    assign stage_3_array[93][1:0]   = stage_3_93[1:0] ;
    assign stage_3_array[94][1:0]   = stage_3_94[1:0] ;
    assign stage_3_array[95][1:0]   = stage_3_95[1:0] ;
    assign stage_3_array[96][1:0]   = stage_3_96[1:0] ;
    assign stage_3_array[97][1:0]   = stage_3_97[1:0] ;
    assign stage_3_array[98][1:0]   = stage_3_98[1:0] ;
    assign stage_3_array[99][1:0]   = stage_3_99[1:0] ;
    assign stage_3_array[100][1:0]  = stage_3_100[1:0] ;
    assign stage_3_array[101][1:0]  = stage_3_101[1:0] ;
    assign stage_3_array[102][1:0]  = stage_3_102[1:0] ;
    assign stage_3_array[103][1:0]  = stage_3_103[1:0] ;
    assign stage_3_array[104][1:0]  = stage_3_104[1:0] ;
    assign stage_3_array[105][1:0]  = stage_3_105[1:0] ;
    assign stage_3_array[106][1:0]  = stage_3_106[1:0] ;
    assign stage_3_array[107][1:0]  = stage_3_107[1:0] ;


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                        Use CLA to prediction result                                                                                   //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign last_lv_A = { 
            stage_3_array[107][0] ,
            stage_3_array[106][0] ,
            stage_3_array[105][0] ,
            stage_3_array[104][0] ,
            stage_3_array[103][0] ,
            stage_3_array[102][0] ,
            stage_3_array[101][0] ,
            stage_3_array[100][0] ,
            stage_3_array[99][0] ,
            stage_3_array[98][0] ,
            stage_3_array[97][0] ,
            stage_3_array[96][0] ,
            stage_3_array[95][0] ,
            stage_3_array[94][0] ,
            stage_3_array[93][0] ,
            stage_3_array[92][0] ,
            stage_3_array[91][0] ,
            stage_3_array[90][0] ,
            stage_3_array[89][0] ,
            stage_3_array[88][0] ,
            stage_3_array[87][0] ,
            stage_3_array[86][0] ,
            stage_3_array[85][0] ,
            stage_3_array[84][0] ,
            stage_3_array[83][0] ,
            stage_3_array[82][0] ,
            stage_3_array[81][0] ,
            stage_3_array[80][0] ,
            stage_3_array[79][0] ,
            stage_3_array[78][0] ,
            stage_3_array[77][0] ,
            stage_3_array[76][0] ,
            stage_3_array[75][0] ,
            stage_3_array[74][0] ,
            stage_3_array[73][0] ,
            stage_3_array[72][0] ,
            stage_3_array[71][0] ,
            stage_3_array[70][0] ,
            stage_3_array[69][0] ,
            stage_3_array[68][0] ,
            stage_3_array[67][0] ,
            stage_3_array[66][0] ,
            stage_3_array[65][0] ,
            stage_3_array[64][0] ,
            stage_3_array[63][0] ,
            stage_3_array[62][0] ,
            stage_3_array[61][0] ,
            stage_3_array[60][0] ,
            stage_3_array[59][0] ,
            stage_3_array[58][0] ,
            stage_3_array[57][0] ,
            stage_3_array[56][0] ,
            stage_3_array[55][0] ,
            stage_3_array[54][0] ,
            stage_3_array[53][0] ,
            stage_3_array[52][0] ,
            stage_3_array[51][0] ,
            stage_3_array[50][0] ,
            stage_3_array[49][0] ,
            stage_3_array[48][0] ,
            stage_3_array[47][0] ,
            stage_3_array[46][0] ,
            stage_3_array[45][0] ,
            stage_3_array[44][0] ,
            stage_3_array[43][0] ,
            stage_3_array[42][0] ,
            stage_3_array[41][0] ,
            stage_3_array[40][0] ,
            stage_3_array[39][0] ,
            stage_3_array[38][0] ,
            stage_3_array[37][0] ,
            stage_3_array[36][0] ,
            stage_3_array[35][0] ,
            stage_3_array[34][0] ,
            stage_3_array[33][0] ,
            stage_3_array[32][0] ,
            stage_3_array[31][0] ,
            stage_3_array[30][0] ,
            stage_3_array[29][0] ,
            stage_3_array[28][0] ,
            stage_3_array[27][0] ,
            stage_3_array[26][0] ,
            stage_3_array[25][0] ,
            stage_3_array[24][0] ,
            stage_3_array[23][0] ,
            stage_3_array[22][0] ,
            stage_3_array[21][0] ,
            stage_3_array[20][0] ,
            stage_3_array[19][0] ,
            stage_3_array[18][0] ,
            stage_3_array[17][0] ,
            stage_3_array[16][0] ,
            stage_3_array[15][0] ,
            stage_3_array[14][0] ,
            stage_3_array[13][0] ,
            stage_3_array[12][0] ,
            stage_3_array[11][0] ,
            stage_3_array[10][0] ,
            stage_3_array[9][0] ,
            stage_3_array[8][0] ,
            stage_3_array[7][0] ,
            stage_3_array[6][0] ,
            stage_3_array[5][0] ,
            stage_3_array[4][0] ,
            stage_3_array[3][0] ,
            stage_3_array[2][0] ,
            stage_3_array[1][0] ,
            stage_3_array[0][0]   
    };

    assign last_lv_B = {
            stage_3_array[107][1] ,
            stage_3_array[106][1] ,
            stage_3_array[105][1] ,
            stage_3_array[104][1] ,
            stage_3_array[103][1] ,
            stage_3_array[102][1] ,
            stage_3_array[101][1] ,
            stage_3_array[100][1] ,
            stage_3_array[99][1] ,
            stage_3_array[98][1] ,
            stage_3_array[97][1] ,
            stage_3_array[96][1] ,
            stage_3_array[95][1] ,
            stage_3_array[94][1] ,
            stage_3_array[93][1] ,
            stage_3_array[92][1] ,
            stage_3_array[91][1] ,
            stage_3_array[90][1] ,
            stage_3_array[89][1] ,
            stage_3_array[88][1] ,
            stage_3_array[87][1] ,
            stage_3_array[86][1] ,
            stage_3_array[85][1] ,
            stage_3_array[84][1] ,
            stage_3_array[83][1] ,
            stage_3_array[82][1] ,
            stage_3_array[81][1] ,
            stage_3_array[80][1] ,
            stage_3_array[79][1] ,
            stage_3_array[78][1] ,
            stage_3_array[77][1] ,
            stage_3_array[76][1] ,
            stage_3_array[75][1] ,
            stage_3_array[74][1] ,
            stage_3_array[73][1] ,
            stage_3_array[72][1] ,
            stage_3_array[71][1] ,
            stage_3_array[70][1] ,
            stage_3_array[69][1] ,
            stage_3_array[68][1] ,
            stage_3_array[67][1] ,
            stage_3_array[66][1] ,
            stage_3_array[65][1] ,
            stage_3_array[64][1] ,
            stage_3_array[63][1] ,
            stage_3_array[62][1] ,
            stage_3_array[61][1] ,
            stage_3_array[60][1] ,
            stage_3_array[59][1] ,
            stage_3_array[58][1] ,
            stage_3_array[57][1] ,
            stage_3_array[56][1] ,
            stage_3_array[55][1] ,
            stage_3_array[54][1] ,
            stage_3_array[53][1] ,
            stage_3_array[52][1] ,
            stage_3_array[51][1] ,
            stage_3_array[50][1] ,
            1'd0 ,
            stage_3_array[48][1] ,
            stage_3_array[47][1] ,
            stage_3_array[46][1] ,
            stage_3_array[45][1] ,
            stage_3_array[44][1] ,
            stage_3_array[43][1] ,
            stage_3_array[42][1] ,
            stage_3_array[41][1] ,
            stage_3_array[40][1] ,
            stage_3_array[39][1] ,
            stage_3_array[38][1] ,
            stage_3_array[37][1] ,
            stage_3_array[36][1] ,
            stage_3_array[35][1] ,
            stage_3_array[34][1] ,
            stage_3_array[33][1] ,
            stage_3_array[32][1] ,
            stage_3_array[31][1] ,
            stage_3_array[30][1] ,
            stage_3_array[29][1] ,
            stage_3_array[28][1] ,
            stage_3_array[27][1] ,
            stage_3_array[26][1] ,
            stage_3_array[25][1] ,
            stage_3_array[24][1] ,
            stage_3_array[23][1] ,
            stage_3_array[22][1] ,
            stage_3_array[21][1] ,
            stage_3_array[20][1] ,
            stage_3_array[19][1] ,
            19'd0
    };

    assign logic_one   =  1'b1;
    assign logic_zero  =  1'b0;
    
    genvar s ;
    generate 
        for(s = 0 ; s < 11 ; s = s+1)begin : GEN_CLA_8
            CLA_8 CLA_one  (.A( last_lv_A[ s*8+26 : s*8+19 ] ) , .B( last_lv_B[s*8+26 : s*8+19] ) , .Cin( logic_one  ) , .result( result_one [s] ));
            CLA_8 CLA_zero (.A( last_lv_A[ s*8+26 : s*8+19 ] ) , .B( last_lv_B[s*8+26 : s*8+19] ) , .Cin( logic_zero ) , .result( result_zero[s] ));
        end    
    endgenerate


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                  Pipeline stage 4                                                                                     //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    integer u , v;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            for(u=0 ; u<11 ; u=u+1)begin
                stage_4_zero[u]  <= 9'd0 ;
                stage_4_one[u]   <= 9'd0 ;
            end                          
        end else begin
            for(v=0 ; v<11 ; v=v+1)begin
                stage_4_zero[v]  <= result_zero[v] ;
                stage_4_one[v]   <= result_one[v]  ;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            valid[4]  <= 1'b0     ;
            stage_4   <= 19'd0    ;
        end else begin
            valid[4]  <= valid[3]        ;
            stage_4   <= last_lv_A[18:0] ;
        end
    end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                  Resilt select                                                                                        //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign out_valid    =  valid[4]; 
    assign r[0]         =  stage_4_zero[0];
    assign r[1]         =  ( r[0][8])? stage_4_one[1] : stage_4_zero[1];
    assign r[2]         =  ( r[1][8])? stage_4_one[2] : stage_4_zero[2];  
    assign r[3]         =  ( r[2][8])? stage_4_one[3] : stage_4_zero[3];
    assign r[4]         =  ( r[3][8])? stage_4_one[4] : stage_4_zero[4];
    assign r[5]         =  ( r[4][8])? stage_4_one[5] : stage_4_zero[5];
    assign r[6]         =  ( r[5][8])? stage_4_one[6] : stage_4_zero[6];
    assign r[7]         =  ( r[6][8])? stage_4_one[7] : stage_4_zero[7];
    assign r[8]         =  ( r[7][8])? stage_4_one[8] : stage_4_zero[8];
    assign r[9]         =  ( r[8][8])? stage_4_one[9] : stage_4_zero[9];
    assign r[10]        =  ( r[9][8])? stage_4_one[10]: stage_4_zero[10];
    

    assign result_53 = {21'd0 , r[10][7:0] , r[9][7:0] , r[8][7:0] , r[7][7:0] , r[6][7:0] , r[5][7:0] , r[4][7:0] , r[3][7:0] , r[2][7:0] , r[1][7:0] , r[0][7:0] , stage_4 };
    assign result_16 = {stage_4_16bit[3] , stage_4_16bit[2] , stage_4_16bit[1] , stage_4_16bit[0] };

    assign result = (stage_mode[8])? result_16 : result_53;

endmodule


