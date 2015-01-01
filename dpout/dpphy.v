`timescale 1ns / 1ps
`default_nettype none

module dpphy(
	clk,
	usrclk,
	ctl0,
	refclk,
	tx,
	datain,
	iskin
);

	input wire clk;
	input wire [1:0] refclk;
	output wire [3:0] tx;
	input wire [31:0] ctl0;
	input wire [31:0] datain;
	input wire [3:0] iskin;
	output wire usrclk;
	
	reg [31:0] ctl;
	wire rdy;
	wire txreset;
	reg[31:0] txdata;
	wire[1:0] txbufstat;
	reg[1:0] mode;
	reg[3:0] isk;
	reg[3:0] ctr;
	reg[2:0] prbs;
	reg reset;
	
	assign txreset = ctl0[31];
	assign rdy = !txreset;
	
	always @(posedge usrclk) begin
		ctl <= ctl0;
		reset <= ctl[31];
		mode <= ctl[1:0];
		prbs <= ctl[4:2];
		case(mode)
		default: begin
			txdata <= 0;
			isk <= 0;
		end
		1: begin
			txdata <= datain;
			isk <= iskin;
		end
		2: begin
			txdata <= 32'h4A4A4A4A;
			isk <= 0;
		end
		3: begin
			ctr <= ctr + 1;
			case(ctr)
			0: begin
				txdata <= 32'hCBBCCBBC;
				isk <= 4'b0101;
			end
			1: begin
				txdata <= 32'h4A4A4A4A;
				isk <= 4'b0000;
			end
			2: begin
				txdata <= 32'hCBBC4A4A;
				isk <= 4'b0100;
			end
			3: begin
				txdata <= 32'h4A4A4A4A;
				isk <= 4'b0000;
				ctr <= 0;
			end
			endcase
		end
		endcase
		if(reset)
			ctr <= 0;
	end

mainlinkgtp_support  mainlinkgtp_i
(
.sysclk_in_i(clk), // input wire sysclk_in
 .soft_reset_in(txreset), // input wire soft_reset_in
 .dont_reset_on_data_error_in(1), // input wire dont_reset_on_data_error_in
 .q0_clk1_gtrefclk_pad_n_in(refclk[1]), // input wire q0_clk1_gtrefclk_pad_n_in
 .q0_clk1_gtrefclk_pad_p_in(refclk[0]), // input wire q0_clk1_gtrefclk_pad_p_in
 .gt0_data_valid_in(rdy), // input wire gt0_data_valid_in
 .gt1_data_valid_in(0), // input wire gt1_data_valid_in

//_________________________________________________________________________
//GT0  (X0Y0)
//____________________________CHANNEL PORTS________________________________
//-------------------------- Channel - DRP Ports  --------------------------
//    .gt0_drpaddr_in                 (gt0_drpaddr_in), // input wire [8:0] gt0_drpaddr_in
//    .gt0_drpdi_in                   (gt0_drpdi_in), // input wire [15:0] gt0_drpdi_in
//    .gt0_drpdo_out                  (gt0_drpdo_out), // output wire [15:0] gt0_drpdo_out
    .gt0_drpen_in                   (0), // input wire gt0_drpen_in
//    .gt0_drprdy_out                 (gt0_drprdy_out), // output wire gt0_drprdy_out
    .gt0_drpwe_in                   (0), // input wire gt0_drpwe_in
//------------------- RX Initialization and Reset Ports --------------------
    .gt0_eyescanreset_in            (0), // input wire gt0_eyescanreset_in
//------------------------ RX Margin Analysis Ports ------------------------
//    .gt0_eyescandataerror_out       (gt0_eyescandataerror_out), // output wire gt0_eyescandataerror_out
//    .gt0_eyescantrigger_in          (gt0_eyescantrigger_in), // input wire gt0_eyescantrigger_in
//---------- Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
//    .gt0_dmonitorout_out            (gt0_dmonitorout_out), // output wire [14:0] gt0_dmonitorout_out
//----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt0_gtrxreset_in               (reset), // input wire gt0_gtrxreset_in
    .gt0_rxlpmreset_in              (reset), // input wire gt0_rxlpmreset_in
//------------------- TX Initialization and Reset Ports --------------------
    .gt0_gttxreset_in               (reset), // input wire gt0_gttxreset_in
    .gt0_txuserrdy_in               (rdy), // input wire gt0_txuserrdy_in
//---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt0_txdata_in                  (txdata), // input wire [31:0] gt0_txdata_in
//---------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
    .gt0_txcharisk_in               (isk), // input wire [3:0] gt0_txcharisk_in
//-------------------- Transmit Ports - TX Buffer Ports --------------------
    .gt0_txbufstatus_out            (txbufstat), // output wire [1:0] gt0_txbufstatus_out
//------------- Transmit Ports - TX Configurable Driver Ports --------------
    .gt0_gtptxn_out                 (tx[1]), // output wire gt0_gtptxn_out
    .gt0_gtptxp_out                 (tx[0]), // output wire gt0_gtptxp_out
//--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
//    .gt0_txoutclk_out               (gt0_txoutclk_out), // output wire gt0_txoutclk_out
//    .gt0_txoutclkfabric_out         (gt0_txoutclkfabric_out), // output wire gt0_txoutclkfabric_out
//    .gt0_txoutclkpcs_out            (gt0_txoutclkpcs_out), // output wire gt0_txoutclkpcs_out
//----------- Transmit Ports - TX Initialization and Reset Ports -----------
//    .gt0_txresetdone_out(debug),          // output wire gt0_txresetdone_out

//GT1  (X0Y3)
//____________________________CHANNEL PORTS________________________________
//-------------------------- Channel - DRP Ports  --------------------------
//    .gt1_drpaddr_in                 (gt1_drpaddr_in), // input wire [8:0] gt1_drpaddr_in
//    .gt1_drpdi_in                   (gt1_drpdi_in), // input wire [15:0] gt1_drpdi_in
//    .gt1_drpdo_out                  (gt1_drpdo_out), // output wire [15:0] gt1_drpdo_out
    .gt1_drpen_in                   (0), // input wire gt1_drpen_in
//    .gt1_drprdy_out                 (gt1_drprdy_out), // output wire gt1_drprdy_out
    .gt1_drpwe_in                   (0), // input wire gt1_drpwe_in
//------------------- RX Initialization and Reset Ports --------------------
    .gt1_eyescanreset_in            (0), // input wire gt1_eyescanreset_in
//------------------------ RX Margin Analysis Ports ------------------------
//    .gt1_eyescandataerror_out       (gt1_eyescandataerror_out), // output wire gt1_eyescandataerror_out
//    .gt1_eyescantrigger_in          (gt1_eyescantrigger_in), // input wire gt1_eyescantrigger_in
//---------- Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
//    .gt1_dmonitorout_out            (gt1_dmonitorout_out), // output wire [14:0] gt1_dmonitorout_out
//----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt1_gtrxreset_in               (txreset), // input wire gt1_gtrxreset_in
    .gt1_rxlpmreset_in              (txreset), // input wire gt1_rxlpmreset_in
//------------------- TX Initialization and Reset Ports --------------------
    .gt1_gttxreset_in               (txreset), // input wire gt1_gttxreset_in
    .gt1_txuserrdy_in               (0), // input wire gt1_txuserrdy_in
//---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt1_txdata_in                  (0), // input wire [31:0] gt1_txdata_in
//---------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
    .gt1_txcharisk_in               (0), // input wire [3:0] gt1_txcharisk_in
//-------------------- Transmit Ports - TX Buffer Ports --------------------
//    .gt1_txbufstatus_out            (gt1_txbufstatus_out), // output wire [1:0] gt1_txbufstatus_out
//------------- Transmit Ports - TX Configurable Driver Ports --------------
    .gt1_gtptxn_out                 (tx[3]), // output wire gt1_gtptxn_out
    .gt1_gtptxp_out                 (tx[2]), // output wire gt1_gtptxp_out
//--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
//    .gt1_txoutclk_out               (gt1_txoutclk_out), // output wire gt1_txoutclk_out
//    .gt1_txoutclkfabric_out         (gt1_txoutclkfabric_out), // output wire gt1_txoutclkfabric_out
//    .gt1_txoutclkpcs_out            (gt1_txoutclkpcs_out), // output wire gt1_txoutclkpcs_out
//----------- Transmit Ports - TX Initialization and Reset Ports -----------
//    .gt1_txresetdone_out            (gt1_txresetdone_out), // output wire gt1_txresetdone_out
.gt0_txpolarity_in(1),
.gt1_txpolarity_in(1),
.gt0_txprbssel_in(prbs),
.gt1_txprbssel_in(0),
.gt0_txusrclk2_out(usrclk)
); 
endmodule