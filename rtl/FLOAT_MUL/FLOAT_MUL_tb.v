// Author: Jesse
`timescale 1ns / 1ps
`include "FLOAT_MUL.v"
module FLOAT_MUL_tb ();
localparam BIT = 64;
localparam BIAS = 1023;
localparam EXPONENT_LEN = 11;
localparam MANTISSA_LEN = 52;
localparam N=1000;


reg clk;
reg rstn;
reg [(BIT-1):0]num1;
reg [(BIT-1):0]num2;
wire [63:0]result;
reg valid;
wire ready;

FLOAT_MUL uut(
    .num1(num1),
    .num2(num2),
    .clk(clk),
    .rstn(rstn),
    .result(result),
    .valid(valid),
    .ready(ready)
);
//-----clock generate-----//
initial begin
    clk = 0;
    forever begin
        #5 clk = (~clk);
    end
end
//-----reset-----//
initial begin
    rstn = 0;
    repeat (2) @(posedge clk);
    rstn = 1;
end

// ---------- memory ----------
reg [63:0] num1_mem [0:N-1];
reg [63:0] num2_mem [0:N-1];
reg [63:0] golden_result [0:N-1];

integer fd, i = 0, r;
reg [63:0] t1, t2, t3;

// ---------- file reading ----------
initial begin
    fd = $fopen("./py/golden.dat", "r"); // read("r") golden.dat
    if (!fd) begin
        $display("❌ Error: Cannot open golden.dat");
        $finish;
    end
    //if file is end, $feof will return 1, jump out of loop
    //r represent read how many row from file
    while (!$feof(fd)) begin
        r = $fscanf(fd, "%h %h %h\n", t1, t2, t3);
        if (r == 3) begin
            num1_mem[i] = t1;
            num2_mem[i] = t2;
            golden_result[i] = t3;
            i = i + 1;
        end else begin
            $display("⚠️ Warning: Invalid line format at index %0d", i);
        end
    end
    $fclose(fd);
    $display("✅ Loaded %0d test patterns from golden.dat", i);
end

// ---------- feed input ----------
integer j;
initial begin
    valid = 0;
    wait(rstn == 1);
    for (j = 0; j < i; j = j + 1) begin
        @(negedge clk);
        valid <= 1;
        num1 <= num1_mem[j];
        num2 <= num2_mem[j];
    end
    // flush
    @(negedge clk);
    valid <= 0;
    num1 <= 0;
    num2 <= 0;
end

//-----prevent hang
integer timeout = (100000);
initial begin
    while(timeout > 0) begin
        @(posedge clk);
        timeout = timeout - 1;
    end
    $display($time, "Simualtion Hang ....");
    $finish;
end

// ---------- check result ----------
integer k = 0;
integer errors = 0;
initial begin
    wait(rstn == 1);
    repeat(14) @(posedge clk); // 等待 pipeline 開始輸出

    while (k < N) begin
        @(posedge clk);
        if (result != golden_result[k]) begin
          $display("❌ [Mismatch] Pattern %0d: result = %h, expected = %h",
                    k , result, golden_result[k]);
                errors = errors + 1;
        end else begin
          $display("✅ [Match] Pattern %0d: result = %h, expected = %h", k, result, golden_result[k]);
        end
        k = k + 1;
    end

    $display("🎯 Test completed: %0d errors out of %0d patterns", errors, i);
    if (errors == 0)
        $display("🎉 ALL PASS!");
    else
        $display("⚠️ Some mismatches found. Please check your design.");
    repeat (10) @(posedge clk);
    $finish;
end

initial begin
    $dumpfile("mul.vcd");
    $dumpvars();
    //$dumpvars(0, uut.pip1_mantissa1[52]);
    //$dumpvars(0, uut.pip1_mantissa1[2]);
    //$dumpvars(0, uut.pip1_mantissa1[1]);
end


endmodule //IEEE754_64bit_mul_tb