`include "dport.vh"

module dpconv(
	input wire clk,
	input wire [8:0] ppux,
	input wire [8:0] ppuy,
	input wire [23:0] pix,
	input wire empty,
	output reg rden,
	input wire restart,
	input wire consume,
	output wire [31:0] outdat
);
	reg [8:0] ppux0, ppuy0;
	reg [23:0] pix0;

	reg xyinc, xyzero;
	reg [9:0] ox, oy;
	reg [1:0] state, state_;
	reg [2:0] rem;
	reg [31:0] outdatr, outdatr_;
	assign outdat = consume ? outdatr_ : outdatr;
	localparam SKIP = 0;
	localparam OUT = 1;
	
	initial state = SKIP;
	
	always @(posedge clk) begin
		state <= state_;
		if(xyinc) begin
			outdatr <= outdatr_;
			if(ox != 479)
				ox <= ox + 1;
			else if(oy != 479) begin
				ox <= 0;
				oy <= oy + 1;
			end else begin
				ox <= 0;
				oy <= 0;
			end
			if(rem != 2)
				rem <= rem + 1;
			else
				rem <= 0;
		end
		if(xyzero) begin
			ox <= 0;
			oy <= 0;
			rem <= 1;
		end
		if(rden) begin
			pix0 <= pix;
			ppux0 <= ppux;
			ppuy0 <= ppuy;
		end
	end
	
	always @(*) begin
		state_ = state;
		xyzero = 0;
		xyinc = 0;
		rden = 0;
		outdatr_ = 0;
		case(state)
		SKIP: begin
			xyzero = 1;
			if(!empty)
				if(ppux0 == 0 && ppuy0 == 0)
					state_ = OUT;
				else
					rden = 1;
		end
		OUT: begin
			if(ox >= 48 && ox < 432 && !oy[0])
				case(rem)
				0: outdatr_ = {pix0[23:16], pix0[7:0], pix0[15:8], pix0[23:16]};
				1: begin
					outdatr_ = {pix[15:8], pix[23:16], pix0[7:0], pix0[15:8]};
					rden = consume;
				end
				2: begin
					outdatr_ = {pix0[7:0], pix0[15:8], pix0[23:16], pix0[7:0]};
					rden = consume;
				end
				endcase
			xyinc = consume;
		end
		endcase
		if(restart)
			state_ = SKIP;
	end

endmodule
