`include "dat.vh"

module ppureg(
	input wire clk,
	input wire tick,
	
	input wire [2:0] memaddr,
	output reg [7:0] ppurdata,
	input wire [7:0] memwdata,
	input wire memwr,
	input wire memreq,
	output reg memack,
	
	output reg [7:0] ppuctrl,
	output reg [7:0] ppumask,
	input wire vbl,
	input wire spr0hit,
	input wire sprovf,
	input wire [7:0] oamdata,
	input wire [7:0] ppudata,
	input wire upalacc,
	input wire [5:0] upaldata,
	
	output reg [7:0] regwdata,
	output reg wr2000,
	output reg rd2002,
	output reg wr2003,
	output reg rd2004,
	output reg wr2004,
	output reg wr20051,
	output reg wr20052,
	output reg wr20061,
	output reg wr20062,
	output reg rd2007,
	output reg wr2007,
	
	input wire reset
);

	reg [2:0] smemaddr;
	reg [7:0] smemwdata;
	reg smemwr, smemrd, smemwlatch;
	reg memreq0;
	
	reg [7:0] ppuwbuf;
	reg w, w_;

	always @(posedge clk) begin
		if(tick) begin
			smemwr <= 0;
			smemrd <= 0;
			w <= w_;
		end
		memreq0 <= memreq;
		if(memreq && !memreq0) begin
			smemwr <= memwr;
			smemrd <= !memwr;
			smemaddr <= memaddr;
			smemwdata <= memwdata;
			smemwlatch <= w;
			if(!memwr) begin
				ppurdata <= ppuwbuf;
				case(memaddr)
				2: begin
					ppurdata[7:5] <= {vbl, spr0hit, sprovf};
					w_ <= 0;
				end
				4: ppurdata <= oamdata;
				7: ppurdata <= upalacc ? {2'b00, upaldata} : ppudata;
				endcase
			end else
				case(memaddr)
				5, 6: w_ <= !w;
				endcase
			memack <= 1;
		end else
			memack <= 0;
	end
	
	always @(*) begin
		regwdata = smemwdata;
		wr2000 = smemwr && smemaddr == 0;
		rd2002 = smemrd && smemaddr == 2;
		wr2003 = smemwr && smemaddr == 3;
		rd2004 = smemrd && smemaddr == 4;
		wr2004 = smemwr && smemaddr == 4;
		wr20051 = smemwr && smemaddr == 5 && !smemwlatch;
		wr20052 = smemwr && smemaddr == 5 && smemwlatch;
		wr20061 = smemwr && smemaddr == 6 && !smemwlatch;
		wr20062 = smemwr && smemaddr == 6 && smemwlatch;
		rd2007 = smemrd && smemaddr == 7;
		wr2007 = smemwr && smemaddr == 7;
	end
	
	always @(posedge clk)
		if(tick && smemwr) begin
			ppuwbuf <= smemwdata;
			case(memaddr)
			0: ppuctrl <= smemwdata;
			1: ppumask <= smemwdata;
			endcase
		end

endmodule
