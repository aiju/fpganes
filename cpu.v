`include "dat.vh"

module cpu(
	input wire clk,
	input wire tick,
	output reg [15:0] memaddr,
	input wire [7:0] memrdata,
	output wire [7:0] memwdata,
	output reg memwr,
	output reg memreq,
	input wire memack,
	input wire irq,
	input wire nmi,
	input wire halt,
	input wire reset,
	output reg cpudone,
	output wire [94:0] cputrace
);
	
	reg [15:0] pc, pc_, rAD, rAD_;
	reg [7:0] rA, rA_, rX, rX_, rY, rY_, rP, rP_, rS, rS_, rD, rD_, op, op_;
	localparam FLAGC = 1;
	localparam FLAGZ = 2;
	localparam FLAGI = 4;
	localparam FLAGD = 8;
	localparam FLAGB = 'h10;
	localparam FLAGV = 'h40;
	localparam FLAGN = 'h80;
	
	reg [3:0] t, t_;
	assign cputrace = {t, memwr, irq, nmi, op, rA, memwr ? memwdata : memrdata, memaddr, pc, rX, rY, rP, rS};
	reg [7:0] alua, alub;
	reg [7:0] aluq, aluq_;
	
	reg [3:0] aluas, alubs;
	localparam AS0 = 0;
	localparam ASA = 1;
	localparam ASX = 2;
	localparam ASY = 3;
	localparam ASADL = 4;
	localparam ASADH = 5;
	localparam ASMEM = 6;
	localparam ASD = 7;
	localparam ASS = 8;
	localparam ASP = 9;
	localparam ASPCL = 10;
	localparam ASPCH = 11;
	reg [3:0] aluop;
	localparam ALUNOPA = 0;
	localparam ALUNOPB = 1;
	localparam ALUADD = 2;
	localparam ALUSUB = 3;
	localparam ALUOR = 4;
	localparam ALUAND = 5;
	localparam ALUXOR = 6;
	localparam ALUASL = 7;
	localparam ALULSR = 8;
	reg [7:0] aluflag, aluflagout, aluflagout_, aluflagout0, clrflag, setflag, cpyflag;
	reg [1:0] intrcause, intrcause_;
	localparam INTRESET = 0;
	localparam INTNMI = 1;
	localparam INTBRK = 2;
	localparam INTIRQ = 3;
	reg intr, nmi0, tick0, fetch, seta, setx, sety, sets, decs, setd, memsetd, setadl, setadh, memsetadl, memsetadh, zeroadh, setpc, setpcl, setpch, cin;
	reg incpc;
	reg memack0, memack1, memack2, reset0;
	
	reg [3:0] memsrc;
	localparam MEMPC = 0;
	localparam MEMAD = 1;
	localparam MEMD = 2;
	localparam MEMS = 3;
	localparam MEMVECL = 4;
	localparam MEMVECH = 5;
	
	reg [3:0] amode;
	localparam ANONE = 0;
	localparam AZP = 1;
	
	always @(posedge clk) begin
		if(tick && !halt) begin
			pc <= pc_;
			op <= op_;
			t <= t_;
			rA <= rA_;
			rX <= rX_;
			rY <= rY_;
			rP <= rP_;
			rS <= rS_;
			rD <= rD_;
			rAD <= rAD_;
			if(t == 0)
				nmi0 <= nmi;
			intrcause <= intrcause_;
			aluflagout0 <= aluflagout;
			reset0 <= reset;
		 end
		 if(reset) begin
		 	op <= 0;
		 	t <= 0;
		 end
		 tick0 <= tick;
		 if(tick0 && !halt && !reset)
		 	memreq <= 1;
		 if(memack)
		 	memreq <= 0;
	end
	
	always @(posedge clk) begin
		memack0 <= tick ? 0 : memack;
		memack1 <= tick ? 0 : memack0;
		memack2 <= tick ? 0 : memack1;
		if(tick)
			cpudone <= 0;
		if(memack2 || reset)
			cpudone <= 1;
	end
	
	initial begin
		rA = 0;
		rX = 0;
		rY = 0;
		rS = 0;
		rP = 8'h20;
	end

   	always @(*) begin
		pc_ = incpc ? pc + 1 : setpc ? {memrdata, aluq} : setpch ? {aluq, pc[7:0]} : setpcl ? {pc[15:8], aluq} : pc;
		rA_ = seta ? aluq : rA;
		rX_ = setx ? aluq : rX;
		rY_ = sety ? aluq : rY;
		rP_ = rP & ~(aluflag | clrflag | cpyflag | 8'h10) | 8'h20 | aluflagout & aluflag | memrdata & cpyflag | setflag;
		rS_ = sets ? aluq : decs ? rS - 1 : rS;
		rD_ = setd ? aluq : memsetd ? memrdata : rD;
		rAD_[7:0] = memsetadl ? memrdata : setadl ? aluq : rAD[7:0];
		rAD_[15:8] = zeroadh ? 0 : memsetadh ? memrdata : setadh ? aluq : rAD[15:8];
		intr = reset0 || nmi && !nmi0 || irq && (rP & FLAGI) == 0;
		op_ = fetch ? intr ? 0 : memrdata : op;
		if(fetch)
			if(reset0)
				intrcause_ = INTRESET;
			else if(nmi && !nmi0)
				intrcause_ = INTNMI;
			else if(irq && (rP & FLAGI) == 0)
				intrcause_ = INTIRQ;
			else
				intrcause_ = INTBRK;
		else
			intrcause_ = intrcause;
	end
	
	function [7:0] alumux;
	input [3:0] as;
	begin
		case(as)
		AS0: alumux = 0;
		ASA: alumux = rA;
		ASX: alumux = rX;
		ASY: alumux = rY;
		ASMEM: alumux = memrdata;
		ASADL: alumux = rAD[7:0];
		ASADH: alumux = rAD[15:8];
		ASD: alumux = rD;
		ASS: alumux = rS;
		ASP: alumux = rP | (intrcause == INTBRK ? FLAGB : 0);
		ASPCL: alumux = pc[7:0];
		ASPCH: alumux = pc[15:8];
		default: alumux = 8'hXX;
		endcase
	end
	endfunction

	always @(posedge clk) begin
		alua <= alumux(aluas);
		alub <= alumux(alubs);
		aluq <= aluq_;
		aluflagout <= aluflagout_;
	end

	always @(*) begin
		aluflagout_ = 0;
		case(aluop)
		ALUNOPA: aluq_ = alua;
		ALUNOPB: aluq_ = alub;
		ALUADD: begin {aluflagout_[0], aluq_} = {1'b0, alua} + {1'b0, alub} + {8'd0, cin}; aluflagout_[6] = ~(alua[7] ^ alub[7]) & (alua[7] ^ aluq_[7]); end
		ALUSUB: begin {aluflagout_[0], aluq_} = {1'b0, alua} + {1'b0, ~alub} + {8'd0, cin}; aluflagout_[6] = (alua[7] ^ alub[7]) & (alua[7] ^ aluq_[7]); end
		ALUOR: aluq_ = alua | alub;
		ALUAND: aluq_ = alua & alub;
		ALUXOR: aluq_ = alua ^ alub;
		ALUASL: {aluflagout_[0], aluq_} = {alua, cin};
		ALULSR: {aluq_, aluflagout_[0]} = {cin, alua};
		default: aluq_ = 8'hXX;
		endcase
		if(aluq_ == 0)
			aluflagout_ = aluflagout_ | FLAGZ;
		aluflagout_[7] = aluq_[7];
	end
	
	assign memwdata = alua;
	always @(*) begin
		case(memsrc)
		MEMPC: memaddr = pc;
		MEMAD: memaddr = rAD;
		MEMD: memaddr = {8'h00, rD};
		MEMS: memaddr = {8'h01, rS};
		MEMVECL: memaddr = intrcause == INTRESET ? 'hFFFC : intrcause == INTNMI ? 'hFFFA : 'hFFFE;
		MEMVECH: memaddr = intrcause == INTRESET ? 'hFFFD : intrcause == INTNMI ? 'hFFFB : 'hFFFF;
		default: memaddr = 16'hXXXX;
		endcase
	end
	
	always @(*) begin
		t_ = t + 1;
		aluas = AS0;
		alubs = ASMEM;
		aluop = ALUNOPB;
		memsrc = MEMPC;
		seta = 0;
		setx = 0;
		sety = 0;
		setd = 0;
		sets = 0;
		decs = 0;
		setadl = 0;
		setadh = 0;
		memsetadl = 0;
		memsetadh = 0;
		memsetd = 0;
		zeroadh = 0;
		setpc = 0;
		setpcl = 0;
		setpch = 0;
		fetch = 0;
		incpc = 0;
		aluflag = 0;
		cin = 0;
		clrflag = 0;
		setflag = 0;
		cpyflag = 0;
		memwr = 0;
		
		`define ALUOP(op, a, b) aluas = a; alubs = b; aluop = op
		casez({op, t})
		12'h??0: begin fetch = 1; incpc = intrcause_ == INTBRK; end
		
		`define ZP(x) {8'h05, x}, {8'h25, x}, {8'h45, x}, {8'h65, x}, {8'hE5, x}, {8'hC5, x}, {8'hE4, x},\
		{8'hC4, x}, {8'hC6, x}, {8'hE6, x}, {8'h06, x}, {8'h26, x}, {8'h46, x}, {8'h66, x}, {8'hA5, x},\
		{8'h85, x}, {8'hA6, x}, {8'h86, x}, {8'hA4, x}, {8'h84, x}, {8'h24, x}
		`define ZPX(x) {8'h15, x}, {8'h35, x}, {8'h55, x}, {8'h75, x}, {8'hF5, x}, {8'hD5, x}, {8'hD6, x},\
		{8'hF6, x}, {8'h16, x}, {8'h36, x}, {8'h56, x}, {8'h76, x}, {8'hB5, x}, {8'h95, x}, {8'hB4, x}, {8'h94, x}
		`define ZPY(x) {8'hB6, x}, {8'h96, x}
		`define IZX(x) {8'h01, x}, {8'h21, x}, {8'h41, x}, {8'h61, x}, {8'hE1, x}, {8'hC1, x}, {8'hA1, x}, {8'h81, x}
		`define IZY(x) {8'h11, x}, {8'h31, x}, {8'h51, x}, {8'h71, x}, {8'hF1, x}, {8'hD1, x}, {8'hB1, x}, {8'h91, x}
		`define ABS(x) {8'h0D, x}, {8'h2D, x}, {8'h4D, x}, {8'h6D, x}, {8'hED, x}, {8'hCD, x}, {8'hEC, x},\
		{8'hCC, x}, {8'hCE, x}, {8'hEE, x}, {8'h0E, x}, {8'h2E, x}, {8'h4E, x}, {8'h6E, x}, {8'hAD, x},\
		{8'h8D, x}, {8'hAE, x}, {8'h8E, x}, {8'hAC, x}, {8'h8C, x}, {8'h2C, x}, {8'h6C, x}
		`define RABX(x) {8'h1D, x}, {8'h3D, x}, {8'h5D, x}, {8'h7D, x}, {8'hFD, x}, {8'hDD, x}, {8'hBD, x},  {8'hBC, x}
		`define WABX(x) {8'hDE, x}, {8'hFE, x}, {8'h1E, x}, {8'h3E, x}, {8'h5E, x}, {8'h7E, x}, {8'h9D, x}
		`define ABX(x) `RABX(x), `WABX(x)
		`define ABY(x) {8'h19, x}, {8'h39, x}, {8'h59, x}, {8'h79, x}, {8'hF9, x}, {8'hD9, x}, {8'hB9, x}, {8'hBE, x}, {8'h99, x}
	
		`ZP(4'h1): begin setadl = 1; zeroadh = 1; incpc = 1; end
		`ZPX(4'h1), `ZPY(4'h1): begin setadl = 1; zeroadh = 1; incpc = 1; end
		`ZPX(4'h2): begin memsrc = MEMAD; setadl = 1; `ALUOP(ALUADD, ASADL, ASX); end
		`ZPY(4'h2): begin memsrc = MEMAD; setadl = 1; `ALUOP(ALUADD, ASADL, ASY); end
		`ABS(4'h1): begin setadl = 1; incpc = 1; end
		`ABS(4'h2): begin setadh = 1; incpc = 1; end
		`ABX(4'h1), `ABY(4'h1): begin setadl = 1; incpc = 1; end
		`RABX(4'h2): begin memsetadh = 1; incpc = 1; setadl = 1; `ALUOP(ALUADD, ASADL, ASX); t_ = aluflagout[0] ? 3 : 4; end
		`WABX(4'h2): begin memsetadh = 1; incpc = 1; setadl = 1; `ALUOP(ALUADD, ASADL, ASX); end
		`ABY(4'h2): begin memsetadh = 1; incpc = 1; setadl = 1; `ALUOP(ALUADD, ASADL, ASY); t_ = aluflagout[0] || op == 8'h99 ? 3 : 4; end
		`ABX(4'h3), `ABY(4'h3): begin memsrc = MEMAD; setadh = 1; `ALUOP(ALUADD, ASADH, AS0); cin = aluflagout0[0]; end
		`IZX(4'h1): begin setd = 1; incpc = 1; end
		`IZX(4'h2): begin memsrc = MEMD; setd = 1; `ALUOP(ALUADD, ASD, ASX); end
		`IZX(4'h3): begin memsetadl = 1; memsrc = MEMD; setd = 1; `ALUOP(ALUADD, ASD, AS0); cin = 1; end
		`IZX(4'h4): begin setadh = 1; memsrc = MEMD; end
		`IZY(4'h1): begin setd = 1; incpc = 1; end
		`IZY(4'h2): begin memsetadl = 1; memsrc = MEMD; setd = 1; `ALUOP(ALUADD, ASD, AS0); cin = 1; end
		`IZY(4'h3): begin memsetadh = 1; memsrc = MEMD; setadl = 1; `ALUOP(ALUADD, ASADL, ASY); t_ = aluflagout[0] || op == 8'h91 ? 4 : 5; end
		`IZY(4'h4): begin memsrc = MEMAD; setadh = 1; `ALUOP(ALUADD, ASADH, AS0); cin = aluflagout0[0]; end
		`define ADORPC memsrc = t == 1 ? MEMPC : MEMAD; incpc = t == 1
	
		'hA52, 'hA91, 'hB53, 'hAD3, 'hBD4, 'hB94, 'hA15, 'hB15: begin `ADORPC; seta = 1; aluflag = FLAGN | FLAGZ; t_ = 0; end
		'hA21, 'hA62, 'hB63, 'hAE3, 'hBE4: begin `ADORPC; setx = 1; aluflag = FLAGN | FLAGZ; t_ = 0; end
		'hA01, 'hA42, 'hB43, 'hAC3, 'hBC4: begin `ADORPC; sety = 1; aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h091, 'h052, 'h153, 'h0D3, 'h1D4, 'h194, 'h015, 'h115: begin `ADORPC; seta = 1; `ALUOP(ALUOR, ASA, ASMEM); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h291, 'h252, 'h353, 'h2D3, 'h3D4, 'h394, 'h215, 'h315: begin `ADORPC; seta = 1; `ALUOP(ALUAND, ASA, ASMEM); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h491, 'h452, 'h553, 'h4D3, 'h5D4, 'h594, 'h415, 'h515: begin `ADORPC; seta = 1; `ALUOP(ALUXOR, ASA, ASMEM); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h691, 'h652, 'h753, 'h6D3, 'h7D4, 'h794, 'h615, 'h715: begin `ADORPC; seta = 1; `ALUOP(ALUADD, ASA, ASMEM); cin = rP[0]; aluflag = FLAGN | FLAGZ | FLAGV | FLAGC; t_ = 0; end
		'hE91, 'hE52, 'hF53, 'hED3, 'hFD4, 'hF94, 'hE15, 'hF15: begin `ADORPC; seta = 1; `ALUOP(ALUSUB, ASA, ASMEM); cin = rP[0]; aluflag = FLAGN | FLAGZ | FLAGV | FLAGC; t_ = 0; end
		'hC91, 'hC52, 'hD53, 'hCD3, 'hDD4, 'hD94, 'hC15, 'hD15: begin `ADORPC; `ALUOP(ALUSUB, ASA, ASMEM); cin = 1; aluflag = FLAGN | FLAGZ | FLAGC; t_ = 0; end
		'hE01, 'hE42, 'hEC3: begin `ADORPC; `ALUOP(ALUSUB, ASX, ASMEM); cin = 1; aluflag = FLAGN | FLAGZ | FLAGC; t_ = 0; end
		'hC01, 'hC42, 'hCC3: begin `ADORPC; `ALUOP(ALUSUB, ASY, ASMEM); cin = 1; aluflag = FLAGN | FLAGZ | FLAGC; t_ = 0; end
		'h242, 'h2C3: begin `ADORPC; `ALUOP(ALUAND, ASA, ASMEM); aluflag = FLAGZ; cpyflag = FLAGN | FLAGV; t_ = 0; end
		
		'h852, 'h953, 'h8D3, 'h9D4, 'h994, 'h815, 'h915: begin memsrc = MEMAD; memwr = 1; aluas = ASA; t_ = 0; end
		'h862, 'h963, 'h8E3: begin memsrc = MEMAD; memwr = 1; aluas = ASX; t_ = 0; end
		'h842, 'h943, 'h8C3: begin memsrc = MEMAD; memwr = 1; aluas = ASY; t_ = 0; end
		'h0A1: begin seta = 1; `ALUOP(ALUASL, ASA, AS0); aluflag = FLAGN | FLAGZ | FLAGC; t_ = 0; end
		'h4A1: begin seta = 1; `ALUOP(ALULSR, ASA, AS0); aluflag = FLAGN | FLAGZ | FLAGC; t_ = 0; end
		'h2A1: begin seta = 1; `ALUOP(ALUASL, ASA, AS0); cin = rP[0]; aluflag = FLAGN | FLAGZ | FLAGC; t_ = 0; end
		'h6A1: begin seta = 1; `ALUOP(ALULSR, ASA, AS0); cin = rP[0]; aluflag = FLAGN | FLAGZ | FLAGC; t_ = 0; end
		'h062, 'h163, 'h0E3, 'h1E4, 'h462, 'h563, 'h4E3, 'h5E4, 'h262, 'h363, 'h2E3, 'h3E4, 'h662, 'h763, 'h6E3, 'h7E4, 'hC62,  'hD63, 'hCE3, 'hDE4, 'hE62, 'hF63, 'hEE3, 'hFE4: begin memsrc = MEMAD; setd = 1; end
		'h063, 'h164, 'h0E4, 'h1E5: begin memsrc = MEMAD; memwr = 1; setd = 1; `ALUOP(ALUASL, ASD, AS0); aluflag = FLAGN | FLAGZ | FLAGC; end
		'h463, 'h564, 'h4E4, 'h5E5: begin memsrc = MEMAD; memwr = 1; setd = 1; `ALUOP(ALULSR, ASD, AS0); aluflag = FLAGN | FLAGZ | FLAGC; end
		'h263, 'h364, 'h2E4, 'h3E5: begin memsrc = MEMAD; memwr = 1; setd = 1; `ALUOP(ALUASL, ASD, AS0); cin = rP[0]; aluflag = FLAGN | FLAGZ | FLAGC; end
		'h663, 'h764, 'h6E4, 'h7E5: begin memsrc = MEMAD; memwr = 1; setd = 1; `ALUOP(ALULSR, ASD, AS0); cin = rP[0]; aluflag = FLAGN | FLAGZ | FLAGC; end
		'hE63, 'hF64, 'hEE4, 'hFE5: begin memsrc = MEMAD; memwr = 1; setd = 1; `ALUOP(ALUADD, ASD, AS0); cin = 1; aluflag = FLAGN | FLAGZ; end
		'hC63, 'hD64, 'hCE4, 'hDE5: begin memsrc = MEMAD; memwr = 1; setd = 1; `ALUOP(ALUSUB, ASD, AS0); cin = 0; aluflag = FLAGN | FLAGZ; end
		'h064, 'h165, 'h0E5, 'h1E6, 'h464, 'h565, 'h4E5, 'h5E6, 'h264, 'h365, 'h2E5, 'h3E6, 'h664, 'h765, 'h6E5, 'h7E6, 'hC64, 'hD65, 'hCE5, 'hDE6, 'hE64, 'hF65, 'hEE5, 'hFE6: begin memsrc = MEMAD; memwr = 1; aluas = ASD; t_ = 0; end
		'hAA1: begin setx = 1; `ALUOP(ALUNOPA, ASA, AS0); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h8A1: begin seta = 1; `ALUOP(ALUNOPA, ASX, AS0); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'hA81: begin sety = 1; `ALUOP(ALUNOPA, ASA, AS0); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h981: begin seta = 1; `ALUOP(ALUNOPA, ASY, AS0); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h9A1: begin sets = 1; `ALUOP(ALUNOPA, ASX, AS0); t_ = 0; end
		'hBA1: begin setx = 1; `ALUOP(ALUNOPA, ASS, AS0); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'hCA1: begin setx = 1; `ALUOP(ALUSUB, ASX, AS0); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h881: begin sety = 1; `ALUOP(ALUSUB, ASY, AS0); aluflag = FLAGN | FLAGZ; t_ = 0; end
		'hE81: begin setx = 1; `ALUOP(ALUADD, ASX, AS0); cin = 1; aluflag = FLAGN | FLAGZ; t_ = 0; end
		'hC81: begin sety = 1; `ALUOP(ALUADD, ASY, AS0); cin = 1; aluflag = FLAGN | FLAGZ; t_ = 0; end
		'h482: begin aluas = ASA; memsrc = MEMS; memwr = 1; decs = 1; t_ = 0; end
		'h082: begin aluas = ASP; memsrc = MEMS; memwr = 1; decs = 1; t_ = 0; end
		'h682, 'h282: begin sets = 1; `ALUOP(ALUADD, ASS, AS0); cin = 1; end
		'h683: begin seta = 1; memsrc = MEMS; aluflag = FLAGN | FLAGZ; t_ = 0;end
		'h283: begin cpyflag = 8'hFF; memsrc = MEMS; t_ = 0; end
		
		'h4C1: begin setd = 1; incpc = 1; end
		'h4C2: begin setpc = 1; `ALUOP(ALUNOPA, ASD, AS0); t_ = 0; end
		'h6C3: begin memsrc = MEMAD; memsetd = 1; setadl = 1; `ALUOP(ALUADD, ASADL, AS0); cin = 1; end
		'h6C4: begin setpc = 1; memsrc = MEMAD; `ALUOP(ALUNOPA, ASD, AS0); t_ = 0; end
		'h201: begin setd = 1; incpc = 1; end
		'h203: begin aluas = ASPCH; memwr = 1; memsrc = MEMS; decs = 1; end
		'h204: begin aluas = ASPCL; memwr = 1; memsrc = MEMS; decs = 1; end
		'h205: begin setpc = 1; `ALUOP(ALUNOPA, ASD, AS0); t_ = 0; end
		'h602: begin sets = 1; `ALUOP(ALUADD, ASS, AS0); cin = 1; end
		'h603: begin memsetd = 1; memsrc = MEMS; sets = 1; `ALUOP(ALUADD, ASS, AS0); cin = 1; end
		'h604: begin setpc = 1; memsrc = MEMS; `ALUOP(ALUNOPA, ASD, AS0); end
		'h605: begin incpc = 1; t_ = 0; end
		'h402: begin sets = 1; `ALUOP(ALUADD, ASS, AS0); cin = 1; end
		'h403: begin cpyflag = 8'hFF; memsrc = MEMS; sets = 1; `ALUOP(ALUADD, ASS, AS0); cin = 1; end
		'h404: begin memsetd = 1; memsrc = MEMS; sets = 1; `ALUOP(ALUADD, ASS, AS0); cin = 1; end
		'h405: begin setpc = 1; memsrc = MEMS; `ALUOP(ALUNOPA, ASD, AS0); t_ = 0; end
		'h001: begin incpc = intrcause == INTBRK; end
		'h002: begin memsrc = MEMS; memwr = intrcause != INTRESET; aluas = ASPCH; decs = 1; end
		'h003: begin memsrc = MEMS; memwr = intrcause != INTRESET; aluas = ASPCL; decs = 1; end
		'h004: begin memsrc = MEMS; memwr = intrcause != INTRESET; aluas = ASP; decs = 1; end
		'h005: begin memsrc = MEMVECL; memsetd = 1; setflag = FLAGI; end
		'h006: begin setpc = 1; memsrc = MEMVECH; `ALUOP(ALUNOPA, ASD, AS0); t_ = 0; end
		
		'h101: begin setd = 1; incpc = 1; if((rP & FLAGN) != 0) t_ = 0; end
		'h301: begin setd = 1; incpc = 1; if((rP & FLAGN) == 0) t_ = 0; end
		'h501: begin setd = 1; incpc = 1; if((rP & FLAGV) != 0) t_ = 0; end
		'h701: begin setd = 1; incpc = 1; if((rP & FLAGV) == 0) t_ = 0; end
		'h901: begin setd = 1; incpc = 1; if((rP & FLAGC) != 0) t_ = 0; end
		'hB01: begin setd = 1; incpc = 1; if((rP & FLAGC) == 0) t_ = 0; end
		'hD01: begin setd = 1; incpc = 1; if((rP & FLAGZ) != 0) t_ = 0; end
		'hF01: begin setd = 1; incpc = 1; if((rP & FLAGZ) == 0) t_ = 0; end
		'h102, 'h302, 'h502, 'h702, 'h902, 'hB02, 'hD02, 'hF02: begin setpcl = 1; `ALUOP(ALUADD, ASPCL, ASD); if(aluflagout[0] == rD[7]) t_ = 0; end
		'h103, 'h303, 'h503, 'h703, 'h903, 'hB03, 'hD03, 'hF03: begin setpch = 1; `ALUOP(rD[7] ? ALUSUB : ALUADD, ASPCH, AS0); cin = ~rD[7]; t_ = 0; end

		'h181: begin clrflag = FLAGC; t_ = 0; end
		'h381: begin setflag = FLAGC; t_ = 0; end
		'h581: begin clrflag = FLAGI; t_ = 0; end
		'h781: begin setflag = FLAGI; t_ = 0; end
		'hB81: begin clrflag = FLAGV; t_ = 0; end
		'hD81: begin clrflag = FLAGD; t_ = 0; end
		'hF81: begin setflag = FLAGD; t_ = 0; end
		'hEA1: begin t_ = 0; end
		endcase
		if(reset)
			memwr = 0;
	end
endmodule
