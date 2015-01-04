`include "dport.vh"

module romread(
	input wire clk,
	input wire reset,
	input wire [21:0] addr,
	output reg [7:0] data,
	input wire req,
	output reg ack,
	
	input wire [31:0] dmastart,
	input wire [31:0] dmaend,
	
	output reg arvalid,
	input wire arready,
	output reg [31:0] araddr,
	output wire [1:0] arburst,
	output wire [3:0] arcache,
	output wire [5:0] arid,
	output wire [3:0] arlen,
	output wire [1:0] arlock,
	output wire [2:0] arprot,
	output wire [3:0] arqos,
	output wire [1:0] arsize,
	
	input wire rvalid,
	output reg rready,
	input wire rlast,
	input wire [63:0] rdata,
	input wire [1:0] rresp
);

	assign arid = 0;
	assign arlen = 0;
	assign arlock = 0;
	assign arcache = 15;
	assign arprot = 0;
	assign arqos = -1;
	assign arsize = 0;
	assign arburst = 0;
	
	reg [2:0] state, state_;
	reg setaddr, setdata;
	localparam IDLE = 0;
	localparam ADDR = 1;
	localparam DATA = 2;
	localparam ACK = 3;
	reg [2:0] sel;
	reg req0;
	
	always @(posedge clk) begin
		state <= state_;
		if(setaddr) begin
			araddr <= addr + dmastart;
			sel <= addr[2:0];
		end
		if(setdata)
			case(sel)
			0: data <= rdata[7:0];
			1: data <= rdata[15:8];
			2: data <= rdata[23:16];
			3: data <= rdata[31:24];
			4: data <= rdata[39:32];
			5: data <= rdata[47:40];
			6: data <= rdata[55:48];
			7: data <= rdata[63:56];
			endcase
		req0 <= req;
	end
		
	
	always @(*) begin
		state_ = state;
		setaddr = 0;
		setdata = 0;
		arvalid = 0;
		rready = 0;
		ack = 0;
		case(state)
		IDLE:
			if(req && !req0 && !reset) begin
				setaddr = 1;
				state_ = ADDR;
			end
		ADDR: begin
			arvalid = 1;
			if(arready)
				state_ = DATA;
		end
		DATA: begin
			rready = 1;
			if(rvalid) begin
				setdata = 1;
				state_ = ACK;
			end
		end
		ACK: begin
			ack = 1;
			state_ = IDLE;
		end
		endcase
	end
endmodule
