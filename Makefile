# try to do some autodetecting
UNAME := $(shell uname -s)
ARCH := $(shell uname -m)

ifeq ($(UNAME),Darwin)
	OS := macos
else ifeq ($(UNAME),Linux)
	OS := linux
else ifneq ($(findstring MINGW,$(UNAME)),)
	OS := windows
else ifneq ($(findstring MSYS,$(UNAME)),)
	OS := windows
else ifeq ($(OS),Windows_NT)
	OS := windows
endif

# deal with stupid Windows not having 'cc'
ifeq (default,$(origin CC))
  CC = gcc
endif

# Select USB backend: libusb (default) or hidapi
BACKEND ?= libusb
STATIC ?= 0
PKG_CONFIG ?= pkg-config

ifeq ($(BACKEND),hidapi)
ifeq ($(OS),macos)
PKG_NAME = hidapi
else ifeq ($(OS),linux)
PKG_NAME = hidapi-libusb
else ifeq ($(OS),windows)
PKG_NAME = hidapi
else
$(error Unsupported OS for BACKEND=hidapi)
endif
else ifeq ($(BACKEND),libusb)
PKG_NAME = libusb-1.0
else
$(error Unsupported BACKEND='$(BACKEND)')
endif

define check_pkg_config
	@$(PKG_CONFIG) --exists $(PKG_NAME) || \
	  (echo "error: pkg-config package '$(PKG_NAME)' was not found" >&2; \
	   echo "       install the development package and try again" >&2; \
	   exit 1)
endef

ifeq "$(OS)" "macos"

ifeq "$(BACKEND)" "hidapi"
CFLAGS += $(shell $(PKG_CONFIG) --cflags $(PKG_NAME))
LIBS += $(shell $(PKG_CONFIG) --libs $(PKG_NAME))
SRCS_BACKEND = src/usb_device_hidapi.c
else ifeq "$(BACKEND)" "libusb"
CFLAGS += $(shell $(PKG_CONFIG) --cflags $(PKG_NAME))
ifeq "$(STATIC)" "1"
LIBS += $(shell $(PKG_CONFIG) --static --libs $(PKG_NAME))
else
LIBS += $(shell $(PKG_CONFIG) --libs $(PKG_NAME))
endif
SRCS_BACKEND = src/usb_device_libusb.c
endif

LIBS += -framework IOKit -framework CoreFoundation -framework AppKit
EXE=

endif

ifeq "$(OS)" "windows"

ifeq "$(BACKEND)" "hidapi"
CFLAGS += $(shell $(PKG_CONFIG) --cflags $(PKG_NAME))
LIBS += $(shell $(PKG_CONFIG) --libs $(PKG_NAME))
SRCS_BACKEND = src/usb_device_hidapi.c
else ifeq "$(BACKEND)" "libusb"
CFLAGS += $(shell $(PKG_CONFIG) --cflags $(PKG_NAME))
ifeq "$(STATIC)" "1"
LIBS += $(shell $(PKG_CONFIG) --static --libs $(PKG_NAME))
else
LIBS += $(shell $(PKG_CONFIG) --libs $(PKG_NAME))
endif
SRCS_BACKEND = src/usb_device_libusb.c
endif

LIBS += -lsetupapi -lwinmm -lole32 -static-libgcc
EXE=.exe

endif

ifeq "$(OS)" "linux"

ifeq "$(BACKEND)" "hidapi"
CFLAGS += $(shell $(PKG_CONFIG) --cflags $(PKG_NAME))
LIBS += $(shell $(PKG_CONFIG) --libs $(PKG_NAME))
SRCS_BACKEND = src/usb_device_hidapi.c
else ifeq "$(BACKEND)" "libusb"
CFLAGS += $(shell $(PKG_CONFIG) --cflags $(PKG_NAME))
ifeq "$(STATIC)" "1"
LIBS += $(shell $(PKG_CONFIG) --static --libs $(PKG_NAME))
else
LIBS += $(shell $(PKG_CONFIG) --libs $(PKG_NAME))
endif
SRCS_BACKEND = src/usb_device_libusb.c
endif

EXE=

endif

SRCS := $(filter-out src/usb_device_hidapi.c src/usb_device_libusb.c,$(wildcard src/*.c)) $(SRCS_BACKEND)
OBJS := $(SRCS:.c=.o)

CFLAGS += -Wall -Iinclude
CLANG ?= clang

all: sonixflasher
	@echo "Built with BACKEND=$(BACKEND) STATIC=$(STATIC)"

src/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

sonixflasher: $(OBJS)
	$(call check_pkg_config)
	$(CC) $(CFLAGS) $(OBJS) -o $@$(EXE) $(LIBS)
ifeq "$(STATIC)" "1"
	strip $@$(EXE)
endif

.PHONY: release
release:
	$(MAKE) clean
	$(MAKE) STATIC=1 BACKEND=libusb all

clean:
	rm -f $(OBJS)
	rm -f sonixflasher$(EXE)

package: sonixflasher$(EXE)
	@echo "Packaging up sonixflasher for '$(OS)-$(ARCH)'"
	7z a sonixflasher-$(OS)-$(ARCH).zip sonixflasher$(EXE)

WARNINGS = \
	-Wall \
	-Wextra \
	-Wpedantic \
	-Werror \
	-Wmissing-prototypes \
	-Wstrict-prototypes \
	-Wmissing-declarations \
	-Wold-style-definition \
	-Wshadow \
	-Wformat=2 \
	-Wundef \
	-Wvla \
	-Wwrite-strings \
	-Wcast-qual \
	-Wpointer-arith \
	-Wconversion \
	-Wsign-conversion \
	-Wdouble-promotion \
	-Wnull-dereference

.PHONY: lint-compile
lint-compile:
	@echo "Syntax-checking with $(CLANG) (BACKEND=$(BACKEND))..."
	@for src in $(SRCS); do \
		echo "  $$src"; \
		$(CLANG) $(CFLAGS) $(WARNINGS) -fsyntax-only $$src || exit 1; \
	done