
src := $(wildcard *.cpp)
exe := $(patsubst %.cpp,%.exe,$(wildcard *.cpp))

.PHONY: all clean clobber

all: disasm8.exe
	
%.exe: %.cpp
	cmd.exe /C bcc32x "$<" getopt.c -o "$@"
	rm -f *.tds
	
install:
	copy disasm.exe ../bin

clean:
	
clobber: clean
	del disasm.exe

