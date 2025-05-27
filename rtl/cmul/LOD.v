module LOD #(
    parameter pDATA_WIDTH    = 128,
    parameter pCOUNTER_WIDTH = 11
)(
    input [(pDATA_WIDTH-1)   :0] A,
    output[(pCOUNTER_WIDTH-1):0] position
);

localparam pSECOND_WIDTH  = pDATA_WIDTH  /2;   //* 64
localparam pTHIRD_WIDTH   = pSECOND_WIDTH/2;   //* 32
localparam pFOURTH_WIDTH  = pTHIRD_WIDTH /2;   //* 16
localparam pFIFTH_WIDTH   = pFOURTH_WIDTH/2;   //* 8
localparam pSIXTH_WIDTH   = pFIFTH_WIDTH/2 ;   //* 4
localparam pSEVENTH_WIDTH = pSIXTH_WIDTH/2 ;   //* 2


wire [6:0]                  data_chk;

wire [(pSECOND_WIDTH-1):0]  part_1;
wire [(pTHIRD_WIDTH-1):0]   part_2;
wire [(pFOURTH_WIDTH-1):0]  part_3;
wire [(pFIFTH_WIDTH-1):0]   part_4;
wire [(pSIXTH_WIDTH-1):0]   part_5;
wire [(pSEVENTH_WIDTH-1):0] part_6;


assign data_chk[6] = |A     [(pDATA_WIDTH-1):pSECOND_WIDTH];   
assign data_chk[5] = |part_1[(pSECOND_WIDTH-1): pTHIRD_WIDTH];
assign data_chk[4] = |part_2[(pTHIRD_WIDTH-1) : pFOURTH_WIDTH];
assign data_chk[3] = |part_3[(pFOURTH_WIDTH-1): pFIFTH_WIDTH ];
assign data_chk[2] = |part_4[(pFIFTH_WIDTH-1) : pSIXTH_WIDTH ];
assign data_chk[1] = |part_5[(pSIXTH_WIDTH-1) : pSEVENTH_WIDTH];
assign data_chk[0] = |part_6[(pSEVENTH_WIDTH-1)];


 
assign	part_1	 = (data_chk[6]) ?      A[(pDATA_WIDTH-1):pSECOND_WIDTH]    :      A[(pSECOND_WIDTH-1):0]; 
assign	part_2 	 = (data_chk[5]) ? part_1[(pSECOND_WIDTH-1):pTHIRD_WIDTH]   : part_1[(pTHIRD_WIDTH-1):0];		
assign	part_3 	 = (data_chk[4]) ? part_2[(pTHIRD_WIDTH-1) :pFOURTH_WIDTH]  : part_2[(pFOURTH_WIDTH-1):0];		
assign	part_4 	 = (data_chk[3]) ? part_3[(pFOURTH_WIDTH-1):pFIFTH_WIDTH]   : part_3[(pFIFTH_WIDTH-1 ):0];		
assign  part_5   = (data_chk[2]) ? part_4[(pFIFTH_WIDTH-1 ):pSIXTH_WIDTH]   : part_4[(pSIXTH_WIDTH-1):0];		
assign  part_6   = (data_chk[1]) ? part_5[(pSIXTH_WIDTH-1) :pSEVENTH_WIDTH] : part_5[(pSEVENTH_WIDTH-1):0];		


assign 	position = (|A) ? {{(pCOUNTER_WIDTH-7){1'b0}}, ~data_chk} : {(pCOUNTER_WIDTH){1'b1}} ;

endmodule