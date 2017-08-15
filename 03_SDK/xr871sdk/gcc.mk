#
# Common rules for GCC Makefile
#

# ----------------------------------------------------------------------------
# cross compiler
# ----------------------------------------------------------------------------
CC_DIR := ~/tools/gcc-arm-none-eabi-4_9-2015q2/bin
CC_PREFIX := $(CC_DIR)/arm-none-eabi-

AS      := $(CC_PREFIX)as
CC      := $(CC_PREFIX)gcc
CPP     := $(CC_PREFIX)g++
LD      := $(CC_PREFIX)ld
AR      := $(CC_PREFIX)ar
OBJCOPY := $(CC_PREFIX)objcopy
OBJDUMP := $(CC_PREFIX)objdump
SIZE    := $(CC_PREFIX)size
STRIP   := $(CC_PREFIX)strip

# ----------------------------------------------------------------------------
# tools
# ----------------------------------------------------------------------------
CP := cp -u

# $(MKIMAGE) is a tool for creating image
ifeq ($(shell uname -o), Cygwin)
  MKIMAGE := mkimage.exe
else
  MKIMAGE := mkimage
endif

# ----------------------------------------------------------------------------
# global configuration
# ----------------------------------------------------------------------------
include $(ROOT_PATH)/config.mk

# ----------------------------------------------------------------------------
# options
# ----------------------------------------------------------------------------
QUIET ?= n
OPTIMIZE := y
MDK_DBG_EN := y
HARDFP := n

# building display
ifeq ($(QUIET), y)
  Q := @
  S := -s
endif

ifeq ($(OPTIMIZE), y)
  OPTIMIZE_FLAG := -Os -DNDEBUG
else
  OPTIMIZE_FLAG := -O0 -DDEBUG
endif

ifeq ($(MDK_DBG_EN), y)
  DBG_FLAG := -gdwarf-2
else
  DBG_FLAG := -g
endif

ifeq ($(HARDFP), y)
  FLOAT_ABI := hard
else
  FLOAT_ABI := softfp
endif

# ----------------------------------------------------------------------------
# flags for compiler and linker
# ----------------------------------------------------------------------------
# CPU/FPU options
ifeq ($(__CONFIG_CPU_CM4F), y)
  CPU := -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=$(FLOAT_ABI)
else
  CPU := -mcpu=cortex-m3 -mthumb
endif

CC_FLAGS = $(CPU) -c $(DBG_FLAG) -fno-common -fmessage-length=0 \
	-fno-exceptions -ffunction-sections -fdata-sections -fomit-frame-pointer \
	-MMD -MP -Wall -Werror $(OPTIMIZE_FLAG)

# config symbols
CC_SYMBOLS = $(CONFIG_SYMBOLS)
AS_SYMBOLS = $(CONFIG_SYMBOLS)

LD_FLAGS = $(CPU) -Wl,--gc-sections --specs=nano.specs \
	-Wl,-Map=$(basename $@).map,--cref

ifeq ($(__CONFIG_LIBC_PRINTF_FLOAT), y)
  LD_FLAGS += -u _printf_float
endif

ifeq ($(__CONFIG_LIBC_SCANF_FLOAT), y)
  LD_FLAGS += -u _scanf_float
endif

LD_FLAGS += -Wl,--wrap,main
LD_FLAGS += -Wl,--wrap,malloc
LD_FLAGS += -Wl,--wrap,realloc
LD_FLAGS += -Wl,--wrap,free
LD_FLAGS += -Wl,--wrap,_malloc_r
LD_FLAGS += -Wl,--wrap,_realloc_r
LD_FLAGS += -Wl,--wrap,_free_r
ifeq ($(__CONFIG_MALLOC_TRACE), y)
LD_FLAGS += -Wl,--wrap,calloc
LD_FLAGS += -Wl,--wrap,strdup
endif

# standard libraries
LD_SYS_LIBS := -lstdc++ -lsupc++ -lm -lc -lgcc -lnosys

# include path
INCLUDE_ROOT_PATH := $(ROOT_PATH)/include
INCLUDE_PATHS = -I$(INCLUDE_ROOT_PATH) \
	-I$(INCLUDE_ROOT_PATH)/libc \
	-I$(INCLUDE_ROOT_PATH)/driver/cmsis

ifeq ($(__CONFIG_OS_FREERTOS), y)
  INCLUDE_PATHS += -I$(INCLUDE_ROOT_PATH)/kernel/FreeRTOS
  ifeq ($(__CONFIG_CPU_CM4F), y)
    INCLUDE_PATHS += -I$(INCLUDE_ROOT_PATH)/kernel/FreeRTOS/portable/GCC/ARM_CM4F
  else
    INCLUDE_PATHS += -I$(INCLUDE_ROOT_PATH)/kernel/FreeRTOS/portable/GCC/ARM_CM3
  endif
endif

ifneq ($(__CONFIG_BOOTLOADER), y)
  INCLUDE_PATHS += -I$(INCLUDE_ROOT_PATH)/net/lwip \
	-I$(INCLUDE_ROOT_PATH)/net/lwip/ipv4
endif

# ----------------------------------------------------------------------------
# common makefile for library and project
# ----------------------------------------------------------------------------
LIB_MAKE_RULES := $(ROOT_PATH)/src/lib.mk
PRJ_MAKE_RULES := $(ROOT_PATH)/project/project.mk

# ----------------------------------------------------------------------------
# common rules of compiling objects
# ----------------------------------------------------------------------------
%.o: %.asm
	$(Q)$(CC) $(CPU) $(AS_SYMBOLS) -c -x assembler-with-cpp -o $@ $<

%.o: %.s
	$(Q)$(CC) $(CPU) $(AS_SYMBOLS) -c -x assembler-with-cpp -o $@ $<

%.o: %.S
	$(Q)$(CC) $(CPU) $(AS_SYMBOLS) -c -x assembler-with-cpp -o $@ $<

%.o: %.c
	$(Q)$(CC) $(CC_FLAGS) $(CC_SYMBOLS) -std=gnu99 $(INCLUDE_PATHS) -o $@ $<

%.o: %.cpp
	$(Q)$(CPP) $(CC_FLAGS) $(CC_SYMBOLS) -std=gnu++98 -fno-rtti $(INCLUDE_PATHS) -o $@ $<
