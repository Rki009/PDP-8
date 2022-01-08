#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include "getopt.h"

uint16_t mem[32*1024];		// 32K memory

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
			mem[paddr] = data;
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

void usage(void) {
	printf("Usage: tape2mem [-v] infile.bin outfile.mem\n");
	printf("Options:  -k n     Memory Size in K bytes\n");
	printf("Options:  -v       verbose\n");
}


int main(int argc, char** argv) {
	bool bflag = false;
	char* cvalue = NULL;
	int c;
	(void) bflag;	// use it to avoid compiler warning
	(void) cvalue;	// use it to avoid compiler warning
	int mem_size = 4;	// default to 4K

	while((c = getopt(argc, argv, "vbc:k:")) != -1) {
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
		case 'k':
			mem_size = atoi(optarg);
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

	// int len = sizeof(mem)/sizeof(uint16_t);
	int len = mem_size * 1024;
	if (mem_size > sizeof(mem)/sizeof(uint16_t)) {
		printf("Bad memory size: %d\n", mem_size);
	}
	
	for(int i=0; i<len; ++i) {
		mem[i] = 0;
	}

	printf("Input:  %s\n", infile);
	process(infile);

	FILE* ofp = fopen(outfile, "w");
	if(ofp == NULL) {
		printf("Can not open %s\n", outfile);
		exit(-1);
	}
	printf("Output: %s\n", outfile);
	for(int i=0; i<len; ++i) {
		// fprintf(ofp, "%04o: %04o\n", i, mem[i]&0xfff);
		// fprintf(ofp, "%04o\n", mem[i]&0xfff);
		fprintf(ofp, "%03x\n", mem[i]&0xfff);
	}

	fclose(ofp);
	return(0);
}
