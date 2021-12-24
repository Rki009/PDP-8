<!---
![Screen Shot](https://github.com/Rki009/<project>/raw/master/<file>.png?raw=true "Screen Shot")
-->

# PDP-8 - Classic PDP-8 12 bit computer


## Features

- 4K x 12 bit Memory
- GPS Clock Demo on a DE10-Lite FPGA Board
- Updated Palbart PDP-8 Assembler (version 2.14)
- PDP-8 Disassembler included
- Tools to create *.mif and *.mem files for FPGAs

## PDP-8 Notes

The PDP-8 was a 12 bit computer developed by Digital Equipment Corporation in the 1960's.
It was a very successful design and found many applications in the emerging computer control business.
It simple, yet powerful design was used real time control system from research laboratories to industrial systems.
For the time it was very cost effective.
Some applications were able to payback the cost of the PDP-8 computer and programming in very short time.

### TAD/DCA Instructions
Since the PDP-8 has only 8 basic instructions the designers decided to use a TAD (Transfer And Add) and DCA (Deposit And Clear) instruction dual rather than a LOAD/STORE/ADD combination. This save valuable instruction space and created a rather unique machine. Both the TAD and DAC have two operations at once. The TAD will load a value from memory, at the same time it will preform an add to the AC (accumulator) this new value. If the AC was zero, then the TAD becomes a LOAD from memory operation. If the AC is non-zero the TAD becomes a ADD from memory operation. When programming the PDP-8 it is necessary to ensure the AC is zero before a TAD instruction in order to LOAD from memory. This can become complicated for a TAD instruction that is the destination of program jumps or calls. In this case, to be safe, the programmer will insert a CLA CLL instruction to clear the AC and LINK registers before the intended TAD load.

To help ensure a cleared AC before a TAD instruction DCA instructions STORE the AC in memory and then clear the AC. This dual operation ensures the AC is zeroed before a subsequent TAD instruction. Thus the DCA/TAD combination functions like a STORE/LOAD pair. Unlike a store operation, the DCA will not preserve the value of the AC, so if the value is to be reused it must be reloaded (with a TAD) from memory.

While the TAD/DCA combination made it possible to reduce the number of machine instructions it created a bit of a headache for programmers and added to the quirkiness of the PDP-8.

### ISZ Instruction, and Auto Increment Memory
The PDP-8 was built using magnetic core memory for storage. While magnetic core memory is quite robust and provides non-volatile, reasonably fast storage (for the time) it did have one unique property. Read were destructive, so the value read needed to be written back into the core memory. All read accesses were effectively read/write accesses. This provided the opportunity to modify the value read before it was written back to memory. The obvious choice was to add 1 to the value and create an auto-increment operation. This could be done using the cpu's adder logic or even provide a separate adder in the memory unit.

The ISZ instruction utilized the auto-increment memory functionality to provide counting capability for the PDP-8 that effectively bypassed the AC with little cost in hardware. Similarly the location 10 to 17 auto-indexing memory locations were easily added to the hardware. Both these functions were done without slowing down the processor since the core memory unit had to rewrite any read value anyway.

More modern solid state RAM would require a write cycle to be added for the auto-increment functionality since solid state RAM can be read without the need to write back the read value.

### IOT Instructions
The IOT (I/O Transfer) instruction provide a simple, yet effective was to talk to I/O devices. The PDP-8 has a total of 64 possible devices with 8 basic transfer operations.

#### Standard Devices
- 00 - CPU Functions; example 6001 (ION) enable interrupts, 6002 (IOFF) disable interrupts
- 01 - High Speed Paper Tape Reader
- 02 - High Speed Paper Tape Punch
- 03 - Console Keyboard
- 04 - Console Printer

The PDP-8 Omnibus provided I/O Pulses for operations based on the three bits of the transfer operation. In addition the current AC value could be read by and I/O board or wire ORed back into the AC for read. A skip flag could also be set to provide conditional execution basic on the I/O device response.

- Bit 11 causes the processor to skip the next instruction if the I/O device's flag is set (ready)
- Bit 10 clears flags, clears AC
- Bit 9  Reading, loading and clearing buffers between AC and the device

For more complex devices the three bits are decoded and provide device specific functionality.

## PDP-8 GPS

A PDP-8 gps demo is provided for the DE10-Lite FPGA development board.
The PDP-8 is used to receive serial NMEA GPS messages (sentences) at 9600 baud for a GPS module.
The NMEA sentences are decoded and the current UTC time is displayed on the DE10-Lite's 6 7-segment displays.

The FPGA PDP-8 is able to synthesize and run at over 75 MHz. This well over 100 times faster than the 1960's PDP-8.
A single PDP-8 processor core is less than 1000 LUTs. The MAX 10 FPGA could hold 50 such cores.
The GPS example included has a dual core build with one core displaying UTC time and another core displaying
a time zone adjusted local time (ICT - Bangkok - UTC+7).
This is done with 2 cores, each running their own GPS code to demonstrate the multi-core possibilities of a tiny but powerful cpu core in an fpga.

The PDP-8 source code is included for the GPS application.

## Installation

- Sources are provided for all tools
- Tools are built using Windows or Ubuntu (via WSL)

## To Do

- Add support for core memory fields to support 64k x 12 bit memory
	- Not a high priority for me ;-)

## Links

https://en.wikipedia.org/wiki/PDP-8


## License

Copyright (c) 2021 Ron K. Irvine

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction for private use, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The Software may not be used in connection with any commercial purposes, except as
specifically approved by Ron K. Irvine or his representative. Unauthorized usage of
the Software or any part of the Software is prohibited. Appropriate legal action
will be taken by us for any illegal or unauthorized use of the Software.

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
