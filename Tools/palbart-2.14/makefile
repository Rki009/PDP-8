
VER=2.14
PROJ=palbart-$(VER)

.PHONY: all

all: $(PROJ).exe

$(PROJ).exe: $(PROJ).c
	gcc -Ofast -Wall -o $@ $<
	x86_64-w64-mingw32-gcc -Ofast -Wall -o $@ $<
	
install: $(PROJ).exe
	cp $< ../bin

clean:
	rm -fr $(PROJ).exe

