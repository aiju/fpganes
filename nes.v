`include "dat.vh"

module nes(
	input wire clk,
	input wire init,
	
	output wire [21:0] romaddr,
	input wire [7:0] romdata,
	output wire romreq,
	input wire romack,
	
	output wire [8:0] outx,
	output wire [8:0] outy,
	output wire pxvalid,
	output wire [23:0] pix,
	
	input wire [7:0] input0,
	input wire [7:0] input1,
	input wire stall,
	output wire [94:0] nestrace,
	output wire cputick_,
	output wire pputick_,
	output wire halt

);
	wire cputick, pputick, memwr, cpuwr, dmawr, vmemwr, vmemreq, vmemack, ppureq, ppuack, ioreq, ioack, prgreq, prgack;
	wire chrreq, chrack, nmi, reset, promreq, promack, cromreq, cromack, chrramreq, chrramack, chrramwr, cpureq, dmareq;
	wire cpuack, dmaack, romstall, cpudone, ppudone, memdone, dmadone;
	wire [2:0] mirr;
	wire [7:0] memrdata, memwdata, vmemrdata, vmemwdata, ppurdata, iordata, prgrdata, chrrdata, promdata, cromdata;
	wire [7:0] chrramrdata, chrramwdata, cpuwdata, dmawdata;
	wire [12:0] chrramaddr;
	wire [13:0] vmemaddr;
	wire [15:0] memaddr, cpuaddr, dmaaddr;
	wire [20:0] promaddr, cromaddr;
	wire [127:0] header;

	tickgen tickgen0(clk, stall, memdone, ppudone, cputick, cputick_, pputick, pputick_);
	mem mem0(clk, halt, cpudone, dmadone, memdone, memaddr, memrdata, memwdata, memwr, cpuaddr, cpuwdata, cpuwr, cpureq, cpuack,
		dmaaddr, dmawdata, dmawr, dmareq, dmaack, vmemaddr, vmemrdata, vmemwdata, vmemwr, vmemreq, vmemack, ppurdata, ppureq, ppuack,
		iordata, ioreq, ioack, prgrdata, prgreq, prgack, chrrdata, chrreq, chrack, chrramaddr, chrramrdata, chrramwdata, chrramwr,
		chrramreq, chrramack, mirr);
	cpu cpu0(clk, cputick, cpuaddr, memrdata, cpuwdata, cpuwr, cpureq, cpuack, 0, nmi, halt, reset, cpudone, nestrace);
	io io0(clk, cputick, dmadone, memaddr[4:0], iordata, memwdata, memwr, ioreq, ioack, halt, dmaaddr, memrdata, dmawdata,
		dmawr, dmareq, dmaack, input0, input1, reset);
	ppu ppu0(clk, pputick, memaddr[2:0], ppurdata, memwdata, memwr, ppureq, ppuack, vmemaddr, vmemrdata, vmemwdata,
		vmemwr, vmemreq, vmemack, outx, outy, pxvalid, pix, nmi, ppudone, reset);
	nrom nrom0(clk, memaddr, prgrdata, memwdata, memwr, prgreq, prgack, vmemaddr, chrrdata, vmemwdata, vmemwr, chrreq, chrack,
		promaddr, promdata, promreq, promack, cromaddr, cromdata, cromreq, cromack, chrramaddr, chrramrdata, chrramwdata,
		chrramwr, chrramreq, chrramack, header, mirr);
	romarb romarb0(clk, init, reset, cputick, promaddr, promdata, promreq, promack, cromaddr, cromdata, cromreq, cromack, romaddr, romdata, romreq, romack, header);
endmodule
