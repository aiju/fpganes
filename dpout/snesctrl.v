`include "dport.vh"

module snesctrl(
	input wire clk,
	output reg dclk,
	output reg dlatch,
	input wire data,
	input wire restart,
	output reg [7:0] buttons
);

	parameter SYSMHZ = 100;
	localparam DIV = 6*SYSMHZ;

	reg data0, data1, restart0;
	reg tick, copy, shift, incctr;
	
	reg [31:0] ctr;
	reg [2:0] state, state_;
	reg [15:0] bits;
	reg [3:0] nbit;
	localparam IDLE = 0;
	localparam LATCH0 = 1;
	localparam LATCH1 = 2;
	localparam DCLKH = 3;
	localparam DCLKL = 4;
	
	always @(posedge clk) begin
		data0 <= data;
		data1 <= data0;
		
		if(ctr == 0) begin
			tick <= 1;
			ctr <= DIV;
		end else begin
			tick <= 0;
			ctr <= ctr - 1;
		end
		
		if(tick) begin
			state <= state_;
			restart0 <= 0;
		end
		if(restart)
			restart0 <= 1;
		if(shift && tick) begin
			bits <= {bits[14:0], data1};
			nbit <= nbit + 1;
		end
		if(copy && tick)
			buttons <= ~{bits[15], bits[7], bits[13:8]};
	end
	
	always @(*) begin
		state_ = state;
		dlatch = 0;
		dclk = 1;
		shift = 0;
		copy = 0;
		case(state)
		IDLE:
			if(restart0)
				state_ = LATCH0;
		LATCH0: begin
			dlatch = 1;
			state_ = LATCH1;
		end
		LATCH1: begin
			dlatch = 1;
			state_ = DCLKH;
		end
		DCLKH: begin
			shift = 1;
			state_ = DCLKL;
		end
		DCLKL: begin
			dclk = 0;
			if(nbit == 0) begin
				state_ = IDLE;
				copy = 1;
			end else
				state_ = DCLKH;
		end
		endcase
	end
endmodule
