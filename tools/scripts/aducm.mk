#------------------------------------------------------------------------------
#                             EXPORTED VARIABLES                               
#------------------------------------------------------------------------------
# Used by nested Makefils (mbedtls, fatfs, iio)
export CFLAGS
export CC
export AR

#------------------------------------------------------------------------------
#                     PLATFORM SPECIFIC INITIALIZATION                               
#------------------------------------------------------------------------------

# New line variable
define ENDL


endef

# Initialize copy_fun and remove_fun
# Initialize CCES_HOME to default, if directory not found show error
#	WINDOWS
ifeq ($(OS), Windows_NT)
copy_fun = copy /Y /B "$(subst /,\,$1)" "$(subst /,\,$2)"
copy_folder = xcopy /S /Y /C /I "$(subst /,\,$1)" "$(subst /,\,$2)"
remove_fun = del /S /Q "$(subst /,\,$1)"
remove_dir = rd /S /Q "$(subst /,\,$1)"
mk_dir = md "$(subst /,\,$1)"
#cces works to but has no console output
CCES = ccesc
CCES_HOME ?= $(wildcard C:/Analog\ Devices/CrossCore*)
ifeq ($(CCES_HOME),)
$(error $(ENDL)$(ENDL)CCES_HOME not found at c:/Analog Devices/[CrossCore...]\
		$(ENDL)$(ENDL)\
Please run command "set CCES_HOME=c:\Analog Devices\[CrossCore...]"$(ENDL)\
Ex: set CCES_HOME=c:\Analog Devices\[CrossCore...] Embedded Studio 2.8.0$(ENDL)$(ENDL))
endif
#	LINUX
else
copy_fun = cp $(1) $(2)
copy_folder = cp -r $(1) $(2)
remove_fun = rm -rf $(1)
remove_dir = rm -rf $(1)
mk_dir = mkdir -p $(1)

CCES = cces
CCES_HOME ?= $(wildcard /opt/analog/cces/*)
ifeq ($(CCES_HOME),)
$(error $(ENDL)$(ENDL)CCES_HOME not found at /opt/analog/cces/[version_number]\
		$(ENDL)$(ENDL)\
		Please run command "export CCES_HOME=[cces_path]"$(ENDL)\
		Ex: export CCES_HOME=/opt/analog/cces/2.9.2$(ENDL)$(ENDL))
endif
endif

#Set PATH variables where used binaries are found
COMPILER_BIN = $(CCES_HOME)/ARM/gcc-arm-embedded/bin
OPENOCD_SCRIPTS = $(CCES_HOME)/ARM/openocd/share/openocd/scripts
OPENOCD_BIN = $(CCES_HOME)/ARM/openocd/bin
CCES_EXE = $(CCES_HOME)/Eclipse

export PATH := $(CCES_EXE):$(OPENOCD_SCRIPTS):$(OPENOCD_BIN):$(COMPILER_BIN):$(PATH)

#------------------------------------------------------------------------------
#                           ENVIRONMENT VARIABLES                              
#------------------------------------------------------------------------------
#SHARED to use in src.mk
PLATFORM		= aducm3029
PROJECT			= $(realpath .)
NO-OS			= $(realpath ../..)
DRIVERS			= $(NO-OS)/drivers
INCLUDE			= $(NO-OS)/include
PLATFORM_DRIVERS	= $(NO-OS)/drivers/platform/$(PLATFORM)

#USED IN MAKEFILE
PROJECT_NAME		= $(notdir $(PROJECT))
BUILD_DIR		= build
PROJECT_BUILD		= $(PROJECT)/project
WORKSPACE		= $(NO-OS)/projects

PLATFORM_TOOLS		= $(NO-OS)/tools/scripts/platform/$(PLATFORM)

BINARY			= $(BUILD_DIR)/$(PROJECT_NAME)
HEX			= $(PROJECT)/$(PROJECT_NAME).hex

#------------------------------------------------------------------------------
#                          FIX SPACES PROBLEM                              
#------------------------------------------------------------------------------

#If dfp have spaces, copy sources from dfp in platform_tools

ADUCM_DFP = $(wildcard \
$(call escape_spaces,$(CCES_HOME))/ARM/packs/AnalogDevices/ADuCM302x_DFP/*)

ifneq ($(words $(CCES_HOME)), 1)

ifeq ($(wildcard $(PLATFORM_TOOLS)/dfp_drivers),)
$(warning ERROR:$(ENDL)\
CCES_HOME dir have spaces. To avoid this you can install CCES in a path without\
spaces.$(ENDL)$(ENDL) Or you can copy the dfp into noos running:$(ENDL)$(ENDL)\
 make install_dfp$(ENDL))
else
DFP_DRIVERS = $(PLATFORM_TOOLS)/dfp_drivers
endif

else

DFP_DRIVERS = $(ADUCM_DFP)/Source/drivers

endif

#------------------------------------------------------------------------------
#                           MAKEFILE SOURCES                              
#------------------------------------------------------------------------------

include src.mk

#------------------------------------------------------------------------------
#                     SETTING LIBRARIES IF NEEDED                              
#------------------------------------------------------------------------------

#	MBEDTLS
#If network dir is included, mbedtls will be used
ifneq ($(if $(findstring $(NO-OS)/network, $(SRC_DIRS)), 1),)

LIBS_DIRS	+= -L=$(NO-OS)/libraries/mbedtls/library
LIBS		+= -lmbedtls -lmbedx509 -lmbedcrypto
INCLUDE_DIRS 	+= $(NO-OS)/libraries/mbedtls/include

CFLAGS += -I $(NO-OS)/network/transport \
	-D MBEDTLS_CONFIG_FILE='"noos_mbedtls_config.h"'
MAKE_MBEDTLS	= $(MAKE) -C $(NO-OS)/libraries/mbedtls lib
CLEAN_MBEDTLS	= $(MAKE) -C $(NO-OS)/libraries/mbedtls clean

endif

#	FATFS
#If fatfs is found in SRC_DIRS
ifneq ($(if $(findstring $(NO-OS)/libraries/fatfs, $(SRC_DIRS)), 1),)
#Remove fatfs from srcdirs because it is a library
SRC_DIRS := $(filter-out $(NO-OS)/libraries/fatfs, $(SRC_DIRS))

LIBS_DIRS	+= -L=$(NO-OS)/libraries/fatfs
LIBS		+= -lfatfs
INCLUDE_DIRS	+= $(NO-OS)/libraries/fatfs/source

CFLAGS += -I$(DRIVERS)/sd-card -I$(INCLUDE)
MAKE_FATFS	= $(MAKE) -C $(NO-OS)/libraries/fatfs
CLEAN_FATFS	= $(MAKE) -C $(NO-OS)/libraries/fatfs clean

endif

#------------------------------------------------------------------------------
#                           UTIL FUNCTIONS                              
#------------------------------------------------------------------------------

null :=
SPACE := $(null) $(null)

#This work for wildcards
escape_spaces = $(subst $(SPACE),\$(SPACE),$1)

# Transforme full path to relative path to be used in build
get_relative_path = $(patsubst $(NO-OS)%,noos%,$(patsubst $(PLATFORM_TOOLS)%,aducm3029%,$(patsubst $(PROJECT)%,project%,$1)))

# Transforme relative path to full path in order to find the needed .c files
get_full_path = $(patsubst noos%,$(NO-OS)%,$(patsubst aducm3029%,$(PLATFORM_TOOLS)%,$(patsubst project%,$(PROJECT)%,$1)))

# recursive wildcard
_rwildcard = $(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call _rwildcard,$d/,$2))

#------------------------------------------------------------------------------
#                             DFP DEPENDENCIES                          
#------------------------------------------------------------------------------

DFP_FILES += $(foreach dir, $(DFP_DRIVERS), $(call rwildcard, $(dir),*.c))

INCS_FLAGS += -I"$(CCES_HOME)/ARM/packs/AnalogDevices/ADuCM302x_DFP/3.2.0/include"
INCS_FLAGS += -I"$(CCES_HOME)/ARM/packs/ARM/CMSIS/5.6.0/CMSIS/Core/Include"

#Specific files needed on aducm_build that 
#if there is no projects
ifeq ($(wildcard $(PROJECT_BUILD)),)

AUX_DIR = $(PROJECT)/aux_src
SRCS += $(AUX_DIR)/adi_initialize.c
SRCS += $(AUX_DIR)/startup_ADuCM3029.c
SRCS += $(AUX_DIR)/system_ADuCM3029.c
INCLUDE_DIRS += $(AUX_DIR)

else

SRCS += $(PROJECT_BUILD)/system/adi_initialize.c
SRCS += $(PROJECT_BUILD)/RTE/Device/ADuCM3029/startup_ADuCM3029.c
SRCS += $(PROJECT_BUILD)/RTE/Device/ADuCM3029/system_ADuCM3029.c
INCLUDE_DIRS += $(PROJECT_BUILD)/RTE/Device/ADuCM3029
INCLUDE_DIRS += $(PROJECT_BUILD)/system

endif

#ALL directories containing a .h file
INCLUDE_DIRS += $(sort $(foreach dir, $(INCS),$(dir $(dir))))

#Use pinmux_config.c from project root if project created, from project
PIN_MUX = $(if $(wildcard $(PROJECT_BUILD))\
,$(PROJECT_BUILD)/system/pinmux/GeneratedSources/pinmux_config.c,pinmux_config.c)

ifeq ($(wildcard $(PIN_MUX)),)
$(warning pinmux_config.c not found neither in project neither in project root.\
Using default from platform tools)
PIN_MUX = $(PROJECT_BUILD)/autogenerated/pinmux_config.c
endif

SRCS += $(DFP_FILES) $(PIN_MUX)

OBJS = $(foreach file, $(SRCS), $(BUILD_DIR)/$(call get_relative_path,$(file)))
OBJS := $(patsubst %.c,%.o,$(OBJS))

#------------------------------------------------------------------------------
#                           COMPILING DATA                              
#------------------------------------------------------------------------------

INCS_FLAGS += $(addprefix -I,$(INCLUDE_DIRS))

CFLAGS +=	-O2				\
		-ffunction-sections		\
		-fdata-sections			\
		-DCORE0				\
		-DNDEBUG			\
		-D_RTE_				\
		-D__ADUCM3029__			\
		-D__SILICON_REVISION__=0xffff	\
		-Wall				\
		-c -mcpu=cortex-m3		\
		-mthumb				\
		$(INCS_FLAGS)		
#		-Werror

LINKER_FILE	= "$(ADUCM_DFP)/Source/GCC/ADuCM3029.ld"
LDFLAGS		= -T$(LINKER_FILE) -Wl,--gc-sections -mcpu=cortex-m3 -mthumb -lm

CC = arm-none-eabi-gcc
AR = arm-none-eabi-ar

#------------------------------------------------------------------------------
#                                 RULES                              
#------------------------------------------------------------------------------

# Build project Release Configuration
PHONY := all
ifeq ($(AUX_DIR),)
all: $(HEX)
else
all:
	$(MAKE) $(AUX_DIR)
	$(MAKE) $(HEX)
endif

PHONY += install_dfp
install_dfp:
	$(call copy_folder,$(ADUCM_DFP)/Source/drivers/*,$(PLATFORM_TOOLS)/dfp_drivers/)
#This is used to keep directory targets between makefile executions
#More details: http://ismail.badawi.io/blog/2017/03/28/automatic-directory-creation-in-make/
#Also the last . is explained
.PRECIOUS: $(BUILD_DIR)/. $(BUILD_DIR)%/. $(AUX_DIR)

#Will be executed only when no project
$(AUX_DIR):
	$(call mk_dir,$(AUX_DIR))
	$(call copy_fun,$(PLATFORM_TOOLS)/autogenerated/*,$(AUX_DIR)/)
	$(call copy_fun,$(ADUCM_DFP)/Include/config,$(AUX_DIR)/)
	$(call copy_fun,$(ADUCM_DFP)/Source/system_ADuCM3029.c,$(AUX_DIR)/)
	$(call copy_fun,$(ADUCM_DFP)/Source/GCC/startup_ADuCM3029.c,$(AUX_DIR)/)
#TODO Replace with patch if team think is a better aproch to install a windows
#program for patching	
	$(call copy_fun,$(PLATFORM_TOOLS)/patches/startup_ADuCM3029.c\
			,$(AUX_DIR)/startup_ADuCM3029.c)

$(BUILD_DIR)/.:
	@$(call mk_dir,$@)

$(BUILD_DIR)%/.:
	@$(call mk_dir,$@)

.SECONDEXPANSION:
$(BUILD_DIR)/%.o: $$(call get_full_path, %).c | $$(@D)/.
	@echo CC -c $(notdir $<) -o $(notdir $@)
	@$(CC) -c $(CFLAGS) $< -o $@

$(BINARY): $(OBJS)
	@echo CC LDFLAGS -o $(BINARY) OBJS INCS_FLAGS
	@$(CC) $(LDFLAGS) -o $(BINARY) $(OBJS) $(INCS_FLAGS)

$(HEX): $(BINARY)
	arm-none-eabi-objcopy -O ihex $(BINARY) $(HEX)

PHONY += libs
libs:
	$(MAKE_MBEDTLS)
	$(MAKE_FATFS)

# Upload binary to target
PHONY += run
run: all
	openocd -f interface\cmsis-dap.cfg \
		-s "$(ADUCM_DFP)/openocd/scripts" -f target\aducm3029.cfg \
		-c "program  $(subst \,/,$(BINARY)) verify reset exit"

# Remove project binaries
PHONY += clean
clean:
	-$(call remove_fun,$(HEX))
	-$(call remove_dir,$(BUILD_DIR))
	-$(call remove_dir,$(AUX_DIR))
	-$(CLEAN_MBEDTLS)
	-$(CLEAN_FATFS)

# Rebuild porject. SHould we delete project and workspace or just a binary clean?
PHONY += re
re: clean all

PHONY += ra
ra: clean_all
	$(MAKE) all

# Remove workspace data and project directory
PHONY += clean_all
clean_all:
	$(MAKE) clean
	-$(call remove_dir,$(WORKSPACE)/.metadata)
	-$(call remove_fun,*.target)
	-$(call remove_dir,$(PROJECT_BUILD))

#------------------------------------------------------------------------------
#                             PROJECT RULES                              
#------------------------------------------------------------------------------

PROJECT_BINARY = $(PROJECT_BUILD)/Release/$(PROJECT_NAME)

#Flags for each include directory
INCLUDE_FLAGS = $(foreach dir, $(INCLUDE_DIRS),\
		-append-switch compiler -I=$(dir))
#Flags for each linked resource
SRC_FLAGS = $(foreach dir,$(SRC_DIRS),\
		-link $(dir) $(call get_relative_path,$(dir)))
#Lib flags
LIB_FLAGS = $(foreach lib,$(LIBS), -append-switch linker $(lib))
#Lib directory flags
LIB_DIRS_FLAGS = $(foreach dir,$(LIBS_DIR), -append-switch linker $(dir))

#This way will not work if the rest button is press or if a printf is executed
#because there is a bug in crossCore that doesn't enable to remove semihosting
#from command line. If semihosting is removed from the IDE this will work to
#CCESS bug: https://labrea.ad.analog.com/browse/CCES-22274
PHONY += project_run
project_run: build_project
	openocd -f interface\cmsis-dap.cfg \
		-s "$(ADUCM_DFP)/openocd/scripts" -f target\aducm3029.cfg \
	-c init \
	-c "program  $(subst \,/,$(PROJECT_BINARY)) verify" \
	-c "arm semihosting enable" \
	-c "reset run" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c "resume" \
	-c exit

PHONY += build_project
build_project: libs $(PROJECT_BUILD)/project.target
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
		-data $(WORKSPACE) \
		-project $(PROJECT_NAME) \
		-build Release

PHONY += project
project: update_project

PHONY += update_project
update_project: $(PROJECT_BUILD)/project.target
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
		-data $(WORKSPACE) \
		-project $(PROJECT_NAME) \
		$(INCLUDE_FLAGS) \
		$(SRC_FLAGS) \
		$(LIB_FLAGS)\
		$(LIB_DIRS_FLAGS)

#Create new project with platform driver and utils source folders linked
$(PROJECT_BUILD)/project.target:
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
		-command projectcreate \
		-data $(WORKSPACE) \
		-project $(PROJECT_BUILD) \
		-project-name $(PROJECT_NAME) \
		-processor ADuCM3029 \
		-type Executable \
		-revision any \
		-language C \
		-config Release \
		-remove-switch linker -specs=rdimon.specs
#Overwrite system.rteconfig file with one that enables all DFP feautres neede by noos
	$(call copy_fun,$(PLATFORM_TOOLS)/system.rteconfig,$(PROJECT_BUILD))
#Adding pinmux plugin (Did not work to add it in the first command) and update project
	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
 		-command addaddin \
 		-data $(WORKSPACE) \
 		-project $(PROJECT_NAME) \
 		-id com.analog.crosscore.ssldd.pinmux.component \
		-version latest \
		-regensrc
#The default startup_ADuCM3029.c has compiling errors
#TODO replace with patch
	$(call copy_fun\
	,$(PLATFORM_TOOLS)/patches/startup_ADuCM3029.c,$(PROJECT_BUILD)/RTE/Device/ADuCM3029)
#Remove default files from projectsrc
	$(call remove_fun,$(PROJECT_BUILD)/src/*)
	$(if $(wildcard pinmux_config.c),\
		$(call copy_fun,pinmux_config.c\
		,$(PROJECT_BUILD)/system/pinmux/GeneratedSources))
	@echo This shouldn't be removed or edited > $@

PHONY += clean_project
clean_project:
	-$(call remove_dir,$(PROJECT_BUILD)/Release)
#OR	
#	$(CCES) -nosplash -application com.analog.crosscore.headlesstools \
 		-data $(WORKSPACE) \
 		-project $(PROJECT_NAME) \
 		-cleanOnly all

.PHONY: $(PHONY)