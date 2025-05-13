// forward / inverse FFT & NTT
module fiFFNTT 
#(  
    parameter pADDR_WIDTH = 32,
    parameter pDATA_WIDTH = 32,
    parameter pIOPS_WIDTH = 128
)
(
    input   wire                     clk,
    input   wire                     rstn,

    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,

    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast
);

    reg ap_done, ap_idle; // 0x00: Kernel status (configuration address: 0x3000_0000) read by middleware
    reg coef_done;        // 0x10: Indicate coefficient is initialized

    /*================================================================================================
    #                                       Tasks for FSM                                            #
    ==================================================================================================
    1. Stream-in gm constants 
      - FFT/iFFT constants: 64-bit real part + 64-bit imaginary part => needs 4 cycles (32-bit * 4) to complete 1 constant
        - Double the bandwidth of SRAM for real part and imaginary part, store into same address
      - 16-bit NTT constants + 16-bit iNTT constants
        - Use 2 SRAMs => 1 stream-in cycle (32-bit) can store both NTT and iNTT constants in same address
    2. Stream-in data into IOP buffer
    3. Stream-in data from PE to IOP
    ================================================================================================*/


endmodule


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

module butterfly
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers represent real & imaginary part
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [1:0] mode, // FFT/iFFT/NTT/iNTT

    input   wire i_vld,
    output  wire i_rdy,
    
    output  wire o_vld,
    input   wire o_rdy,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    input   wire [(pDATA_WIDTH-1):0] gm, // constant
    output  wire [(pDATA_WIDTH-1):0] ao,
    output  wire [(pDATA_WIDTH-1):0] bo

);

    // complex mul & add & sub for FFT/iFFT

    // Complex Multiplication:
    // y_re = (a_re * b_re) - (a_im * b_im)
    // y_im = (a_re * b_im) + (a_im * b_re)
    // Rewrite as:
    // y_re = a_re * (b_re - b_im) + b_im * (a_re - a_im)
    // y_im = a_im * (b_re + b_im) + b_im * (a_re - a_im)
    // It will reduce the mul usage from 4 to 3 since we reuse [b_im * (a_re - a_im)]

    // montgomery mul & add & sub for NTT/iNTT

endmodule

module fmul64
#(  
    parameter pDATA_WIDTH = 64 // double-precision multiplication
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    output  wire [(pDATA_WIDTH-1):0] bo

);

endmodule

module fadd64
#(  
    parameter pDATA_WIDTH = 64 // double-precision addition
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    output  wire [(pDATA_WIDTH-1):0] bo

);

endmodule

module fsub64
#(  
    parameter pDATA_WIDTH = 64 // double-precision substraction
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    output  wire [(pDATA_WIDTH-1):0] bo

);

endmodule

module umul16
#(  
    parameter pDATA_WIDTH = 16
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    output  wire [(pDATA_WIDTH-1):0] bo

);

endmodule

module uadd16
#(  
    parameter pDATA_WIDTH = 16
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    output  wire [(pDATA_WIDTH-1):0] bo

);

endmodule

module usub16
#(  
    parameter pDATA_WIDTH = 16
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    output  wire [(pDATA_WIDTH-1):0] bo

);

endmodule

