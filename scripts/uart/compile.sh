#!/bin/bash

iverilog -g2012 -y ../../design/std/ -y ../../design/uart/ -Y .sv -o output ../../verif/uart/tb_uart_rx.sv

./output

gtkwave ./uart_rx.vcd