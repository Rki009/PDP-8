// PDP-8/E	- PDP-8/E, 12 bit processor, (C) Ron K. Irvine
//
//	Notes:
//		Variant: PDP-8/E, 1970, Cost: PDP-8/E - $6,500 
//
//
//	BIN Loader at location 7626 and the RIM Loader at 7756
//


`include "pdp8.h"

//=====================================================
//	pdp8 - pdp8 top level
//=====================================================
module pdp8(
	input			clk,
	input			rst,
	input [11:0]	switch_reg,		// Switch register
	output wire [11:0]	status,		// Status output
	
	// UART
	input 			tty_rx,			// Receive  data line input
	output wire 	tty_tx,
	// GPS
	input 			gps_rx,			// Receive  data line input
	output wire 	gps_tx,
	
	// DE10
	output wire de10_sel,
	output wire [2:0] de10_addr,
	output wire de10_we,
	output wire [11:0] de10_wdata,
	input [11:0] de10_rdata

);

	// IO Bus
	wire [5:0]	io_dev;
	wire [2:0]	io_op;
	wire [11:0] io_wdata;		// write data to device
	wire [11:0] io_rdata;		// read data from the device
	wire		io_req;
	wire		io_ack;
	wire		io_skip;
	reg			io_caf;			// clear AC, LINK, and all flags
	wire		io_sac;			// set AC from IO device
	wire		io_slk;			// set LINK from IO device
	wire		cpu_iret;		// Interrupt return
	wire		cpu_link;		// LINK register from the core
	reg			cpu_ion;		// interrupts enabled
	wire		cpu_irq;		// interrupt request
	wire		cpu_iack;		// interrupt acknowledge


	pdp8_core core (.clk(clk), .rst(rst),
		.io_dev(io_dev), .io_op(io_op), .io_wdata(io_wdata), .io_rdata(io_rdata), 
		.io_req(io_req), .io_ack(io_ack), .io_skip(io_skip),
		.io_caf(io_caf), .io_sac(io_sac), .io_slk(io_slk),
		.cpu_ion(cpu_ion), .cpu_irq(cpu_irq), .cpu_iack(cpu_iack),
		.cpu_link(cpu_link), .cpu_iret(cpu_iret),
		.switch_reg(switch_reg), .status(status) );
		
		
	//=====================================================
	// CPU Control
	//	SKON     6000  skip if interrupt ON, and turn interrupts OFF
	//	ION      6001  turn interrupt ON
	//	IOF      6002  turn interrupt OFF, AFTER next instruction
	//	SRQ      6003  skip interrupt request
	//	GTF      6004  get interrupt flags
	//	RTF      6005  restore interrupt flags
	//	SGT      6006  skip on Greater Than flag, if KE8-E Extended Arithmetic Element is installed
	//	CAF      6007  clear all flags
	wire cpu_sel = io_req & (io_dev == `DEV_CPU);
	reg ion_delay;		// delay ION by one instruction
	wire tty_irq;
	wire gps_irq;
	wire irq_request = tty_irq | gps_irq;
	// reg cpu_rtf;		// restore flags
	assign cpu_irq = cpu_ion & irq_request;
	always @(posedge clk) begin
		// ION Queued? May be overwritten by IOF command
		if (ion_delay) begin
			cpu_ion <= 1;
			ion_delay <= 0;
		end

		if (rst) begin
			cpu_ion <= 0;
			ion_delay <= 0;
		end
		else if(io_caf) begin
			cpu_ion <= 0;
			ion_delay <= 0;
		end
		else if (cpu_sel) case (io_op)
		3'o0:	cpu_ion <= 0;		// SKON
		3'o1:	begin
			if (cpu_ion == 0) ion_delay <= 1;		// ION
		end
		3'o2:	begin
			cpu_ion <= 0;			// IOF
			ion_delay <= 0;
		end
		
		3'o5:	begin				// RTF
			// cpu_rtf <= io_wdata[7];	// delay until next JMP/JMS
			// ion_delay <= io_wdata[7];	// Restore Interrupt Enable
			ion_delay <= 1;	// Restore Interrupt Enable ???
		end
		default: ;
		endcase

		if (cpu_iack) begin			// Interrupt Acknowledge
			cpu_ion <= 0;
		end


		if (cpu_iret) begin			// RFT, delayed until IRET
			cpu_ion <= 1;			// interrupts back on
		end
	end

	reg cpu_skip;
	reg [11:0] cpu_gtf;
	reg cpu_sac;		// set AC to new value
	reg cpu_slk;		// set link
	always @(*) begin
		cpu_skip = 0;
		cpu_gtf = 12'o0000;
		cpu_sac = 0;
		cpu_slk = 0;
		io_caf = 0;
		if (cpu_sel) case (io_op)
		3'o0:	cpu_skip = cpu_ion;
		3'o3:	cpu_skip = irq_request;
		3'o4:	begin
			cpu_gtf = {cpu_link, 1'b0, irq_request, 1'b0, (cpu_ion|ion_delay), 7'b0000000 };
			cpu_sac = 1;
		end
		3'o5:	begin				// RTF
			cpu_gtf = io_wdata;
			cpu_slk = 1;
		end
		3'o7:	io_caf = 1;
		default: ;
		endcase
	end

	
	//=====================================================
	// DE10 Interface
	//=====================================================
	assign de10_sel = io_req & (io_dev == `DEV_DE10);
	wire de10_read = (io_op==3'O6);
	wire de10_sac = (de10_sel & de10_read);
	// always @(posedge clk) begin
	// 	if (de10_sel) begin
	//		if (io_op == 3'o6) begin
	//			$display("LED: %04o", io_wdata);
	//			leds <= io_wdata;
	//		end
	//	end
	// end
	assign de10_we = (de10_sel & ~de10_read);
	assign de10_addr = io_op[2:0];
	assign de10_wdata = io_wdata;


	//=====================================================
	// TeleType UART - ASR 33
	//=====================================================
	wire [11:0]	tty_rdata;
	wire		tty_sac;	// set AC from IO device
	wire		tty_skip;
	wire		tty_ack;
	teletype tty (
		.clk(clk), .rst(rst), .div_factor(`BAUD_115200),
		.io_dev(io_dev), .io_op(io_op), .io_req(io_req), .io_wdata(io_wdata), .io_caf(io_caf),
		.tty_rdata(tty_rdata), .tty_sac(tty_sac), .tty_ack(tty_ack), .tty_irq(tty_irq), .tty_skip(tty_skip),
		.tty_rx(tty_rx), .tty_tx(tty_tx) );


	//=====================================================
	// GPS UART
	//=====================================================
	wire [11:0]	gps_rdata;
	wire		gps_sac;	// set AC from IO device
	wire		gps_skip;
	wire		gps_ack;
	teletype #(.RX_ADDR(`DEV_GPS_RX), .TX_ADDR(`DEV_GPS_TX), .RX_IE(1'b0)) gps (
		.clk(clk), .rst(rst), .div_factor(`BAUD_9600),
		.io_dev(io_dev), .io_op(io_op), .io_req(io_req), .io_wdata(io_wdata), .io_caf(io_caf),
		.tty_rdata(gps_rdata), .tty_sac(gps_sac), .tty_ack(gps_ack), .tty_irq(gps_irq), .tty_skip(gps_skip),
		.tty_rx(gps_rx), .tty_tx(gps_tx) );
	
	assign io_rdata = (cpu_gtf | de10_rdata | tty_rdata | gps_rdata);		// wire OR bus
	assign io_sac = (cpu_sac | de10_sac | tty_sac | gps_sac);
	assign io_slk = (cpu_slk);
	assign io_skip = (cpu_skip | tty_skip | gps_skip);
	assign io_ack = (cpu_sel | de10_sel | tty_ack | gps_ack);
endmodule


//=====================================================
//	pdp8_core - pdp8 CPU Core
//=====================================================
module pdp8_core(
	input				clk,
	input				rst,
	
	// IO Bus
	output wire [5:0]	io_dev,
	output wire [2:0]	io_op,
	output wire [11:0]	io_wdata,
	input [11:0] 		io_rdata,
	output wire			io_req,
	input				io_ack,
	input				io_skip,
	input				io_caf,		// clear AC, LINK, and all flags
	input				io_sac,		// set AC from IO device
	input				io_slk,		// set LINK from IO device
	input				cpu_ion,	// interrupts enabled
	input				cpu_irq,	// interrupt request
	output reg			cpu_iack,	// interrupt acknowledge
	output reg			cpu_iret,	// Interrupt acknowledge
	output wire			cpu_link,	// LINK register from the core

	// Switch Register/Status Leds
	input [11:0]		switch_reg,	// Switch register
	output wire [11:0]	status		// Status output
);

	// memory access types
	parameter mop_idle 	= 0;		// idle
	parameter mop_fetch = 1;		// instruction read
	parameter mop_read	= 2;		// data read
	parameter mop_write = 3;		// data wite
	parameter mop_jms 	= 4;		// write return address

	
	assign status = {op_opr, op_iot, op_jmp|op_jms, op_dca|op_isz|op_tad|op_and, state[7:0]};

	wire [11:0] insn = (state==`STATE_EXECUTE)?mem_dout:insn_last;
	reg [11:0] insn_last;
	wire [2:0] op_code = insn[11:9]; 
	wire op_mtype =  ~insn[11];
	wire op_jtype =  (insn[11:10] == 2'b10);
	wire op_i = insn[8] & (op_mtype|op_jtype); 
	wire op_z = insn[7] & (op_mtype|op_jtype);
	wire op_autoinc = insn[8] & ~insn[7] & (insn[6:3] == 4'b0001) & (op_mtype|op_jtype);
	wire [6:0] op_offset = insn[6:0];

	// Main Registers
	reg [11:0]	pc;		// PC - Program Counter
	reg [11:0]	ac;		// AC - Accumulator
	reg [11:0]	mq;		// MQ - Multiplier/Quotient register
	reg	link;			// LINK - Link register
	
	// update at the end of the cycle
	reg [11:0] next_ac;
	reg next_link;
	reg [11:0] next_mq;
	
	// Program Counter updates
	wire [11:0] pc_rst = `START_ADDR;	// pc reset value
	wire [11:0] pc_inc = (rst)?pc_rst:pc + 12'd1;
	reg [11:0] pc_next;

	// Opcodes - 8 basic opcode types
	wire op_and = (op_code==`OP_AND);
	wire op_tad = (op_code==`OP_TAD);
	wire op_isz = (op_code==`OP_ISZ);
	wire op_dca = (op_code==`OP_DCA);
	wire op_jms = (op_code==`OP_JMS);
	wire op_jmp = (op_code==`OP_JMP);
	wire op_iot = (op_code==`OP_IOT);
	wire op_opr = (op_code==`OP_OPR);

	// Next pc processing
	reg do_skip;
	always @(posedge clk) begin
		if (rst) begin
			pc <= pc_rst;
			do_skip <= 0;
		end
		else begin
			pc <= pc_next;
			if (state==`STATE_EXECUTE) insn_last <= mem_dout;
			do_skip <= skip;
			if (state==`STATE_EXECUTE) begin
`ifdef iverilog
				$display("%04o: %04o, %1o:%04o", pc, insn, link, ac);
`endif
			end
		end
	end
	
	
	// wire [2:0] 	mem_field = 0;
	reg [11:0]	mem_raddr;
	reg [11:0]	mem_waddr;
	reg 		mem_read;
	reg 		mem_write;
	reg [11:0]	mem_din;
	wire [11:0] mem_dout;
	reg [2:0]	mem_read_mux;
	reg [2:0]	mem_write_mux;
	
	// memory read/write access mux
	always @(*) begin
		mem_read = 0;
		mem_write = 0;
		mem_raddr = 12'o0000;
		mem_waddr = 12'o0000;

		case(mem_read_mux)
		mop_idle: begin
		end
		mop_fetch: begin
			mem_raddr = pc_next;
			mem_read = 1;
		end
		mop_read: begin
			mem_raddr = data_raddr;
			mem_read = 1;
		end
		default: ;
		endcase

		case(mem_write_mux)
		mop_write: begin
			mem_waddr = data_waddr;
			mem_write = 1;
		end
		mop_jms: begin
			mem_waddr = data_waddr;
			mem_write = 1;
		end
		default: ;
		endcase
	end
	
	core_memory memory_1 (.clk(clk), .rst(rst),
		.raddr(mem_raddr), .waddr(mem_waddr), .read(mem_read), .write(mem_write),
		.din(mem_din), .dout(mem_dout) );

	// processor state machine
	reg [9:0] state;
	reg [9:0] next_state;

	always @(posedge clk) begin
		state <= `STATE_HALT;
		if (rst) begin
			state <= `STATE_IDLE;
			ac <= 12'o0000;
			link <= 0;
			mq <= 12'o0000;
		end
		else begin
			state <= next_state;
			if (io_caf) begin
				ac <= 12'o0000;
				link <= 0;
			end
			else begin
				ac <= next_ac;
				link <= next_link;
			end
			mq <= next_mq;
		end
	end
	assign cpu_link = link;
	
	reg [11:0] data_raddr;
	reg [11:0] data_raddr1;	// save for a cycle
	reg [11:0] data_waddr;
	always @(posedge clk) begin
		data_raddr1 <= data_raddr;
	end
	

	//-----------------------------------------------------
	// skip condition
	//-----------------------------------------------------
	wire sma = ac[11];
	wire sza = (ac == 12'o0000);
	wire snl = link;
	reg skip;

	//-----------------------------------------------------
	// Instruction Execution Cycles ...
	//-----------------------------------------------------
	reg carry;
	reg [11:0] temp;
	// reg [11:0] dca_addr;
	// always @(posedge clk) begin
	//	dca_addr <= temp;
	// end


	// IO Bus Connections
	assign io_dev = insn[8:3];
	assign io_op = insn[2:0];
	assign io_req = (insn[11:9]==6)&(state==`STATE_EXECUTE);
	assign io_wdata = (io_req)?ac:12'o0000;

	always @(*) begin
		pc_next = pc;
		
		data_raddr = 12'o0000;
		data_waddr = 12'o0000;
		mem_din = 12'o0000;
		mem_read_mux = mop_idle;
		mem_write_mux = mop_idle;
		next_state = `STATE_IDLE;

		next_ac = ac;
		next_link = link;
		next_mq = mq;
		skip = 0;
		carry = 1'b0;
		temp = 12'o0000;

		// IO Bus Defaults
		// io_wdata = 12'o0000;
		// io_req = 0;
		
		// CPU States
		cpu_iret = 0;
		cpu_iack = 0;
		
		case (state)
			`STATE_IDLE: begin
				next_state = `STATE_FETCH;
			end
			
			`STATE_FETCH: begin
				next_state = `STATE_EXECUTE;
				mem_read_mux = mop_fetch;
			end
			
			`STATE_INTERRUPT: begin
				next_state = `STATE_EXECUTE;
				mem_read_mux = mop_fetch;
			end

			`STATE_EXECUTE: begin
				// address: 0 = page zero, 1 = current page
				if (op_z) begin	// 1 = current page
					data_raddr = { pc[11:7], op_offset };
				end
				else begin	// 0 = page zero
					data_raddr = { 5'h00, op_offset };
				end

				// Interrupt processing
				if (cpu_ion & cpu_irq & ~do_skip) begin
					next_state = `STATE_INTERRUPT;
					pc_next = 12'o0001;
					mem_read_mux = mop_fetch;
					data_waddr = 12'o0000;
					mem_din = pc;
					mem_write_mux = mop_jms;
					cpu_iack = 1;
				end
				
				// SKIP processing
				else if (do_skip) begin
					next_state = `STATE_EXECUTE;
					pc_next = pc_inc;
					mem_read_mux = mop_fetch;
				end
				
				// Instruction processing
				else begin
					case(op_code)
					`OP_AND, `OP_TAD, `OP_ISZ, `OP_DCA: begin
						if(op_i) begin
							if (op_autoinc) next_state = `STATE_AUTOINC;
							else next_state = `STATE_INDIRECT;
							mem_read_mux = mop_read;
						end
						else begin
							if (op_code == `OP_DCA) begin
								data_waddr = data_raddr;
								mem_din = ac;
								mem_write_mux = mop_write;
								next_state = `STATE_FETCH;
								pc_next = pc_inc;
								next_ac = 12'o0000;
							end
							else if (op_code == `OP_ISZ) begin
								mem_read_mux = mop_read;
								next_state = `STATE_EXECUTE2;
							end
							else begin
								mem_read_mux = mop_read;
								next_state = `STATE_EXECUTE2;
							end
						end
					end					

					`OP_JMS: begin
						if(op_i) begin
							if (op_autoinc) next_state = `STATE_AUTOINC;
							else next_state = `STATE_INDIRECT;
							mem_read_mux = mop_read;
						end
						else begin
							next_state = `STATE_JMS;
							pc_next = data_raddr;
							mem_read_mux = mop_fetch;
							data_waddr = data_raddr;
							mem_din = pc_inc;
							mem_write_mux = mop_jms;
						end
					end					
					`OP_JMP: begin
						if(op_i) begin
							if (op_autoinc) next_state = `STATE_AUTOINC;
							else next_state = `STATE_INDIRECT;
							mem_read_mux = mop_read;
						end
						else begin
							next_state = `STATE_FETCH;
							pc_next = data_raddr;
							mem_read_mux = mop_fetch;
						end
					end					


					`OP_IOT: begin		// IOT - 6000
						next_state = `STATE_EXECUTE;
						pc_next = pc_inc;
						mem_read_mux = mop_fetch;

						if (io_sac) next_ac = io_rdata;
						if (io_slk) next_link = io_rdata[11];
						skip = io_skip;
					end

					`OP_OPR: begin		// OPR - 7000
						next_state = `STATE_EXECUTE;
						pc_next = pc_inc;
						mem_read_mux = mop_fetch;

						// if (insn == 12'o7402) next_state = `STATE_HALT;
						if (~insn[8]) begin		// GROUP 1
							// 1 - CLA, CLL - Clear the AC, Clear the LINK
							if (insn[7]) next_ac = 12'o0000;
							if (insn[6]) next_link = 0;
							
							// 2 - CMA, CML - Complement the AC, Complement the LINK
							if (insn[5]) next_ac = ~next_ac;
							if (insn[4]) next_link = ~next_link;

							// 3 -IAC - Increment the AC
							if (insn[0]) {next_link, next_ac} = {next_link, next_ac} + 13'd1;

							// 4 - RAR, RAL, RTR, RTL, BSW - Rotate Left/Right, by one or two, or Swap AC
							case (insn[3:1])
							3'b001:	next_ac = {next_ac[5:0], next_ac[11:6]};						// BSW
							3'b010:	{next_link, next_ac} = {next_ac, next_link};					// RAL
							3'b011:	{next_link, next_ac} = {next_ac[10:0], next_link, next_ac[11]};	// RTL
							3'b100:	{next_link, next_ac} = {next_ac[0], next_link, next_ac[11:1]};	// RAR
							3'b101:	{next_link, next_ac} = {next_ac[1:0], next_link, next_ac[11:2]};// RTR
							default:{next_link, next_ac} = {next_link, next_ac};	// NOP
							endcase
						end
						if (insn[8] & ~insn[0]) begin	// GROUP 2
							// 1 - SMA/SZA/SNL, SPA/SNA/SZL
							skip = (sma&insn[6]) | (sza&insn[5]) | (snl&insn[4]);
							if (insn[3]) skip = ~skip;
							
							// 2 - CLA
							if (insn[7]) next_ac = 12'o0000;
							
							// 3 - OSR
							if (insn[2]) next_ac = next_ac | switch_reg;	// OSR
							// 4 - HLT
							if (insn[1]) begin
								next_state = `STATE_HALT;			// HLT
								// pc_next = pc;
							end
							
						end
						if (insn[8] & insn[0]) begin	// GROUP 3
							// CLA - Clear AC, AC <= 0
							if (insn[7]) next_ac = 12'o0000;

							// MQA - Multiplier Quotient with AC (logical or MQ into AC), AC <= MQ
							if (insn[6] & ~insn[4]) begin
								next_ac = mq | next_ac;		// Note: bitwise OR available to the programmer 
							end	

							// MQL - Multiplier Quotient Load (Transfer AC to MQ, clear AC), MQ <= AC; AC <= 0
							if (~insn[6] & insn[4]) begin
								// CAM - CLA + MQL clears both AC and MQ
								next_mq = next_ac;
								next_ac = 12'o0000;
							end
							
							// SWAP, AC <=> MQ
							if (insn[6] & insn[4]) begin
								next_mq = next_ac;
								next_ac = mq;
							end
							
							// SCA - Step counter load into AC
							// if (insn[5]) next_ac = ...

							// insn[3:1] = mul/div operation
							// **** IF UNIT IS INSTALLED ****
						end
					end
					endcase
				end

			end

			`STATE_AUTOINC: begin
				// page zero 0010..0017 are auto inc locations
				temp = mem_dout + 12'd1;
				data_raddr = temp;
				mem_read_mux = mop_idle;
				next_state = `STATE_INDIRECT;
				mem_write_mux = mop_write;
				data_waddr = { 5'h00, op_offset };
				mem_din = temp;
				// $display("AutoInc: %04o - %04o <=%04o", mem_dout, data_waddr, temp); 
			end

			`STATE_INDIRECT: begin
				mem_read_mux = mop_read;
				next_state = `STATE_EXECUTE2;
				if (op_autoinc) data_raddr = data_raddr1;
				else data_raddr = mem_dout;

				if (op_code == `OP_DCA) begin
					// next_state = `STATE_EXECUTE;
					next_state = `STATE_FETCH;
					pc_next = pc_inc;
					mem_read_mux = mop_fetch;

					data_waddr = data_raddr;
					mem_din = ac;
					mem_write_mux = mop_write;
					// Clear the AC
					next_ac = 12'o0000;
				end
				if (op_code == `OP_JMP) begin
					next_state = `STATE_FETCH;
					pc_next = data_raddr;
					mem_read_mux = mop_fetch;
				end
				if (op_code == `OP_JMS) begin
					next_state = `STATE_JMS;
					pc_next = data_raddr;
					mem_read_mux = mop_fetch;
					data_waddr = data_raddr;
					mem_din = pc_inc;
					mem_write_mux = mop_jms;
				end
			end

			`STATE_EXECUTE2: begin
				next_state = `STATE_EXECUTE;
				pc_next = pc_inc;
				mem_read_mux = mop_fetch;

				case(op_code)

					`OP_AND: begin
						// bitwise AND the Memory with the AC
						next_ac = ac & mem_dout;
					end
					`OP_TAD: begin
						// Add the Memory to the AC
						// Complement the LINK if there is a carry out
						{carry, next_ac} = ac + mem_dout;
						next_link = carry?~link:link;
					end

					`OP_ISZ: begin
						// increment Memory by 1 and skip if zero
						// AC is not affected
						temp = mem_dout + 12'd1;
						data_waddr = data_raddr1;						
						mem_din = temp;
						mem_write_mux = mop_write;
						skip = (temp == 12'o0000);
					end

					default: ;
				endcase
			end

			// Write Back the Auto Inc value
			`STATE_WRITEBACK: begin
				next_state = `STATE_EXECUTE2;
			end
			
			`STATE_JMS: begin
				next_state = `STATE_EXECUTE;
				mem_read_mux = mop_fetch;
				skip = 1;
			end
			
			
			`STATE_HALT: begin
`ifdef iverilog
				$display("HALT!!!");
				$display("pc: %04o, %1o:%04o",  pc-1, link, ac);
				if (pc-1 != 12'o0146) $finish;	// continue if 1st maindec HLT
`endif
`ifdef verilator
				// HALT don in the sim.cpp code
				// $display("HALT!!!");
				// $display("pc: %04o, %1o:%04o", pc-1, link, ac);
				// if (pc-1 != 12'o0146) $finish;	// continue if 1st maindec HLT
`endif
				// next_state = `STATE_HALT;
				next_state = `STATE_FETCH;
				// next_state = `STATE_EXECUTE;
			end
			
			default: begin
				next_state = `STATE_HALT;
			end
		endcase
	end

endmodule


//=========================================================
//	Core Memory
//=========================================================
`ifdef CORE_4K_12BITS
module core_memory(
	input	clk,
	input	rst,
	input	[11:0] waddr,
	input	write,
	input	[11:0] din,

	input	[11:0] raddr,
	input	read,
	output wire [11:0] dout
);

	wire [11:0]  q;

	core4k12 core4k12_1 (
		.clock(clk), 
		.wraddress(waddr), .wren(write&~rst), .data({4'h0, din}),
		.rdaddress(raddr), .q(q) );
		
	// add by-pass logic for write to read address
	wire bypass = (waddr == raddr) & write;
	reg [11:0] save_din;
	reg do_bypass;
	always @ (posedge clk) begin
		do_bypass <= bypass;
		if (bypass) save_din <= din;
	end
	assign dout = (~rst)?(do_bypass?save_din:q):12'o0000;
	// assign dout = {12{~rst}} & q;	// no by-pass

endmodule
`endif	// CORE_4K_12BITS


`ifdef CORE_4K_16BITS
// Quartus likes 16 bit wide memory, but will optimize it dow to 12 bits
// Could also be done with 3 x 4 bit wide memory banks
module core_memory(
	input	clk,
	input	rst,
	input	[11:0] waddr,
	input	write,
	input	[11:0] din,

	input	[11:0] raddr,
	input	read,
	output wire [11:0] dout
);

	wire [15:0]  q;

	core4k16 core4k16_1 (
		.clock(clk), 
		.wraddress(waddr), .wren(write&~rst), .data({4'h0, din}),
		.rdaddress(raddr), .q(q) );
		
	// add by-pass logic for write to read address
	wire bypass = (waddr == raddr) & write;
	reg [11:0] save_din;
	reg do_bypass;
	always @ (posedge clk) begin
		do_bypass <= bypass;
		if (bypass) save_din <= din;
	end
	assign dout = (~rst)?(do_bypass?save_din:q[11:0]):12'o0000;
	// assign dout = {12{~rst}} & q[11:0];	// no by-pass
	
endmodule
`endif	// CORE_4K_16BITS

