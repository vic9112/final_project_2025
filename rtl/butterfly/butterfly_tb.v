`timescale 1ns/1ps

//`define FSDB
`define CLK_PERIOD 10

module butterfly_tb();

localparam FFT_MODE  =  3'b000;
localparam IFFT_MODE =  3'b001;
localparam NTT_MODE  =  3'b010;
localparam INTT_MODE =  3'b011;
localparam NTM_MODE  =  3'b100;
localparam MTN_MODE  =  3'b101;
localparam MTND_MODE =  3'b110;

`ifdef FSDB
    initial begin
        $fsdbDumpfile("butterfly.fsdb");
        $fsdbDumpvars("+mda");
    end
`else
    initial begin
        $dumpfile("butterfly.vcd");
        $dumpvars();
    end
`endif

//------- input port --------//
    reg [127:0]     A_in;
    reg [127:0]     B_in;
    reg [127:0]     G_in;
    reg [2:0]       mode;
    reg             in_valid;
    wire            in_ready;
//------- output port --------//
    wire            out_valid;
    reg             out_ready;
    wire[127:0]     A_out;
    wire[127:0]     B_out;
    reg             clk;
    reg             rst_n;
//----------------------------//
//------- debug signal -------//
    reg [3:0]       switch_count = 0;
//----------------------------//
localparam PAT_NUM = 200;

butterfly BUTTERFLY_DUT(
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode), // FFT/iFFT/NTT/iNTT
    .i_vld(in_valid),
    .i_rdy(in_ready),
    .o_vld(out_valid),
    .o_rdy(out_ready),
    .ai(A_in),
    .bi(B_in),
    .gm(G_in), // constant
    .ao(A_out),
    .bo(B_out)
    );



    initial begin
        clk = 0;
        forever begin
            #(`CLK_PERIOD/2)  clk = (~clk);
        end
    end

    integer timeout = (1000000);
    initial begin
        while(timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        $display($time, "Simualtion Hang ....");
        $finish;
    end

    initial begin
        rst_n <= 1;
        @(negedge clk);
        #2
        rst_n <= 0; 
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        rst_n <= 1;
    end

// * input data
    integer Din_a_FFT  , Din_b_FFT  , Din_g_FFT   , Din_a_NTT   , Din_b_NTT  , Din_g_NTT   ;
    integer Din_a_iFFT , Din_b_iFFT , Din_g_iFFT  , Din_a_iNTT  , Din_b_iNTT , Din_g_iNTT  ;
// * golden result
    integer Gin_a_FFT  , Gin_b_FFT  , Gin_a_NTT  , Gin_b_NTT ;
    integer Gin_a_iFFT , Gin_b_iFFT , Gin_a_iNTT , Gin_b_iNTT ;

    integer din_ntt [0:2]     , din_fft [0:2];
    integer din_intt[0:2]     , din_ifft[0:2];
    integer golden_ntt [0:1]  , golden_fft [0:1];
    integer golden_intt[0:1]  , golden_ifft[0:1];
    integer m ;


    reg[127:0]   FFT_Ai_list     [0:(PAT_NUM-1)];
    reg[127:0]   FFT_Bi_list     [0:(PAT_NUM-1)];
    reg[127:0]   FFT_Gi_list     [0:(PAT_NUM-1)];
    
    reg[127:0]   iFFT_Ai_list    [0:(PAT_NUM-1)];
    reg[127:0]   iFFT_Bi_list    [0:(PAT_NUM-1)];
    reg[127:0]   iFFT_Gi_list    [0:(PAT_NUM-1)];

    reg[127:0]   NTT_Ai_list     [0:(PAT_NUM-1)];
    reg[127:0]   NTT_Bi_list     [0:(PAT_NUM-1)];
    reg[127:0]   NTT_Gi_list     [0:(PAT_NUM-1)];

    reg[127:0]   iNTT_Ai_list    [0:(PAT_NUM-1)];
    reg[127:0]   iNTT_Bi_list    [0:(PAT_NUM-1)];
    reg[127:0]   iNTT_Gi_list    [0:(PAT_NUM-1)];

    reg[127:0]   FFT_A_golden_list  [0:(PAT_NUM-1)];
    reg[127:0]   FFT_B_golden_list  [0:(PAT_NUM-1)];

    reg[127:0]   iFFT_A_golden_list [0:(PAT_NUM-1)];
    reg[127:0]   iFFT_B_golden_list [0:(PAT_NUM-1)];

    reg[127:0]   NTT_A_golden_list  [0:(PAT_NUM-1)];
    reg[127:0]   NTT_B_golden_list  [0:(PAT_NUM-1)];

    reg[127:0]   iNTT_A_golden_list [0:(PAT_NUM-1)];
    reg[127:0]   iNTT_B_golden_list [0:(PAT_NUM-1)];


    integer Din_a_NTM  , Din_b_NTM  , Din_g_NTM;
    integer Din_a_MTN  , Din_b_MTN  , Din_g_MTN;
    integer Din_a_MTND , Din_b_MTND , Din_g_MTND;

    integer Gin_a_NTM  , Gin_b_NTM;
    integer Gin_a_MTN  , Gin_b_MTN;
    integer Gin_a_MTND , Gin_b_MTND;

    integer din_ntm [0:2], din_mtn [0:2], din_mtnd [0:2];
    integer golden_ntm[0:1], golden_mtn[0:1], golden_mtnd[0:1];

    reg[127:0]   NTM_Ai_list   [0:(PAT_NUM-1)];
    reg[127:0]   NTM_Bi_list   [0:(PAT_NUM-1)];
    reg[127:0]   NTM_Gi_list   [0:(PAT_NUM-1)];

    reg[127:0]   MTN_Ai_list   [0:(PAT_NUM-1)];
    reg[127:0]   MTN_Bi_list   [0:(PAT_NUM-1)];
    reg[127:0]   MTN_Gi_list   [0:(PAT_NUM-1)];

    reg[127:0]   MTND_Ai_list  [0:(PAT_NUM-1)];
    reg[127:0]   MTND_Bi_list  [0:(PAT_NUM-1)];
    reg[127:0]   MTND_Gi_list  [0:(PAT_NUM-1)];

    reg[127:0]   NTM_A_golden_list  [0:(PAT_NUM-1)];
    reg[127:0]   NTM_B_golden_list  [0:(PAT_NUM-1)];

    reg[127:0]   MTN_A_golden_list  [0:(PAT_NUM-1)];
    reg[127:0]   MTN_B_golden_list  [0:(PAT_NUM-1)];

    reg[127:0]   MTND_A_golden_list [0:(PAT_NUM-1)];
    reg[127:0]   MTND_B_golden_list [0:(PAT_NUM-1)];

// set pattern //
    initial begin
        // fft pat
        Din_a_FFT  = $fopen("./FFT_pat/a_in.dat" ,"r");
        Din_b_FFT  = $fopen("./FFT_pat/b_in.dat" ,"r");
        Din_g_FFT  = $fopen("./FFT_pat/g_in.dat" ,"r");
        
        // ifft pat
        Din_a_iFFT = $fopen("./iFFT_pat/a_in.dat" ,"r");
        Din_b_iFFT = $fopen("./iFFT_pat/b_in.dat" ,"r");
        Din_g_iFFT = $fopen("./iFFT_pat/g_in.dat" ,"r");

        // ntt pat
        Din_a_NTT  = $fopen("./NTT_pat/ntt_ai.dat" ,"r");
        Din_b_NTT  = $fopen("./NTT_pat/ntt_bi.dat" , "r");
        Din_g_NTT  = $fopen("./NTT_pat/ntt_gm.dat" , "r");
        
        // intt pat
        Din_a_iNTT = $fopen("./iNTT_pat/ntt_ai.dat" ,"r");
        Din_b_iNTT = $fopen("./iNTT_pat/ntt_bi.dat" , "r");
        Din_g_iNTT = $fopen("./iNTT_pat/ntt_gm.dat" , "r");
        
        // fft golden
        Gin_a_FFT = $fopen("./FFT_pat/golden_a.dat" , "r");
        Gin_b_FFT = $fopen("./FFT_pat/golden_b.dat" , "r");

        // ifft golden
        Gin_a_iFFT = $fopen("./iFFT_pat/golden_a.dat" , "r");
        Gin_b_iFFT = $fopen("./iFFT_pat/golden_b.dat" , "r");
        
        // ntt golden
        Gin_a_NTT = $fopen("./NTT_pat/ntt_ao.dat" , "r");
        Gin_b_NTT = $fopen("./NTT_pat/ntt_bo.dat" , "r");

        // intt golden
        Gin_a_iNTT = $fopen("./iNTT_pat/ntt_ao.dat" , "r");
        Gin_b_iNTT = $fopen("./iNTT_pat/ntt_bo.dat" , "r");

        // ntm pat
        Din_a_NTM  = $fopen("./NTM_pat/ntm_ai.dat" ,"r");
        Din_b_NTM  = $fopen("./NTM_pat/ntm_bi.dat" , "r");
        Din_g_NTM  = $fopen("./NTM_pat/ntm_gm.dat" , "r");

        // mtn pat
        Din_a_MTN  = $fopen("./MTN_pat/mtn_ai.dat" ,"r");
        Din_b_MTN  = $fopen("./MTN_pat/mtn_bi.dat" , "r");
        Din_g_MTN  = $fopen("./MTN_pat/mtn_gm.dat" , "r");

        // mtnd pat
        Din_a_MTND = $fopen("./MTND_pat/mtnd_ai.dat" ,"r");
        Din_b_MTND = $fopen("./MTND_pat/mtnd_bi.dat" , "r");
        Din_g_MTND = $fopen("./MTND_pat/mtnd_gm.dat" , "r");

        // ntm golden
        Gin_a_NTM  = $fopen("./NTM_pat/ntm_ao.dat" , "r");
        Gin_b_NTM  = $fopen("./NTM_pat/ntm_bo.dat" , "r");

        // mtn golden
        Gin_a_MTN  = $fopen("./MTN_pat/mtn_ao.dat" , "r");
        Gin_b_MTN  = $fopen("./MTN_pat/mtn_bo.dat" , "r");

        // mtnd golden
        Gin_a_MTND = $fopen("./MTND_pat/mtnd_ao.dat" , "r");
        Gin_b_MTND = $fopen("./MTND_pat/mtnd_bo.dat" , "r");



        if ((Din_a_FFT == 0) || (Din_b_FFT == 0) || (Din_g_FFT == 0) || (Gin_a_FFT == 0) || (Gin_b_FFT == 0) ) begin
            $display("[ERROR] Failed to load FFT pattern files .....   (Q_Q) ");
            $finish;
        end else if ((Din_a_iFFT == 0) || (Din_b_iFFT == 0) || (Din_g_iFFT == 0) || (Gin_a_iFFT == 0) || (Gin_b_iFFT == 0) )begin
            $display("[ERROR] Failed to load iFFT pattern files .....   (Q_Q) ");
            $finish;
        end else if ((Din_a_NTT == 0)  || (Din_b_NTT == 0)  || (Din_g_NTT == 0)  || (Gin_a_NTT == 0)  || (Gin_b_NTT == 0) ) begin
            $display("[ERROR] Failed to load NTT pattern files .....   (Q_Q) ");
            $finish;
        end else if ((Din_a_iNTT == 0) || (Din_b_iNTT == 0) || (Din_g_iNTT == 0) || (Gin_a_iNTT == 0) || (Gin_b_iNTT == 0) )begin
            $display("[ERROR] Failed to load iNTT pattern files .....   (Q_Q) ");
            $finish;
        end else if ((Din_a_NTM==0)||(Din_b_NTM==0)||(Din_g_NTM==0)||(Gin_a_NTM==0)||(Gin_b_NTM==0)) begin
            $display("[ERROR] Failed to load NTM pattern files .....   (Q_Q) ");
            $finish;
        end else if ((Din_a_MTN==0)||(Din_b_MTN==0)||(Din_g_MTN==0)||(Gin_a_MTN==0)||(Gin_b_MTN==0)) begin
            $display("[ERROR] Failed to load MTN pattern files .....   (Q_Q) ");
            $finish;
        end else if ((Din_a_MTND==0)||(Din_b_MTND==0)||(Din_g_MTND==0)||(Gin_a_MTND==0)||(Gin_b_MTND==0)) begin
            $display("[ERROR] Failed to load MTND pattern files .....  (Q_Q) ");
            $finish;
        end else begin    
            for(m=0 ; m<PAT_NUM ;m=m+1)begin
                // fft pat
                din_fft[0]      = $fscanf(Din_a_FFT , "%h" , FFT_Ai_list[m]);
                din_fft[1]      = $fscanf(Din_b_FFT , "%h" , FFT_Bi_list[m]);
                din_fft[2]      = $fscanf(Din_g_FFT , "%h" , FFT_Gi_list[m]);

                // ifft pat
                din_ifft[0]     = $fscanf(Din_a_iFFT , "%h" , iFFT_Ai_list[m]);
                din_ifft[1]     = $fscanf(Din_b_iFFT , "%h" , iFFT_Bi_list[m]);
                din_ifft[2]     = $fscanf(Din_g_iFFT , "%h" , iFFT_Gi_list[m]);

                // ntt pat
                din_ntt[0]      = $fscanf(Din_a_NTT , "%h" , NTT_Ai_list[m]);
                din_ntt[1]      = $fscanf(Din_b_NTT , "%h" , NTT_Bi_list[m]);
                din_ntt[2]      = $fscanf(Din_g_NTT , "%h" , NTT_Gi_list[m]);
               
               // intt pat
                din_intt[0]     = $fscanf(Din_a_iNTT , "%h" , iNTT_Ai_list[m]);
                din_intt[1]     = $fscanf(Din_b_iNTT , "%h" , iNTT_Bi_list[m]);
                din_intt[2]     = $fscanf(Din_g_iNTT , "%h" , iNTT_Gi_list[m]);

                // fft golden
                golden_fft[0]   = $fscanf(Gin_a_FFT , "%h" , FFT_A_golden_list[m]); 
                golden_fft[1]   = $fscanf(Gin_b_FFT , "%h" , FFT_B_golden_list[m]);

                // ifft golden
                golden_ifft[0]  = $fscanf(Gin_a_iFFT , "%h" , iFFT_A_golden_list[m]); 
                golden_ifft[1]  = $fscanf(Gin_b_iFFT , "%h" , iFFT_B_golden_list[m]);

                // ntt golden
                golden_ntt[0]   = $fscanf(Gin_a_NTT , "%h" , NTT_A_golden_list[m]);
                golden_ntt[1]   = $fscanf(Gin_b_NTT , "%h" , NTT_B_golden_list[m]);

                // intt golden
                golden_intt[0]  = $fscanf(Gin_a_iNTT , "%h" , iNTT_A_golden_list[m]);
                golden_intt[1]  = $fscanf(Gin_b_iNTT , "%h" , iNTT_B_golden_list[m]);

                // ntm pat
                din_ntm[0] = $fscanf(Din_a_NTM , "%h" , NTM_Ai_list[m]);
                din_ntm[1] = $fscanf(Din_b_NTM , "%h" , NTM_Bi_list[m]);
                din_ntm[2] = $fscanf(Din_g_NTM , "%h" , NTM_Gi_list[m]);

                // mtn pat
                din_mtn[0] = $fscanf(Din_a_MTN , "%h" , MTN_Ai_list[m]);
                din_mtn[1] = $fscanf(Din_b_MTN , "%h" , MTN_Bi_list[m]);
                din_mtn[2] = $fscanf(Din_g_MTN , "%h" , MTN_Gi_list[m]);

                // mtnd pat
                din_mtnd[0] = $fscanf(Din_a_MTND , "%h" , MTND_Ai_list[m]);
                din_mtnd[1] = $fscanf(Din_b_MTND , "%h" , MTND_Bi_list[m]);
                din_mtnd[2] = $fscanf(Din_g_MTND , "%h" , MTND_Gi_list[m]);

                // ntm golden
                golden_ntm[0] = $fscanf(Gin_a_NTM , "%h" , NTM_A_golden_list[m]);
                golden_ntm[1] = $fscanf(Gin_b_NTM , "%h" , NTM_B_golden_list[m]);

                // mtn golden
                golden_mtn[0] = $fscanf(Gin_a_MTN , "%h" , MTN_A_golden_list[m]);
                golden_mtn[1] = $fscanf(Gin_b_MTN , "%h" , MTN_B_golden_list[m]);

                // mtnd golden
                golden_mtnd[0] = $fscanf(Gin_a_MTND , "%h" , MTND_A_golden_list[m]);
                golden_mtnd[1] = $fscanf(Gin_b_MTND , "%h" , MTND_B_golden_list[m]);

            end
        end
        $display("------------------ Pattern initializeation done , start simulation  ---------------------------");
    end

//
    integer i;
    integer first_switch    = 50;  // * latency between  ntt  ->  fft  (slowly switch)
    integer second_switch   = 50;  // * latency between  fft  ->  intt (slowly switch)
    integer third_switch    = 50;  // * latency between  intt ->  ifft (slowly switch)
    integer forth_switch    = 50;  // * latency between  ifft ->  ntt  (slowly switch)

    integer fifth_switch    = 4 ;  // * latency betewwn  ntt  ->  fft  (fast switch)
    integer sixth_switch    = 22;  // * latency between  fft  ->  intt (fast switch)
    integer seventh_switch  = 22;  // * latency betewwn  intt ->  ifft (fast switch)
    integer eighth_switch   = 4 ;  // * latency between  ifft ->  ntt  (fast switch)
    
    integer ninth_switch    = 0 ;  // * latency between  ntt  ->  fft  (immediately switch)
    integer tenth_switch    = 0 ;  // * latency between  fft  ->  intt (immediately switch)
    integer eleventh_switch = 0 ;  // * latency between  intt ->  ifft (immediately switch)
    integer twelveth_switch = 0 ;  // * latency between  ifft ->  ntt  (immediately switch)

    initial begin
        switch_count <= 0;
        in_valid  <= 0;
        A_in      <= 0;
        B_in      <= 0;
        G_in      <= 0;
        mode      <= 0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        //============================ first level ===================================//
        //----------- feed ntt pat -------------//
        for(i=0 ;i< PAT_NUM*3/10; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 0 );
        end
        // * delay of switch 1
        switch_count <= 4'd1;
        while(first_switch > 0)begin
            @(posedge clk);
            first_switch = first_switch -1;
        end 
        //----------- feed fft pat -------------//
        for(i=0 ; i< PAT_NUM*3/10 ;i=i+1)begin
            fft_input(FFT_Ai_list[i] , FFT_Bi_list[i] ,  FFT_Gi_list[i] , 0 );
        end
        // * delay of switch 2
        switch_count <= 4'd2;
        while(second_switch >0)begin
            @(posedge clk);
            second_switch = second_switch-1;
        end
        //----------- feed intt pat -------------//
        for(i=0 ;i< PAT_NUM*3/10; i=i+1)begin
            intt_input(iNTT_Ai_list[i] , iNTT_Bi_list[i] ,  iNTT_Gi_list[i] , 0 );
        end
        // * delay of switch 3
        while(third_switch >0)begin
            @(posedge clk);
            third_switch = third_switch-1;
        end
        //----------- feed ifft pat -------------//
        for(i=0 ; i< PAT_NUM*3/10 ;i=i+1)begin
            ifft_input(iFFT_Ai_list[i] , iFFT_Bi_list[i] ,  iFFT_Gi_list[i] , 0 );
        end
        // * delay of switch 4
        while(forth_switch >0)begin
            @(posedge clk);
            forth_switch = forth_switch-1;
        end

        //============================ second level ===================================//
        //----------- feed ntt pat -------------//
        for(i=PAT_NUM*3/10 ;i< PAT_NUM*6/10 ; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 100 );
        end
        // * delay of switch 5
        switch_count <= 4'd3;
        while(fifth_switch >0)begin
            @(posedge clk);
            fifth_switch = fifth_switch -1;
        end 
        //----------- feed fft pat -------------//
        for(i=PAT_NUM*3/10 ; i<PAT_NUM*6/10 ;i=i+1)begin
            fft_input(FFT_Ai_list[i] , FFT_Bi_list[i] ,  FFT_Gi_list[i] , 100 );
        end
        switch_count <= 4'd4;
        // * delay of switch 6
        while(sixth_switch >0)begin
            @(posedge clk);
            sixth_switch = sixth_switch -1;
        end
        //----------- feed intt pat -------------//
        for(i=PAT_NUM*3/10 ;i< PAT_NUM*6/10 ; i=i+1)begin
            intt_input(iNTT_Ai_list[i] , iNTT_Bi_list[i] ,  iNTT_Gi_list[i] , 100 );
        end
        // * delay of switch 7
        while(seventh_switch >0)begin
            @(posedge clk);
            seventh_switch = seventh_switch -1;
        end        
        //----------- feed ifft pat -------------//
        for(i=PAT_NUM*3/10 ; i<PAT_NUM*6/10 ;i=i+1)begin
            ifft_input(iFFT_Ai_list[i] , iFFT_Bi_list[i] ,  iFFT_Gi_list[i] , 100 );
        end
        // * delay of switch 8
        while(eighth_switch >0)begin
            @(posedge clk);
            eighth_switch = eighth_switch -1;
        end  
        //============================ third level ===================================//
        //----------- feed ntt pat -------------//
        for(i=PAT_NUM*6/10 ;i< PAT_NUM*9/10 ; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 0 );
        end
        switch_count <= 4'd5;
        // * delay of switch 9
        while(ninth_switch >0)begin
            @(posedge clk);
            ninth_switch = ninth_switch -1;
        end 
        //----------- feed fft pat -------------//
        for(i=PAT_NUM*6/10 ; i<PAT_NUM ;i=i+1)begin
            fft_input(FFT_Ai_list[i] , FFT_Bi_list[i] ,  FFT_Gi_list[i] , 0 );
        end
        switch_count <= 4'd6;
        // * delay of switch 10
        while(tenth_switch >0)begin
            @(posedge clk);
            tenth_switch = tenth_switch -1;
        end
        //----------- feed intt pat -------------//
        for(i=PAT_NUM*6/10 ;i< PAT_NUM ; i=i+1)begin
            intt_input(iNTT_Ai_list[i] , iNTT_Bi_list[i] ,  iNTT_Gi_list[i] , 0 );
        end
        // * delay of switch 11
        while(eleventh_switch >0)begin
            @(posedge clk);
            eleventh_switch = eleventh_switch -1;
        end
        //----------- feed ifft pat -------------//
        for(i=PAT_NUM*6/10 ; i<PAT_NUM ;i=i+1)begin
            ifft_input(iFFT_Ai_list[i] , iFFT_Bi_list[i] ,  iFFT_Gi_list[i] , 0 );
        end
        while(twelveth_switch >0)begin
            @(posedge clk);
            twelveth_switch = twelveth_switch -1;
        end
        //----------- last ntt pat --------------//
        for(i=PAT_NUM*9/10 ;i< PAT_NUM ; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 100 );
        end
        //============================ fourth level (new modes) ===========================//
        switch_count <= 4'd7;
        // feed NTM
        for(i=0 ; i<PAT_NUM ; i=i+1) begin
            ntm_input(NTM_Ai_list[i], NTM_Bi_list[i], NTM_Gi_list[i], 20);
        end
        // feed MTN
        for(i=0 ; i<PAT_NUM ; i=i+1) begin
            mtn_input(MTN_Ai_list[i], MTN_Bi_list[i], MTN_Gi_list[i], 20);
        end
        // feed MTND
        for(i=0 ; i<PAT_NUM ; i=i+1) begin
            mtnd_input(MTND_Ai_list[i], MTND_Bi_list[i], MTND_Gi_list[i], 20);
        end

        //=========================== input finish ===================================//
        A_in      <= 0;
        B_in      <= 0;
        G_in      <= 0;
        mode      <= 0;
    end

    integer j;
    reg error;
    reg[31:0] ntt_error;
    reg[31:0] fft_error;
    reg[31:0] intt_error;
    reg[31:0] ifft_error;
    reg[31:0] ntm_error;
    reg[31:0] mtn_error;
    reg[31:0] mtnd_error;


// * output check
    initial begin
        error     <=0;
        ntt_error <=0;
        fft_error <= 0;
        intt_error <=0;
        ifft_error <= 0;
        ntm_error <= 0;
        mtn_error <= 0;
        mtnd_error <= 0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        $display("/////////////////////////////////////////////////////////////////");
        $display("//                First level test start                       //");
        $display("/////////////////////////////////////////////////////////////////");
        for(j=0 ; j< PAT_NUM*3/10 ;j=j+1)begin
            ntt_output_check(NTT_A_golden_list[j] , NTT_B_golden_list[j] , 0 ,j );
        end
        for(j=0 ; j< PAT_NUM*3/10 ;j=j+1)begin
            fft_output_check(FFT_A_golden_list[j] , FFT_B_golden_list[j] , 0 ,j );
        end

        for(j=0 ; j< PAT_NUM*3/10 ;j=j+1)begin
            intt_output_check(iNTT_A_golden_list[j] , iNTT_B_golden_list[j] , 0 ,j );
        end
        for(j=0 ; j< PAT_NUM*3/10 ;j=j+1)begin
            ifft_output_check(iFFT_A_golden_list[j] , iFFT_B_golden_list[j] , 0 ,j );
        end
        $display("/////////////////////////////////////////////////////////////////");
        $display("//               Second level test start                       //");
        $display("/////////////////////////////////////////////////////////////////");
        for(j=PAT_NUM*3/10 ; j<PAT_NUM*6/10 ;j=j+1)begin
            ntt_output_check(NTT_A_golden_list[j] , NTT_B_golden_list[j] , 100 ,j );
        end
        for(j=PAT_NUM*3/10 ; j<PAT_NUM*6/10 ;j=j+1)begin
            fft_output_check(FFT_A_golden_list[j] , FFT_B_golden_list[j] , 100 ,j );
        end
        for(j=PAT_NUM*3/10 ; j<PAT_NUM*6/10 ;j=j+1)begin
            intt_output_check(iNTT_A_golden_list[j] , iNTT_B_golden_list[j] , 100 ,j );
        end
        for(j=PAT_NUM*3/10 ; j<PAT_NUM*6/10 ;j=j+1)begin
            ifft_output_check(iFFT_A_golden_list[j] , iFFT_B_golden_list[j] , 100 ,j );
        end
        $display("/////////////////////////////////////////////////////////////////");
        $display("//                Third level test start                       //");
        $display("/////////////////////////////////////////////////////////////////");
        for(j=PAT_NUM*6/10 ; j<PAT_NUM*9/10 ;j=j+1)begin
            ntt_output_check(NTT_A_golden_list[j] , NTT_B_golden_list[j] , 0 ,j );
        end
        for(j=PAT_NUM*6/10 ; j<PAT_NUM ;j=j+1)begin
            fft_output_check(FFT_A_golden_list[j] , FFT_B_golden_list[j] , 0 ,j );
        end
        for(j=PAT_NUM*6/10 ; j<PAT_NUM ;j=j+1)begin
            intt_output_check(iNTT_A_golden_list[j] , iNTT_B_golden_list[j] , 0 ,j );
        end
        for(j=PAT_NUM*6/10 ; j<PAT_NUM ;j=j+1)begin
            ifft_output_check(iFFT_A_golden_list[j] , iFFT_B_golden_list[j] , 0 ,j );
        end
        for(j=PAT_NUM*9/10 ; j<PAT_NUM ;j=j+1)begin
            ntt_output_check(NTT_A_golden_list[j] , NTT_B_golden_list[j] , 100 ,j );
        end
        $display("/////////////////////////////////////////////////////////////////");
        $display("//               Fourth level (NTM/MTN/MTND) start              //");
        $display("/////////////////////////////////////////////////////////////////");
        // NTM
        for(j=0 ; j<PAT_NUM ; j=j+1) begin
            ntm_output_check(NTM_A_golden_list[j], NTM_B_golden_list[j], 0, j);
        end
        // MTN
        for(j=0 ; j<PAT_NUM ; j=j+1) begin
            mtn_output_check(MTN_A_golden_list[j], MTN_B_golden_list[j], 0, j);
        end
        // MTND
        for(j=0 ; j<PAT_NUM ; j=j+1) begin
            mtnd_output_check(MTND_A_golden_list[j], MTND_B_golden_list[j], 0, j);
        end

        @(posedge clk);
        if(error)begin
            $display(" ========================================================================================");
            $display(" |                              Simulation FAILED ...                                   |");
            $display(" ========================================================================================");
            $display("------------------------------------------------------------------------------------------");
            $display("  Number of FFT error  :                                 %d  " , fft_error  );
            $display("  Number of NTT error  :                                 %d  " , ntt_error  );
            $display("  Number of iFFT error :                                 %d  " , ifft_error );
            $display("  Number of iNTT error :                                 %d  " , intt_error );
            $display("  Number of NTM error  :                                 %d  " , ntm_error  );
            $display("  Number of MTN error  :                                 %d  " , mtn_error  );
            $display("  Number of MTND error :                                 %d  " , mtnd_error );
        end else begin
            $display("#########################################################################################");
            $display("##                                Simulation  PASS !                                   ##");
            $display("##########################################################################################");
        end
        $finish;
    end


    integer in_k;
    task fft_input ;
        input [127:0] fft_in_a ;
        input [127:0] fft_in_b ;
        input [127:0] fft_in_g ;
        input [31:0]  fft_input_latency ;
        begin
            in_valid <= 0;
            mode     <= FFT_MODE;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
            for (in_k=0 ; in_k < fft_input_latency ; in_k = in_k + 1)begin
                @(posedge clk);
            end
            @(posedge clk);
            in_valid  <= 1;
            mode      <= FFT_MODE;
            A_in      <= fft_in_a;
            B_in      <= fft_in_b;
            G_in      <= fft_in_g;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0;
            mode     <= 2'b00;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
        end
    endtask

    task ifft_input ;
        input [127:0] ifft_in_a ;
        input [127:0] ifft_in_b ;
        input [127:0] ifft_in_g ;
        input [31:0]  ifft_input_latency ;
        begin
            in_valid <= 0;
            mode     <= 0;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
            for (in_k=0 ; in_k < ifft_input_latency ; in_k = in_k + 1)begin
                @(posedge clk);
            end
            @(posedge clk);
            in_valid <= 1;
            mode     <= IFFT_MODE;
            A_in      <= ifft_in_a;
            B_in      <= ifft_in_b;
            G_in      <= ifft_in_g;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0;
            mode     <= 2'b00;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
        end
    endtask
    
    integer out_k ;
    task fft_output_check ;
        input   [127:0] fft_answer_a;
        input   [127:0] fft_answer_b;
        input   [31:0]  fft_slave_latency ;
        input   [31:0]  fft_ocnt;
        begin
            out_ready <= 1;

            // for (out_k=0 ; out_k < fft_slave_latency ; out_k = out_k+1)begin
            //     @(posedge clk);
            // end
            @(posedge clk);
            out_ready <= 1;
            //@(posedge clk);
            while (!(out_valid && out_ready)) @(posedge clk);
            out_ready <= 1;   
            if( (A_out !== fft_answer_a) ||(B_out !== fft_answer_b) )begin
                $display("[ERROR] [FFT_Pattern %d] Golden A :  %h    , Your A :   %h" , fft_ocnt, fft_answer_a , A_out );
                $display("[ERROR] [FFT_Pattern %d] Golden B :  %h    , Your B :   %h" , fft_ocnt, fft_answer_b , B_out );
                error <= 1;
                fft_error <= fft_error + 1 ;
            end else begin
                $display("[PASS]  [FFT_Pattern %d] Golden A :  %h    , Your A :   %h" , fft_ocnt, fft_answer_a , A_out );
                $display("[PASS]  [FFT_Pattern %d] Golden B :  %h    , Your B :   %h" , fft_ocnt, fft_answer_b , B_out );
            end
            out_ready <= 0;  
        end
    endtask


    task ifft_output_check ;
        input   [127:0] ifft_answer_a;
        input   [127:0] ifft_answer_b;
        input   [31:0]  ifft_slave_latency ;
        input   [31:0]  ifft_ocnt;
        begin
            out_ready <= 1;
            // for (out_k=0 ; out_k < ifft_slave_latency ; out_k = out_k+1)begin
            //     @(posedge clk);
            // end
            @(posedge clk);
            out_ready <= 1;
            //@(posedge clk);
            while (!(out_valid && out_ready)) @(posedge clk);
            out_ready <= 1;   
            if( (A_out !== ifft_answer_a) ||(B_out !== ifft_answer_b) )begin
                $display("[ERROR] [iFFT_Pattern %d] Golden A :  %h    , Your A :   %h" , ifft_ocnt, ifft_answer_a , A_out );
                $display("[ERROR] [iFFT_Pattern %d] Golden B :  %h    , Your B :   %h" , ifft_ocnt, ifft_answer_b , B_out );
                error <= 1;
                ifft_error <= ifft_error + 1 ;
            end else begin
                $display("[PASS]  [iFFT_Pattern %d] Golden A :  %h    , Your A :   %h" , ifft_ocnt, ifft_answer_a , A_out );
                $display("[PASS]  [iFFT_Pattern %d] Golden B :  %h    , Your B :   %h" , ifft_ocnt, ifft_answer_b , B_out );
            end
            out_ready <= 0;  
        end
    endtask

    integer in_j;
    task intt_input ;
        input [127:0] intt_in_a ;
        input [127:0] intt_in_b ;
        input [127:0] intt_in_g ;
        input [31:0]  intt_input_latency ;
        begin
            in_valid <= 0;
            mode     <= 2'b00;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
            for (in_j=0 ; in_j < intt_input_latency ; in_j = in_j + 1)begin
                @(posedge clk);
            end
            @(posedge clk);
            in_valid <= 1;
            mode      <= INTT_MODE;
            A_in      <= intt_in_a;
            B_in      <= intt_in_b;
            G_in      <= intt_in_g;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0;
            mode     <= 2'b00;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
        end
    endtask

    task ntt_input ;
        input [127:0] ntt_in_a ;
        input [127:0] ntt_in_b ;
        input [127:0] ntt_in_g ;
        input [31:0]  ntt_input_latency ;
        begin
            in_valid <= 0;
            mode     <= 2'b00;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
            for (in_j=0 ; in_j < ntt_input_latency ; in_j = in_j + 1)begin
                @(posedge clk);
            end
            @(posedge clk);
            in_valid <= 1;
            mode     <= NTT_MODE;
            A_in      <= ntt_in_a;
            B_in      <= ntt_in_b;
            G_in      <= ntt_in_g;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0;
            mode     <= 2'b00;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
        end
    endtask


    integer out_j ;
    task ntt_output_check ;
        input   [127:0] ntt_answer_a;
        input   [127:0] ntt_answer_b;
        input   [31:0]  ntt_slave_latency ;
        input   [31:0]  ntt_ocnt;
        begin
            out_ready <= 1;
            // for (out_j=0 ; out_j < ntt_slave_latency ; out_j = out_j+1)begin
            //     @(posedge clk);
            // end
            @(posedge clk);
            out_ready <= 1;
            //@(posedge clk);
            while (!(out_valid && out_ready)) @(posedge clk);
            out_ready <= 1;   
            if( (A_out !== ntt_answer_a) ||(B_out !== ntt_answer_b) )begin
                $display("[ERROR] [NTT_Pattern %d] Golden A :  %h  , Your A : %h " , ntt_ocnt, ntt_answer_a ,  A_out );
                $display("[ERROR] [NTT_Pattern %d] Golden B :  %h  , Your B : %h " , ntt_ocnt, ntt_answer_b ,  B_out );
                error <= 1;
                ntt_error <= ntt_error + 1 ;
            end else begin
                $display("[PASS]  [NTT_Pattern %d] Golden A :  %h  , Your A : %h " , ntt_ocnt, ntt_answer_a  , A_out  );
                $display("[PASS]  [NTT_Pattern %d] Golden B :  %h  , Your B : %h " , ntt_ocnt, ntt_answer_b  , B_out );
            end
            out_ready <= 0;
        end
    endtask

    task intt_output_check ;
        input   [127:0] intt_answer_a;
        input   [127:0] intt_answer_b;
        input   [31:0]  intt_slave_latency ;
        input   [31:0]  intt_ocnt;
        begin
            out_ready <= 1;
            // for (out_j=0 ; out_j < intt_slave_latency ; out_j = out_j+1)begin
            //     @(posedge clk);
            // end
            @(posedge clk);
            out_ready <= 1;
            //@(posedge clk);
            while (!(out_valid && out_ready)) @(posedge clk);
            out_ready <= 1;   
            if( (A_out !== intt_answer_a) ||(B_out !== intt_answer_b) )begin
                $display("[ERROR] [iNTT_Pattern %d] Golden A :  %h  , Your A : %h " , intt_ocnt, intt_answer_a ,  A_out );
                $display("[ERROR] [iNTT_Pattern %d] Golden B :  %h  , Your B : %h " , intt_ocnt, intt_answer_b ,  B_out );
                error <= 1;
                intt_error <= intt_error + 1 ;
            end else begin
                $display("[PASS]  [iNTT_Pattern %d] Golden A :  %h  , Your A : %h " , intt_ocnt, intt_answer_a  , A_out  );
                $display("[PASS]  [iNTT_Pattern %d] Golden B :  %h  , Your B : %h " , intt_ocnt, intt_answer_b  , B_out );
            end
            out_ready <= 0;
        end
    endtask

    integer in_p;
    task ntm_input ;
        input [127:0] ntm_in_a ;
        input [127:0] ntm_in_b ;
        input [127:0] ntm_in_g ;
        input [31:0]  ntm_input_latency ;
        begin
            in_valid <= 0; mode <= FFT_MODE; A_in <= 0; B_in <= 0; G_in <= 0;
            for (in_p=0 ; in_p < ntm_input_latency ; in_p = in_p + 1) @(posedge clk);
            @(posedge clk);
            in_valid <= 1; mode <= NTM_MODE;
            A_in <= ntm_in_a; B_in <= ntm_in_b; G_in <= ntm_in_g;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0; mode <= FFT_MODE; A_in <= 0; B_in <= 0; G_in <= 0;
        end
    endtask

    integer in_q;
    task mtn_input ;
        input [127:0] mtn_in_a ;
        input [127:0] mtn_in_b ;
        input [127:0] mtn_in_g ;
        input [31:0]  mtn_input_latency ;
        begin
            in_valid <= 0; mode <= FFT_MODE; A_in <= 0; B_in <= 0; G_in <= 0;
            for (in_q=0 ; in_q < mtn_input_latency ; in_q = in_q + 1) @(posedge clk);
            @(posedge clk);
            in_valid <= 1; mode <= MTN_MODE;
            A_in <= mtn_in_a; B_in <= mtn_in_b; G_in <= mtn_in_g;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0; mode <= FFT_MODE; A_in <= 0; B_in <= 0; G_in <= 0;
        end
    endtask

    integer in_r;
    task mtnd_input ;
        input [127:0] mtnd_in_a ;
        input [127:0] mtnd_in_b ;
        input [127:0] mtnd_in_g ;
        input [31:0]  mtnd_input_latency ;
        begin
            in_valid <= 0; mode <= FFT_MODE; A_in <= 0; B_in <= 0; G_in <= 0;
            for (in_r=0 ; in_r < mtnd_input_latency ; in_r = in_r + 1) @(posedge clk);
            @(posedge clk);
            in_valid <= 1; mode <= MTND_MODE;
            A_in <= mtnd_in_a; B_in <= mtnd_in_b; G_in <= mtnd_in_g;
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0; mode <= FFT_MODE; A_in <= 0; B_in <= 0; G_in <= 0;
        end
    endtask

    integer out_p;
    task ntm_output_check ;
        input   [127:0] ntm_answer_a;
        input   [127:0] ntm_answer_b;
        input   [31:0]  ntm_slave_latency ;
        input   [31:0]  ntm_ocnt;
        begin
            out_ready <= 1;
            @(posedge clk);
            out_ready <= 1;
            while (!(out_valid && out_ready)) @(posedge clk);
            out_ready <= 1;   
            if ( (A_out !== ntm_answer_a) || (B_out !== ntm_answer_b) ) begin
                $display("[ERROR] [NTM_Pattern %0d] Golden A:%h , Your A:%h", ntm_ocnt, ntm_answer_a, A_out);
                $display("[ERROR] [NTM_Pattern %0d] Golden B:%h , Your B:%h", ntm_ocnt, ntm_answer_b, B_out);
                error <= 1;
                ntm_error <= ntm_error + 1 ;
            end else begin
                $display("[PASS ] [NTM_Pattern %0d] Golden A:%h , Your A:%h", ntm_ocnt, ntm_answer_a, A_out);
                $display("[PASS ] [NTM_Pattern %0d] Golden B:%h , Your B:%h", ntm_ocnt, ntm_answer_b, B_out);
            end
            out_ready <= 0;
        end
    endtask

    integer out_q;
    task mtn_output_check ;
        input   [127:0] mtn_answer_a;
        input   [127:0] mtn_answer_b;
        input   [31:0]  mtn_slave_latency ;
        input   [31:0]  mtn_ocnt;
        begin
            out_ready <= 1;
            @(posedge clk);
            out_ready <= 1;
            while (!(out_valid && out_ready)) @(posedge clk);
            out_ready <= 1;   
            if ( (A_out !== mtn_answer_a) || (B_out !== mtn_answer_b) ) begin
                $display("[ERROR] [MTN_Pattern %0d] Golden A:%h , Your A:%h", mtn_ocnt, mtn_answer_a, A_out);
                $display("[ERROR] [MTN_Pattern %0d] Golden B:%h , Your B:%h", mtn_ocnt, mtn_answer_b, B_out);
                error <= 1;
                mtn_error <= mtn_error + 1 ;
            end else begin
                $display("[PASS ] [MTN_Pattern %0d] Golden A:%h , Your A:%h", mtn_ocnt, mtn_answer_a, A_out);
                $display("[PASS ] [MTN_Pattern %0d] Golden B:%h , Your B:%h", mtn_ocnt, mtn_answer_b, B_out);
            end
            out_ready <= 0;
        end
    endtask

    integer out_r;
    task mtnd_output_check ;
        input   [127:0] mtnd_answer_a;
        input   [127:0] mtnd_answer_b;
        input   [31:0]  mtnd_slave_latency ;
        input   [31:0]  mtnd_ocnt;
        begin
            out_ready <= 1;
            @(posedge clk);
            out_ready <= 1;
            while (!(out_valid && out_ready)) @(posedge clk);
            out_ready <= 1;   
            if ( (A_out !== mtnd_answer_a) || (B_out !== mtnd_answer_b) ) begin
                $display("[ERROR] [MTND_Pattern %0d] Golden A:%h , Your A:%h", mtnd_ocnt, mtnd_answer_a, A_out);
                $display("[ERROR] [MTND_Pattern %0d] Golden B:%h , Your B:%h", mtnd_ocnt, mtnd_answer_b, B_out);
                error <= 1;
                mtnd_error <= mtnd_error + 1 ;
            end else begin
                $display("[PASS ] [MTND_Pattern %0d] Golden A:%h , Your A:%h", mtnd_ocnt, mtnd_answer_a, A_out);
                $display("[PASS ] [MTND_Pattern %0d] Golden B:%h , Your B:%h", mtnd_ocnt, mtnd_answer_b, B_out);
            end
            out_ready <= 0;
        end
    endtask


endmodule