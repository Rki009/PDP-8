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

## License

<!---
[MIT](https://choosealicense.com/licenses/mit/)
-->

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
