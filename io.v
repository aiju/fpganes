`include "dat.vh"

module io(
	input wire clk,
	input wire tick,
	
	input wire [4:0] memaddr,
	output reg [7:0] iordata,
	input wire [7:0] memwdata,
	input wire memwr,
	input wire ioreq,
	output reg ioack,
	
	output reg halt,
	output reg [15:0] dmaaddr,
	input wire [7:0] memrdata,
	output reg [7:0] dmawdata,
	output reg dmawr,
	output reg dmareq,
	input wire dmaack,
	
	input wire [7:0] input0,
	input wire [7:0] input1
);
	
	reg strobe;
	reg [7:0] sh0, sh1;
	reg startdma;
	reg [7:0] startaddr;
	reg [15:0] curaddr;

	always @(posedge clk) begin
		if(strobe) begin
			sh0 <= input0;
			sh1 <= input1;
		end
		if(tick)
			startdma <= 0;
		if(ioreq && !ioack) begin
			ioack <= 1;
			if(memwr)
				case(memaddr)
				5'h14: begin
					startaddr <= memwdata;
					startdma <= 1;
				end
				5'h16:
					strobe <= memwdata[0];
				endcase
			else
				case(memaddr)
				5'h16: begin
					iordata[2:0] <= {2'd0, sh0[7]};
					sh0 <= {sh0[6:0], 1'b1};
				end
				5'h17: begin
					iordata[2:0] <= {2'd0, sh1[7]};
					sh1 <= {sh1[6:0], 1'b1};
				end
				endcase
		end else
			ioack <= 0;
	end
	
	reg [1:0] state, state_;
	reg tick0;
	reg dmacyc;
	reg loadaddr;
	reg incaddr;
	localparam IDLE = 0;
	localparam INIT = 1;
	localparam DMAR = 2;
	localparam DMAW = 3;

	always @(posedge clk) begin
		tick0 <= tick;
		if(tick) begin
			state <= state_;
			if(loadaddr)
				curaddr <= {startaddr, 8'h00};
			if(incaddr)
				curaddr <= curaddr + 1;
		end
		if(tick0 && dmacyc)
			dmareq <= 1;
		if(dmacyc && dmaack) begin
			if(!dmawr)
				dmawdata <= memrdata;
			dmareq <= 0;
		end
	end
	
	always @(*) begin
		state_ = state;
		loadaddr = 0;
		incaddr = 0;
		halt = 1;
		dmawr = 0;
		dmacyc = 0;
		dmaaddr = 16'hxxxx;
		case(state)
		default: begin
			halt = 0;
			if(startdma)
				state_ = INIT;
		end
		INIT: begin
			loadaddr = 1;
			state_ = DMAR;
		end
		DMAR: begin
			dmacyc = 1;
			state_ = DMAW;
			dmaaddr = curaddr;
		end
		DMAW: begin
			dmaaddr = 16'h2004;
			dmawr = 1;
			dmacyc = 1;
			incaddr = 1;
			if(curaddr[7:0] == 8'hFF)
				state_ = IDLE;
			else
				state_ = DMAR;
		end
		endcase
	end
			

endmodule
