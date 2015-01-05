`include "dat.vh"

module mmc(
	input wire clk,
	
	input wire [15:0] memaddr,
	output wire [7:0] prgrdata,
	input wire [7:0] memwdata,
	input wire memwr,
	input wire prgreq,
	output wire prgack,
	
	input wire [13:0] vmemaddr,
	output wire [7:0] chrrdata,
	input wire [7:0] vmemwdata,
	input wire vmemwr,
	input wire chrreq,
	output wire chrack,
	
	output wire [20:0] promaddr,
	input wire [7:0] promdata,
	output wire promreq,
	input wire promack,
	
	output wire [20:0] cromaddr,
	input wire [7:0] cromdata,
	output wire cromreq,
	input wire cromack,
	
	output wire [12:0] chrramaddr,
	input wire [7:0] chrramrdata,
	output wire [7:0] chrramwdata,
	output wire chrramwr,
	output wire chrramreq,
	input wire chrramack,
	
	input wire [127:0] header,
	output wire [2:0] mirr,
	output wire [7:0] err
);

	localparam NMMC = 3;
	localparam MMCB = 2;
	reg [MMCB-1:0] act;
	wire [NMMC-1:0] aresetn, aprgack, achrack, apromreq, acromreq, achrramwr, achrramreq;
	wire [7:0] aprgrdata[NMMC-1:0], achrrdata[NMMC-1:0], achrramwdata[NMMC-1:0];
	wire [20:0] apromaddr[NMMC-1:0], acromaddr[NMMC-1:0];
	wire [12:0] achrramaddr[NMMC-1:0];
	wire [2:0] amirr[NMMC-1:0];

`define MMC(name, n) name name``_i(clk, act != n, memaddr, aprgrdata[n], memwdata, memwr, prgreq, aprgack[n],\
	vmemaddr, achrrdata[n], vmemwdata, vmemwr, chrreq, achrack[n], apromaddr[n], promdata, apromreq[n], promack,\
	acromaddr[n], cromdata, acromreq[n], cromack, achrramaddr[n], chrramrdata, achrramwdata[n], achrramwr[n], achrramreq[n],\
	chrramack, header, amirr[n])
	
	`MMC(nrom, 0);
	`MMC(mmc1, 1);
	
	assign prgack = aprgack[act];
	assign chrack = achrack[act];
	assign promreq = apromreq[act];
	assign cromreq = acromreq[act];
	assign chrramwr = achrramwr[act];
	assign chrramreq = achrramreq[act];
	assign prgrdata = aprgrdata[act];
	assign chrrdata = achrrdata[act];
	assign chrramwdata = achrramwdata[act];
	assign promaddr = apromaddr[act];
	assign cromaddr = acromaddr[act];
	assign chrramaddr = achrramaddr[act];
	assign mirr = amirr[act];
	
	reg [MMCB-1:0] mmctab[0:255];
	integer i;
	
	initial begin
		for(i = 0; i < 256; i = i + 1)
			mmctab[i] = -1;
		mmctab[0] = 0;
		mmctab[1] = 1;
	end
	
	wire [7:0] mapper;
	assign mapper = {header[127:96] != 0 ? 4'd0 : header[63:60], header[55:52]};
	assign err = act == ~0 ? mapper : 0;
	always @(posedge clk)
		act <= mmctab[mapper];
endmodule
