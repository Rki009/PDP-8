// PDP-8/E	- PDP-8/E, 12 bit processor, (C) Ron K. Irvine
//
//	Notes:
//		Variant: PDP-8/E, 1970, Cost: PDP-8/E - $6,500 
//
//
// Skips:
//		SMA SZA = GE - Great than or Equal to Zero
//		SPA SNA = LT - Less than Zero
//		SZA		= EQ - Equal to Zero
//
//	MNEMONIC	CODE	OPERATION
//	SZA SNl		7460 	Skip if AC = 0 or L = 1 or both.
//	SNA SZl		7470	Skip if AC != O and L = 0
//	SMA SNl 	7520	Skip if AC < 0 or L = 1 or both.
//	SPA SZl 	7530	Skip if AC >= and L = 0
//	SMA SZA 	7540	Skip if AC <= 0
//	SPA SNA 	7550	Skip if AC > 0
//	SMA SZA SNl 7560	Skip if AC~O or L = 1 or both.
//	SPA SNA SZl 7570	Skip if AC >0 and L = O.

//	Comparison:
//		CLA CLL		/ AC = 0
//		TAD B		/ AC = B
//		CML CMA IAC	/ NEG - AC = -B
//		TAD A		/ AC = (A-B)
//		Sxx CLA		/ Test AC, Clear AC
//		JMP FAIL
//
//	SKIP IF		UNSIGNED	 SIGNED
//	A NE B 		SNA			SNA
//	A LT B 		SNL 		SMA
//	A LE B 		SNL SZA		SMA SZA
//	A EQ B 		SZA			SZA
//	A GE B 		SZL			SPA
//	A GT B 		SZL SNA		SPA SNA


// Combination Instructions:
//		CIA	7041	Complement and Increment the AC, = Negate the AC
//		STL	7120	Set the LINK, LINK <= 1
//		STA	7240	Set the AC, AC <= 7777
//		GLK	7204	Get the LINK, {11{0}, AC} <= LINK
//		LAS			Load AC with the Switch Register
//		CLA IAC		Set the AC to 1, AC <= 1

// IOTs For Sample Interface
//		6520	Not used.
//		6521	Transfer contents of the AC to the output buffer.
//		6522	Clear the AC.
//		6523	Transfer the contents of the AC to the output buffer and clear the AC. 
//		6524	Transfer the contents of the AC to the output buffer (OR transfer).
//		6525	Clear the flag.
//		6526	Transfer the contents of the AC to the output buffer (jam transfer).
//		6527	Skip if flag set (1).

// CPU
//	SKON     6000  Skip if interrupt ON, and turn OFF
//	ION      6001  Turn interrupt ON. The interrupt system is enabled after the
//						CPU executes the next sequential instruction.
//	IOF      6002  Turn interrupt OFF
//	SRQ      6003  Skip interrupt request
//	GTF      6004  Get interrupt flags
//						bit 0 - Link
//						bit 1 - Greater than flag
//						bit 2 - INT request bus
//						bit 3 - Interrupt Inhibit FF 
//						bit 4 - Interrupt Enable FF
//						bit 5 - User flag
//						bit 6 - 11 - Save Field Register
//	RTF      6005  Restore interrupt flags. The interrupt system is enabled after the
//						CPU executes the next sequential instruction.
//	SGT      6006  Skip on Greater Than flag, ignored
//	CAF      6007  Clear All Flags - AC and Link are cleared. Interrupt system is disabled.


//	Keyboard/Reader
//		KSF	6031	Skip the next instruction when the keyboard buffer register is loaded
//						with an ASCII symbol (causing the keyboard flag to be raised).
//		KCC	6032	Clear AC, clear keyboard flag.
//		KRS	6034	Transfer the contents of the keyboard buffer into the AC.
//		KRB	6036	Transfer the contents of the keyboard buffer into the AC, clear the
//						keyboard flag.

//	Printer/Punch
//		TSF	6041	Skip the next instruction if the printer flag is set to 1.
//		TCF	6043	Clear the printer flag.
//		TPC	6044	Load the printer buffer register with the contents of the AC, select and
//						print the character. (The flag is raised when the action is completed.)
//		TLS	6046	Clear the printer flag, transfer the contents of the ACinto the printer buffer,
//						select and print the character. (The flag is raised when the action is completed.)

// Summary of IOT Instructions, Harris HD-6102
//		MEDIC - Memory Extension/DMA/Interval Time/Controller
//	GTF 6004 1 0 0 1 (1) Get Flags
//	IOF 6002 1 1 0 0 (2) I interrupts Off
//	RTF 6005 1 1 1 1 (3) Restore Flags
//	CAF 6007 1 1 1 1 (4) Clear All Flags
//	CDF 62N1 1 1 1 1 Change Data Field
//	CIF 62N2 1 1 1 1 Change I instruction Field
//	CDF CIF 62N3 1 1 1 1 Combination of CDF & CIF
//	RDF 6214 1 1 0 1 Read Data Field
//	RIF 6224 1 1 0 1 Read Instruction Field
//	RIB 6234 1 1 0 1 Read I interrupt Buffer
//	RMF 6244 1 1 1 1 Restore Memory Field
//	LlF 6254 1 1 1 1 Load I instruction Field
//	CLZE 6130 1 1 1 1 Clear Clock Enable Register per AC
//	CLSK 6131 0 1 1 1 Skip on Clock Overflow Interrupt
//	CLOE 6132 1 1 1 1 Set Clock Enable Register per AC
//	CLAB 6133 1 1 1 1 AC to Clock Buffer
//	CLEN 6134 1 0 0 1 Load Clock Enable Register into AC
//	CLSA 6135 1 0 0 1 Clock Status to AC
//	CLBA 6136 1 0 0 1 Clock Buffer to AC
//	CLCA 6137 1 0 0 1 Clock Counter to AC
//	LCAR 6205 1 0 1 1 Load Current Address Register
//	RCAR 6215 1 0 0 1 Read Current Address Register
//	LWCR 6225 1 0 1 1 Load Word Count Register
//	LEAR 62N6 1 1 1 1 Load Extended Current Address Register
//	REAR 6235 1 1 0 1 Read Extended Current Address Register
//	LFSR 6245 1 0 1 1 Load DMA Flags and Status Register
//	RFSR 6255 1 1 0 1 Read DMA Flags and Status Register
//	SKOF 6265 0 1 1 1 Skip on Word Count Overflow
//	WRVR 6275 1 0 1 1 Write Vector Register

// IOT Device Allocation PDP-8E
//	DEVICE SELECTION
//	PDP-8/E 	DEVICE TYPE
//	00			Internal lOT's
//	01			DEC High Speed Reader
//	02			DEC High Speed Punch
//	03			DEC Teletype Keyboard/Reader
//	04			DEC Teletype Printer/Punch
//	05			User Definable
//	06,07		User Definable
//	10,11		User Definable
//	12			User Definable
//	13			MEDIC Real Time Clock
//	14,15		User Definable
//	16,17		User Definable
//	20,21		MED IC Extended Memory Control and DMA
//	22,23		MED IC Extended Memory Control and DMA
//	24,25		MEDIC Extended Memory Control and DMA
//	26,27		MED IC Extended Memory Control and DMA
//	30,31		HD-6103 Pia No. One
//	32,33		HD-6103 Pia No. Two
//	34,35		HD-6103 Pia No. Three
//	36,37		HD-6103 Pia No. Four
//	40,41		User Definable
//	42,43		User Definable
//	44,45		User Definable
//	46,47		User Definable
//	50,51		User Definable
//	52,53		User Definable
//	54,55		User Definable
//	56,57		User Definable
//	60,61		User Definable
//	62,63		User Definable
//	64,65		User Definable
//	66,67		DEC Line Printer ~ 66
//	70,71		User Definable
//	72,73		User Definable
//	74,75		DEC Floppy Disk Drive ~ 75
//	76,77		User Definable

//	New PDP-8/E Instructions
//	OCTAL	NEW INSTRUCTION
//	CODE	(MNEMONIC)		PREVIOUS FUNCTION
//	6000	SKON			NOP
//	6003	SRQ				ION
//	6004	GIF				ADC or NOP
//	6005	RTF				ION (ORed with ADC)
//	6006	SGT				IOF (ORed with ADC)
//	6007	CAF				ION (ORed with ADC)
//	7002	BSW				NOP
//	7014	Reserved		RAR RAL
//	7016	Reserved		RTR RTL
//	74X1 	MQ Instructions Only available with EAE.
//	7521 	SWP MQL MQA
//	Octal codes 7014 and 7016 produced predictable but undocumented
//	results in the PDP-8/1 and PDP-8/L. In the PDP-8/E these codes are
//	specifically reserved for future expansion.


// Options:
`define CORE_4K	1
// `define CORE_32K 1

// `define START_ADDR	12'o7777
`ifndef START_ADDR
	`define START_ADDR	12'o0200
`endif

//	DE10 Led Output
//	6776		Write the AC[9:0] to LEDR (10 DE10 Status Leds)

`define DEV_CPU			6'o00		// CPU Interrupt Control
`define DEV_TTY_RX		6'o03		// teletype Keyboard
`define DEV_TTY_TX		6'o04		// teletype Printer
`define DEV_GPS_RX		6'o43		// GPS UART Receiver
`define DEV_GPS_TX		6'o44		// GPS UART Transmitter
`define DEV_DE10		6'o47		// DE10 Interface

 
// Major Opcodes
`define OP_AND 			3'b000		// AND memory with AC
`define OP_TAD 			3'b001		// Transfer and Add to AC
`define OP_ISZ 			3'b010		// INC and Skip on Zero
`define OP_DCA 			3'b011		// Deposit and Clear AC
`define OP_JMS 			3'b100		// JuMp to Subroutine
`define OP_JMP 			3'b101		// JuMP
`define OP_IOT 			3'b110		// Input/Output Transfer
`define OP_OPR 			3'b111		// micro coded OPeRations


// CPU Cycle State - use one-shot logic
`define STATE_IDLE		10'h001
`define STATE_FETCH		10'h002
`define STATE_EXECUTE	10'h004
`define STATE_INDIRECT	10'h008
`define STATE_WRITEBACK 10'h010
`define STATE_JMS 		10'h020
`define STATE_EXECUTE2	10'h040
`define STATE_INTERRUPT	10'h080
`define STATE_AUTOINC	10'h100
`define STATE_HALT		10'h200

`define OP_NOP 			12'o7000	// NOP - No Operation
`define OP_JMS0			12'o4000	// JMS 0 - Interrupt


// various baud rate factors for 50MHz clk
//	  Baud    Factor  iFactor  Error
//	   300  10416.667  10417  -0.003%
//	  9600    325.521    326  -0.147%
//	 19200    162.760    163  -0.147%
//	115200     27.127     27   0.467%
//	256000     12.207     12   1.696%
// 1000000      3.125      3   4.000%
`define BAUD_300		16'd10417	// 300 = 10417, 
`define BAUD_9600		16'd326		// 9600 = 325.52, -0.15% 
`define BAUD_19200		16'd163		// 19200 = 162.76,
`define BAUD_115200		16'd27		// 115,200 = 27.13, 
`define BAUD_256000		16'd12		// 256,000 = 12.21
`define BAUD_1M			16'd3		// 1000000 = 3.125

`ifdef iverilog
	`define	BAUD_FACTOR `BAUD_1M		// very fast for simulation
`endif

`ifndef BAUD_FACTOR
	`define	BAUD_FACTOR `BAUD_300		// Teletype = 300 baud
`endif


// `define OLD_WAY
`ifdef OLD_WAY
// CORE Memory - xK by 12 bits wide
	`ifdef EXTENDED_MEM
		`define CORE_32K_12BITS 1
	`else
		`define CORE_4K_12BITS 1
	`endif
`else
	`define MEM_12BITS
`endif

`ifndef MEM_SIZE_K
	`define MEM_SIZE_K 8		// 8K
	// Extended Memory Interface
	`define EXTENDED_MEM
`endif
`define MEM_AWIDTH ($clog2(`MEM_SIZE_K*1024))

// add a second UART for GPS interface
`define ADD_GPS

