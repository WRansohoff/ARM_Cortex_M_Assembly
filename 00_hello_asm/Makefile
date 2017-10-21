# Makefile for compiling ARM Cortex-M assembly projects.
TARGET = asm-firmware

# Default to TSSOP-20 4KB/16KB
MCU ?= STM32F030F4

# Linker scripts for memory allocation.
ifeq ($(MCU), STM32F030F4)
	# STM32 naming conventions: STM32 [LFH] m xy p r tt
	#   [LFH]
	#     L  = low-power (although some Fxx8 chips can operate on 1.8V too)
	#     F  = general-purpose
	#     H  = ultra-high performance
	#   m  = MCU class. F0 and L0 chips are Cortex-M0+ (m=0)
	#   xy = more specific identifier, indicates chip capabilities.
	#   p  = package footprint. 'F' means '20-pin TSSOP' here.
	#        'K', 'C', and 'R' are common; 32-, 48-, and 64-pin QFPs.
	#   f  = flash storage. Higher numbers means more program space.
	#        Here, 4 = 16KB, 6 = 32KB.
	#   tt = temperature coefficient. 'T6' is the standard operating range.
	LD_SCRIPT = STM32F030F4T6.ld
	MCU_CLASS = F0
else ifeq ($(MCU), STM32F038F6)
	# (Untested, just as an example of
	# supporting multiple similar MCUs.
	# The -F038 is designed for low-power
	# applications and may need more init.)
	LD_SCRIPT = STM32F038F6T6.ld
	MCU_CLASS = F0
endif

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
# (Set messages to appear on a single line.)
ASFLAGS += -fmessage-length=0

# Linker directives.
LFLAGS += -nostdlib
LFLAGS += -static
# For this example, no linker scripts; just put the whole program at the base
# program memory space address.
LFLAGS += -Ttext 0x8000000

# (For use in preprocessor directives)
OPTS += -D$(MCU)

# (I think the capital 'S' means that gcc will pay attention to things like #define)
AS_SRC += ./main.S
OBJS = $(AS_SRC:.S=.o)

.PHONY: all
all: $(TARGET).bin

# (Use GCC instead of AS to technically do the assembling.)
%.o: %.S
	$(CC) -x assembler-with-cpp -c $(ASFLAGS) $< -o $@

$(TARGET).elf: $(OBJS)
	$(LD) $(LFLAGS) $^ -o $@

$(TARGET).bin: $(TARGET).elf
	$(OC) -S -O binary $< $@
	$(OS) $<

.PHONY: clean
clean:
	rm -f $(OBJS)
	rm -f $(TARGET).elf $(TARGET).bin
