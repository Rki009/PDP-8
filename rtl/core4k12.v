//  Memory Block Using M9K
//	4K x 12 memory 
module core4k12 (
	input	  clock,
	input	[11:0]  data,
	input	[11:0]  rdaddress,
	input	[11:0]  wraddress,
	input	  wren,
	output reg [11:0]  q
);

	
	// 4k x 12 bits
	reg [11:0] mem[0:4095] /* ramstyle = "M9K" */ ;
	
`ifdef IVERILOG
	initial begin
		$readmemh("../FOCAL/Focal569.mem", mem);
	end
`endif

`ifdef QUARTUS
	initial begin
		// $readmemh("core.mif", mem);
		// $readmemh("../FOCAL/Focal569.mem", mem);
		
		$readmemh("../src/GPSClock/gps_clock.mem", mem);
	end
`endif
	
	always @(posedge clock) begin
		if (wren) begin
			mem[wraddress] <= data;
		end
		q = mem[rdaddress];
	end

endmodule

