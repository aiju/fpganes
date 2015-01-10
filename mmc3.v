`include "dat.vh"

module mmc3(
	input wire clk,
	input wire reset,
	output wire irq,
	
	input wire [15:0] memaddr,
	output wire [7:0] prgrdata,
	input wire [7:0] memwdata,
	input wire memwr,
	input wire prgreq,
	output wire prgack,
	
	input wire [13:0] vmemaddr,
	output wire [7:0] chrrdata,
	input wire [7:0] vmemwdata,
	input wire vmemwr,
	input wire chrreq,
	output wire chrack,
	
	output reg [20:0] promaddr,
	input wire [7:0] promdata,
	output wire promreq,
	input wire promack,
	
	output reg [20:0] cromaddr,
	input wire [7:0] cromdata,
	output wire cromreq,
	input wire cromack,
	
	output wire [12:0] chrramaddr,
	input wire [7:0] chrramrdata,
	output wire [7:0] chrramwdata,
	output wire chrramwr,
	output wire chrramreq,
	input wire chrramack,
	
	input wire [127:0] header,
	output wire [2:0] mirr
);

	reg prgreq0, chrmode, prgmode, mirrmode, irqpend, irqen, setreload, clrirq;
	reg [2:0] bs;
	reg [5:0] prgb[0:1];
	reg [7:0] chrb[0:5], irqlatch;
	
	always @(posedge clk) begin
		prgreq0 <= prgreq;
		setreload <= 0;
		clrirq <= 0;
		if(memwr && prgreq && !prgreq0 && memaddr[15])
			case({memaddr[14:13], memaddr[0]})
			0: begin
				bs <= memwdata[2:0];
				prgmode <= memwdata[6];
				chrmode <= memwdata[7];
			end
			1:
				if(bs >= 6)
					prgb[bs - 6] <= memwdata[5:0];
				else
					chrb[bs] <= memwdata;
			2:
				mirrmode <= memwdata[0];
			4:
				irqlatch <= memwdata;
			5:
				setreload <= 1;
			6: begin
				clrirq <= 1;
				irqen <= 0;
			end
			7:
				irqen <= 1;
			endcase
	end
	
	wire [4:0] last;
	
	assign last = header[36:32] - 1;
	
	always @(*) begin
		promaddr[20:19] = 0;
		promaddr[12:0] = memaddr[12:0];
		case({memaddr[14] ^ !memaddr[13] & prgmode, memaddr[13]})
		0: promaddr[18:13] = prgb[0];
		1: promaddr[18:13] = prgb[1];
		2: promaddr[18:13] = {last, 1'd0};
		3: promaddr[18:13] = {last, 1'd1};
		endcase
		cromaddr[20:18] = 0;
		cromaddr[9:0] = vmemaddr[9:0];
		if(vmemaddr[12] ^ chrmode)
			cromaddr[17:10] = chrb[vmemaddr[11:10] + 2];
		else
			cromaddr[17:10] = {chrb[{2'd0, vmemaddr[11]}][7:1], vmemaddr[10]};
	end
	
	assign prgrdata = promdata;
	assign promreq = prgreq;
	assign prgack = promack;
	
	wire chrram;
	
	assign chrram = header[47:40] == 0;
	assign chrramaddr = cromaddr[12:0];
	assign chrrdata = chrram ? chrramrdata : cromdata;
	assign chrramwdata = vmemwdata;
	assign chrramwr = vmemwr;
	assign chrramreq = chrram ? chrreq : 0;
	assign cromreq = chrram ? 0 : chrreq;
	assign chrack = chrram ? chrramack : cromack;
	
	assign mirr = mirrmode ? `MIRRHOR : `MIRRVER;
	
	reg a12, a120, chrreq0, reload, irqpend;
	reg [7:0] scanline;
	
	always @(posedge clk) begin
		chrreq0 <= chrreq;
		if(chrreq && !chrreq0)
			a12 <= vmemaddr[12];
		a120 <= a12;
		if(setreload)
			reload <= 1;
		if(clrirq)
			irqpend <= 0;
		if(a12 && !a120) begin
			if(scanline == 0 || reload)
				scanline <= irqlatch;
			else begin
				if(scanline == 1)
					irqpend <= 1;
				scanline <= scanline - 1;
			end
			reload <= 0;
		end
	end
	assign irq = irqen && irqpend;
		
endmodule
