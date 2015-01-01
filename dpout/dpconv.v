`include "dport.vh"

module dpconv(
	input wire clk0,
	input wire [8:0] ppux,
	input wire [8:0] ppuy,
	input wire pxvalid,
	input wire [23:0] pix,
	output wire stall,
	
	input wire clk,
	input wire restart,
	input wire consume,
	output reg [31:0] outdat,
);

	wire [63:0] do;
	wire [8:0] oppux, oppuy;
	wire [23:0] opix;
	assign oppux = do[41:33];
	assign oppuy = do[32:24];
	assign opix = do[23:0];
	reg rden;
	
	FIFO36E1 #(.FIRST_WORD_FALL_THROUGH(TRUE)) fifo(
		.FULL(stall),
		.EMPTY(empty),
		.WREN(pxvalid),
		.DI({22'd0, ppux, ppuy, pix}),
		.DO(do),
		.RDEN(rden),
		.WRCLK(clk0),
		.RDCLK(clk),
	);
	
	reg [8:0] oppux0, oppuy0;
	reg [23:0] opix0;

	reg xyinc, xyzero;
	reg [9:0] ox, oy;
	reg [1:0] state, state_;
	reg [2:0] rem;
	localparam SKIP = 0;
	
	always @(posedge clk) begin
		state <= state_;
		if(xyinc) begin
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
			rem <= 0;
		end
		if(do)
			opix0 <= opix;
	end
	
	always @(*) begin
		state_ = state;
		xyzero = 0;
		xyinc = 0;
		case(state)
		SKIP: begin
			xyzero = 0;
			if(!empty)
				if(oppux0 == 0 && oppuy0 == 0)
					state_ = OUT;
				else
					do = 1;
		end
		OUT:
			if(ox < 96 || ox >= 544 || oy[0])
				outdat = 0;
			else begin
				case(rem)
				0: outdat = {opix0, opix0[7:0]};
				1: begin
					outdat = {opix0[15:0], opix[23:8]};
					do = 1;
				end
				2: begin
					outdat = {opix0[7:0], opix0};
					do = 1;
				end
				endcase
			xyinc = consume;
		endcase
		if(restart)
			state_ = SKIP;
	end

endmodule
