`timescale 1ns/1ps

interface soup_interface (input logic clk, input logic rstn);
	logic rx_pad;
	logic tx_pad;
	logic cmd_done;
	logic error_flag;

	// synchronous monitoring!
	clocking mon_cb @(posedge clk);
	    default input #1ns output #1ns;
	    input rx_pad;
	    input tx_pad;
	    input cmd_done;
	    input error_flag;
	endclocking
endinterface : soup_interface