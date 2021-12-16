// 50MHz base clock:
// 		9600	= 325.52, -0.16% error
//		115200  = 27.12674, -0.47% error
//
//	Standard Baud Rates (bits/s), 50MHz 16x clock divider:
//		110			28409
//		300			10417
//		1,200		2604.2
//		9,600		325.52
//		19,200		162.76
//		38,400		81.38
//		115,200		27.13
//		256,000		12.21
//		1,000,000	3.125				
//		3,125,000	1.00
//
//	Use a 16 bit counter for the divider:
//		for a 50MHz source clock this covers 75 baud up to 2M baud
//
 
module uart_baud1 (
	input wire		clk,
	input wire		rst,
	input [15:0]	div_factor,		// divider factor
	input wire		reload,			// start new baudrate
	output wire		mclkx16			// 16x baud rate clock
);

	// divider - integer part
	reg [15:0]	div;	// clk divider
	wire [15:0] div_next = div - 16'd1;
	assign		mclkx16 = (~|div_next) & ~rst;
	
	always @(posedge clk) begin
		if (rst | reload | mclkx16) div <= div_factor;
		else div <= div_next;
	end
		
endmodule