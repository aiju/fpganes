`default_nettype none
`timescale 1 ns / 1 ps

module axi3test();

	reg clk, resetn;
	
	initial clk = 0;
	always #0.5 clk = !clk;
	initial begin
		resetn = 0;
		@(posedge clk) resetn = 1;
	end

	reg gp0_awvalid;
	wire gp0_awready;
	reg [1:0] gp0_awburst, gp0_awlock;
	reg [2:0] gp0_awsize, gp0_awprot;
	reg [3:0] gp0_awlen, gp0_awcache, gp0_awqos;
	reg [11:0] gp0_awid;
	reg [31:0] gp0_awaddr;
	
	reg gp0_arvalid;
	wire gp0_arready;
	reg [1:0] gp0_arburst, gp0_arlock;
	reg [2:0] gp0_arsize, gp0_arprot;
	reg [3:0] gp0_arlen, gp0_arcache, gp0_arqos;
	reg [11:0] gp0_arid;
	reg [31:0] gp0_araddr;
	
	reg gp0_wvalid, gp0_wlast;
	wire gp0_wready;
	reg [3:0] gp0_wstrb;
	reg [11:0] gp0_wid;
	reg [31:0] gp0_wdata;

	wire gp0_bvalid;
	reg gp0_bready;
	wire [1:0] gp0_bresp;
	wire [11:0] gp0_bid;
	
	wire gp0_rvalid;
	reg gp0_rready;
	wire [1:0] gp0_rresp;
	wire gp0_rlast;
	wire [11:0] gp0_rid;
	wire [31:0] gp0_rdata;
	
	wire [31:0] arm_addr;
	wire [31:0] arm_rdata, arm_wdata;
	wire [3:0] arm_wstrb;
	wire arm_wr, arm_req;
	reg arm_ack, arm_err;
	
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

	initial begin
		gp0_awburst = 0;
		gp0_awsize = 0;
		gp0_awlen = 0;
		gp0_awid = 12'hABC;
		gp0_awaddr = 32'hDEADBEEF;
		
		gp0_arburst = 0;
		gp0_arsize = 0;
		gp0_arlen = 0;
		gp0_arid = 12'h123;
		gp0_araddr = 32'hEA731337;
		
		gp0_bready = 1;
		gp0_rready = 1;
		gp0_arvalid = 0;
		gp0_awvalid = 0;
		gp0_wvalid = 0;
		gp0_wlast = 0;
		arm_err = 0;
		arm_ack = 0;
		
		#2 gp0_awvalid = 1;
		gp0_arvalid = 1;
		#1 gp0_awvalid = 0;
		gp0_arvalid = 0;
		
		#2 gp0_wvalid = 1;
		#1 gp0_wvalid = 0;
		#30 gp0_wlast = 1;
		gp0_wvalid = 1;
		#1 gp0_wvalid = 0;
	end
endmodule
