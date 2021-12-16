
`include "pdp8.h"

`define UART_8BIT 1


//=============================================================================
//		Teletype Module
//=============================================================================
module teletype #(
		parameter RX_ADDR=`DEV_TTY_RX,
		parameter TX_ADDR=`DEV_TTY_TX,
		parameter RX_IE=1'b1
	)(
	input				clk,
	input				rst,
	input [15:0] 		div_factor,		// for baud rate
	
	// IO Bus
	input wire [5:0]	io_dev,
	input wire [2:0]	io_op,
	input wire			io_req,
	input wire [11:0]	io_wdata,
	input				io_caf,		// clear AC, LINK, and all flags
	
	output wire [11:0]	tty_rdata,
	output wire			tty_sac,	// set AC from IO device
	output wire			tty_skip,
	output wire			tty_ack,
	output wire			tty_irq,	// interrupt request
	
	// UART
	input 				tty_rx,
	output wire			tty_tx
);


	// assign tty_irq = (keyboard_ie&(printer_flag |keyboard_flag));
	assign tty_irq = (keyboard_ie&(printer_irq | keyboard_irq));


	//=====================================================
	// TTY - Keyboard
	//	KCF	6030	Clear the keyboard flag without operating the device
	//	KSF	6031	Skip the next instruction when the keyboard buffer register is loaded with
	//					an ASCII symbol (causing the keyboard flag to be raised)
	//	KCC	6032	Clear the AC, clear the keyboard flag
	//	KRS	6034	Transfer the contents of the keyboard buffer into the AC
	//	KIE 6035	Set/Clear Interrupt Enable
	//	KRB	6036	Transfer the contents of the keyboard buffer into the AC, clear the keyboard flag
/*
	wire keyboard_sel = io_req & (io_dev == RX_ADDR);
	reg keyboard_flag;
	reg keyboard_ie;	// interrupt enable
	reg last_rx_rdy;
	reg keyboard_irq;
	always @(posedge clk) begin
		if (rst) begin
			keyboard_flag <= 0;
			keyboard_ie <= 1;		//rest to enabled ?
			last_rx_rdy <= 0;
			keyboard_irq <= 0;
		end
		else begin
			if (io_caf) begin
				keyboard_flag <= 0;
				keyboard_ie <= 1;		// enable interrupts
				keyboard_irq <= 0;
			end
			else if (keyboard_sel) begin
				case (io_op)
				//	KCF	6030	Clear the keyboard flag without operating the device
				3'b000: begin
					keyboard_irq <= 0;
				end
				//	KSF	6031	Skip the next instruction when the keyboard buffer register is loaded with
				//					an ASCII symbol (causing the keyboard flag to be raised)
				3'b001: begin
					keyboard_flag <= 0;
					last_rx_rdy <= 0;
					keyboard_irq <= 0;
				end
				//	KIE 6035	Set/Clear Interrupt Enable
				3'b101: begin
					keyboard_ie <= io_wdata[0];
				end
				//	KRB	6036	Transfer the contents of the keyboard buffer into the AC, clear the keyboard flag
				3'b110: begin
					keyboard_flag <= 0;
					keyboard_irq <= 0;
				end
				default:	;
				endcase
			end
			
			// look for rising edge of RX ready
			if (~last_rx_rdy & rx_rdy) begin
				keyboard_flag <= 1;
				keyboard_irq <= 1;
			end
			last_rx_rdy <= rx_rdy;
		end
	end
	
	
	wire keyboard_skip = (keyboard_sel&(io_op == 3'b001))?keyboard_flag:1'b0;
`ifdef UART_8BIT
	wire [11:0] keyboard_out = { 4'h0, rx_data };
`else
	wire [11:0] keyboard_out = { 4'h0, 1'b1, rx_data[6:0] };
`endif
	wire keyboard_sac = keyboard_sel&(io_op[2]&~io_op[0]);	// set AC to new value
*/

	wire keyboard_sel = io_req & (io_dev == RX_ADDR);
	// wire keyboard_skip = (keyboard_sel&(io_op == 3'b001))?keyboard_flag:1'b0;
	reg keyboard_ie;		// interrupt enable
	wire keyboard_ack = keyboard_sel;
	reg keyboard_sac;
	reg keyboard_skip;
	reg keyboard_clr;
	reg keyboard_flag;
	reg keyboard_read;
	always @(*) begin
		keyboard_clr = 0;
		keyboard_read = 0;
		keyboard_sac = 0;
		keyboard_skip = 0;

		if (keyboard_sel) begin
			case (io_op)
				//	KCF	6030	Clear the keyboard flag without operating the device
				3'b000: begin
					keyboard_clr = 1;
				end
				
				//	KSF	6031	Skip the next instruction when the keyboard buffer register is loaded with
				//					an ASCII symbol (causing the keyboard flag to be raised)
				3'b001: begin
					keyboard_skip = keyboard_flag;
				end

				// KCC 6032		Clear Keyboard Flag, Clear AC
				3'b010: begin
					keyboard_sac = 1;
					keyboard_clr = 1;
				end

				// KRS 6034		Read Keyboard Buffer Status
				3'b100: begin
					keyboard_sac = 1;
					keyboard_read = 1;
				end

				//	KIE 6035	Set/Clear Interrupt Enable
				3'b101: begin
					;
				end

				//	KRB	6036	Transfer the contents of the keyboard buffer into the AC, clear the keyboard flag
				3'b110: begin
					keyboard_read = 1;
					keyboard_sac = 1;
					keyboard_clr = 1;
				end

				//  IOT 6xx3 and 6xx7:
				default: begin
					;
				end
			endcase
		end
	end
		
	wire keyboard_irq = keyboard_flag & keyboard_ie;
`ifdef UART_8BIT
	wire [11:0] keyboard_out = (io_op==3'b010)?12'o0000:{ 4'h0, rx_data };
`else
	wire [11:0] keyboard_out = (io_op==3'b010)?12'o0000:{ 4'h0, 1'b1, rx_data[6:0] };
`endif



	// Keyboard Interrupt Enable Flip-Flop
	// The CAF instruction should enable interupts
	wire keyboard_done = ~last_rx_rdy & rx_rdy;
	reg last_rx_rdy;
	always @(posedge clk) begin
		if (rst) begin
			keyboard_ie <= RX_IE;	// set for TTY
			// keyboard_ie <= 1'b1;	// set for TTY
			keyboard_flag <= 0;
		end
		else begin
			if (keyboard_sel) begin
				//	KIE 6035	Set/Clear Interrupt Enable
				if (io_op == 3'b101) keyboard_ie <= io_wdata[0];
			end

			if (io_caf) begin
				keyboard_ie <= RX_IE;
			end
			if (io_caf | keyboard_clr) begin
				keyboard_flag <= 0;
			end
/*
			if (io_caf | keyboard_clr) begin
				keyboard_ie <= 1'b1;
				keyboard_flag <= 0;
			end
*/
			else if (keyboard_done) begin
				keyboard_flag <= 1;
			end
		end
		last_rx_rdy <= rx_rdy;
	end




	//=====================================================
	// TTY - Printer
	//	TFL	6040	Set printer flag, PDP-8/E
	//	TSF	6041	Skip the next instruction if the printer flag is set to 1
	//	TCF	6042	Clear the printer flag
	//	TPC	6044	Load the printer register with the contents of the AC, select and
	//					print the character. (The flag is raised when the action is completed)
	//	TSK	6045	Skip the next sequential instruction if either the printer interrupt
	//				request flag or the keyboard interrupt request flag is set, PDP-8/E
	//	TLS	6046	Clear the printer flag, transfer the contents of the AC, select and
	//					print the character. (The flag is raised when the action is completed)
/*
	wire printer_sel = io_req & (io_dev == TX_ADDR);
	reg printer_flag;
	reg printer_irq;
	reg last_tx_rdy;
	always @(posedge clk) begin
		if (rst) begin
			printer_flag <= 1;		// reset to ready to print
			last_tx_rdy <= 1;
			printer_irq <= 0;
		end
		else begin
			if (io_caf) begin
				printer_flag <= 0;
				printer_irq <= 0;
			end
			else if (printer_sel) begin
				if (io_op == 3'b000) printer_flag <= 1;
				if (io_op == 3'b001) begin
					printer_irq <= 0;
				end
				if (io_op[1]) begin
					printer_flag <= 0;
					printer_irq <= 0;
				end
				if (io_op[2]) begin
					$display("Print: %04o, '%c'", io_wdata, io_wdata[6:0]);
				end
			end
			if (~last_tx_rdy & tx_rdy) begin
				printer_flag <= 1;	// maybe rising edge?
				printer_irq <= 1;
				printer_done <= 1;
			end
			else printer_done <= 1;
			
			last_tx_rdy <= tx_rdy;
		end
	end
	wire printer_skip = (printer_sel&(io_op==1))?printer_flag:1'b0;
*/
	
	
	wire printer_sel = io_req & (io_dev == TX_ADDR);
	wire printer_done = ~last_tx_rdy & tx_rdy;	// single clk pulse
	reg printer_skip;		// skip next instruction
	reg printer_ack;		//	device acknowledge
	reg printer_flag;		// busy/done flag
	reg tx_write;			// write data to the uart
	reg last_tx_rdy;		// look for tx_rdy posedge
	reg printer_set;
	reg printer_clr;

	always @(*) begin 
		printer_set = 0;
		printer_clr = 0;
		printer_skip = 0;
		printer_ack = 0;
		tx_write = 0;

		if (printer_sel) begin
			printer_ack = 1;
			case (io_op)
				// 	IOT 6xx0: TFL - Teleprinter Flag Set
				3'b000: begin
					printer_set = 1;
				end
				
				//	IOT 6xx1: TSF - Teleprinter Skip if Flag
				3'b001: begin
					printer_skip = printer_flag;
				end
				
				//	IOT 6xx2: TCF - Teleprinter Clear Flag
				3'b010: begin
					printer_clr = 1;
				end
				
				//	IOT 6xx4: TPC - Teleprinter Print Character
				3'b100: begin
					tx_write = 1;
				end
				
				//	IOT 6xx5: TSK: Teleprinter Skip
				3'b101: begin
					// printer_skip = keyboard_ie;
					printer_skip = printer_irq | keyboard_irq;
				end
				
				//	IOT 6xx6: TLS: Teleprinter Load and Clear Flag, Flag Set when Done
				3'b110: begin
					printer_clr = 1;
					tx_write = 1;
				end

				default: begin
					printer_ack = 0;
				end
			endcase
		end
	end
	wire printer_irq = printer_flag & keyboard_ie;


	// JK Flip Flop style logic for printer flag latch
	always @(posedge clk) begin
		if (rst) begin
			printer_flag  <= 0;
		end
		else begin
			if (printer_clr | io_caf) begin
				printer_flag <= 0;
			end
			else if (printer_set | printer_done) begin
				printer_flag <= 1;
			end
			
			last_tx_rdy <= tx_rdy;
		end
	end


	//=====================================================
	//	UART
	//=====================================================
	// Receiver input signal, error and status flags
	wire rx_rdy;			// Data ready to be read
	wire rx_read;			// Data read
	wire [7:0] rx_data;		// Recieve data
	wire rx_err;			// Data error (bad stop bit)

	// Transmit side
	wire tx_rdy;			// Data ready to be read
	// wire tx_write;			// Data write strobe
	wire [7:0] tx_data;		// Xmit data
	
`ifdef UART_8BIT
	assign tx_data = io_wdata[7:0];
`else
	assign tx_data = { 1'b0, io_wdata[6:0] };
`endif

	// assign tx_write = printer_sel&io_op[2];
	assign rx_read = keyboard_read;

	wire mclkx16;
	uart_baud1 baud_1(.clk(clk), .rst(rst), .div_factor(div_factor),
		.reload(1'b0), .mclkx16(mclkx16) );

	uart_rx rx_1 (.clk(clk), .rst(rst), .mclkx16(mclkx16),
		.rx_rdy(rx_rdy), .rx_read(rx_read), .rx_data(rx_data), .rx_err(rx_err), .rx(tty_rx));

	uart_tx tx_1 (.clk(clk), .rst(rst), .mclkx16(mclkx16),
		 .tx_rdy(tx_rdy), .tx_write(tx_write), .tx_data(tx_data), .tx(tty_tx) );
		 
		 
	assign tty_rdata = keyboard_sac?keyboard_out:12'o0000;		// wire OR bus
	assign tty_sac = keyboard_sac;
	assign tty_skip = keyboard_skip | printer_skip;
	assign tty_ack = keyboard_ack | printer_ack;

endmodule

