// =======================================================
// Glitch-Free 2:1 Clock MUX (fast & slow=fast/2, phase-aligned)
// =======================================================
module clk_mux #(
    parameter RESET_SEL = 1'b0  // 0: default fast, 1: default slow
)(
    input  wire clk_fast,
    input  wire clk_slow,
    input  wire rstn,
    input  wire sel,
    output wire clk_out
);

    wire sel_fast = sel;

    reg en_fast, en_slow;

    always @ (clk_fast or rstn or sel_fast or en_slow) begin
        if (!rstn)
            en_fast <= (RESET_SEL == 1'b0);
        else if (~clk_fast)
            en_fast <= (~sel_fast) & (~en_slow);
    end

    always @ (clk_slow or rstn or sel_fast or en_fast) begin
        if (!rstn)
            en_slow <= (RESET_SEL == 1'b1);
        else if (~clk_slow)
            en_slow <= ( sel_fast) & (~en_fast);
    end

    (* keep = "true" *) wire clk_fast_g = clk_fast & en_fast;
    (* keep = "true" *) wire clk_slow_g = clk_slow & en_slow;

    assign clk_out = clk_fast_g | clk_slow_g;

endmodule
