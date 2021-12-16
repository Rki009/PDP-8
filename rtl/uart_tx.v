// uart.v - Simple 8bit, no parity, 1 stop bit
module uart_tx (
	input clk,					// 50MHz
	input rst,					// Master reset input
	input mclkx16,				// 16x baud clock

	// Transmit side
	output wire tx_rdy,			// Data ready to be read
	input tx_write,				// Data write strobe
	input [7:0] tx_data,		// Xmit data
	output tx
);


	//**************
	// Transmit Part
	//**************
	reg tx_busy;
	reg tx_start;
	reg [7:0] tx_cnt;		// bit counter x16
	reg [7:0] tx_hold;		// data to send
	reg [9:0] tx_shift;		// 10 bit shift register
	always @(posedge clk) begin
		if (rst) begin
			tx_cnt <= 8'h80;		// add a mark before starting
			tx_busy <= 1;
			tx_shift <= 10'h3ff;	// all mark
			tx_start <= 0;
		end
		else begin
			if (tx_write) begin
				tx_hold <= tx_data;		// save the data
				tx_start <= 1;			// ready for xmit
			end
			if (mclkx16) begin
				if (tx_start & ~tx_busy) begin
					tx_busy <= 1;
					tx_start <= 0;
					tx_shift <= { 1'b1, tx_hold, 1'b0 };
					tx_cnt <= 8'd0;
				end
				if (tx_busy) begin
					tx_cnt <= tx_cnt + 8'h01;
					if (tx_cnt >= 8'h9e) tx_busy <= 0;
					if (tx_cnt[3:0] == 4'hf) tx_shift <= { 1'b1, tx_shift[9:1] };
				end
			end
		end
	end
	
	assign tx = tx_shift[0];
	assign tx_rdy = ~tx_start;
	
endmodule