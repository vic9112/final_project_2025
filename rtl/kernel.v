
module kernel 
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers
)
(
    input  wire                     clk,
    input  wire                     rstn,

    input  wire                     ld_vld,
    output wire                     ld_rdy,
    input  wire [(pDATA_WIDTH-1):0] ld_dat,

    output wire                     sw_vld,
    input  wire                     sw_rdy,
    output wire [(pDATA_WIDTH-1):0] sw_dat,

    input  wire               [7:0] mode,
    input  wire                     decode,
    output wire                     sw_lst,  // this is set when handshake
);

    //========================== Declaration ==========================
    // =============== axi-lite =============== //
    reg ld_rdy_tmp;
    reg ld_rdy_next;
    reg sw_vld_tmp;
    reg sw_vld_next;

    // local parameter
    localparam PULL_DN = 0;
    localparam PULL_UP = 1;

    // =============== kernel mode =============== //
    reg [7:0] mode_state_tmp;
    reg [7:0] mode_state_next;
    wire [7:0] butterfly_mode;

    //========================== Function ==========================
    // =============== axi-lite =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        ld_rdy_tmp <= PULL_DN;
      end else begin
        ld_rdy_tmp <= ld_rdy_next;
      end
    end
    
    always @(*) begin
      if (ld_vld && !ld_rdy_tmp) begin
        ld_rdy_next = PULL_UP;
      end else begin
        ld_rdy_next = PULL_DN;
      end
    end

    // =============== kernel mode =============== //
    always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        mode_state_tmp <= PULL_DN;
      end else begin
        mode_state_tmp <= mode_state_next;
      end
    end

    always @(*) begin
      if (decode) begin
        mode_state_next = mode;
      end else begin
        mode_state_next = mode_state_tmp;
      end
    end

    assign butterfly_mode = mode_state_tmp;

    /*================================================================================================
    #                                       Address Generation                                       #
    ================================================================================================*/
    
    butterfly BPE1 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
        .i_vld (),
        .i_rdy (),
        .o_vld (),
        .o_rdy (),
        .ai    (),
        .bi    (),
        .gm    (),
        .ao    (),
        .bo    ()
    );

    butterfly BPE2 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
        .i_vld (),
        .i_rdy (),
        .o_vld (),
        .o_rdy (),
        .ai    (),
        .bi    (),
        .gm    (),
        .ao    (),
        .bo    ()
    );

    butterfly BPE3 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
        .i_vld (),
        .i_rdy (),
        .o_vld (),
        .o_rdy (),
        .ai    (),
        .bi    (),
        .gm    (),
        .ao    (),
        .bo    ()
    );

    butterfly BPE4 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
        .i_vld (),
        .i_rdy (),
        .o_vld (),
        .o_rdy (),
        .ai    (),
        .bi    (),
        .gm    (),
        .ao    (),
        .bo    ()
    );

    butterfly BPE5 (
        .clk   (clk),
        .rstn  (rstn),
        .mode  (),
        .i_vld (),
        .i_rdy (),
        .o_vld (),
        .o_rdy (),
        .ai    (),
        .bi    (),
        .gm    (),
        .ao    (),
        .bo    ()
    );

endmodule

