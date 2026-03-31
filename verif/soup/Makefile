# verif/soup/Makefile

# 1. Basic Metadata
MODULE   := test_soup
TOPLEVEL := soup_top

# 2. Add Sources for soup_top
VERILOG_SOURCES += $(DESIGN_ROOT)/soup/soup_pkg.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/soup/soup_cmd_decode.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/soup/soup_rcv.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/soup/soup_send.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/soup/soup_top.sv
# Dependency modules
VERILOG_SOURCES += $(DESIGN_ROOT)/uart/uart_rx.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/uart/uart_tx.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/uart/uart_top.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/fifo/fifo.sv
VERILOG_SOURCES += $(DESIGN_ROOT)/std/std_data_sync.sv

# 3. Include common base configuration
include $(abspath ../base_config.mk)
