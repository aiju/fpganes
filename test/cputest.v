`include "dat.vh"

module cputest();

	wire tick, memwr, memreq, memack;
	wire [15:0] memaddr;
	reg [7:0] memrdata;
	wire [7:0] memwdata; 
	reg [7:0] ram[0:65535];
	reg clk, reset, irq, nmi;
	
	initial begin
		ram[0] = 'h18;
		ram[1] = 'h90;
		ram[2] = 'hD0;
		ram['h82] = 'h90;
		ram['h83] = 'h7F;
		ram['h1337] = 'h40;
		ram['hFFFC] = 'h37;
		ram['hFFFD] = 'h13;
		
		irq = 0;
		nmi = 0;
	end
	
	initial clk = 0;
	always #1 clk = ~clk;
	initial begin reset = 1; @(posedge clk) @(posedge clk) reset = 0; end
	
	assign tick = clk; 
	
	always @(*) memrdata = ram[memaddr];
	always @(posedge clk) if(memwr) ram[memaddr] = memwdata;
    
	cpu cpu0(clk, tick, memaddr, memrdata, memwdata, memwr, memreq, memack, irq, nmi, reset);
endmodule
