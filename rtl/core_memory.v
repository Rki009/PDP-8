
`default_nettype none
`timescale 1ns/10ps


//  Memory Block Using M9K
//	nK x 12 memory 
module core_memory #(parameter KSIZE=32) (
	input				clk,
	input [11:0]		wdata,
	input [`MEM_AWIDTH-1:0]	raddr,
	input [`MEM_AWIDTH-1:0]	waddr,
	input	  			wren,
	output reg [11:0]	rdata
);

	localparam mem_size = (KSIZE*1024);
    localparam mem_bits = $clog2(mem_size);
	
	initial begin
		$display("Mem Size: %0d", mem_size);
		$display("Mem Bits: %0d [%0d:0]", mem_bits, `MEM_AWIDTH-1);
	end
	
	// nk x 12 bits
	reg [11:0] mem[0:mem_size-1] /* ramstyle = "M9K" */ ;
	
`ifdef IVERILOG
	initial begin
		$readmemh("../FOCAL/Focal569.mem", mem);
	end
`endif

`ifdef QUARTUS
	initial begin
		$readmemh("../src/GPSClock/gps_clock.mem", mem);
	end
`endif
	
	always @(posedge clk) begin
		if (wren) begin
			mem[waddr] <= wdata;
		end
		rdata = mem[raddr];
	end

endmodule

