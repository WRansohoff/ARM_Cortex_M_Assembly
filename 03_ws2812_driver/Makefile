# Makefile for compiling ARM Cortex-M assembly projects.
TARGET = asm-firmware

# Default to TSSOP-20 4KB/16KB
MCU ?= STM32F030F4

# Linker scripts for memory allocation.
ifeq ($(MCU), STM32F030F4)
	CHIP_FILE = STM32F030F4T6
	MCU_CLASS = F0
else ifeq ($(MCU), STM32F038F6)
	CHIP_FILE = STM32F038F6T6
	MCU_CLASS = F0
endif

LD_SCRIPT = ${CHIP_FILE}.ld
VECT_TBL  = ./vector_tables/${CHIP_FILE}_vt.S
BOOT_FILE = ./boot/${CHIP_FILE}_boot.S

# For now, just Cortex-M0+
ifeq ($(MCU_CLASS), F0)
	MCU_SPEC = cortex-m0plus
endif

# Toolchain definition (ARM bare metal)
TOOLCHAIN = /usr
CC = $(TOOLCHAIN)/bin/arm-none-eabi-gcc
AS = $(TOOLCHAIN)/bin/arm-none-eabi-as
LD = $(TOOLCHAIN)/bin/arm-none-eabi-ld
OC = $(TOOLCHAIN)/bin/arm-none-eabi-objcopy
OD = $(TOOLCHAIN)/bin/arm-none-eabi-objdump
OS = $(TOOLCHAIN)/bin/arm-none-eabi-size

# Assembly directives.
ASFLAGS += -mcpu=$(MCU_SPEC)
ASFLAGS += -mthumb
ASFLAGS += -Wall
#ASFLAGS += -c
# (Set error messages to appear on a single line.)
ASFLAGS += -fmessage-length=0
# For preprocessor definitions:
ASFLAGS += -D$(MCU)

# Linker directives.
LSCRIPT = ./ld/$(LD_SCRIPT)
LFLAGS += -nostdlib
LFLAGS += -static
LFLAGS += -T$(LSCRIPT)

AS_SRC += ./src/main.S
AS_SRC += ./src/util.S
AS_SRC += $(VECT_TBL)
AS_SRC += $(BOOT_FILE)
OBJS = $(AS_SRC:.S=.o)

.PHONY: all
all: $(TARGET).bin

#$(AS) -mthumb -mcpu=cortex-m0plus $< -o $@
%.o: %.S
	$(CC) -x assembler-with-cpp -c -O0 $(ASFLAGS) $< -o $@

$(TARGET).elf: $(OBJS)
	$(LD) $(LFLAGS) $^ -o $@

$(TARGET).bin: $(TARGET).elf
	$(OC) -S -O binary $< $@
	$(OS) $<

.PHONY: clean
clean:
	rm -f $(OBJS)
	rm -f $(TARGET).elf $(TARGET).bin
