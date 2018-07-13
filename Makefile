.PHONY: all

LUACPATH ?= luacpath
ZLIBPATH ?= zlib
include silly/Platform.mk

linux macosx: all

CCFLAG += -I./silly/deps/lua/
CCFLAG += -I./zlib/

all:\
	$(LUACPATH)\
	$(LUACPATH)/gzip.so\
	$(LUACPATH)/iconv.so\

$(LUACPATH):
	mkdir $(LUACPATH)

$(LUACPATH)/gzip.so:lualib-src/lgzip.c $(ZLIBPATH)/libz.a
	$(CC) $(CCFLAG) -o $@ $^ $(SHARED)

$(LUACPATH)/iconv.so:lualib-src/luaiconv.c
	$(CC) $(CCFLAG) -o $@ $^ $(SHARED)

$(ZLIBPATH)/libz.a:$(ZLIBPATH)/Makefile
	make -C $(ZLIBPATH)

$(ZLIBPATH)/Makefile:$(ZLIBPATH)/configure
	cd $(ZLIBPATH);./configure;cd ../

$(ZLIBPATH)/configure:
	git submodule update --init

clean:
	rm -rf $(LUACPATH)

