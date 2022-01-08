// DE10 Board

// Connect Serial Port, USB-UART
//	==========================================
//	GPIO #		JP1-#		Description
//	==========================================
//	GPIO 5		Pin 6		PIN_??	dtr signal
//	GPIO 7		Pin 8		PIN_W7	tx data
//	GPIO 9		Pin 10		PIN_V5	rx data
//	GND			Pin 12		GND		GND

// Connect GPS Port,
//	============================================
//	ARDUINO #			JP-?		Description
//	============================================
//	ARDUINO_IO[0]		Pin ?		Rx from GPS
//	ARDUINO_IO[1]		Pin ?		Tx to GPS
//	ARDUINO_IO[2]		Pin ?		PPS from GPS

// `define DUAL_CORE 	1
// `define BOOT_DISP24	24'hcDcb8E	// spell out "PDP-8E"

// `define COMMON_CATHODE
// HEX Display Constants, Common Anode
`define HEX_0	8'b00111111	// 0
`define HEX_1	8'b00000110	// 1	//	-- A --
`define HEX_2	8'b01011011	// 2	//	|	  |
`define HEX_3	8'b01001111	// 3	//	F	  B
`define HEX_4	8'b01100110	// 4	//	|	  |
`define HEX_5	8'b01101101	// 5	//	-- G --
`define HEX_6	8'b01111101	// 6	//	|	  |
`define HEX_7	8'b00000111	// 7	//	E	  C
`define HEX_8	8'b01111111	// 8	//	|	  |
`define HEX_9	8'b01100111	// 9	//	-- D --
`define HEX_A	8'b01110111	// A
`define HEX_B	8'b01111100	// B
`define HEX_C	8'b00111001	// C
`define HEX_D	8'b01011110	// D
`define HEX_E	8'b01111001	// E
`define HEX_F	8'b01110001	// F
`define HEX_DS	8'b01000000	// -
`define HEX_P	8'b01110011	// P
`define HEX_SP	8'b00000000	// ' '

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

	assign switch_reg = { KEY, SW };

	// ****************************************************
	// GPS Device
	// ****************************************************
	wire gps_rx;					// GPS receive data
	wire gps_tx;					// GPS transmit data
	assign ARDUINO_IO[1] = gps_tx;
	assign gps_rx = ARDUINO_IO[0];

	// Serial Port
	wire tty_rx;					// UART receive data
	wire tty_tx;					// UART transmit data
	assign GPIO[7] = tty_tx;
	assign tty_rx = GPIO[9];

	// Switch Register/Status Leds
	wire [11:0]	switch_reg;			// Switch register
	wire [11:0]	status;				// Status output
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
	reg [7:0] display24 [0:5];
	always @(posedge clk) begin
		if (rst) begin
			display24[5] <= `HEX_P;
			display24[4] <= `HEX_D;
			display24[3] <= `HEX_P;
			display24[2] <= `HEX_DS;
			display24[1] <= `HEX_8;
			display24[0] <= `HEX_E;
			leds <= 12'o0000;
		end
		else if (de10_sel & de10_we) begin
			case (de10_addr)
			3'o0:	display24[0] <= de10_wdata[7:0];
			3'o1:	display24[1] <= de10_wdata[7:0];
			3'o2:	display24[2] <= de10_wdata[7:0];
			3'o3:	display24[3] <= de10_wdata[7:0];
			3'o4:	display24[4] <= de10_wdata[7:0];
			3'o5:	display24[5] <= de10_wdata[7:0];
			3'o7:	leds <= de10_wdata[11:0];
			default: ;
			endcase
		end
	end

	// HEXx are Common Cathode, need to be inverted
	assign HEX0 = ~display24[0];	// ss
	assign HEX1 = ~display24[1];
	assign HEX2 = ~display24[2];	// mm
	assign HEX3 = ~display24[3];
	assign HEX4 = ~display24[4];	// hh
	assign HEX5 = ~display24[5];
	assign LEDR[7:0] = leds[7:0];
	assign LEDR[8] = ~tty_tx;
	assign LEDR[9] = ~tty_rx;

endmodule

// https://www.dcode.fr/7-segment-display
