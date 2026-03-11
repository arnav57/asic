interface uart_if(input logic clk, input logic rstn);
	logic 		rx_data_i;
	logic [7:0] rx_data_o;
	logic 		rx_data_valid_o;
endinterface : uart_if