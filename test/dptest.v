`include "../dpout/dport.vh"

module dptest();

	reg clk, reset;
	reg [8:0] ppux, ppuy;
	reg [23:0] pix;
	wire restart, rden, consume;
	wire [3:0] isk;
	wire [31:0] indat, data;
	wire [207:0] attr;
	reg empty;
	
	assign attr = 208'h4f910000fb000027002100900023806080020320020d028001e0;
	
	initial clk = 0;
	always #0.5 clk = !clk;
	
	initial begin
		reset = 1;
		@(posedge clk) reset = 0;
	end
	
	initial begin
		ppux = 0;
		ppuy = 0;
		empty = 0;
		pix =  'hFF00FF;
	end
	
	integer state;
	parameter BLANK = 0;
	parameter DATA = 1;
	parameter FILL = 2;
	initial state = BLANK;
	integer rem;
	initial rem = 0;
	reg [23:0] rec;
	
	task out;
	input [7:0] data;
	input isk;
	begin
		if(isk)
			case(data)
			`symFE: state = DATA;
			`symFS: state = FILL;
			`symBS: state = BLANK;
			`symBE: state = DATA;
			endcase
		else if(state == DATA) begin
			case(rem)
			0: rec[23:16] = data;
			1: rec[15:8] = data;
			2: rec[7:0] = data;
			endcase
			if(rem == 2) begin
				$display("%x",rec);
				rem = 0;
			end else
				rem = rem + 1;
		end
	end
	endtask

	dpconv dpconv0(clk, ppux, ppuy, pix, empty, rden, restart, consume, indat);
	dpsrc dpsrc0(clk, reset, attr, indat, consume, restart, data, isk);
	
	always @(posedge clk) begin
		out(data[7:0], isk[0]);
		out(data[15:8], isk[1]);
		out(data[23:16], isk[2]);
		out(data[31:24], isk[3]);
	end
	
endmodule
