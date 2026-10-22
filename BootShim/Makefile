ARCH              = arm64
TARGET            = aarch64-linux-gnu
CC                = clang
CFLAGS            = --target=$(TARGET)
OBJCOPY           = llvm-objcopy

# Optional bring-up marker (see BootShim.S): 1 = paint progress bands into the
# bootloader framebuffer before entering EDK2, 0 = leave the splash untouched.
PAINT_MARKER      ?= 0

all: BootShim.elf BootShim.bin

BootShim.bin: BootShim.elf
	$(OBJCOPY) -O binary $< $@

BootShim.elf: BootShim.S
	$(CC) ${CFLAGS} -c $< -o $@ -DREQUIRES_KERNEL_HEADER=$(REQUIRES_KERNEL_HEADER) -DFD_BASE=$(FD_BASE) -DFD_SIZE=$(FD_SIZE) -DPAINT_MARKER=$(PAINT_MARKER)

BootShim.S:
