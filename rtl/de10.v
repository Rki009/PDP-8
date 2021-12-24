// DE10 Board

// Connect Serial Port, USB-UART
//	==========================================
//	GPIO #		JP1-#		Description
//	==========================================
//	GPIO 5		Pin 6		PIN_??	dtr signal
//	GPIO 7		Pin 8		PIN_W7	tx data
//	GPIO 9		Pin 10	PIN_V5	rx data
//	GND			Pin 12	GND		GND

// Connect GPS Port,
//	============================================
//	ARDUINO #			JP-?		Description
//	============================================
//	ARDUINO_IO[0]		Pin ?		Rx from GPS
//	ARDUINO_IO[1]		Pin ?		Tx to GPS
//	ARDUINO_IO[2]		Pin ?		PPS from GPS

`define DUAL_CORE 	1
`define BOOT_DISP24	24'hcDcb8E	// spell out "PDP-8E"

module de10(

	//////////// CLOCK //////////
	input				ADC_CLK_10,
	input				MAX10_CLK1_50,
	input				MAX10_CLK2_50,

	//////////// SDRAM //////////
	output [12:0]		DRAM_ADDR,
	output [1:0]		DRAM_BA,
	output				DRAM_CAS_N,
	output				DRAM_CKE,
	output				DRAM_CLK,
	output				DRAM_CS_N,
	inout [15:0]		DRAM_DQ,
	output				DRAM_LDQM,
	output				DRAM_RAS_N,
	output				DRAM_UDQM,
	output				DRAM_WE_N,

	//////////// SEG7 //////////
	output [7:0]		HEX0,
	output [7:0]		HEX1,
	output [7:0]		HEX2,
	output [7:0]		HEX3,
	output [7:0]		HEX4,
	output [7:0]		HEX5,

	//////////// KEY //////////
	input [1:0]			KEY,

	//////////// LED //////////
	output wire [9:0]	LEDR,

	//////////// SW //////////
	input wire [9:0]	SW,

	//////////// VGA //////////
	output [3:0]		VGA_B,
	output [3:0]		VGA_G,
	output				VGA_HS,
	output [3:0]		VGA_R,
	output				VGA_VS,

	//////////// Accelerometer //////////
	output				GSENSOR_CS_N,
	input [2:1]			GSENSOR_INT,
	output				GSENSOR_SCLK,
	inout				GSENSOR_SDI,
	inout				GSENSOR_SDO,

	//////////// Arduino //////////
	inout [15:0]		ARDUINO_IO,
	inout				ARDUINO_RESET_N,

	// GPIO
	inout [35:0]		GPIO
);

	// general default connections
	assign GSENSOR_CS_N = 1'b1;
	assign GSENSOR_SCLK = 1'b1;
	assign GSENSOR_SDI = 1'bz;
	assign GSENSOR_SDO = 1'bz;

	assign VGA_R = 4'h0;
	assign VGA_G = 4'h0;
	assign VGA_B = 4'h0;
	assign VGA_HS = 1'b0;
	assign VGA_VS = 1'b0;

	assign DRAM_ADDR = 13'd0;
	assign DRAM_BA = 2'b00;
	assign DRAM_CAS_N = 1'b1;
	assign DRAM_CKE = 1'b0;
	assign DRAM_CLK = 1'b0;
	assign DRAM_CS_N = 1'b1;
	assign DRAM_LDQM = 1'b0;
	assign DRAM_RAS_N = 1'b1;
	assign DRAM_UDQM = 1'b0;
	assign DRAM_WE_N = 1'b1;
	assign DRAM_DQ = 16'hzzzz;

	assign ARDUINO_IO = 16'hzzzz;
	assign ARDUINO_RESET_N = 1'bz;

	// ****************************************************
	// System clk and reset signals
	// ****************************************************
	// 50 MHz base clock
	wire clk = MAX10_CLK1_50;

	// reset counter, reset for 15 cycles ...
	reg [3:0] rst_cnt = 4'h0;
	wire rst_done = &rst_cnt;
	always @(posedge clk) begin
		if(~rst_done) rst_cnt <= rst_cnt + 4'h1;
		if (~KEY[0]) rst_cnt <= 4'h0;
	end
	wire rst = ~rst_done;	// reset signal, 1 = reset

	// ****************************************************
	// GPS Device
	// ****************************************************
	wire gps_rx;					// GPS recieve data
	wire gps_tx;					// GPS transmit data
	assign ARDUINO_IO[1] = gps_tx;
	assign gps_rx = ARDUINO_IO[0];

	// Serial Port
	wire tty_rx;					// UART recieve data
	wire tty_tx;					// UART transmit data
	assign GPIO[7] = tty_tx;
	assign tty_rx = GPIO[9];

	// Switch Register/Status Leds
	wire [11:0]	switch_reg;	// Switch register
	wire [11:0]	status;			// Status output
	// DE10
	wire de10_sel;
	wire [2:0] de10_addr;
	wire de10_we;
	wire [11:0] de10_wdata;
	wire [11:0] de10_rdata = 12'o0000;
	pdp8 pdp8 (
		.clk(clk), .rst(rst),
		.switch_reg(switch_reg), .status(status),
		.tty_rx(tty_rx), .tty_tx(tty_tx),
		.gps_rx(gps_rx), .gps_tx(gps_tx),
		.de10_sel(de10_sel), .de10_addr(de10_addr), .de10_we(de10_we),
		.de10_wdata(de10_wdata), .de10_rdata(de10_rdata)
		);

	// DE10 LEDS/SEGn and SW interface
	//	IOT:		Write		Read
	//	6470		HEX0		--
	//	6471		HEX1		--
	//	6472		HEX2		--
	//	6473		HEX3		--
	//	6474		HEX4		--
	//	6475		HEX5		--
	//	6476		--			--
	//	6477		LEDR		--
	reg [11:0] leds;
	reg [23:0] display24;
	always @(posedge clk) begin
		if (rst) begin
			leds <= 12'o0000;
			// display24 <= 24'h000000;
			display24 <= `BOOT_DISP24;
		end
		else if (de10_sel & de10_we) begin
			case (de10_addr)
			3'o0:	display24[3:0] <= de10_wdata[3:0];
			3'o1:	display24[7:4] <= de10_wdata[3:0];
			3'o2:	display24[11:8] <= de10_wdata[3:0];
			3'o3:	display24[15:12] <= de10_wdata[3:0];
			3'o4:	display24[19:16] <= de10_wdata[3:0];
			3'o5:	display24[23:20] <= de10_wdata[3:0];
			3'o7:	leds <= de10_wdata[11:0];
			default: ;
			endcase
		end
	end

	// DE10
	wire de10_2_sel;
	wire [2:0] de10_2_addr;
	wire de10_2_we;
	wire [11:0] de10_2_wdata;
	wire [11:0] de10_2_rdata = 12'o0000;
	pdp8 pdp8_2 (
		.clk(clk), .rst(rst),
		.switch_reg(12'o0000), .status(status),
		.tty_rx(1'b1), .tty_tx(),
		.gps_rx(gps_rx), .gps_tx(),
		.de10_sel(de10_2_sel), .de10_addr(de10_2_addr), .de10_we(de10_2_we),
		.de10_wdata(de10_2_wdata), .de10_rdata(de10_2_rdata)
		);
	reg [11:0] leds_2;
	reg [23:0] display24_2;
	always @(posedge clk) begin
		if (rst) begin
			leds_2 <= 12'o0000;
			display24_2 <= 24'h9d908e;
		end
		else if (de10_2_sel & de10_2_we) begin
			case (de10_2_addr)
			3'o0:	display24_2[3:0] <= de10_2_wdata[3:0];
			3'o1:	display24_2[7:4] <= de10_2_wdata[3:0];
			3'o2:	display24_2[11:8] <= de10_2_wdata[3:0];
			3'o3:	display24_2[15:12] <= de10_2_wdata[3:0];
			3'o4:	display24_2[19:16] <= de10_2_wdata[3:0];
			3'o5:	display24_2[23:20] <= de10_2_wdata[3:0];
			3'o7:	leds_2 <= de10_2_wdata[11:0];
			default: ;
			endcase
		end
	end

	wire ok = 1'b1;
	//use KEY[1] to select between core 0 and core 1
	SEG7_LUT lut0((~KEY[1]?display24_2[3:0]:display24[3:0]), 	 ok, HEX0[6:0]);	// ss
	SEG7_LUT lut1((~KEY[1]?display24_2[7:4]:display24[7:4]),   	 ok, HEX1[6:0]);
	SEG7_LUT lut2((~KEY[1]?display24_2[11:8]:display24[11:8]), 	 ok, HEX2[6:0]);	// mm
	SEG7_LUT lut3((~KEY[1]?display24_2[15:12]:display24[15:12]), ok, HEX3[6:0]);
	SEG7_LUT lut4((~KEY[1]?display24_2[19:16]:display24[19:16]), ok, HEX4[6:0]);	// hh
	SEG7_LUT lut5((~KEY[1]?display24_2[23:20]:display24[23:20]), ok, HEX5[6:0]);
	assign LEDR[9:0] = (~KEY[1])?leds[9:0]:leds_2[9:0];

	// assign HEX0[7] = ~gps_A;
	assign HEX0[7] = 1'b1;
	assign HEX1[7] = 1'b1;
	assign HEX2[7] = 1'b1;
	assign HEX3[7] = 1'b1;
	assign HEX4[7] = 1'b1;
	assign HEX5[7] = 1'b1;

	assign switch_reg = { KEY, SW };

endmodule

// https://www.dcode.fr/7-segment-display
module SEG7_LUT	(
	input	[3:0]		hex_in,
	input				en,		// enable
	output	reg [6:0]	seg_out
);
	always @(*) begin
		if (en) case(hex_in)	//  GFEDCBA
		4'h0: seg_out = 7'b1000000;	// 0
		4'h1: seg_out = 7'b1111001;	// 1	//	-- A --
		4'h2: seg_out = 7'b0100100;	// 2	//	|	  |
		4'h3: seg_out = 7'b0110000;	// 3	//	F	  B
		4'h4: seg_out = 7'b0011001;	// 4	//	|	  |
		4'h5: seg_out = 7'b0010010;	// 5	//	-- G --
		4'h6: seg_out = 7'b0000010;	// 6	//	|	  |
		4'h7: seg_out = 7'b1111000;	// 7	//	E	  C
		4'h8: seg_out = 7'b0000000;	// 8	//	|	  |
		4'h9: seg_out = 7'b0011000;	// 9	//	-- D --
		4'ha: seg_out = 7'b0001000;	// A
		4'hb: seg_out = 7'b0111111;	// -
		4'hc: seg_out = 7'b0001100;	// P
		4'hd: seg_out = 7'b0100001;	// D
		4'he: seg_out = 7'b0000110;	// E
		4'hf: seg_out = 7'b1111111;	// ' '
		endcase
		else seg_out  = 7'b1111111;	// disable
	end
endmodule
