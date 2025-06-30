`timescale 1ns/1ps
module mul_tb();

    reg [127:0]     A;
    reg             clk;
    reg             rst_n;
    reg             in_valid;
    wire[127:0]     result_int;
    wire            out_valid;
    

    divN mul_DUT(
        .in_A( A ),
        .clk  (clk  ),
        .rst_n ( rst_n ),
        .in_valid( in_valid ),
        .result_int( result_int ),
        .out_valid ( out_valid )
    );

`ifdef FSDB
    initial begin
        $fsdbDumpfile("divN.fsdb");
        $fsdbDumpvars("+mda");
    end
`else
    initial begin
        $dumpfile("divN.vcd");
        $dumpvars();
    end
`endif

    initial begin
        clk = 0;
        forever begin
            #5 clk = (~clk);
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


    integer Din_a_int , Din_b_int , Din_a_com  , Din_b_com ,Gin_int  , Gin_com;
    integer a_in_int ,b_in_int , a_in_com , b_in_com , g_in_int , g_in_com ;
    integer m,n;

    localparam PAT_NUM = 100;

    reg[127:0]   int_A_list     [0:PAT_NUM-1];
    reg[127:0]   int_B_list     [0:PAT_NUM-1];

    //reg[127:0]   complex_A_list [0:PAT_NUM-1];
    //reg[127:0]   complex_B_list [0:PAT_NUM-1];


    reg[127:0]   golden_list_int[0:PAT_NUM-1];
    //reg[127:0]   golden_list_complex[0:PAT_NUM-1];
// set pattern //
    initial begin
        Din_a_int = $fopen("./NTT_pat/int_A.dat" ,"r");
        Din_b_int = $fopen("./NTT_pat/int_B.dat" ,"r");

        //Din_a_com = $fopen("./mul_pat/complex_A.dat" , "r");
        //Din_b_com = $fopen("./mul_pat/complex_B.dat" , "r");
        
        Gin_int   = $fopen("./NTT_pat/golden_int.dat" , "r");
        //Gin_com   = $fopen("./mul_pat/golden_complex.dat" , "r");
        
        if (Din_a_int == 0 || Din_b_int == 0 || Gin_int == 0) begin
            $display("[ERROR] Failed to open pattern file....");
            $finish;
        end else begin 
            for(m=0 ; m<PAT_NUM ;m=m+1)begin
                a_in_int    = $fscanf(Din_a_int , "%h" , int_A_list[m]);
                b_in_int    = $fscanf(Din_b_int , "%h" , int_B_list[m]);

                //a_in_com    = $fscanf(Din_a_com , "%h" , complex_A_list[m]);
                //b_in_com    = $fscanf(Din_b_com , "%h" , complex_B_list[m]);

                g_in_int    = $fscanf(Gin_int , "%h" , golden_list_int[m]);
                //g_in_com    = $fscanf(Gin_com , "%h" , golden_list_complex[m]);
            end
        end
        $display("---------------------- papttern initialize done -----------------------------");
    end

//
    integer i;
    integer first_switch  = 30; // * latency between     int mul  -> complex mul
    integer second_switch = 30; // * latency between  complex mul -> int_mul
    integer third_switch  = 30 ;

    initial begin
        in_valid  <= 0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        for(i=0 ;i<PAT_NUM ; i=i+1)begin
            int_dat_in(int_A_list[i] , int_B_list[i] );
        end
        // while(first_switch >0)begin
        //     @(posedge clk);
        //     first_switch = first_switch -1;
        // end 
        // $display("---------------------------- First switch ( int => complex ) -------------------------------------------");
        // for(i=0 ; i<PAT_NUM/2 ;i=i+1)begin
        //     complex_dat_in(complex_A_list[i] , complex_B_list[i] ) ;
        // end
        // while(second_switch >0)begin
        //     @(posedge clk);
        //     second_switch = second_switch-1;
        // end
        // $display("--------------------------- Second switch ( complex => int )--------------------------------------------");
        // for(i=PAT_NUM/2 ; i<PAT_NUM ; i = i+1)begin
        //     int_dat_in(int_A_list[i] , int_B_list[i] );
        // end
        // while(third_switch >0)begin
        //     @(posedge clk);
        //     third_switch = third_switch -1;
        // end 
        // $display("---------------------------- Third switch ( int => complex ) -------------------------------------------");
        // for(i=PAT_NUM/2 ; i<PAT_NUM ; i=i+1)begin
        //     complex_dat_in(complex_A_list[i] , complex_B_list[i] ) ;
        // end
        // in_valid  <= 0;
        // mode      <= 0;
    end

    integer j;

    reg int_error;
    reg com_error;

    initial begin
        com_error <=0;
        int_error <= 0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        for(j=0 ; j<PAT_NUM;j=j+1)begin
            int_out_check(golden_list_int[j] , j );
        end
        // if(int_error || com_error)begin
        //     $display("----------- Simulation ERROR (QAQ)-------------------");
        //     //$finish;
        // end else begin
        //     $display("###########################################################");
        //     $display("##             FIRST 5000 INT PATTERN PASS               ##");
        //     $display("###########################################################");
        // end
        // for(j=0 ; j<PAT_NUM/2;j=j+1)begin
        //     complex_out_check(golden_list_complex[j] , j);
        // end
        // if(int_error || com_error)begin
        //     $display("----------- Simulation ERROR (QAQ)-------------------");
        //     //$finish;
        // end else begin
        //     $display("###########################################################");
        //     $display("##             FIRST 5000 COMP PATTERN PASS              ##");
        //     $display("###########################################################");
        // end
        // for(j=PAT_NUM/2 ; j<PAT_NUM;j=j+1)begin
        //     int_out_check(golden_list_int[j] , j );
        // end
        // for(j=PAT_NUM/2 ; j<PAT_NUM;j=j+1)begin
        //     complex_out_check(golden_list_complex[j] , j);
        // end
        // if(int_error || com_error)begin
        //     $display("----------- Simulation ERROR (QAQ)-------------------");
        // end else begin
        //     $display("----------- Simulation PASS (^_^) -------------------");
        // end
        $finish;
    end


    task int_dat_in ;
        input  [127:0]  in_1;
        input  [127:0]  in_2;
        begin
            @(posedge clk);
            @(posedge clk)            
            in_valid <= 1;
            //mode     <= 1;
            A        <= in_1;
            //B        <= in_2;
            @(posedge clk)
            in_valid<= 0;
            A       <= 0;
            //B       <= 0;
            //mode    <= 1;
        end
    endtask

    // task complex_dat_in ;
    //     input  [127:0]  in_1;
    //     input  [127:0]  in_2;
    //     begin
    //         @(posedge clk);
    //         @(posedge clk)            
    //         in_valid <= 1;
    //         mode     <= 0;
    //         A        <= in_1;
    //         B        <= in_2;
    //         @(posedge clk)
    //         in_valid <= 0;
    //         mode     <= 0;
    //         A        <= 0;
    //         B        <= 0;
    //     end
    // endtask


    task int_out_check ;
        input   [127:0] answer_int;
        input   [31:0] ocnt;
        begin
            while (!out_valid) @(posedge clk);   
            if( (result_int !== answer_int) )begin
                $display("[ERROR] [INT_Pattern %d] Golden : %h , Your : %h", ocnt, answer_int , result_int );
                int_error <= 1;
            end else begin
                $display("[PASS]  [INT_Pattern %d] Golden : %h , Your : %h", ocnt, answer_int , result_int );
            end
            @(posedge clk);
        end
    endtask

    // task complex_out_check ;
    //     input   [127:0] answer_complex;
    //     input   [31:0] ocnt;
    //     begin
    //         while (!out_valid) @(posedge clk);   
    //         if( (result_c !== answer_complex) )begin
    //             $display("[ERROR] [COMPLEX_Pattern %d] Golden : %h , Your : %h", ocnt, answer_complex, result_c);
    //             com_error <= 1;
    //         end else begin
    //             $display("[PASS]  [COMPLEX_Pattern %d] Golden : %h , Your : %h", ocnt, answer_complex , result_c);
    //         end
    //         @(posedge clk);
    //     end
    // endtask

endmodule