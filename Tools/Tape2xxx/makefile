
src := $(wildcard *.cpp)
exe := $(patsubst %.cpp,%.exe,$(wildcard *.cpp))

.PHONY: all clean clobber

all: $(exe)
	
%.exe: %.cpp
	# cmd.exe /C bcc32x "$<" getopt.c -o "$@"
	# rm -f *.tds
	# gcc -Ofast -Wall -o $@ $<
	x86_64-w64-mingw32-gcc -Ofast -Wall -o $@ $<
	
install:
	cp *.exe ../bin

clean:
	
clobber: clean
	rm $(exe)

