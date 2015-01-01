`include "dport.vh"

module top(
	inout wire aux_p,
	inout wire aux_n,
	input wire [1:0] refclk,
	output wire [3:0] tx,
	output wire debug
);

	wire clk, resetn;
	wire [3:0] fclk, fresetn;
	assign clk = fclk[0];
	assign resetn = fresetn[0];

	wire gp0_awvalid;
	wire gp0_awready;
	wire [1:0] gp0_awburst, gp0_awlock;
	wire [2:0] gp0_awsize, gp0_awprot;
	wire [3:0] gp0_awlen, gp0_awcache, gp0_awqos;
	wire [11:0] gp0_awid;
	wire [31:0] gp0_awaddr;
	
	wire gp0_arvalid;
	wire gp0_arready;
	wire [1:0] gp0_arburst, gp0_arlock;
	wire [2:0] gp0_arsize, gp0_arprot;
	wire [3:0] gp0_arlen, gp0_arcache, gp0_arqos;
	wire [11:0] gp0_arid;
	wire [31:0] gp0_araddr;
	
	wire gp0_wvalid, gp0_wlast;
	wire gp0_wready;
	wire [3:0] gp0_wstrb;
	wire [11:0] gp0_wid;
	wire [31:0] gp0_wdata;

	wire gp0_bvalid;
	wire gp0_bready;
	wire [1:0] gp0_bresp;
	wire [11:0] gp0_bid;
	
	wire gp0_rvalid;
	wire gp0_rready;
	wire [1:0] gp0_rresp;
	wire gp0_rlast;
	wire [11:0] gp0_rid;
	wire [31:0] gp0_rdata;
	
	wire [31:0] arm_addr;
	wire [31:0] arm_rdata, arm_wdata;
	wire [3:0] arm_wstrb;
	wire arm_wr, arm_req;
	wire arm_ack, arm_err;
	
	axi3 axi3_0(
		clk,
		resetn,
		
		gp0_arvalid,
		gp0_awvalid,
		gp0_bready,
		gp0_rready,
		gp0_wlast,
		gp0_wvalid,
		gp0_arid,
		gp0_awid,
		gp0_wid,
		gp0_arburst,
		gp0_arlock,
		gp0_arsize,
		gp0_awburst,
		gp0_awlock,
		gp0_awsize,
		gp0_arprot,
		gp0_awprot,
		gp0_araddr,
		gp0_awaddr,
		gp0_wdata,
		gp0_arcache,
		gp0_arlen,
		gp0_arqos,
		gp0_awcache,
		gp0_awlen,
		gp0_awqos,
		gp0_wstrb,
		gp0_arready,
		gp0_awready,
		gp0_bvalid,
		gp0_rlast,
		gp0_rvalid,
		gp0_wready,
		gp0_bid,
		gp0_rid,
		gp0_bresp,
		gp0_rresp,
		gp0_rdata,
		
		arm_addr,
		arm_rdata,
		arm_wdata,
		arm_wr,
		arm_req,
		arm_ack,
		arm_wstrb,
		arm_err
	);

	reg auxi1, auxi, auxo0;
	wire auxi0, auxd, auxo;
	wire debug2;
	wire [31:0] phyctl;
	wire [`ATTRMAX:0] attr;
	wire [31:0] dmastart, dmaend;

	aux aux0(
		clk,
		arm_addr,
		arm_rdata,
		arm_wdata,
		arm_wr,
		arm_req,
		arm_ack,
		arm_wstrb,
		arm_err,
		auxi,
		auxo,
		auxd,
		phyctl,
		attr,
		dmastart,
		dmaend,
		debug,
		debug2
	);

	wire usrclk;
	wire [31:0] indata, frdata, scrdata;
	wire [3:0] frisk, scrisk;
	wire consume, restart;
	wire [21:0] romaddr;
	wire [7:0] romdata, input0, input1;
	wire romreq, romack;
	wire [8:0] outx, outy;
	wire [23:0] pix;
	
	nes nes_i(clk, phyctl[29], romaddr, romdata, romreq, romack, outx, outy, pxvalid, pix, input0, input1, stall);
	romread romread_i(clk, romaddr, romdata, romreq, romack);
	dpconv conv_i(clk, ppux, ppuy, pxvalid, pix, stall, usrclk, restart, consume, indata);
	dpsrc src_i(usrclk, !phyctl[30], attr, indata, consume, restart, frdata, frisk); 
	scrambler scr_i(usrclk, frdata, frisk, scrdata, scrisk);
	dpphy phy_i(clk, usrclk, phyctl, refclk, tx, scrdata, scrisk);

     always @(posedge clk) begin
     	auxi1 <= auxi0;
     	auxi <= !auxi1;
     	auxo0 <= !auxo;
     end
     PULLUP p0(.O(aux_p));
     PULLDOWN p1(.O(aux_n));

IOBUFDS #(.DIFF_TERM("false"), .IOSTANDARD("BLVDS_25")) io_1(.I(auxo0), .O(auxi0), .T(auxd), .IO(aux_p), .IOB(aux_n));
	PS7 PS7_0(
		.MAXIGP0ARVALID(gp0_arvalid),
		.MAXIGP0AWVALID(gp0_awvalid),
		.MAXIGP0BREADY(gp0_bready),
		.MAXIGP0RREADY(gp0_rready),
		.MAXIGP0WLAST(gp0_wlast),
		.MAXIGP0WVALID(gp0_wvalid),
		.MAXIGP0ARID(gp0_arid),
		.MAXIGP0AWID(gp0_awid),
		.MAXIGP0WID(gp0_wid),
		.MAXIGP0ARBURST(gp0_arburst),
		.MAXIGP0ARLOCK(gp0_arlock),
		.MAXIGP0ARSIZE(gp0_arsize),
		.MAXIGP0AWBURST(gp0_awburst),
		.MAXIGP0AWLOCK(gp0_awlock),
		.MAXIGP0AWSIZE(gp0_awsize),
		.MAXIGP0ARPROT(gp0_arprot),
		.MAXIGP0AWPROT(gp0_awprot),
		.MAXIGP0ARADDR(gp0_araddr),
		.MAXIGP0AWADDR(gp0_awaddr),
		.MAXIGP0WDATA(gp0_wdata),
		.MAXIGP0ARCACHE(gp0_arcache),
		.MAXIGP0ARLEN(gp0_arlen),
		.MAXIGP0ARQOS(gp0_arqos),
		.MAXIGP0AWCACHE(gp0_awcache),
		.MAXIGP0AWLEN(gp0_awlen),
		.MAXIGP0AWQOS(gp0_awqos),
		.MAXIGP0WSTRB(gp0_wstrb),
		.MAXIGP0ACLK(clk),
		.MAXIGP0ARREADY(gp0_arready),
		.MAXIGP0AWREADY(gp0_awready),
		.MAXIGP0BVALID(gp0_bvalid),
		.MAXIGP0RLAST(gp0_rlast),
		.MAXIGP0RVALID(gp0_rvalid),
		.MAXIGP0WREADY(gp0_wready),
		.MAXIGP0BID(gp0_bid),
		.MAXIGP0RID(gp0_rid),
		.MAXIGP0BRESP(gp0_bresp),
		.MAXIGP0RRESP(gp0_rresp),
		.MAXIGP0RDATA(gp0_rdata),
		
		.FCLKCLK(fclk),
		.FCLKRESETN(fresetn)
	);

endmodule
