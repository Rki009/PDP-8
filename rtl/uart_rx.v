// uart.v - Simple 8bit, no parity, 1 stop bit
module uart_rx (
	input clk,					// 50MHz
	input rst,					// Master reset input
	input mclkx16,				// 16x baud clock

	// Receiver input signal, error and status flags
	output reg rx_rdy,			// Data ready to be read
	input  rx_read,				// Data read
	output reg [7:0] rx_data,	// Recieve data
	output reg rx_err,			// Data error (bad stop bit)
	input rx					// Receive  data line input
);
	//**************
	// Receiver Part
	//**************
	
	// sync to start bit
	wire tick;
	always @(posedge clk) begin
		if (mclkx16) begin
			bclk <= { bclk[14:0], rx };
		end
	end
	assign tick = (bclk == 16'hff00);	
	
	// colect next 8 bits
	reg [15:0] bclk = 16'd0;
	reg [7:0] cnt;		// state clock 16xn bits
	reg start;
	reg [7:0] shr;
	always @(posedge clk) begin
		if (rst) begin
			cnt <= 8'h00;
			start <= 0;
			rx_rdy <= 0;
			rx_err <= 0;
			rx_data <= 8'h00;
		end
		else if (mclkx16) begin
			if (~start) begin
				if (tick) begin
					start <= 1;	// colect data bits
				end
				cnt <= 8'h01;
				shr <= 8'h00;
			end
			else begin	// running
				cnt <= cnt + 8'h01;
				if(cnt[3:0] == 4'h0) begin
					if (cnt[7:4] < 4'h9) begin
						shr <= { rx, shr[7:1] };
					end
					else begin
						rx_err <= ~rx;	// error is invalid stop bit
						rx_data <= shr;
						rx_rdy <= 1;
						start <= 0;
					end
				end
			end
		end
		if (rx_read) begin
			rx_rdy <= 0;
			rx_err <= 0;
		end
	end
	
endmodule