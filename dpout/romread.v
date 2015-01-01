`include "dpout.v"

module(
	input wire clk,
	input wire [21:0] addr,
	ouput reg [7:0] data,
	input wire req,
	output reg ack
);

	reg [7:0] mem[0:65535];
	
	initial $readmem("../smb.nes", mem);

	always @(posedge clk) begin
		ack <= req;
		if(req)
			data <= mem[addr[15:0]];
	end

endmodule
