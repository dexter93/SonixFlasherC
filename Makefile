# try to do some autodetecting
UNAME := $(shell uname -s)
ARCH := $(shell uname -m)

ifeq "$(UNAME)" "Darwin"
	OS=macos
endif
ifeq "$(OS)" "Windows_NT"
	OS=windows
endif
ifeq "$(UNAME)" "Linux"
	OS=linux
endif

# deal with stupid Windows not having 'cc'
ifeq (default,$(origin CC))
  CC = gcc
endif

# Static linking flag
STATIC ?= 0

#############  Mac
ifeq "$(OS)" "macos"

ifeq "$(STATIC)" "1"
	CFLAGS+=-Wall -I/opt/homebrew/include/hidapi
	LIBS=/opt/homebrew/lib/libhidapi.a -framework IOKit -framework CoreFoundation -framework AppKit
else
	CFLAGS+=`pkg-config hidapi --cflags`
	LIBS=-lhidapi -framework IOKit -framework CoreFoundation -framework AppKit
endif
EXE=

endif

############# Windows
ifeq "$(OS)" "windows"

ifeq "$(STATIC)" "1"
	CFLAGS+=-Wall -I/mingw64/include/hidapi
	LIBS=/mingw64/lib/libhidapi.a -lsetupapi -lwinmm -lws2_32 -static-libgcc
else
	CFLAGS+=`pkg-config hidapi --cflags`
	LIBS+=-lhidapi -lsetupapi -Wl,--enable-auto-import
endif
EXE=.exe

endif

############ Linux (hidraw)
ifeq "$(OS)" "linux"

ifeq "$(STATIC)" "1"
	CFLAGS+=-Wall -I/usr/local/include/hidapi
	LIBS=/usr/local/lib/libhidapi-libusb.a -lusb-1.0 -ludev -lpthread
else
	LIBS = `pkg-config libudev --libs`
	CFLAGS+=`pkg-config hidapi-libusb --cflags`
	LIBS+=`pkg-config hidapi-libusb --libs`
endif
EXE=

endif


############# common

CFLAGS+=-Wall
OBJS += sonixflasher.o

all: sonixflasher

$(OBJS): %.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@


sonixflasher: $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o sonixflasher$(EXE) $(LIBS)
ifeq "$(STATIC)" "1"
	strip sonixflasher$(EXE)
endif

static:
	$(MAKE) STATIC=1

clean:
	rm -f $(OBJS)
	rm -f sonixflasher$(EXE)

package: sonixflasher$(EXE)
	@echo "Packaging up sonixflasher for '$(OS)-$(ARCH)'"
	7z a sonixflasher-$(OS)-$(ARCH).zip sonixflasher$(EXE)

.PHONY: all static clean package