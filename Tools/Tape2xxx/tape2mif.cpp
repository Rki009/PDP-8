#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include "getopt.h"

uint16_t mem[4096];		// 4K memory
// uint16_t mem[32*1024];		// 32K memory

int verbose = 0;
bool fillall = true;	// fill all memory


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
	if(ifp == NULL) {
		printf("Can not open %s\n", infile);
		exit(-1);
	}

	// suck in the entire *.bin file
	fseek(ifp, 0, SEEK_END);
	int len = ftell(ifp);
	fseek(ifp, 0, SEEK_SET);
	if(verbose >= 1) {
		printf("Len = %d\n", len);
	}
	uint8_t* bin = (uint8_t*)malloc(len);
	fread(bin, 1, len, ifp);
	fclose(ifp);

	int start = -1;
	int end = -1;
	// skip leader
	for(int i=0; i<len; ++i) {
		uint8_t c = bin[i];
		if(c == 0x00) {
			continue;
		}
		start = i;
		if(c != 0x80) {
			break;
		}
	}
	// find trailer
	for(int i=start; i<len; ++i) {
		uint8_t c = bin[i];
		end = i;
		if(c == 0x80) {
			break;
		}
	}
	if(verbose >= 2) {
		printf("Start: %d, End: %d\n", start, end);
	}

	// skip lead in
	int field = 0;
	int origin = 0;
	int data = 0;
	int addr = 0;
	(void) data;	// use it to avoid compiler warning

	uint16_t checksum = 0;
	for(int i=start; i<end-2; ++i) {
		uint8_t c = bin[i];
		if(c == 0x80) {
			break;    // done
		}
		if((c&0xc0) == 0xc0) {
			field = ((c>>3)&0x07);
			if(verbose >= 1) {
				printf("Field: %01o\n", field);
			}
		}
		else if((c&0xc0) == 0x40) {
			origin = (c&0x3f)<<6;
			checksum += (c&0xff);
			c = bin[++i];
			origin |= c&0x3f;
			checksum += (c&0xff);
			if(verbose >= 1) {
				printf("Origin: %04o\n", origin);
			}
			addr = origin;
		}
		else if((c&0xc0) == 0x00) {
			int data = (c&0x3f)<<6;
			checksum += (c&0xff);
			c = bin[++i];
			data |= (c&0x3f);
			checksum += (c&0xff);
			if(verbose >= 2) {
				printf("Data: %1o:%04o: %04o\n", field, addr, data);
			}
			uint32_t paddr = ((field%0x3)<<12) | (addr&0xfff);
			mem[paddr] = data&0x0fff;
			if(verbose >= 3) {
				printf("  %05o: %04o\n", paddr, data);
			}
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
	if(!sum_ok) {
		exit(-1);
	}

}

// outMem - output *.mem file
//	format is:
//		xxx			<= 3 hex digits = 12 bits, start at 0000
//		xxx
//		...
void saveMem(const char* outfile, uint16_t* mem, uint32_t len) {

	FILE* ofp = fopen(outfile, "w");
	if(ofp == NULL) {
		printf("Can not open %s\n", outfile);
		exit(-1);
	}
	printf("Output: %s\n", outfile);
	for(uint32_t i=0; i<len; ++i) {
		// fprintf(ofp, "%04o: %04o\n", i, mem[i]&0xfff);
		// fprintf(ofp, "%04o\n", mem[i]&0xfff);
		fprintf(ofp, "%03x\n", mem[i]&0xfff);
	}

	fclose(ofp);
}



/*	MIF - format ...
%  multiple-line comment
multiple-line comment  %
-- single-line comment

DEPTH = 32;                   -- The size of memory in words
WIDTH = 8;                    -- The size of data in bits
ADDRESS_RADIX = HEX;          -- The radix for address values
DATA_RADIX = BIN;             -- The radix for data values
CONTENT                       -- start of (address : data pairs)
BEGIN
00 : 00000000;                -- memory address : data
01 : 00000001;
02 : 00000010;
03 : 00000011;
04 : 00000100;
05 : 00000101;
06 : 00000110;
07 : 00000111;
08 : 00001000;
09 : 00001001;
0A : 00001010;
0B : 00001011;
0C : 00001100;
END;
*/
void saveMif(const char* filename, uint8_t* data, int len) {
	FILE* ofp = fopen(filename, "w");
	if(ofp == NULL) {
		printf("Unable to write to file %s\n", filename);
		return;
	}
	fprintf(ofp, "DEPTH = 4096;         -- The size of memory in words\n");
	fprintf(ofp, "WIDTH = 32;           -- The size of data in bits\n");
	fprintf(ofp, "ADDRESS_RADIX = HEX;  -- The radix for address values\n");
	fprintf(ofp, "DATA_RADIX = HEX;     -- The radix for data values\n");
	fprintf(ofp, "CONTENT               -- start of (address : data pairs)\n");
	fprintf(ofp, "BEGIN\n");

	uint32_t* wp = (uint32_t*)data;
	int n = len/4;
	for(int i=0; i<n; ++i) {
		fprintf(ofp, "%04x : %08x;\n", i, *wp++);
	}
	// fprintf(ofp, "\n");
	fprintf(ofp, "END;\n");
	fclose(ofp);
};


void saveMif_12(const char* filename, uint16_t* data, int len) {
	FILE* ofp = fopen(filename, "w");
	if(ofp == NULL) {
		printf("Unable to write to file %s\n", filename);
		return;
	}
	printf("Output: %s\n", filename);
	printf("  Len: %d\n", len);

	fprintf(ofp, "DEPTH = %d;           -- The size of memory in words\n", len);
	fprintf(ofp, "WIDTH = 12;           -- The size of data in bits\n");
	fprintf(ofp, "ADDRESS_RADIX = OCT;  -- The radix for address values\n");
	fprintf(ofp, "DATA_RADIX = OCT;     -- The radix for data values\n");
	fprintf(ofp, "CONTENT               -- start of (address : data pairs)\n");
	fprintf(ofp, "BEGIN\n");

	int n = 0;
	int minAddr = 32*1024;
	int maxAddr = 0;

	for(int i=0; i<len; ++i) {
		uint16_t word = data[i];
		if(fillall && (word == 0xffff)) {
			word =0;
		}
		if(word != 0xffff) {
			// printf(" %05o : %04o;\n", i, word&0x0fff);
			if(len >= 4096) {
				fprintf(ofp, "%05o : %04o;\n", i, word&0x0fff);
			}
			else {
				fprintf(ofp, "%04o : %04o;\n", i, word&0x0fff);
			}
			if(i < minAddr) {
				minAddr = i;
			}
			if(i > maxAddr) {
				maxAddr = i;
			}
			++n;
		}
	}
	fprintf(ofp, "END;\n");
	printf("  Words: %d, minAddr = %05o, maxAddr = %05o\n", n, minAddr, maxAddr);
	fclose(ofp);
};


void usage(void) {
	printf("Usage: tape2mem [-v] infile.bin outfile.mem\n");
	printf("Options:  -v       verbose\n");
}


int main(int argc, char** argv) {
	bool bflag = false;
	char* cvalue = NULL;
	int c;

	(void) bflag;	// use it to avoid compiler warning
	(void) cvalue;	// use it to avoid compiler warning

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

	// int index;
	// for(index = optind; index < argc; index++) {
	// 	printf("Non-option argument [%d] %s\n", index, argv[index]);
	// }
	int narg = argc-optind;
	// printf("narg: %d\n", argc-optind);
	if(narg != 2) {
		usage();
		exit(-1);
	}

	const char* infile = argv[optind];
	const char* outfile = argv[optind+1];

	// Mark all of memory Unused
	int len = sizeof(mem)/sizeof(uint16_t);
	for(int i=0; i<len; ++i) {
		mem[i] = 0xffff;
	}

	printf("Input:  %s\n", infile);
	process(infile);

	// saveMem(outfile, mem, len);

	saveMif_12(outfile, mem, len);

	return(0);
}
