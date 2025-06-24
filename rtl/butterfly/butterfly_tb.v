`timescale 1ns/1ps

//`define FSDB
`define CLK_PERIOD 10

module butterfly_tb();

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
    reg [1:0]       mode;
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
    . clk(clk),
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
            #(`CLK_PERIOD)  clk = (~clk);
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


    integer Din_a_FFT , Din_b_FFT , Din_g_FFT  , Din_a_NTT  , Din_b_NTT , Din_g_NTT   ;
    integer Gin_a_FFT , Gin_b_FFT , Gin_a_NTT , Gin_b_NTT ;
    integer din_ntt[0:2]    , din_fft[0:2];
    integer golden_ntt[0:1] , golden_fft[0:1];
    integer m ;

    reg[127:0]   FFT_Ai_list     [0:(PAT_NUM-1)];
    reg[127:0]   FFT_Bi_list     [0:(PAT_NUM-1)];
    reg[127:0]   FFT_Gi_list     [0:(PAT_NUM-1)];

    reg[127:0]   NTT_Ai_list     [0:(PAT_NUM-1)];
    reg[127:0]   NTT_Bi_list     [0:(PAT_NUM-1)];
    reg[127:0]   NTT_Gi_list     [0:(PAT_NUM-1)];

    reg[127:0]   FFT_A_golden_list[0:(PAT_NUM-1)];
    reg[127:0]   FFT_B_golden_list[0:(PAT_NUM-1)];

    reg[127:0]   NTT_A_golden_list[0:(PAT_NUM-1)];
    reg[127:0]   NTT_B_golden_list[0:(PAT_NUM-1)];
// set pattern //
    initial begin
        Din_a_FFT = $fopen("./FFT_pat/a_in.dat" ,"r");
        Din_b_FFT = $fopen("./FFT_pat/b_in.dat" ,"r");
        Din_g_FFT = $fopen("./FFT_pat/g_in.dat" ,"r");
        
        Din_a_NTT = $fopen("./NTT_pat/ntt_ai.dat" ,"r");
        Din_b_NTT = $fopen("./NTT_pat/ntt_bi.dat" , "r");
        Din_g_NTT = $fopen("./NTT_pat/ntt_gm.dat" , "r");
        
        Gin_a_FFT = $fopen("./FFT_pat/golden_a.dat" , "r");
        Gin_b_FFT = $fopen("./FFT_pat/golden_b.dat" , "r");
        
        Gin_a_NTT = $fopen("./NTT_pat/ntt_ao.dat" , "r");
        Gin_b_NTT = $fopen("./NTT_pat/ntt_bo.dat" , "r");
        
        if ((Din_a_FFT == 0) || (Din_b_FFT == 0) || (Din_g_FFT == 0) || (Gin_a_FFT == 0) || (Gin_b_FFT == 0)) begin
            $display("[ERROR] Failed to load FFT pattern files .....   (Q_Q) ");
            $finish;
        end else if ((Din_a_NTT == 0) || (Din_b_NTT == 0) || (Din_g_NTT == 0) || (Gin_a_NTT == 0) || (Gin_b_NTT == 0) ) begin
            $display("[ERROR] Failed to load NTT pattern files .....   (Q_Q) ");
            $finish;       
        end else begin    
            for(m=0 ; m<PAT_NUM ;m=m+1)begin
                din_fft[0]      = $fscanf(Din_a_FFT , "%h" , FFT_Ai_list[m]);
                din_fft[1]      = $fscanf(Din_b_FFT , "%h" , FFT_Bi_list[m]);
                din_fft[2]      = $fscanf(Din_g_FFT , "%h" , FFT_Gi_list[m]);

                din_ntt[0]      = $fscanf(Din_a_NTT , "%h" , NTT_Ai_list[m]);
                din_ntt[1]      = $fscanf(Din_b_NTT , "%h" , NTT_Bi_list[m]);
                din_ntt[2]      = $fscanf(Din_g_NTT , "%h" , NTT_Gi_list[m]);
               
                golden_fft[0]   = $fscanf(Gin_a_FFT , "%h" , FFT_A_golden_list[m]); 
                golden_fft[1]   = $fscanf(Gin_b_FFT , "%h" , FFT_B_golden_list[m]);

                golden_ntt[0]   = $fscanf(Gin_a_NTT , "%h" , NTT_A_golden_list[m]);
                golden_ntt[1]   = $fscanf(Gin_b_NTT , "%h" , NTT_B_golden_list[m]);
            end
        end
        $display("------------------ Pattern initializeation done , start simulation  ---------------------------");
    end

//
    integer i;
    integer first_switch  = 50; // * latency between  ntt  ->  fft (slowly switch)
    integer second_switch = 50; // * latency between  fft  ->  ntt (slowly switch)
    integer third_switch  = 4 ; // * latency betewwn  ntt  ->  fft (fast switch)
    integer forth_switch  = 22; // * latency between  fft  ->  ntt (fast switch)
    integer fifth_switch  = 0 ; // * latency between  ntt  ->  fft (immediately switch)
    integer sixth_switch  = 0 ; // * latency between  fft  ->  ntt (immediately switch)

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
        //------------------------------ first level -------------------------------------//
        for(i=0 ;i< PAT_NUM*3/10; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 0 );
        end
        // * delay of switch
        switch_count <= 4'd1;
        while(first_switch > 0)begin
            @(posedge clk);
            first_switch = first_switch -1;
        end 
        for(i=0 ; i< PAT_NUM*3/10 ;i=i+1)begin
            fft_input(FFT_Ai_list[i] , FFT_Bi_list[i] ,  FFT_Gi_list[i] , 0 );
        end
        // * delay of switch
        switch_count <= 4'd2;
        while(second_switch >0)begin
            @(posedge clk);
            second_switch = second_switch-1;
        end
        //------------------------------ second level --------------------------------------//
        for(i=PAT_NUM*3/10 ;i< PAT_NUM*6/10 ; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 100 );
        end
        // * delay of switch
        switch_count <= 4'd3;
        while(third_switch >0)begin
            @(posedge clk);
            third_switch = third_switch -1;
        end 
        for(i=PAT_NUM*3/10 ; i<PAT_NUM*6/10 ;i=i+1)begin
            fft_input(FFT_Ai_list[i] , FFT_Bi_list[i] ,  FFT_Gi_list[i] , 100 );
        end
        switch_count <= 4'd4;
        while(forth_switch >0)begin
            @(posedge clk);
            forth_switch = forth_switch -1;
        end 
        //------------------------------ thhird level --------------------------------------//
        for(i=PAT_NUM*6/10 ;i< PAT_NUM*9/10 ; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 0 );
        end
        switch_count <= 4'd5;
        while(fifth_switch >0)begin
            @(posedge clk);
            fifth_switch = fifth_switch -1;
        end 
        for(i=PAT_NUM*6/10 ; i<PAT_NUM ;i=i+1)begin
            fft_input(FFT_Ai_list[i] , FFT_Bi_list[i] ,  FFT_Gi_list[i] , 0 );
        end
        switch_count <= 4'd6;
        while(sixth_switch >0)begin
            @(posedge clk);
            sixth_switch = sixth_switch -1;
        end 
        for(i=PAT_NUM*9/10 ;i< PAT_NUM ; i=i+1)begin
            ntt_input(NTT_Ai_list[i] , NTT_Bi_list[i] ,  NTT_Gi_list[i] , 100 );
        end
        A_in      <= 0;
        B_in      <= 0;
        G_in      <= 0;
        mode      <= 0;
    end

    integer j;
    reg error;
    reg[31:0] ntt_error;
    reg[31:0] fft_error;
// * output check
    initial begin
        error     <=0;
        ntt_error <=0;
        fft_error <= 0;
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
        $display("/////////////////////////////////////////////////////////////////");
        $display("//               Second level test start                       //");
        $display("/////////////////////////////////////////////////////////////////");
        for(j=PAT_NUM*3/10 ; j<PAT_NUM*6/10 ;j=j+1)begin
            ntt_output_check(NTT_A_golden_list[j] , NTT_B_golden_list[j] , 100 ,j );
        end
        for(j=PAT_NUM*3/10 ; j<PAT_NUM*6/10 ;j=j+1)begin
            fft_output_check(FFT_A_golden_list[j] , FFT_B_golden_list[j] , 100 ,j );
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
        for(j=PAT_NUM*9/10 ; j<PAT_NUM ;j=j+1)begin
            ntt_output_check(NTT_A_golden_list[j] , NTT_B_golden_list[j] , 100 ,j );
        end
        @(posedge clk);
        if(error)begin
            $display(" ========================================================================================");
            $display(" |                              Simulation FAILED ...                                   |");
            $display(" ========================================================================================");
            $display("------------------------------------------------------------------------------------------");
            $display("  Number of FFT error :                                 %d  " , fft_error );
            $display("  Number of NTT error :                                 %d  " , ntt_error );
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
            mode     <= 2'b11;
            A_in      <= 0;
            B_in      <= 0;
            G_in      <= 0;
            for (in_k=0 ; in_k < fft_input_latency ; in_k = in_k + 1)begin
                @(posedge clk);
            end
            @(posedge clk);
            in_valid <= 1;
            mode     <= 2'b00;
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




    integer in_j;
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
            mode     <= 2'b10;
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


endmodule