# base_config.mk
all: run_and_clean

### ENV VARS
export VERIF_ROOT  := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export WS_ROOT     := $(abspath $(VERIF_ROOT)/..)
export DESIGN_ROOT := $(WS_ROOT)/design
export PYTHONPATH  := $(VERIF_ROOT):$(PYTHONPATH)

### COCOTB STUFF
SIM ?= questa
TOPLEVEL_LANG ?= verilog
SIM_ARGS += -voptargs="+acc"
WAVES ?= 1
export COCOTB_LOG_LEVEL := INFO
export PYTHONUNBUFFERED := 1

# --- Build Directory Management ---
export SIM_DIR := $(WS_ROOT)/sim
$(shell mkdir -p $(SIM_DIR))

ifeq ($(TIMESTAMP),)
export TIMESTAMP := $(shell date +"%Y%m%d_%H%M%S")
endif

export SIM_BUILD := $(SIM_DIR)/$(MODULE)_$(TIMESTAMP)
$(shell mkdir -p $(SIM_BUILD))

export COCOTB_RESULTS_FILE := $(SIM_BUILD)/results.xml

# --- Questa File Routing ---
# 1. Sneakily create modelsim.ini in the build folder BEFORE cocotb checks the version
$(shell cd $(SIM_BUILD) && vmap -c > /dev/null 2>&1)

# 2. Now it's safe to export this globally
export MODELSIM := $(SIM_BUILD)/modelsim.ini

SIM_ARGS += -l $(SIM_BUILD)/transcript
SIM_ARGS += -wlf $(SIM_BUILD)/vsim.wlf


# waveform adding (wave dump on by default)
ifeq ($(WAVES),1)
   $(shell echo "log -r /*" > wave_log.do)
   SIM_ARGS += -do wave_log.do
endif


# include actual cocotb makefile
include $(shell cocotb-config --makefiles)/Makefile.sim

debug:
	@echo "Using the following env vars..."
	@echo "WS_ROOT:    $(WS_ROOT)"
	@echo "VERIF_ROOT: $(VERIF_ROOT)"
	@echo "DESIGN_ROOT:$(DESIGN_ROOT)"
	@echo ""
	@echo ""

run_and_clean: debug sim
	@echo ""
	@echo ""
	@echo "Opening Waveform Viewer..."
	@vsim -view $(SIM_BUILD)/vsim.wlf
	@echo ""
	@echo ""
	@echo "Moving residual files.."
	@-mv modelsim.ini transcript vsim.wlf wave_log.do $(SIM_BUILD)/ > /dev/null 2>&1 || true
