`include "dat.vh"

module ppuspr(
	input wire clk,
	input wire tick,
	
	input wire [8:0] ppux,
	input wire [8:0] ppuy,
	input wire render,
	
	input wire [7:0] ppuctrl,
	input wire [7:0] ppumask,
	input wire [7:0] regwdata,
	input wire wr2003,
	input wire rd2004,
	input wire wr2004,
	output reg [7:0] oamdata,
	output reg sprovf,
	
	output reg [13:0] sprvmemaddr,
	input wire [7:0] vmemrdata,
	
	output reg [4:0] sprpxout,
	output reg spr0,
	
	input wire reset
);

	reg incn, incm, zoamaddr, incsoam, zsoamaddr, clearoam, wrinhib;
	reg [7:0] oamaddr, oamaddr_;
	reg [4:0] soamaddr, soamaddr_;
	reg oaminrange;
	reg sprovf_;
	reg spr0act, spr0act0, spr0act0_;
	
	always @(posedge clk)
		if(tick) begin
			oamaddr <= oamaddr_;
			soamaddr <= soamaddr_;
			spr0act0 <= spr0act0_;
			sprovf <= sprovf_;
			if(ppux == 0)
				spr0act <= spr0act0;
		end
	
	always @(*) begin
		oamaddr_ = oamaddr;
		if(incn)
			if(render)
				oamaddr_[7:2] = oamaddr[7:2] + 1;
			else
				oamaddr_ = oamaddr + 1;
		if(incm)
			oamaddr_[1:0] = oamaddr[1:0] + 1;
		if(zoamaddr)
			oamaddr_ = 0;
		if(wr2003)
			oamaddr_ = regwdata;
	end
	
	always @(*) begin
		soamaddr_ = soamaddr;
		if(incsoam)
			soamaddr_ = soamaddr + 1;
		if(zsoamaddr)
			soamaddr_ = 0;
	end
	
	reg [2:0] oamstate, oamstate_;
	localparam OAMSEARCH = 0;
	localparam OAMCOPY = 1;
	localparam OAMFULL = 2;
	localparam OAMSKIP = 3;
	localparam OAMIDLE = 4;
	always @(posedge clk)
		if(tick)
			oamstate <= oamstate_;

	reg sety, setvraddr, setattr, setx, flipvraddr, setlow, sethigh;
	reg vflip, hflip;

	always @(*) begin
		incm = 0;
		zoamaddr = 0;
		zsoamaddr = 0;
		incsoam = 0;
		incn = wr2004;
		clearoam = 0;
		wrinhib = 1;
		sprovf_ = sprovf;
		oamstate_ = OAMSEARCH;
		sety = 0;
		setvraddr = 0;
		setattr = 0;
		setx = 0;
		flipvraddr = 0;
		setlow = 0;
		sethigh = 0;
		spr0act0_ = spr0act0;
		if(ppuy == 261 && ppux == 1)
			sprovf_ = 0;
		if(render)
			if(ppux == 0) begin
				zsoamaddr = 1;
				spr0act0_ = 0;
			end else if(ppux <= 64) begin
				clearoam = 1;
				wrinhib = 0;
				incsoam = ppux[0];
			end else if(ppux <= 256) begin
				oamstate_ = oamstate;
				case(oamstate)
				OAMSEARCH: begin
					wrinhib = 0;
					if(!ppux[0])
						if(oaminrange) begin
							if(oamaddr == 0)
								spr0act0_ = 1;
							oamstate_ = OAMCOPY;
							incsoam = 1;
							incm = 1;
						end else
							incn = 1;
				end
				OAMCOPY: begin
					wrinhib = 0;
					if(!ppux[0]) begin
						incm = 1;
						incsoam = 1;
						if(oamaddr[1:0] == 2'b11) begin
							oamstate_ = OAMSEARCH;
							incn = 1;
						end
					end
				end
				OAMFULL:
					if(ppux[0])
						if(oaminrange) begin
							sprovf_ = 1;
							incm = 1;
							if(oamaddr[1:0] == 2'b11)
								incn = 1;
							else
								oamstate_ = OAMSKIP;
						end else begin
							incn = 1;
							incm = 1;
						end
				OAMSKIP:
					if(ppux[0]) begin
						incm = 1;
						if(oamaddr[1:0] == 2'b11) begin
							incn = 1;
							oamstate_ = OAMFULL;
						end
					end
				endcase
				if(incsoam && soamaddr == 31)
					oamstate_ = OAMFULL;
				if(incn && oamaddr[7:2] == 6'b111111)
					oamstate_ = OAMIDLE;
				if(ppux == 256)
					zsoamaddr = 1;
			end else if(ppux <= 320) begin
				zoamaddr = 1;
				case(ppux[2:0])
				1: sety = 1;
				2: setvraddr = 1;
				3: setattr = 1;
				4: begin
					setx = 1;
					flipvraddr = vflip;
				end
				5: setlow = 1;
				7: sethigh = 1;
				endcase
				case(ppux[2:0])
				1,2,3,7: incsoam = 1;
				endcase
			end
	end
	
	reg [7:0] oam[0:287];
	always @(posedge clk) begin
		if(render)
			if(ppux > 256 || wrinhib && !ppux[0])
				oamdata <= oam[{4'b1000, soamaddr}];
			else if(ppux[0])
				oamdata <= oam[{1'b0, oamaddr}] | {8{clearoam}};	
			else
				oam[{4'b1000, soamaddr}] <= oamdata;			
		else if(wr2004)
			oam[{1'b0, oamaddr}] <= regwdata;
		else if(rd2004)
			oamdata <= oam[{1'b0, oamaddr}];
	end
	
	reg [8:0] dy;

	always @(*) begin
		dy = ppuy - {1'b0, oamdata};
		oaminrange = dy < (ppuctrl[`SPR16] ? 16 : 8);
	end

	wire [2:0] i;
	reg [2:0] pal[0:7];
	reg [7:0] sprx[0:7];
	reg [15:0] sprsh[0:7];
	reg [1:0] state[0:7], state_[0:7];
	reg decsprx[7:0];
	reg [1:0] sprpx[0:7];
	localparam SPRIDLE = 0;
	localparam SPRWAIT = 1;
	localparam SPRACT = 2;
	reg [13:0] sprvmemaddr_;
	integer j;
	
	assign i = soamaddr[4:2];

	always @(posedge clk)
		if(tick) begin
			sprvmemaddr <= sprvmemaddr_;
			if(sety)
				if(oamdata == 8'hFF)
					state[i] <= SPRIDLE;
				else
					state[i] <= SPRWAIT;
			if(setattr) begin
				pal[i] <= {oamdata[5], oamdata[1:0]};
				hflip <= oamdata[6];
				vflip <= oamdata[7];
			end
			if(setx) begin
				sprx[i] <= oamdata;
				if(oamdata == 0 && state[i] == SPRWAIT)
					state[i] <= SPRACT;
			end
			if(setlow && !hflip)
				{sprsh[i][14], sprsh[i][12], sprsh[i][10], sprsh[i][8], sprsh[i][6], sprsh[i][4], sprsh[i][2], sprsh[i][0]} <= vmemrdata;
			if(sethigh && !hflip)
				{sprsh[i][15], sprsh[i][13], sprsh[i][11], sprsh[i][9], sprsh[i][7], sprsh[i][5], sprsh[i][3], sprsh[i][1]} <= vmemrdata;
			if(setlow && hflip)
				{sprsh[i][0], sprsh[i][2], sprsh[i][4], sprsh[i][6], sprsh[i][8], sprsh[i][10], sprsh[i][12], sprsh[i][14]} <= vmemrdata;
			if(sethigh && hflip)
				{sprsh[i][1], sprsh[i][3], sprsh[i][5], sprsh[i][7], sprsh[i][9], sprsh[i][11], sprsh[i][13], sprsh[i][15]} <= vmemrdata;
			if(ppux < 256)
				for(j = 0; j < 8; j = j + 1) begin
					state[j] <= state_[j];
					if(decsprx[j])
						sprx[j] <= sprx[j] - 1;
					if(state[j] == SPRACT)
						sprsh[j] <= {sprsh[j][13:0], 2'b00};
				end
		end
	
	always @(*) begin
		sprvmemaddr_ = sprvmemaddr;
		if(sety)
			sprvmemaddr_[3:0] = {1'b0, dy[2:0]};
		if(setvraddr)
			if(ppuctrl[`SPR16])
				sprvmemaddr_[13:4] = {1'b0, oamdata[0], oamdata[7:1], dy[3]};
			else
				sprvmemaddr_[13:4] = {1'b0, ppuctrl[`SPRTAB], oamdata};
		if(flipvraddr) begin
			if(ppuctrl[`SPR16])
				sprvmemaddr_[4] = !sprvmemaddr[4];
			sprvmemaddr_[2:0] = ~sprvmemaddr[2:0];
		end
	end
	
	always @(*) begin
		for(j = 0; j < 8; j = j + 1) begin
			state_[j] = state[j];
			decsprx[j] = 0;
			sprpx[j] = 0;
			case(state[j])
			SPRWAIT:
				if(sprx[j] == 0)
					state_[j] = SPRACT;
				else
					decsprx[j] = 1;
			SPRACT: begin
				if(sprx[j] == 8'hF8)
					state_[j] = SPRIDLE;
				else
					decsprx[j] = 1;
				sprpx[j] = sprsh[j][15:14];
			end
			endcase
		end
		sprpxout = 0;
		for(j = 7; j >= 0; j = j - 1)
			if(sprpx[j] != 0)
				sprpxout = {pal[j], sprpx[j]};
		spr0 = spr0act && sprpx[0] != 0;
	end

endmodule
