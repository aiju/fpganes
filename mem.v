`include "dat.vh"

module mem(
	input wire clk,
	input wire halt,
	input wire cpudone,
	input wire dmadone,
	output wire memdone,
	
	output reg [15:0] memaddr,
	output reg [7:0] memrdata,
	output reg [7:0] memwdata,
	output reg memwr,
	
	input wire [15:0] cpuaddr,
	input wire [7:0] cpuwdata,
	input wire cpuwr,
	input wire cpureq,
	output reg cpuack,
	
	input wire [15:0] dmaaddr,
	input wire [7:0] dmawdata,
	input wire dmawr,
	input wire dmareq,
	output reg dmaack,
	
	input wire [13:0] vmemaddr,
	output reg [7:0] vmemrdata_,
	input wire [7:0] vmemwdata,
	input wire vmemwr,
	input wire vmemreq,
	output reg vmemack,
	
	input wire [7:0] ppurdata,
	output reg ppureq,
	input wire ppuack,
	
	input wire [7:0] iordata,
	output reg ioreq,
	input wire ioack,
	
	input wire [7:0] prgrdata,
	output reg prgreq,
	input wire prgack,
	
	input wire [7:0] chrrdata,
	output reg chrreq,
	input wire chrack,
	
	input wire [12:0] chrramaddr,
	output reg [7:0] chrramrdata,
	input wire [7:0] chrramwdata,
	input wire chrramwr,
	input wire chrramreq,
	output reg chrramack,
	
	input wire [2:0] mirr
);
	reg memreq, memack;
	reg [7:0] memrdata_;
	
	always @(posedge clk) begin
		memrdata <= memrdata_;
		cpuack <= halt ? 0 : memack;
		dmaack <= halt ? memack : 0;
		memreq <= halt ? dmareq : cpureq;
		memaddr <= halt ? dmaaddr : cpuaddr;
		memwdata <= halt ? dmawdata : cpuwdata;
		memwr <= halt ? dmawr : cpuwr;
	end
	assign memdone = halt ? dmadone : cpudone;

	reg wramreq, wramack, ntreq, ntack;
	reg [7:0] wramdata, ntdata;
	
	always @(*) begin
		wramreq = 0;
		ppureq = 0;
		prgreq = 0;
		ioreq = 0;
		memack = 0;
		memrdata_ = 8'hxx;
		case(memaddr[15:13])
		0: begin
			wramreq = memreq;
			memack = wramack;
			memrdata_ = wramdata;
		end
		1: begin
			ppureq = memreq;
			memack = ppuack;
			memrdata_ = ppurdata;
		end
		default:
			if(memaddr < 16'h4020) begin
				ioreq = memreq;
				memack = ioack;
				memrdata_ = iordata;
			end else begin
				prgreq = memreq;
				memack = prgack;
				memrdata_ = prgrdata;
			end
		endcase
	end
	
	always @(*) begin
		chrreq = 0;
		ntreq = 0;
		if(vmemaddr[13]) begin
			ntreq = vmemreq && vmemaddr < 14'h3F00;
			vmemack = ntack;
			vmemrdata_ = ntdata;
		end else begin
			chrreq = vmemreq;
			vmemack = chrack;
			vmemrdata_ = chrrdata;
		end
	end

	reg [7:0] wram[0:2047];
	reg [7:0] nt[0:4095];
	reg [7:0] chrram[0:8191];
	reg [11:0] ntaddr;
	
	reg wramreq0;
	always @(posedge clk) begin
		wramreq0 <= wramreq;
		if(wramreq && !wramreq0) begin
			wramack <= 1;
			if(memwr)
				wram[memaddr[10:0]] <= memwdata;
			else
				wramdata <= wram[memaddr[10:0]];
		end else
			wramack <= 0;
	end
	
	always @(*)
		case(mirr)
		`MIRRHOR: ntaddr = {1'b0, vmemaddr[11],vmemaddr[9:0]};
		`MIRRVER: ntaddr = {1'b0, vmemaddr[10:0]};
		`MIRRA: ntaddr = {2'b00, vmemaddr[9:0]};
		`MIRRB: ntaddr = {2'b01, vmemaddr[9:0]};
		`MIRR4: ntaddr = vmemaddr[11:0];
		default: ntaddr = 12'hxxx;
		endcase

	reg ntreq0, chrramreq0;
	always @(posedge clk) begin
		ntreq0 <= ntreq;
		if(ntreq && !ntreq0) begin
			ntack <= 1;
			if(vmemwr)
				nt[ntaddr] <= vmemwdata;
			else
				ntdata <= nt[ntaddr];
		end else
			ntack <= 0;
	end
	
	always @(posedge clk) begin
		chrramreq0 <= chrramreq;
		if(chrramreq && !chrramreq0) begin
			chrramack <= 1;
			if(chrramwr)
				chrram[chrramaddr] <= chrramwdata;
			else
				chrramrdata <= chrram[chrramaddr];
		end else
			chrramack <= 0;
	end
	
endmodule
