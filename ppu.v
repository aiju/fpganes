`include "dat.vh"

module ppu(
	input wire clk,
	input wire tick,
	
	input wire [2:0] memaddr,
	output wire [7:0] ppurdata,
	input wire [7:0] memwdata,
	input wire memwr,
	input wire memreq,
	output wire memack,
	
	output reg [13:0] vmemaddr,
	input wire [7:0] vmemrdata,
	output reg [7:0] vmemwdata,
	output reg vmemwr,
	output reg vmemreq,
	input wire vmemack,
	
	output wire [8:0] outx,
	output wire [8:0] outy,
	output wire pxvalid,
	output reg [23:0] pix,
	
	output wire nmi,
	output wire ppudone,
	input wire reset
);
	
	reg vbl, vbl_, odd, odd_;
	reg [8:0] ppux, ppuy, ppux_, ppuy_;

	always @(posedge clk)
		if(tick) begin
			ppux <= ppux_;
			ppuy <= ppuy_;
			odd <= odd_;
			vbl <= vbl_;

		end

	always @(*) begin
		odd_ = odd;
		vbl_ = vbl;
		if(ppux != 340) begin
			ppux_ = ppux + 1;
			ppuy_ = ppuy;
		end else if(ppuy != 261) begin
			ppux_ = 0;
			ppuy_ = ppuy + 1;
		end else begin	
			ppux_ = 0;
			ppuy_ = 0;
			odd_ = !odd;
		end
		if(ppux == 1 && ppuy == 241)
			vbl_ = 1;
		if(ppux == 1 & ppuy == 261 || rd2002)
			vbl_ = 0;
		render = ppumask[`SHOWSPR:`SHOWBG] != 0 && (ppuy == 261 || ppuy < 240);
	end
	assign nmi = vbl && ppuctrl[7];
	
	wire wr2000, rd2002, wr2003, rd2004, wr2004, wr20051, wr20052, wr20061, wr20062, rd2007, wr2007, sprovf, spr0, left8, upalacc;
	wire vmemreq_, vmemwr_;
	reg render, spr00, spr01, spr0hit, spr0hit_;
	wire [3:0] bgpix;
	reg [3:0] bgpix0;
	wire [4:0] sprpxout, upaladdr;
	reg [4:0] sprpxout0, sprpxout1;
	wire [7:0] ppumask, ppuctrl, ppudata, regwdata, oamdata, vmemwdata_;
	reg [5:0] upaldata;
	wire [13:0] sprvmemaddr, vmemaddr_;
	
	always @(posedge clk) begin
		vmemaddr <= vmemaddr_;
		vmemwdata <= vmemwdata_;
		vmemreq <= vmemreq_;
		vmemwr <= vmemwr_;
	end
	
	ppureg ppureg0(clk, tick, memaddr, ppurdata, memwdata, memwr, memreq, memack, ppuctrl, ppumask, vbl, spr0hit, sprovf, 
		oamdata, ppudata, upalacc, upaldata, regwdata, wr2000, rd2002, wr2003, rd2004, wr2004, wr20051, wr20052, wr20061, wr20062, rd2007,
		wr2007, reset);
	ppubg ppubg0(clk, tick, vmemaddr_, vmemrdata, vmemwdata_, vmemwr_, vmemreq_, vmemack, ppux, ppuy, render, bgpix,
		ppuctrl, ppumask, regwdata, ppudata, wr2000, wr20051, wr20052, wr20061, wr20062, rd2007, wr2007,
		sprvmemaddr, upalacc, upaladdr, ppudone, reset);
	ppuspr ppuspr0(clk, tick, ppux, ppuy, render, ppuctrl, ppumask, regwdata, wr2003, rd2004, wr2004, oamdata, sprovf, sprvmemaddr,
		vmemrdata, sprpxout, spr0, reset);
	
	assign left8 = ppux < 10;
	always @(posedge clk)
		if(tick) begin
			bgpix0 <= ppumask[`SHOWBG] && (!left8 || ppumask[`BG8]) ? bgpix : 0;
			sprpxout0 <= ppumask[`SHOWSPR] && (!left8 || ppumask[`SPR8]) ? sprpxout : 0;
			sprpxout1 <= sprpxout0;
			spr00 <= spr0;
			spr01 <= spr00;
			spr0hit <= spr0hit_;
		end
	
	reg usespr;
	reg [4:0] paladdr;
	always @(*) begin
		spr0hit_ = spr0hit;
		if(ppux == 1 && ppuy == 261)
			spr0hit_ = 0;
		if(spr01 && bgpix0[1:0] != 0 && sprpxout1[1:0] != 0)
			spr0hit_ = 1;
		
		usespr = sprpxout1[1:0] != 0 && (!sprpxout1[4] || bgpix0[1:0] == 0);
		paladdr = {usespr, usespr ? sprpxout1[3:0] : bgpix0};
		if(paladdr[1:0] == 0)
			paladdr = 0;
	end
	
	function [4:0] palwrap;
	input [4:0] addr;
	begin
		palwrap = addr;
		if(addr[4] && addr[2:0] == 0)
			palwrap[4] = 0;
	end
	endfunction
	
	reg [5:0] pal[0:31];
	reg [23:0] rgb[0:63];
	initial $readmemh("ppurom.dat", rgb);
	reg [5:0] paldata;
	always @(posedge clk) begin
		paldata <= pal[palwrap(paladdr)];
		if(wr2007 && tick && upalacc)
			pal[palwrap(upaladdr)] <= regwdata[5:0];
		else
			upaldata <= pal[palwrap(upaladdr)];
		if(tick)
			pix <= rgb[paldata];
	end
	

	assign outx = ppux - 3;
	assign outy = ppuy;
	assign pxvalid = tick && ppux >= 3 && ppux < 259 && ppuy < 240;
	
endmodule
