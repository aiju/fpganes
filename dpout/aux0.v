`include "dport.vh"

module aux(
        clk,
	regaddr,
	regrdata,
	regwdata,
	regwr,
	regreq,
	regack,
	regwstrb,
	regerr,
        auxi,
        auxo,
        auxd,
        phyctl,
        attr,
        dmastart,
        dmaend,
        debug,
        debug2,
        trace,
        debugstall,
        halt,
        cputick_,
		ppux,
		ppuy,
		pix,
	pputick_,
	input0,
	input1
    );
	input wire clk;
	input wire [31:0] regaddr, regwdata;
	output reg [31:0] regrdata;
	input wire regwr;
	input wire regreq;
	output reg regack;
	input wire [3:0] regwstrb;
	output wire regerr;
	input wire auxi;
	output reg auxo;
	output reg auxd;
	output wire debug, debug2;
	output reg [31:0] phyctl;
	output reg [`ATTRMAX:0] attr;
	output reg [31:0] dmastart, dmaend;
	input wire [94:0] trace;
	output wire debugstall;
	input wire cputick_, halt;
	input wire [8:0] ppux, ppuy;
	input wire [23:0] pix;
	input wire pputick_;
	output reg [7:0] input0, input1;
    
	reg[31:0] mem[0:4];
	reg[4:0] len, slen;
	
	parameter CLKDIV = 100;
	reg[6:0] auxdiv;
	wire auxclk, auxtick;
	reg[2:0] state;
	reg start, rxstart;
	reg[4:0] ctr;
	reg[1:0] wctr;
	reg[31:0] sr;
	parameter AUXIDLE = 0;
	parameter AUXPREC = 1;
	parameter AUXSYNC = 2;
	parameter AUXDATA = 3;
	parameter AUXEND = 4;
	
	reg[4:0] invalid, rxbytes;
	reg[7:0] rxd;
	reg rxdok, rxdpos, bytedone;
	reg[2:0] rxbits;
	reg[3:0] rxstate;
	reg[7:0] rxsr;
	reg[31:0] rxbuf, rxtmp;
	parameter RXIDLE = 0;
	parameter RXWAIT = 1;
	parameter RXDATA = 2;
	wire sync;
	reg regreq0, singlestep, pixelstep, step, waittick;

	assign regerr = 0;
	always @(posedge clk) begin
		start <= 0;
		step <= 0;
		regack <= 0;
		regreq0 <= regreq;
		if(regreq && !regreq0 && !regwr) begin
			regack <= 1;
			if(regaddr[6] == 1) begin
				regrdata <= mem[regaddr[4:2]];
			end else begin
				case(regaddr[7:0])
				default:
					regrdata <= 0;
				0:
					regrdata <= invalid << 16 | rxbytes;
				4:
					regrdata <= phyctl;
				'h80: regrdata <= trace[31:0];
				'h84: regrdata <= trace[63:32];
				'h88: regrdata <= {1'd0, trace[94:64]};
				'h8C: regrdata <= {7'd0, ppuy, 7'd0, ppux};
				'h90: regrdata <= {8'd0, pix}; 
				endcase
			end
		end
		if(regreq && !regreq0 && regwr) begin
			regack <= 1;
			if(regaddr[6] == 1) begin
				if(regwstrb[0])
					mem[regaddr[4:2]][7:0] <= regwdata[7:0];
				if(regwstrb[1])
					mem[regaddr[4:2]][15:8] <= regwdata[15:8];
				if(regwstrb[2])
					mem[regaddr[4:2]][23:16] <= regwdata[23:16];
				if(regwstrb[3])
					mem[regaddr[4:2]][31:24] <= regwdata[31:24];
			end else begin
				case(regaddr[7:0])
				0: begin
					slen <= regwdata;
					start <= 1;
				end
				4:
					phyctl <= regwdata;
				8:
					attr[31:0] <= regwdata;
				12:
					attr[63:32] <= regwdata;
				16:
					attr[95:64] <= regwdata;
				20:
					attr[127:96] <= regwdata;
				24:
					attr[159:128] <= regwdata;
				28:
					attr[191:160] <= regwdata;
				32:
					attr[207:192] <= regwdata;
				36:
					dmastart <= regwdata;
				40:
					dmaend <= regwdata;
				'h80: begin
					singlestep <= regwdata[0];
					step <= regwdata[1];
					if(regwdata[2]) begin
						regack <= 0;
						waittick <= 1;
					end
					pixelstep <= regwdata[3];
				end
				'h84: begin
					input0 <= regwdata[7:0];
					input1 <= regwdata[15:8];
				end
				endcase
			end
		end
		if(waittick && debugstall) begin
			regack <= 1;
			waittick <= 0;
		end
		if(bytedone) begin
			rxtmp = rxbuf;
			case(rxbytes & 3)
			0: rxtmp[7:0] = rxsr;
			1: rxtmp[15:8] = rxsr;
			2: rxtmp[23:16] = rxsr;
			3: rxtmp[31:24] = rxsr;
			endcase
			mem[rxbytes >> 2] <= rxtmp;
		end
	end
	assign debug = auxi;
	assign debugstall = cputick_ && singlestep && !step && !halt || pputick_ && pixelstep && !step;
	
	assign auxclk = auxdiv < CLKDIV/2;
	assign auxtick = auxdiv == CLKDIV-1;
	initial auxdiv = 0;
	always @(posedge clk) begin
		if(auxtick)
			auxdiv <= 0;
		else
			auxdiv <= auxdiv + 1;
	end
	
	always @(*)
		case(state)
		default: begin
			auxo <= 0;
			auxd <= 1;
		end
		AUXPREC: begin
			auxo <= !auxclk;
			auxd <= 0;
		end
		AUXSYNC, AUXEND: begin
			auxo <= !ctr[1];
			auxd <= 0;
		end
		AUXDATA: begin
			auxo <= !(auxclk ^ sr[31]);
			auxd <= 0;
		end
		endcase

	initial state = AUXIDLE;
	always @(posedge clk) begin
		rxstart <= 0;
		if(auxtick) begin
			ctr <= ctr + 1;
			case(state)
			AUXPREC: begin
				if(ctr == 15) begin
					ctr <= 0;
					state <= AUXSYNC;
				end
			end
			AUXSYNC:
				if(ctr == 3) begin
					ctr <= 0;
					state <= AUXDATA;
					sr <= {mem[0][7:0], mem[0][15:8], mem[0][23:16], mem[0][31:24]};
					wctr <= 1;
				end
			AUXDATA: begin
					sr <= sr << 1;
					if(ctr[4:0] == 31) begin
						wctr <= wctr + 1;
						sr <= {mem[wctr][7:0], mem[wctr][15:8], mem[wctr][23:16], mem[wctr][31:24]};
					end
					if(ctr[2:0] == 7) begin
						if(len == 1) begin
							state <= AUXEND;
							ctr <= 0;
						end else
							len <= len - 1;
					end
			end
			AUXEND:
				if(ctr == 3) begin
					ctr <= 0;
					state <= AUXIDLE;
					rxstart <= 1;
				end
			endcase
		end
		if(start) begin
			len <= slen;
			state <= AUXPREC;
			ctr <= 0;
		end
	end
	
	parameter NCO = 20;
	parameter SYSMHZ = 100;
	parameter MAXKHZ = 1500;
	parameter MINKHZ = 750;
	parameter MAXFREQ = integer(4.0 * MAXKHZ * (1<<NCO) / (SYSMHZ * 1000));
	parameter MINFREQ = integer(4.0 * MINKHZ * (1<<NCO) / (SYSMHZ * 1000));
	reg [NCO-1:0] rxdiv, fctr, freq, alpha, beta;
	reg carry, rxclk, rxclkup, rxclkdn, rxa, rxb;
	wire up, down;
	
	initial begin
		rxdiv = 0;
		fctr = (MAXKHZ+MINKHZ)/2;
		rxclk = 0;
		rxa = 0;
		rxb = 0;
		alpha = 2500;
		beta = 50;
	end
	always @(posedge clk) begin
		if(rxclkdn)
			rxa <= rxb;
		if(rxclkup)
			rxb <= auxi;
	end
	assign up = auxi ^ rxb;
	assign down = rxa ^ rxb;
	always @(posedge clk) begin
		if(up)
			fctr = fctr + beta;
		if(down)
			fctr = fctr - beta;
		if(fctr > MAXFREQ)
			fctr = MAXFREQ;
		if(fctr < MINFREQ)
			fctr = MINFREQ;
	end
	always @(*)
		case({up,down})
		default:
			freq <= fctr;
		2'b10:
			freq <= fctr + alpha;
		2'b01:
			freq <= fctr - alpha;
		endcase
	always @(posedge clk) begin
		{carry, rxdiv} = {1'b0, rxdiv} + {1'b0, freq};
		rxclkup <= 0;
		rxclkdn <= 0;
		if(carry) begin
			rxclk <= !rxclk;
			if(rxclk)
				rxclkdn <= 1;
			else
				rxclkup <= 1;
		end
	end
	
	assign debug2 = rxd[rxdpos];
	
	assign sync = rxd == 8'b11110000;
	always @(posedge clk) begin
		rxdok <= 0;
		if(rxclkup) begin
			rxd <= {rxd[6:0], auxi};
			rxdok <= 1;
		end
	end

	always @(posedge clk) begin
		bytedone <= 0;
		case(rxstate)
		default:
			if(rxstart)
				rxstate <= RXWAIT;
		RXWAIT:
			if(rxdok && sync) begin
				rxstate <= RXDATA;
				rxdpos <= 0;
				invalid <= 0;
				rxbits <= 0;
				rxbytes <= 0;
			end
		RXDATA: begin
			if(rxdok) begin
				rxdpos <= !rxdpos;
				if(rxdpos) begin
					if(rxd[0] == rxd[1])
						invalid <= invalid + 1;
					rxsr <= {rxsr[6:0], rxd[1]};
					rxbits <= rxbits + 1;
					if(rxbits == 7) begin
						bytedone <= 1;
						rxbuf <= mem[rxbytes >> 2];
					end
				end
			end
			if(bytedone) begin
				rxbytes <= rxbytes + 1;
			end
			if(rxdok && sync)
				rxstate <= RXIDLE;
		end
		endcase
	end
endmodule
