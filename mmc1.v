`include "dat.vh"

module mmc1(
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
	output reg [2:0] mirr
);

	assign prgrdata = promdata;
	assign promreq = prgreq;
	assign prgack = promack;
	
	reg prgreq0;
	reg [4:0] sr, sr_, ctrl, chr0, chr1, prg;
	reg [2:0] cnt;
	always @(*)
		sr_ = {memwdata[0], sr[4:1]};
	always @(posedge clk) begin
		prgreq0 <= prgreq;
		if(memaddr[15] != 0 && memwr && prgreq && !prgreq0)
			if(memwdata[7] != 0) begin
				sr <= 0;
				cnt <= 0;
				ctrl[3:2] <= 2'b11;
			end else begin
				sr <= sr_;
				if(cnt == 4) begin
					case(memaddr[14:13])
					0: ctrl <= sr_;
					1: chr0 <= sr_;
					2: chr1 <= sr_;
					3: prg <= sr_;
					endcase
					cnt <= 0;
				end else
					cnt <= cnt + 1;
			end
		if(reset) begin
			sr <= 0;
			cnt <= 0;
			ctrl <= 5'hC;
			chr0 <= 0;
			chr1 <= 0;
			prg <= 0;
		end
	end
	wire [6:0] last;
	assign last = header[38:32] - 1;
	always @(*) begin
		case(ctrl[1:0])
		default: mirr = `MIRRB;
		1: mirr = `MIRRA;
		2: mirr = `MIRRVER;
		3: mirr = `MIRRHOR;
		endcase
		case(ctrl[3:2])
		default: promaddr = {3'd0, prg[3:1], memaddr[14:0]};
		2: promaddr = memaddr[14] ? {3'd0, prg[3:0], memaddr[13:0]} : {7'd0, memaddr[13:0]};
		3: promaddr = memaddr[14] ? {last, memaddr[13:0]} : {3'd0, prg[3:0], memaddr[13:0]};
		endcase
		if(ctrl[4])
			cromaddr = {4'd0, vmemaddr[12] ? chr1 : chr0, vmemaddr[11:0]};
		else
			cromaddr = {4'd0, chr0[4:1], vmemaddr[12:0]};
	end
	
	wire chrram;
	
	assign chrram = header[47:40] == 0;
	assign chrramaddr = cromaddr[12:0];
	assign chrrdata = chrram ? chrramrdata : cromdata;
	assign chrramwdata = vmemwdata;
	assign chrramwr = vmemwr;
	assign chrramreq = chrram ? chrreq : 0;
	assign cromreq = chrram ? 0 : chrreq;
	assign chrack = chrram ? chrramack : cromack;
	
	assign irq = 0;
endmodule
