`timescale 1ns / 1ps
`include "cmul.v"

module cmul_tb ();
localparam BIT = 128;
localparam N = 1000;

reg clk;
reg rstn;
reg [(BIT-1):0] num1;
reg [(BIT-1):0] num2;
wire [(BIT-1):0] result;
reg valid;
wire ready;

cmul uut (
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
    forever #5 clk = ~clk;
end

//-----reset-----//
initial begin
    rstn = 0;
    repeat (2) @(posedge clk);
    rstn = 1;
end

// ---------- memory ---------- //
reg [127:0] num1_mem [0:N-1];
reg [127:0] num2_mem [0:N-1];
reg [127:0] golden_result [0:N-1];

integer fd, i = 0, r;
reg [63:0] Xr, Xi, Yr, Yi, Zr, Zi;

// ---------- file reading ---------- //
initial begin
    fd = $fopen("./py/golden.dat", "r");
    if (!fd) begin
        $display("❌ Error: Cannot open golden.dat");
        $finish;
    end

    while (!$feof(fd)) begin
        r = $fscanf(fd, "%h %h %h %h %h %h\n", Xr, Xi, Yr, Yi, Zr, Zi);
        if (r == 6) begin
            num1_mem[i] = {Xr, Xi};
            num2_mem[i] = {Yr, Yi};
            golden_result[i] = {Zr, Zi};
            i = i + 1;
        end else begin
            $display("⚠️ Warning: Invalid line format at index %0d", i);
        end
    end
    $fclose(fd);
    $display("✅ Loaded %0d test patterns from golden.dat", i);
end

// ---------- feed input ---------- //
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
    @(negedge clk);
    valid <= 0;
    num1 <= 0;
    num2 <= 0;
end

// ---------- timeout prevent ---------- //
integer timeout = 100000;
initial begin
    while(timeout > 0) begin
        @(posedge clk);
        timeout = timeout - 1;
    end
    $display($time, " Simulation Hang ....");
    $finish;
end

// ---------- check result ---------- //
integer k = 0;
integer errors = 0;
//localparam MASK = 127 << 0 | 127 << 64;
//use to mask pattern : if ((result|MASK) !== (golden_result[k]|MASK))
initial begin
    wait(rstn == 1);
    repeat(24) @(posedge clk); // wait for pipeline latency

    while (k < i) begin
        @(posedge clk);
        if ((result) !== (golden_result[k])) begin
            $display("❌ [Mismatch] Pattern %0d:", k+1);
            $display("result   = %h", result);
            $display("expected = %h", golden_result[k]);
            errors = errors + 1;
        end else begin
            $display("✅ [Match] Pattern %0d: result = %h", k+1, result);
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
    $dumpfile("cmul.vcd");
    $dumpvars(0, cmul_tb);
end

endmodule
