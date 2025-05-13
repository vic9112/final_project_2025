
// Using Deep-Feedback structure, we will have
module stage_top
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers
)
(
    input   wire                     clk,
    input   wire                     rstn,

    input   wire               [1:0] in1_sw,

    //========================== 1st Kernel =============================//
    // Use 5 interface since SDF deep-feedback of 1024 FFT/NTT have 5 stages
    // BPE1 
    input   wire                     k1_iop1_vld, //Stream-in to memory
    output  wire                     k1_iop1_rdy,
    input   wire [(pDATA_WIDTH-1):0] k1_iop1_dat,
    output  wire                     k1_bpe1_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k1_bpe1_rdy,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe1_a,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe1_b,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe1_c,

    // BPE2
    input   wire                     k1_iop2_vld, //Stream-in to memory
    output  wire                     k1_iop2_rdy,
    input   wire [(pDATA_WIDTH-1):0] k1_iop2_dat,
    output  wire                     k1_bpe2_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k1_bpe2_rdy,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe2_a,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe2_b,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe2_c,
    
    // BPE3
    input   wire                     k1_iop3_vld, //Stream-in to memory
    output  wire                     k1_iop3_rdy,
    input   wire [(pDATA_WIDTH-1):0] k1_iop3_dat,
    output  wire                     k1_bpe3_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k1_bpe3_rdy,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe3_a,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe3_b,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe3_c,
    
    // BPE4
    input   wire                     k1_iop4_vld, //Stream-in to memory
    output  wire                     k1_iop4_rdy,
    input   wire [(pDATA_WIDTH-1):0] k1_iop4_dat,
    output  wire                     k1_bpe4_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k1_bpe4_rdy,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe4_a,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe4_b,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe4_c,
    
    // BPE5
    input   wire                     k1_iop5_vld, //Stream-in to memory
    output  wire                     k1_iop5_rdy,
    input   wire [(pDATA_WIDTH-1):0] k1_iop5_dat,
    output  wire                     k1_bpe5_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k1_bpe5_rdy,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe5_a,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe5_b,
    output  wire [(pDATA_WIDTH-1):0] k1_bpe5_c,
    
    //========================== 2nd Kernel =============================//
    // BPE1 
    input   wire                     k2_iop1_vld, //Stream-in to memory
    output  wire                     k2_iop1_rdy,
    input   wire [(pDATA_WIDTH-1):0] k2_iop1_dat,
    output  wire                     k2_bpe1_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k2_bpe1_rdy,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe1_a,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe1_b,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe1_c,

    // BPE2
    input   wire                     k2_iop2_vld, //Stream-in to memory
    output  wire                     k2_iop2_rdy,
    input   wire [(pDATA_WIDTH-1):0] k2_iop2_dat,
    output  wire                     k2_bpe2_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k2_bpe2_rdy,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe2_a,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe2_b,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe2_c,
    
    // BPE3
    input   wire                     k2_iop3_vld, //Stream-in to memory
    output  wire                     k2_iop3_rdy,
    input   wire [(pDATA_WIDTH-1):0] k2_iop3_dat,
    output  wire                     k2_bpe3_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k2_bpe3_rdy,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe3_a,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe3_b,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe3_c,
    
    // BPE4
    input   wire                     k2_iop4_vld, //Stream-in to memory
    output  wire                     k2_iop4_rdy,
    input   wire [(pDATA_WIDTH-1):0] k2_iop4_dat,
    output  wire                     k2_bpe4_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k2_bpe4_rdy,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe4_a,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe4_b,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe4_c,
    
    // BPE5
    input   wire                     k2_iop5_vld, //Stream-in to memory
    output  wire                     k2_iop5_rdy,
    input   wire [(pDATA_WIDTH-1):0] k2_iop5_dat,
    output  wire                     k2_bpe5_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k2_bpe5_rdy,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe5_a,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe5_b,
    output  wire [(pDATA_WIDTH-1):0] k2_bpe5_c,
    
    //========================== 3rd Kernel =============================//
    // BPE1 
    input   wire                     k3_iop1_vld, //Stream-in to memory
    output  wire                     k3_iop1_rdy,
    input   wire [(pDATA_WIDTH-1):0] k3_iop1_dat,
    output  wire                     k3_bpe1_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k3_bpe1_rdy,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe1_a,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe1_b,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe1_c,

    // BPE2
    input   wire                     k3_iop2_vld, //Stream-in to memory
    output  wire                     k3_iop2_rdy,
    input   wire [(pDATA_WIDTH-1):0] k3_iop2_dat,
    output  wire                     k3_bpe2_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k3_bpe2_rdy,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe2_a,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe2_b,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe2_c,
    
    // BPE3
    input   wire                     k3_iop3_vld, //Stream-in to memory
    output  wire                     k3_iop3_rdy,
    input   wire [(pDATA_WIDTH-1):0] k3_iop3_dat,
    output  wire                     k3_bpe3_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k3_bpe3_rdy,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe3_a,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe3_b,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe3_c,
    
    // BPE4
    input   wire                     k3_iop4_vld, //Stream-in to memory
    output  wire                     k3_iop4_rdy,
    input   wire [(pDATA_WIDTH-1):0] k3_iop4_dat,
    output  wire                     k3_bpe4_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k3_bpe4_rdy,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe4_a,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe4_b,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe4_c,
    
    // BPE5
    input   wire                     k3_iop5_vld, //Stream-in to memory
    output  wire                     k3_iop5_rdy,
    input   wire [(pDATA_WIDTH-1):0] k3_iop5_dat,
    output  wire                     k3_bpe5_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k3_bpe5_rdy,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe5_a,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe5_b,
    output  wire [(pDATA_WIDTH-1):0] k3_bpe5_c,
    
    //========================== 4st Kernel =============================//
    // BPE1 
    input   wire                     k4_iop1_vld, //Stream-in to memory
    output  wire                     k4_iop1_rdy,
    input   wire [(pDATA_WIDTH-1):0] k4_iop1_dat,
    output  wire                     k4_bpe1_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k4_bpe1_rdy,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe1_a,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe1_b,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe1_c,

    // BPE2
    input   wire                     k4_iop2_vld, //Stream-in to memory
    output  wire                     k4_iop2_rdy,
    input   wire [(pDATA_WIDTH-1):0] k4_iop2_dat,
    output  wire                     k4_bpe2_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k4_bpe2_rdy,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe2_a,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe2_b,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe2_c,
    
    // BPE3
    input   wire                     k4_iop3_vld, //Stream-in to memory
    output  wire                     k4_iop3_rdy,
    input   wire [(pDATA_WIDTH-1):0] k4_iop3_dat,
    output  wire                     k4_bpe3_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k4_bpe3_rdy,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe3_a,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe3_b,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe3_c,
    
    // BPE4
    input   wire                     k4_iop4_vld, //Stream-in to memory
    output  wire                     k4_iop4_rdy,
    input   wire [(pDATA_WIDTH-1):0] k4_iop4_dat,
    output  wire                     k4_bpe4_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k4_bpe4_rdy,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe4_a,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe4_b,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe4_c,
    
    // BPE5
    input   wire                     k4_iop5_vld, //Stream-in to memory
    output  wire                     k4_iop5_rdy,
    input   wire [(pDATA_WIDTH-1):0] k4_iop5_dat,
    output  wire                     k4_bpe5_vld, // Stream-out: X[a], X[b], GM constant
    input   wire                     k4_bpe5_rdy,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe5_a,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe5_b,
    output  wire [(pDATA_WIDTH-1):0] k4_bpe5_c

);

    // =============== Bandwidth 128-bit (64 + 64) =============== //
    // Memories for buffer (from host or PE) [in2m_sw == 2'b00 or 2'b11]

    // Memory for  FFT constant [in2m_sw == 2'b01]

    // ==================== Bandwidth 16-bit ===================== //
    // Memory for  NTT constant [in2m_sw == 2'b10]

    // Memory for iNTT constant [in2m_sw == 2'b10]

endmodule

