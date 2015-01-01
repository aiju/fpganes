`include "dport.vh"

module scrambler(
	clk,
	data_in,
	isk_in,
	data_out,
	isk_out
);

	input wire clk; 
	input wire [31:0] data_in;
	output reg [31:0] data_out;
	input wire [3:0] isk_in;
	output reg [3:0] isk_out;

	reg [15:0] lfsr_q, lfsr_c;
	reg [31:0] key, key0;
	reg [8:0] bsctr;
	wire [3:0] bs;
	wire [3:0] reset;

	initial begin
		lfsr_q <= 16'hFFFF;
		bsctr <= 0;
	end
	assign bs[0] = isk_in[0] && data_in[7:0] == `symBS;
	assign bs[1] = isk_in[1] && data_in[15:8] == `symBS;
	assign bs[2] = isk_in[2] && data_in[23:16] == `symBS;
	assign bs[3] = isk_in[3] && data_in[31:24] == `symBS;
	assign reset = bsctr == 0 ? bs : 0;
	always @(posedge clk) begin
		isk_out <= isk_in;
		data_out[7:0] <= reset[0] ? `symSR : data_in[7:0] ^ (!isk_in[0] ? key0[7:0] : 0);
		data_out[15:8] <= reset[1] ? `symSR : data_in[15:8] ^ (!isk_in[1] ? key0[15:8] : 0);
		data_out[23:16] <= reset[2] ? `symSR : data_in[23:16] ^ (!isk_in[2] ? key0[23:16] : 0);
		data_out[31:24] <= reset[3] ? `symSR : data_in[31:24] ^ (!isk_in[3] ? key0[31:24] : 0);
		lfsr_q <= lfsr_c;
		if(reset[0])
			lfsr_q <= 'h284B;
		if(reset[1])
			lfsr_q <= 'h0328;
		if(reset[2])
			lfsr_q <= 'hE817;
		if(reset[3])
			lfsr_q <= 'hFFFF;
		if(|bs)
			bsctr <= bsctr + 1;
	end

	always @(*) begin
		lfsr_c[0] = lfsr_q[0] ^ lfsr_q[6] ^ lfsr_q[8] ^ lfsr_q[10];
		lfsr_c[1] = lfsr_q[1] ^ lfsr_q[7] ^ lfsr_q[9] ^ lfsr_q[11];
		lfsr_c[2] = lfsr_q[2] ^ lfsr_q[8] ^ lfsr_q[10] ^ lfsr_q[12];
		lfsr_c[3] = lfsr_q[3] ^ lfsr_q[6] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[13];
		lfsr_c[4] = lfsr_q[4] ^ lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[14];
		lfsr_c[5] = lfsr_q[5] ^ lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[9] ^ lfsr_q[12] ^ lfsr_q[13] ^ lfsr_q[15];
		lfsr_c[6] = lfsr_q[0] ^ lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[10] ^ lfsr_q[13] ^ lfsr_q[14];
		lfsr_c[7] = lfsr_q[1] ^ lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[11] ^ lfsr_q[14] ^ lfsr_q[15];
		lfsr_c[8] = lfsr_q[0] ^ lfsr_q[2] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[12] ^ lfsr_q[15];
		lfsr_c[9] = lfsr_q[1] ^ lfsr_q[3] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[13];
		lfsr_c[10] = lfsr_q[0] ^ lfsr_q[2] ^ lfsr_q[4] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[14];
		lfsr_c[11] = lfsr_q[1] ^ lfsr_q[3] ^ lfsr_q[5] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[13] ^ lfsr_q[15];
		lfsr_c[12] = lfsr_q[2] ^ lfsr_q[4] ^ lfsr_q[6] ^ lfsr_q[12] ^ lfsr_q[13] ^ lfsr_q[14];
		lfsr_c[13] = lfsr_q[3] ^ lfsr_q[5] ^ lfsr_q[7] ^ lfsr_q[13] ^ lfsr_q[14] ^ lfsr_q[15];
		lfsr_c[14] = lfsr_q[4] ^ lfsr_q[6] ^ lfsr_q[8] ^ lfsr_q[14] ^ lfsr_q[15];
		lfsr_c[15] = lfsr_q[5] ^ lfsr_q[7] ^ lfsr_q[9] ^ lfsr_q[15];

		key[0] = lfsr_q[15];
		key[1] = lfsr_q[14];
		key[2] = lfsr_q[13];
		key[3] = lfsr_q[12];
		key[4] = lfsr_q[11];
		key[5] = lfsr_q[10];
		key[6] = lfsr_q[9];
		key[7] = lfsr_q[8];
		key[8] = lfsr_q[7];
		key[9] = lfsr_q[6];
		key[10] = lfsr_q[5];
		key[11] = lfsr_q[4] ^ lfsr_q[15];
		key[12] = lfsr_q[3] ^ lfsr_q[14] ^ lfsr_q[15];
		key[13] = lfsr_q[2] ^ lfsr_q[13] ^ lfsr_q[14] ^ lfsr_q[15];
		key[14] = lfsr_q[1] ^ lfsr_q[12] ^ lfsr_q[13] ^ lfsr_q[14];
		key[15] = lfsr_q[0] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[13];
		key[16] = lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[15];
		key[17] = lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[14];
		key[18] = lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[13];
		key[19] = lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[12];
		key[20] = lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[11];
		key[21] = lfsr_q[5] ^ lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[10];
		key[22] = lfsr_q[4] ^ lfsr_q[5] ^ lfsr_q[6] ^ lfsr_q[9] ^ lfsr_q[15];
		key[23] = lfsr_q[3] ^ lfsr_q[4] ^ lfsr_q[5] ^ lfsr_q[8] ^ lfsr_q[14];
		key[24] = lfsr_q[2] ^ lfsr_q[3] ^ lfsr_q[4] ^ lfsr_q[7] ^ lfsr_q[13] ^ lfsr_q[15];
		key[25] = lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[3] ^ lfsr_q[6] ^ lfsr_q[12] ^ lfsr_q[14];
		key[26] = lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[5] ^ lfsr_q[11] ^ lfsr_q[13] ^ lfsr_q[15];
		key[27] = lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[4] ^ lfsr_q[10] ^ lfsr_q[12] ^ lfsr_q[14];
		key[28] = lfsr_q[0] ^ lfsr_q[3] ^ lfsr_q[9] ^ lfsr_q[11] ^ lfsr_q[13];
		key[29] = lfsr_q[2] ^ lfsr_q[8] ^ lfsr_q[10] ^ lfsr_q[12];
		key[30] = lfsr_q[1] ^ lfsr_q[7] ^ lfsr_q[9] ^ lfsr_q[11];
		key[31] = lfsr_q[0] ^ lfsr_q[6] ^ lfsr_q[8] ^ lfsr_q[10];
		
		key0 = key;
		if(reset[0]) begin
			key0[15:8] = 'hFF;
			key0[23:16] = 'h17;
			key0[31:24] = 'hC0;
		end
		if(reset[1]) begin
			key0[23:16] = 'hFF;
			key0[31:24] = 'h17;
		end
		if(reset[2])
			key0[31:24] = 'hFF;
	end
endmodule
