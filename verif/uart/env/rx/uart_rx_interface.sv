`timescale 1ns/1ps

interface uart_rx_interface (input logic clk, input logic rstn);

	logic 		rx_data_i;
	logic [7:0] rx_data_o;
	logic 		rx_data_valid_o;
endinterface : uart_rx_interface