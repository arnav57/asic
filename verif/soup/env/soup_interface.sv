`timescale 1ns/1ps

interface soup_interface (input logic clk, input logic rstn);
	logic rx_pad;
	logic tx_pad;
	logic cmd_done;
	logic error_flag;

	// signals for driving soup_send (Direct RTL Control)
	logic       start_data;
	logic [7:0] data_in;
	logic       soup_data_done;
	logic       fifo_wr_en;
	logic [7:0] fifo_wr_data;

	// synchronous monitoring!
	clocking mon_cb @(posedge clk);
	    default input #1ns output #1ns;
	    input rx_pad;
	    input tx_pad;
	    input cmd_done;
	    input error_flag;
	    input start_data;
	    input data_in;
	    input soup_data_done;
	    input fifo_wr_en;
	    input fifo_wr_data;
	endclocking

	// synchronous driving!
	clocking drv_cb @(posedge clk);
		default input #1ns output #1ns;
		output start_data;
		output data_in;
		output fifo_wr_en;
		output fifo_wr_data;
		input  soup_data_done;
	endclocking

endinterface : soup_interface
