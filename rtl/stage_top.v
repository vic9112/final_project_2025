
// Using Deep-Feedback structure, we will have
module stage_top
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers
)
(
    input   wire                     clk,
    input   wire                     rstn,

    input   wire               [1:0] in1_sw,

    // SS/SM interface:
    // FFT/iFFT SS: concat 4 32-bit data to 128-bit
    // FFT/iFFT SM: split 128-bit data to 32-bit
    input   wire                     ss_vld, 
    input   wire [(pDATA_WIDTH-1):0] ss_dat, 
    input   wire                     ss_lst, 
    output  wire                     ss_rdy, 
    input   wire                     sm_rdy, 
    output  wire                     sm_vld, 
    output  wire [(pDATA_WIDTH-1):0] sm_dat, 
    output  wire                     sm_lst,

    // 1st Kernel
    output  wire                     k1_ld_vld,  // Stream: X[a], X[b], GM constant
    input   wire                     k1_ld_rdy,
    output  wire [(pDATA_WIDTH-1):0] k1_ld_dat,
    input   wire                     k1_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
    output  wire                     k1_sw_rdy,
    input   wire [(pDATA_WIDTH-1):0] k1_sw_d,
    
    // 2nd Kernel
    output  wire                     k2_ld_vld,  // Stream: X[a], X[b], GM constant
    input   wire                     k2_ld_rdy,
    output  wire [(pDATA_WIDTH-1):0] k2_ld_dat,
    input   wire                     k2_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
    output  wire                     k2_sw_rdy,
    input   wire [(pDATA_WIDTH-1):0] k2_sw_d,
    
    // 3rd Kernel
    output  wire                     k3_ld_vld,  // Stream: X[a], X[b], GM constant
    input   wire                     k3_ld_rdy,
    output  wire [(pDATA_WIDTH-1):0] k3_ld_dat,
    input   wire                     k3_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
    output  wire                     k3_sw_rdy,
    input   wire [(pDATA_WIDTH-1):0] k3_sw_d,
    
    // 4th Kernel
    output  wire                     k4_ld_vld,  // Stream: X[a], X[b], GM constant
    input   wire                     k4_ld_rdy,
    output  wire [(pDATA_WIDTH-1):0] k4_ld_dat,
    input   wire                     k4_sw_vld, // Stream: X[a], X[b], GM constant//Stream-in IOP, then stream-out
    output  wire                     k4_sw_rdy,
    input   wire [(pDATA_WIDTH-1):0] k4_sw_d

);

    // =============== Bandwidth 128-bit (64 + 64) =============== //
    // Memories for buffer (from host or PE) [in2m_sw == 2'b00 or 2'b11]

    // Memory for  FFT constant [in2m_sw == 2'b01]

    // ==================== Bandwidth 16-bit ===================== //
    // Memory for  NTT constant [in2m_sw == 2'b10]

    // Memory for iNTT constant [in2m_sw == 2'b10]

endmodule

