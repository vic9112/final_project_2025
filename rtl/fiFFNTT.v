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

