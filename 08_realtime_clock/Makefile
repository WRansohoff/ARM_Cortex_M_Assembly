# Makefile for compiling ARM Cortex-M assembly projects.
TARGET = asm-firmware

# Default to M4F QFP32 12KB SRAM, 4KB CCMRAM, 32KB Flash.
#MCU ?= STM32F303K8
# ...or M4F QFP48 32KB SRAM, 8KB CCMRAM, 256KB Flash.
#MCU ?= STM32F303CC
# ...or M0+ TSSOP20 4KB SRAM, 16KB Flash.
MCU ?= STM32F030F4

# Linker scripts for memory allocation.
ifeq ($(MCU), STM32F303K8)
	CHIP_FILE = STM32F303K8T6
	MCU_CLASS = F3
else ifeq ($(MCU), STM32F303CC)
	CHIP_FILE = STM32F303CCT6
	MCU_CLASS = F3
else ifeq ($(MCU), STM32F030F4)
	CHIP_FILE = STM32F030F4T6
	MCU_CLASS = F0
endif

LD_SCRIPT = ${CHIP_FILE}.ld
VECT_TBL  = ./vector_tables/${CHIP_FILE}_vt.S
BOOT_FILE = ./boot/${CHIP_FILE}_boot.S

ifeq ($(MCU_CLASS), F0)
	MCU_SPEC = cortex-m0plus
else ifeq ($(MCU_CLASS), F3)
	MCU_SPEC = cortex-m4
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
ASFLAGS += -DVVC_$(MCU_CLASS)

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
	rm -f ./vector_tables/*.o
	rm -f ./boot/*.o
	rm -f $(TARGET).elf $(TARGET).bin
