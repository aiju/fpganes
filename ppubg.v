`include "dat.vh"

module ppubg(
	input wire clk,
	input wire tick,
	
	output reg [13:0] vmemaddr,
	input wire [7:0] vmemrdata,
	output wire [7:0] vmemwdata,
	output reg vmemwr,
	output reg vmemreq,
	input wire vmemack,
	
	input wire [8:0] ppux,
	input wire [8:0] ppuy,
	input wire render,
	
	output wire [3:0] bgpix,
	
	input wire [7:0] ppuctrl,
	input wire [7:0] ppumask,
	input wire [7:0] regwdata,
	output reg [7:0] ppudata,
	input wire wr2000,
	input wire wr20051,
	input wire wr20052,
	input wire wr20061,
	input wire wr20062,
	input wire rd2007,
	input wire wr2007,
	
	input wire [13:0] sprvmemaddr,
	
	output wire upalacc,
	output wire [4:0] upaladdr,
	
	output reg ppudone,
	input wire reset
);

	reg access2007, coarsex, yinc;
	reg [2:0] x, x_;
	reg [14:0] v, t, v_, t_;
	always @(posedge clk)
		if(tick) begin
			v <= v_;
			t <= t_;
			x <= x_;
		end
	always @(*) begin
		v_ = v;
		t_ = t;
		x_ = x;
		access2007 = rd2007 || wr2007;
		coarsex = render && (ppux == 328 || ppux == 336 || ppux != 0 && ppux <= 256 && ppux[2:0] == 0 || access2007);
		yinc = render && (ppux == 256 || access2007);
		if(!render && access2007)
			v_ = v + (ppuctrl[`VRAMINC] ? 32 : 1);
		if(coarsex) begin
			v_[4:0] = v[4:0] + 1;
			if(v[4:0] == 'h1f)
				v_[10] = !v[10];
		end
		if(yinc) begin
			v_[14:12] = v[14:12] + 1;
			if(v[14:12] == 7)
				if(v[9:5] == 29) begin
					v_[9:5] = 0;
					v_[11] = !v[11];
				end else
					v_[9:5] = v[9:5] + 1;
		end
		if(render && ppux == 257) begin
			v_[10] = t[10];
			v_[4:0] = t[4:0];
		end
		if(render && ppuy == 261 && ppux >= 280 && ppux <= 304) begin
			v_[14:11] = t[14:11];
			v_[9:5] = t[9:5];
		end
		if(wr2000)
			t_[11:10] = regwdata[1:0];
		if(wr20051) begin
			t_[4:0] = regwdata[7:3];
			x_ = regwdata[2:0];
		end
		if(wr20052)
			t_ = {regwdata[2:0], t[11:10], regwdata[7:3], t[4:0]};
		if(wr20061)
			t_[14:8] = {1'b0, regwdata[5:0]};
		if(wr20062) begin
			t_[7:0] = regwdata;
			v_ = t_;
		end
	end
	
	reg [7:0] ntbyte, atbyte;
	reg [15:0] nextbg;
	reg [13:0] useraddr;
	wire fetch;
	reg fetchnt, fetchat, fetchlow, fetchhigh, fetchdata, bgshiftld;
	reg userrd, userwr;
	reg tick0, tick1;
	
	assign fetch = fetchnt || fetchat || fetchlow || fetchhigh || fetchdata;
	always @(posedge clk) begin
		tick0 <= tick;
		tick1 <= tick0;
		if(fetch && tick0)
			vmemreq <= 1;
		if(tick && wr2007)
			ppudata <= regwdata;
		if(vmemack) begin
			vmemreq <= 0;
			if(fetchnt)
				ntbyte <= vmemrdata;
			if(fetchat)
				atbyte <= vmemrdata;
			if(fetchlow)
				{nextbg[14], nextbg[12], nextbg[10], nextbg[8], nextbg[6], nextbg[4], nextbg[2], nextbg[0]} <= vmemrdata;
			if(fetchhigh)
				{nextbg[15], nextbg[13], nextbg[11], nextbg[9], nextbg[7], nextbg[5], nextbg[3], nextbg[1]} <= vmemrdata;
			if(fetchdata && !vmemwr)
				ppudata <= vmemrdata;
		end
	end
	
	always @(posedge clk) begin
		if(tick)
			ppudone <= 0;
		if(!fetch && tick1 || fetch && vmemack || reset)
			ppudone <= 1;
	end
	
	always @(*)
		case(1'b1)
		fetchnt:
			vmemaddr = {2'b10, v[11:0]};
		fetchat:
			vmemaddr = {2'b10, v[11:10], 4'b1111, v[9:7], v[4:2]};
		fetchlow || fetchhigh:
			if(ppux >= 256 && ppux <= 320)
				vmemaddr = {sprvmemaddr[13:4], fetchhigh, sprvmemaddr[2:0]};
			else
				vmemaddr = {1'b0, ppumask[`PATTAB], ntbyte, fetchhigh, v[14:12]};
		fetchdata:
			vmemaddr = useraddr;
		default:
			vmemaddr = 14'hxxxx;
		endcase
	assign vmemwdata = ppudata;

	always @(*) begin
		vmemwr = 0;
		fetchnt = 0;
		fetchat = 0;
		fetchlow = 0;
		fetchhigh = 0;
		fetchdata = 0;
		bgshiftld = 0;
		if(render && ppux > 0 && ppux <= 336) begin
			case(ppux[2:0])
			1: begin
				fetchnt = 1;
				bgshiftld = 1;
			end
			3: fetchat = 1;
			5: fetchlow = 1;
			7: fetchhigh = 1;
			endcase
		end
		if(render && ppux > 336)
			if(ppux[0])
				fetchnt = 1;
		if(!render && (userrd || userwr)) begin
			vmemwr = userwr;
			fetchdata = 1;
		end
	end
	
	always @(posedge clk)
		if(tick) begin
			if(fetchdata) begin
				userrd <= 0;
				userwr <= 0;
			end
			if(rd2007)
				userrd <= 1;
			if(wr2007 && !upalacc)
				userwr <= 1;
			if(rd2007 || wr2007)
				useraddr <= v[13:0];
		end
	
	reg [31:0] bgshift;
	reg [15:0] palsh;
	reg [1:0] nextpal;
	
	always @(posedge clk)
		if(tick) begin
			if(ppux >= 2 && ppux <= 257 || ppux >= 322 && ppux <= 337)
				bgshift <= {bgshift[29:0], 2'b00};
			if(bgshiftld) begin
				bgshift[15:0] <= nextbg;
				nextpal <= atbyte[{v[6], v[1], 1'b0} +: 2];
			end
			palsh <= {palsh[13:0], nextpal};
		end
	
	assign bgpix = {palsh[14 - 2 * x +: 2], bgshift[30 - 2 * x +: 2]};
	
	assign upalacc = v[13:8] == 6'h3f;
	assign upaladdr = v[4:0];

endmodule
