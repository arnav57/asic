`timescale 1ns/1ps

interface uart_tx_interface (input logic clk, input logic rstn);

	logic 		tx_data_o;
	logic [7:0] tx_data_i;
	logic 		tx_data_valid_i;
	logic		tx_busy_o;
endinterface : uart_tx_interface