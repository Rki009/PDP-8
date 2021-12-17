#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include "getopt.h"

uint16_t mem[4096];		// 4K memory

typedef struct {
	union {
		uint32_t	v;
		struct {
			uint32_t	jmp:1;
			uint32_t	jms:1;
			uint32_t	fill_1:1;
			uint32_t	indirect:1;
			
			uint32_t	tad:1;
			uint32_t	dca:1;
			uint32_t	isz:1;
			uint32_t	opAnd:1;

			uint32_t	fill_2:3;
			uint32_t	ra:1;			// return address?
			
			// access
			uint32_t	fill_3:2;
			uint32_t	read:1;
			uint32_t	write:1;
		};
	};
} info_t;

info_t info[4096];		// tags for memory

int verbose = 0;

// top 2 bits:
//	00 - Data:		00dddddd,	2 x data, 6 + 6 bits
//					00dddddd
//	01 - Origin:	01aaaaaa,	2 x address, 6 + 6 bits
//					00aaaaaa
//	11 - Field:		11fff000,	fff - 3 bit field #		
//	10 - Lead/Trail:10000000

// checksum is the sum of all the data/address characters

void process(const char* infile) {
	FILE* ifp = fopen(infile, "rb");
	if (ifp == NULL) {
		printf("Can not open %s\n", infile);
		exit(-1);
	}
	
	// suck in the entire *.bin file
	fseek(ifp, 0, SEEK_END);
	int len = ftell(ifp);
	fseek(ifp, 0, SEEK_SET);
	if (verbose >= 1) printf("Len = %d\n", len);
	uint8_t* bin = (uint8_t*)malloc(len);
	fread(bin, 1, len, ifp);
	fclose(ifp);	
	
	int start = -1;
	int end = -1;
	// skip leader
	for(int i=0; i<len; ++i) {
		uint8_t c = bin[i];
		if (c == 0x00) continue;
		start = i;
		if (c != 0x80) break;
	}
	// find trailer
	for(int i=start; i<len; ++i) {
		uint8_t c = bin[i];
		end = i;
		if (c == 0x80) break;
	}
	if (verbose >= 2) printf("Start: %d, End: %d\n", start, end);
	
	// skip lead in
	int field = 0;
	int origin = 0;
	int data = 0;
	int addr = 0;
	uint16_t checksum = 0;
	for(int i=start; i<end-2; ++i) {
		uint8_t c = bin[i];
		if (c == 0x80) break;	// done
		if ((c&0xc0) == 0xc0) {
			field = ((c>>3)&0x07);
			if (verbose >= 2) printf("Field: %01o\n", field);
		}
		else if ((c&0xc0) == 0x40) {
			origin = (c&0x3f)<<6;
			checksum += (c&0xff);
			c = bin[++i];
			origin |= c&0x3f;
			checksum += (c&0xff);
			if (verbose >= 2) printf("Origin: %04o\n", origin);
			addr = origin;
		}
		else if ((c&0xc0) == 0x00) {
			int data = (c&0x3f)<<6;
			checksum += (c&0xff);
			c = bin[++i];
			data |= (c&0x3f);
			checksum += (c&0xff);
			if (verbose >= 2) printf("Data: %1o:%04o: %04o\n", field, addr, data);
			uint32_t paddr = ((field%0x3)<<12) | (addr&0xfff); 
			mem[paddr] = data;
			if (verbose >= 3) printf("  %05o: %04o\n", paddr, data);
			++addr;
		}
		else {
			printf("Oops: %03o\n", c);
			exit(-1);
		}
	}
	
	uint16_t tape = ((bin[end-2]&0x3f)<<6) | (bin[end-1]&0x3f); 
	checksum &= 0xfff;
	bool sum_ok = (checksum == tape);
	// if (!sum_ok || verbose)
	printf("Checksum: %04o, Tape: %04o, %s\n", checksum, tape, sum_ok?"OK!":"***BAD***");
	// if (!sum_ok) exit(-1);

}


typedef struct {
	const char* text;
	uint16_t	value;
} symbol_t;


// BIN Loader Symbol Table
symbol_t sym_tab[] = {
	{ "START",	00200 },

	{ NULL,		00000 }
};

#if 0
// BIN Loader Symbol Table
symbol_t sym_tab[] = {
	{ "START",	00200 },
	{ "V1", 	07612 },
	{ "V2",		07613 },
	{ "V3",		07614 },
	{ "V4",		07615 },
	{ "V5",		07616 },
	{ "V6",		07700 },

	{ "L1",		07637 },
	{ "L2",		07627 },
	{ "L3",		07630 },
	{ "L4",		07665 },
	{ "L5",		07715 },
	{ "L6",		07732 },
	{ "L7",		07736 },
	{ "L8",		07675 },
	{ "L9",		07662 },

	{ "F2",		07626 },
	{ "GETC",	07660 },
	// { "F3",		07670 },
	{ "F4",		07736 },
	{ "F5",		07743 },

	{ "N0006",	07753 },
	{ "N0300",	07674 },
	{ "N0070",	07656 },
	{ "N6201",	07657 },

	{ "T1",		07755 },
	// { "A7776",	07776 },

	{ NULL,		00000 }
};
#endif


symbol_t* lookupSym(const char* name) {
	for(symbol_t* sp = sym_tab; sp->text != NULL; ++sp) {
		if (strcmp(sp->text, name)==0) return sp;
	}
	return NULL;
}

symbol_t* lookupSym(uint16_t value) {
	for(symbol_t* sp = sym_tab; sp->text != NULL; ++sp) {
		if (sp->value == value) return sp;
	}
	return NULL;
}



typedef struct {
	const char*	text;
	uint16_t	code;
	const char*	desc;
} opcode_t;

const char* op_str[8] = { "AND", "TAD", "ISZ", "DCA", "JMS", "JMP", "IOT", "OPR" };


opcode_t op_base[] = {
	// Base Instructions
	{ "AND",		00000,	"AND" },
	{ "TAD",		01000,	"TAD" },
	{ "ISZ",		02000,	"ISZ" },
	{ "DCA",		03000,	"DCA" },
	{ "JMS",		04000,	"JMS" },
	{ "JMP",		05000,	"JMP" },
	{ "IOT",		06000,	"IOT" },
	{ "OPR",		07000,	"OPR" },
	{ NULL, 0, NULL }
};

opcode_t op_table[] = {
	// Group One
	{ "NOP",		07000,	"no operation" },
	{ "CLA",		07200,	"clear AC" },
	{ "CLL",		07100,	"clear link" },
	{ "CMA",		07040,	"complement AC" },
	{ "CML",		07020,	"complement link" },
	{ "RAR",		07010,	"rotate AC and link right one" },
	{ "RAL",		07004,	"rotate AC and link left one" },
	{ "RTR",		07012,	"rotate AC and link right two" },
	{ "RTL",		07006,	"rotate AC and link left two" },
	{ "IAC",		07001,	"increment AC" },
	{ "BSW",		07002,	"swap bytes in AC" },
	
	// Group Two
	{ "SMA",		07500,	"skip on minus AC" },
	{ "SZA",		07440,	"skip on zero AC" },
	{ "SPA",		07510,	"skip on plus AC" },
	{ "SNA",		07450,	"skip on non-zero AC" },
	{ "SNL",		07420,	"skip on non-zero link" },
	{ "SZL",		07430,	"skip on zero link" },
	{ "SKP",		07410,	"skip unconditionally" },
	{ "OSR",		07404,	"inclusive OR, switch register with AC" },
	{ "HLT",		07402,	"halts the program" },
	{ "CLA",		07600,	"clear AC" },

	// Combined
	{ "CIA",		07041,	"complement and increment AC" },
	{ "LAS",		07604,	"load AC with switch register" },
	{ "STL",		07120,	"set link (to 1)" },
	{ "GLK",		07204,	"get link (put link in AC bit 11)" },
	{ "CLA CLL",	07300,	"clear AC and link" },
	{ "CLL RAR",	07110,	"shift positive number one right" },
	{ "CLL RAL",	07104,	"shift positive number one left" },
	{ "CLL RTL",	07106,	"clear link, rotate 2 left" },
	{ "CLL RTR",	07112,	"clear link, rotate 2 right" },
	{ "SZA CLA",	07640,	"skip if AC=0, then clear AC" },
	{ "SZA SNL",	07460,	"skip if AC=0, or link is 1, or both 1" },
	{ "SNA CLA",	07650,	"skip if AC/=0, then clear AC" },
	{ "SMA CLA",	07700,	"skip if AC<0, then clear AC" },
	{ "SMA SZA",	07540,	"skip if AC<=0" },
	{ "SMA SNL",	07520,	"skip if AC<0 or line is 1, or both" },
	{ "SPA SNA",	07550,	"skip if AC>0" },
	{ "SPA SZL",	07530,	"skip if AC>=0 and if the link is 0" },
	{ "SPA CLA",	07710,	"skip of AC>=0, then clear AC" },
	{ "SPA SNA CLA",07750,	"skip of AC>0, then clear AC" },
	{ "SNA SZL",	07470,	"skip if AC=0 and link=0" },
	
	// MQ MICROINSTRUCTIONS (1.2usec)
	{ "NOP",		07401,	"no operation" },
	{ "CLA",		07601,	"clear AC" },
	{ "MQL",		07421,	"load MQ from AC then clear AC" },
	{ "MQA",		07501,	"inclusive OR the MQ with the AC" },
	{ "CAM",		07621,	"clear AC and MQ" },
	{ "SWP",		07521,	"swap AC and MQ" },
	{ "ACL",		07701,	"load MQ into AC" },
	{ "CLA, SWP",	07721,	"load AC from MQ then clear MQ" },

	// PROGRAM INTERRUPT AND FLAG
	{ "SKON",		06000,	"skip if interrupt ON, and turn OFF" },
	{ "ION",		06001,	"turn interrupt ON" },
	{ "IOF",		06002,	"turn interrupt OFF" },
	{ "SRQ",		06003,	"skip interrupt request" },
	{ "GTF",		06004,	"get interrupt flags" },
	{ "RTF",		06005,	"restore interrupt flags" },
	{ "SGT",		06006,	"skip on Greater Than flag, if KE8-E installed" },
	{ "CAF",		06007,	"clear all flags" },

	// TELETYPE KEYBOARD/READER
	{ "KCF",		06030,	"Clear Keyboard/Reader Flag, do not start Reader" },
	{ "KSF",		06031,	"Skip if Keyboard/Reader Flag = 1" },
	{ "KCC",		06032,	"Clear AC and Keyboard/Reader Flag, set Reader run" },
	{ "KRS",		06034,	"Read Keyboard/Reader Buffer Static" },
	{ "KIE",		06035,	"AC 11 to Keyboard/Reader Interrupt, Enable F.F." },
	{ "KRB",		06036,	"Clear AC, Read Keyboard Buffer, Clear Keyboard Flags" }, 

	// TELETYPE TELEPRINTER/PUNCH
	{ "SPF",		06040,	"Set Teleprinter/Punch Flag" },
	{ "TSF",		06041,	"Skip if Teleprinter/Punch Flag = 1" },
	{ "TCF",		06042,	"Clear Teleprinter/Punch Flag" },
	{ "TPC",		06044,	"Load Teleprinter/Punch Buffer, Select and Print" },
	{ "SPI",		06045,	"Skip if Teletype Interrupt" },
	{ "TLS",		06046,	"Load Teleprinter Buffer, Select and Print and Clear Flag" },

	{ NULL, 0, NULL }
};



// PDP-8 decode instructions
char* decode_pdp8(char* buf, uint16_t addr, uint16_t insn, bool addDesc=false) {
	insn = insn&0xfff;
	int opcode = (insn>>9)&0x7;
	bool indirect = (insn&0400);
	bool pagezero = !(insn&0200);
	int offset = (insn&0177);
	int thispage = (addr&07600);
	uint16_t tag = pagezero?offset:(thispage | offset);
	
	buf[0] = '\0';
	char* bp = buf;
		

	symbol_t* sp = lookupSym(addr);
	if (sp) {
		sprintf(bp, "%s,\t", sp->text);
		while(*bp) ++bp;
		if (strlen(sp->text) <=3) sprintf(bp, "\t");
		while(*bp) ++bp;
	}
	else {
		sprintf(bp, "\t\t");
	}
	while(*bp) ++bp;
	
	// if insn < 0020, most likely a constand not an AND 00xx
	if (insn < 020) {
		sprintf(bp, "0000");
		return(buf);
	}
	
	if (opcode == 5) {	// JMP
		if ((insn&0777) == (((addr-1)&0177) | 0200)) {
			sprintf(bp, "JMP .-1");
			return(buf);
		}
	}			


	opcode_t* op = op_table;
	for(; op->text != NULL; ++op) {
		if (op->code == insn) {
			if (addDesc) sprintf(bp, "%-12s/ %s", op->text, op->desc);
			else sprintf(bp, "%s", op->text);
			break;
		}
	}
	if (op->text == NULL) {
		if (opcode <= 5) {
			if (1 || addDesc) {
				symbol_t* sp = lookupSym(tag);
				if (sp == NULL) {
					sprintf(bp, "%s %s%04o", op_str[opcode], indirect?"I ":"", tag);
				}
				else {
					sprintf(bp, "%s %s%s", op_str[opcode], indirect?"I ":"", sp->text);
				}
			}
			else sprintf(bp, "%s", op_str[opcode]);
		}
		else {
			sprintf(bp, "%04o", insn);
		}
	}
	
	return buf;
}


void disasm() {
	int len = sizeof(mem)/sizeof(int16_t);
	
		
	// build info table
	for(int i=0; i<len; ++i) {
		int insn = mem[i]&0xfff;
		int opcode = (insn>>9)&0x7;
		bool indirect = (insn&0400);
		bool pagezero = !(insn&0200);
		int offset = (insn&0177);
		int thispage = (i&07600);
		int addr = pagezero?offset:(thispage | offset);

		if (i >= 0200) {	// assume page zero is data
			if (opcode <= 5 && indirect) info[addr].indirect = 1;
			if (opcode == 0) {	// AND
				if (!indirect) {
					info[addr].opAnd = 1;
					info[addr].read = 1;
				}
			}
			if (opcode == 1) {	// TAD
				if (!indirect) {
					info[addr].tad = 1;
					info[addr].read = 1;
				}
			}
			if (opcode == 2) {	// ISZ
				if (!indirect) {
					info[addr].isz = 1;
					info[addr].read = 1;
					info[addr].write = 1;
				}
			}
			if (opcode == 3) {	// DCA
				if (!indirect) {
					info[addr].dca = 1;
					info[addr].write = 1;
				}
			}
			if (opcode == 4) {	// JMS
				info[addr].jms = 1;
				info[addr].read = indirect;
			}
			if (opcode == 5) {	// JMP
				info[addr].jmp = 1;
				info[addr].read = indirect;
				if (indirect && !pagezero) {
					info[addr].ra = 1;
				}
			}
		}
	}

#if 0
	for(int i=0; i<len; ++i) {
		info_t* ip = &info[i];
		if (ip->v != 0) {
			printf("%04o: %08x\n", i, ip->v);
		}
	}
#endif

	// decode instructions
	for(int i=0; i<len; ++i) {
		if (mem[i]&0x8000) continue;	// just memory from the bin file
		
		int insn = mem[i]&0xfff;
		char buf[256];
		decode_pdp8(buf, i, insn, true);
		
		printf("%04o: %04o\t", i, insn);
		printf("%s\n", buf);
	}


	
#if 0
	// decode instructions
	for(int i=0; i<len; ++i) {
		if (mem[i]&0x8000) continue;	// just memory from the bin file
		
		int insn = mem[i]&0xfff;
		int opcode = (insn>>9)&0x7;
		bool indirect = (insn&0400);
		bool pagezero = !(insn&0200);
		int offset = (insn&0177);
		int thispage = (i&07600);
		int addr = pagezero?offset:(thispage | offset);
		
		char text[256];
		text[0] = '\0';
		
		
		opcode_t* op = op_table;
		for(; op->text != NULL; ++op) {
			if (op->code == insn) {
				sprintf(text, "%-12s/ %s", op->text, op->desc);
				break;
			}
		}
		if (op->text == NULL) {
			if (opcode <= 5) {
				sprintf(text, "%s %s%04o", op_str[opcode], indirect?"I ":"", addr);
			}
			else {
				sprintf(text, "%04o", insn);
			}
		}
		
		
		printf("%04o: %04x - %04o,\t%s\n", i, info[i].v, insn, text);
	}
#endif

	
}

void usage(void) {
	printf("Usage: disasm8 [-v] infile.bin\n");
	printf("Options:  -v       verbose\n");
}


int main(int argc, char** argv) {
	bool bflag = false;
	char* cvalue = NULL;
	int c;
	int index;
	while((c = getopt(argc, argv, "vbc:")) != -1) {
		switch(c) {
		case 'v':
			++verbose;
			break;
		case 'b':
			bflag = true;
			break;
		case 'c':
			cvalue = optarg;
			break;
		case '?':
			if(optopt == 'c') {
				fprintf(stderr, "Option -%c requires an argument.\n", optopt);
			}
			else if(isprint(optopt)) {
				fprintf(stderr, "Unknown option `-%c'.\n", optopt);
			}
			else
				fprintf(stderr,
					"Unknown option character `\\x%x'.\n",
					optopt);
			return 1;
		default:
			abort();
		}
	}
	
	// printf("bflag = %d, cvalue = %s\n", bflag, cvalue);

	// for(index = optind; index < argc; index++) {
	// 	printf("Non-option argument [%d] %s\n", index, argv[index]);
	// }
	int narg = argc-optind;
	// printf("narg: %d\n", argc-optind);
#if 0
	if(narg != 1) {
		usage();
		exit(-1);
	}
#endif


	const char* infile = argv[optind];
	// const char* outfile = argv[optind+1];
	
	int len = sizeof(mem)/sizeof(uint16_t);
	for(int i=0; i<len; ++i) mem[i] = -1;
	
	printf("Input:  %s\n", infile);
	process(infile);
	
#if 0
	FILE* ofp = fopen(outfile, "w");
	if (ofp == NULL) {
		printf("Can not open %s\n", outfile);
		exit(-1);
	}
	printf("Output: %s\n", outfile);
	for(int i=0; i<len; ++i) {
		// fprintf(ofp, "%04o: %04o\n", i, mem[i]&0xfff);
		// fprintf(ofp, "%04o\n", mem[i]&0xfff);
		fprintf(ofp, "%03x\n", mem[i]&0xfff);
	}
#endif

	disasm();
	
	// fclose(ofp);
	return(0);
}
