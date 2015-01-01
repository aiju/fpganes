`include "dat.vh"

module romarb(
	input wire clk,
	input wire init,
	output reg reset,
	input wire cputick,
	
	input wire [20:0] promaddr,
	output reg [7:0] promdata,
	input wire promreq,
	output reg promack,
	
	input wire [20:0] cromaddr,
	output reg [7:0] cromdata,
	input wire cromreq,
	output reg cromack,
	
	output reg [21:0] romaddr,
	input wire [7:0] romdata,
	output reg romreq,
	input wire romack,
	
	output reg [127:0] header
);

	reg incheadn, setheader;
	reg [3:0] headn;
	reg [2:0] state, state_;
	reg [21:0] prgsize, chrsize, prgoff, chroff;
	reg promack_, cromack_;
	localparam IDLE = 0;
	localparam INIT = 1;
	localparam INITACK = 2;
	localparam PROM = 3;;
	localparam CROM = 4;
	localparam WAITTICK = 5;
	
	always @(posedge clk) begin
		state <= !init ? state_ : INIT;
		if(setheader)
			header[headn * 8 +: 8] <= romdata;
		if(incheadn)
			headn <= headn + 1;
		if(init)
			headn <= 0;
		promack <= promack_;
		cromack <= cromack_;
		if(promack_)
			promdata <= romdata;
		if(cromack_)
			cromdata <= romdata;
	end
	
	always @(*) begin
		state_ = state;
		reset = 0;
		promack_ = 0;
		cromack_ = 0;
		romreq = 0;
		incheadn = 0;
		romaddr = 22'hxxxx;
		setheader = 0;
		case(state)
		IDLE: begin
			if(promreq)
				state_ = PROM;
			if(cromreq)
				state_ = CROM;
		end
		INIT: begin
			reset = 1;
			romaddr = {18'd0, headn};
			romreq = 1;
			if(romack) begin
				state_ = INITACK;
				setheader = 1;
			end
		end
		INITACK: begin
			reset = 1;
			romaddr = {18'd0, headn};
			romreq = 0;
			if(!romack) begin
				state_ = headn == 15 ? WAITTICK : INIT;
				incheadn = 1;
			end
		end
		PROM: begin
			romaddr = prgoff + {1'b0, promaddr} % prgsize;
			romreq = promreq;
			promack_ = romack;
			if(!promreq && !romack)
				state_ = IDLE;
		end
		CROM: begin
			romaddr = chroff + {1'b0, cromaddr} % chrsize;
			romreq = cromreq;
			cromack_ = romack;
			if(!cromreq && !romack)
				state_ = IDLE;
		end
		WAITTICK: begin
			reset = 1;
			if(cputick)
				state_ = IDLE;
		end
		endcase
	end
	
	always @(*) begin
		prgoff = 16 | (header[50] ? 512 : 0);
		prgsize = header[39:32] * 16384;
		chroff = prgoff + prgsize;
		chrsize = header[47:40] * 8192;
	end
endmodule
