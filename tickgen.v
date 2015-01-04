`include "dat.vh"

module tickgen(
	input wire clk,
	input wire stall,
	input wire memdone,
	input wire ppudone,
	output reg cputick,
	output reg cputick_,
	output reg pputick,
	output reg pputick_
);

	parameter SYSMHZ = 50;
	localparam TARGMHZ = 21.4787272 / 4;
	localparam SCALE = 65536;
	localparam integer INC = TARGMHZ / SYSMHZ * SCALE;
	
	reg [20:0] ctr, ctr_;
	reg [1:0] div, div_;
	reg carry;
	
	always @(posedge clk) begin
		if(!stall) begin
			ctr <= ctr_;
			div <= div_;
			cputick <= cputick_;
			pputick <= pputick_;
		end else begin
			cputick <= 0;
			pputick <= 0;
		end
	end
	
	always @(*) begin
		ctr_ = ctr + INC[20:0];
		pputick_ = ctr >= SCALE && !pputick && ppudone && (div != 0 || memdone);
		if(pputick_)
			ctr_ = ctr - SCALE;
		div_ = div;
		if(pputick_)
			if(div == 2)
				div_ = 0;
			else
				div_ = div + 1;
		cputick_ = pputick_ && div == 0;
	end
			

endmodule
