`include "dport.vh"
module dpsrc(
		clk,
		reset,
		attr,
		indat,
		consume,
		restart,
		data,
		isk
	);
	
	input wire clk;
	input wire [31:0] indat;
	output reg consume, restart;
	output reg [31:0] data;
	output reg [3:0] isk;
	input wire [`ATTRMAX:0] attr;
	input wire reset;
	
	wire [15:0] hact, vact, htot, vtot, hsync, vsync, hstart, vstart, misc, sclkinc;
	wire [23:0] Mvid, Nvid;
	
	assign vact = attr[15:0];
	assign hact = attr[31:16];
	assign vtot = attr[47:32];
	assign htot = attr[63:48];
	assign vsync = attr[79:64];
	assign hsync = attr[95:80];
	assign vstart = attr[111:96];
	assign hstart = attr[127:112];
	assign misc = attr[143:128];
	assign Mvid = attr[167:144];
	assign Nvid = attr[191:168];
	assign sclkinc = attr[207:192];
	
	reg [3:0] state;
	parameter HORDATA = 0;
	parameter HORSTUFF = 1;
	parameter HORBLANK0 = 2;
	parameter HORBLANK = 3;
	parameter VERBLANK0 = 4;
	parameter VERBLANK = 5;
	parameter VERBLANK1 = 6;
	parameter IDLE = 7;
	parameter tusize = 32;
	
	reg [3:0] ctr;
	reg [15:0] pxrem, y;
	reg [30:0] pxctr;
	reg [7:0] VBID;
	reg hline;
	reg [5:0] tu;
	
	reg [31:0] curw, nextw;
	reg [2:0] valid;
	reg [1:0] pos;
	
	wire [4:0] tufill;
	reg [18:0] tufctr;
	wire [18:0] tufinc;
	reg tufreset, tufstep;
	
	reg [31:0] data1;
	reg [2:0] cons, cons1, cons2;
	
	initial begin
		state = IDLE;
		consume = 0;
	end
	
	always @(posedge clk) begin
		if(pxctr[30:15] >= htot) begin
			pxctr <= pxctr - (htot << 15) + sclkinc;
			hline <= 1;
		end else begin
			pxctr <= pxctr + sclkinc;
			hline <= 0;
		end
		if(reset)
			pxctr <= 0;
	end
	
	assign tufinc = sclkinc * 3;
	assign tufill = (tufctr + 'h800) >> 12;
	always @(posedge clk) begin
		if(tufstep)
			tufctr <= tufctr - (tufill << 12) + tufinc;
		if(tufreset)
			tufctr <= tufinc;
	end

	always @(posedge clk) begin
		data <= 0;
		isk <= 0;
		consume <= 0;
		restart <= 0;
		tufreset <= 0;
		tufstep <= 0;
		case(state)
		HORDATA: begin
			if(tu >= 4)
				cons = 4;
			else begin
				cons = tu;
				state = HORSTUFF;
			end
			if(pxrem == 0) begin
				cons = 0;
				state = HORBLANK0;
			end else if(pos + cons >= 6) begin
				pxrem = pxrem - 2;
				if(pxrem == 0) begin
					cons = 4;
					state = HORBLANK0;
				end else if(pxrem == 16'hFFFF) begin
					cons = 3 - pos;
					state = HORBLANK0;
					pxrem = 0;
				end
			end else if(pos + cons >= 3) begin
				pxrem = pxrem - 1;
				if(pxrem == 0) begin
					cons = 3 - pos;
					state = HORBLANK0;
				end
			end
			if(cons >= valid) begin
				cons1 = valid;
				cons2 = cons - valid;
				valid <= 4 - cons2;
				curw <= nextw >> 8 * cons2;
				nextw <= indat;
				consume <= 1;
			end else begin
				cons1 = cons;
				cons2 = 0;
				valid <= valid - cons;
				curw <= curw >> 8 * cons;
			end
			case(cons2)
			0: data1 = 0;
			1: data1 = nextw[7:0];
			2: data1 = nextw[15:0];
			3: data1 = nextw[23:0];
			endcase
			case(cons1)
			0: data <= data1[31:0];
			1: data <= {data1[23:0], curw[7:0]};
			2: data <= {data1[15:0], curw[15:0]};
			3: data <= {data1[7:0], curw[23:0]};
			4: data <= curw;
			endcase
			tu <= tu - cons;
			ctr <= ctr + 1;
			pos <= (pos + cons) % 3;
			if(state == HORSTUFF) begin
				case(cons)
				0: data[7:0] <= `symFS;
				1: data[15:8] <= `symFS;
				2: data[23:16] <= `symFS;
				3: data[31:24] <= `symFS;
				endcase
				if(cons < 4)
					isk[cons] <= 1;
				if(ctr == tusize/4 - 1) begin
					if(cons < 4) begin
						data[31:24] <= `symFE;
						isk[3] <= 1;
					end
					state = HORDATA;
					tu <= tufill;
					tufstep <= 1;
				end
			end
			if(state == HORBLANK0)
				case(cons)
				0: begin
					data[31:24] <= 0;
					data[23:16] <= Mvid;
					data[15:8] <= VBID;
					data[7:0] <= `symBS;
					isk[0] <= 1;
					ctr <= 3;
				end
				1: begin
					data[31:24] <= Mvid;
					data[23:16] <= VBID;
					data[15:8] <= `symBS;
					isk[1] <= 1;
					ctr <= 2;
				end
				2: begin
					data[31:24] <= VBID;
					data[23:16] <= `symBS;
					isk[2] <= 1;
					ctr <= 1;
				end
				3: begin
					data[31:24] <= `symBS;
					isk[3] <= 1;
					ctr <= 0;
				end
				4:
					state = HORDATA;
				endcase
		end
		HORSTUFF:
			if(ctr == tusize/4 - 1) begin
				ctr <= 0;
				data <= `symFE<<24;
				isk <= 8;
				state <= HORDATA;
				tu <= tufill;
				tufstep <= 1;
			end else
				ctr <= ctr + 1;
		HORBLANK0: begin
			case(ctr%3)
			0: begin
				data[7:0] <= VBID;
				data[15:8] <= Mvid;
				data[23:16] <= 0;
				data[31:24] <= VBID;
			end
			1: begin
				data[7:0] <= Mvid;
				data[15:8] <= 0;
				data[23:16] <= VBID;
				data[31:24] <= Mvid;
			end
			2: begin
				data[7:0] <= 0;
				data[15:8] <= VBID;
				data[23:16] <= Mvid;
				data[31:24] <= 0;
			end
			endcase
			if(ctr > 8) begin
				if(y == vact - 1)
					state <= VERBLANK0;
				else if(VBID[0])
					state <= VERBLANK;
				else
					state <= HORBLANK;
				ctr <= 0;
			end else
				ctr <= ctr + 4;
		end
		HORBLANK:
			if(hline) begin
				y <= y + 1;
				pxrem <= hact;
				tu <= tufill;
				tufstep <= 1;
				if(y == vact - 2)
					VBID[0] <= 1;
				data[31:24] <= `symBE;
				isk[3] <= 1;
				state <= HORDATA;
			end
		VERBLANK0: begin
			ctr <= ctr + 1;
			case(ctr)
			0: begin
				data[7:0] <= `symSS;
				data[15:8] <= `symSS;
				data[31:16] <= {Mvid[15:8], Mvid[23:16]};
				isk <= 4'b0011;
				restart <= 1;
			end
			1: data <= {vtot[15:8], htot[7:0], htot[15:8], Mvid[7:0]};
			2: data <= {Mvid[23:16], hsync[7:0], hsync[15:8], vtot[7:0]};
			3: data <= {hstart[7:0], hstart[15:8], Mvid[7:0], Mvid[15:8]};
			4: data <= {vsync[7:0], vsync[15:8], vstart[7:0], vstart[15:8]};
			5: data <= {hact[15:8], Mvid[7:0], Mvid[15:8], Mvid[23:16]};
			6: data <= {8'h00, vact[7:0], vact[15:8], hact[7:0]}; 
			7: data <= {Mvid[7:0], Mvid[15:8], Mvid[23:16], 8'h00};
			8: data <= {misc[7:0], Nvid[7:0], Nvid[15:8], Nvid[23:16]};
			9: begin
				data[7:0] <= misc[15:8];
				data[23:16] <= `symSE;
				isk[2] <= 1;
				state <= VERBLANK;
			end
			endcase
		end
		VERBLANK:
			if(hline) begin
				y <= y + 1;
				if(y + 1 == vtot) begin
					y <= 0;
					curw <= indat;
					consume <= 1;
					tufreset <= 1;
					state <= VERBLANK1;
				end else begin
					data[31:24] <= `symBS;
					isk[3] <= 1;
					ctr <= 0;
					state <= HORBLANK0;
				end
			end
		VERBLANK1: begin
			nextw <= indat;
			consume <= 1;
			
			pos <= 0;
			valid <= 4;
			tu <= tufill;
			tufstep <= 1;
			pxrem <= hact;
			VBID <= 0;
			ctr <= 0;
			
			data[31:24] <= `symBE;
			isk[3] <= 1;
			state <= HORDATA;
		end
		IDLE:
			if(!reset && hline) begin
				state <= VERBLANK1;
				curw <= indat;
				consume <= 1;
				ctr <= 0;
				y <= 0;
			end
		endcase
		if(reset) begin
			state <= IDLE;
			tufreset <= 1;
		end
	end
endmodule
