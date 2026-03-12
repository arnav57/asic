`timescale 1ns/1ps

import uvm_pkg::*;
import uart_env_pkg::*; // how nice is UVM man ohmyfuckinggod
import soup_env_pkg::*;
`include "uvm_macros.svh"


module soup_tb_top;

	// start by declarating clock and rstn
	reg clk, rstn;

	// drive rstn and clock
	initial begin
		clk = 1;
		forever #10 clk = ~clk;
	end
	initial begin
		rstn = 0;
		#300;
		rstn = 1;
	end


	// instantiate both uart and soup interface
	soup_interface u_soup_if (
		.clk(clk),
		.rstn(rstn)
	);

	// instantiate DUT
	soup_top #(
		.LOGIC_FREQ (50_000_000),
		.BAUD_RATE  (115_200),
		.UART_LENGTH(10)
	) dut (
		.PAD_RX     (u_soup_if.pad_rx),
		.PAD_TX     (u_soup_if.pad_tx),
		.soup_clk_i (u_soup_if.clk),
		.soup_rstn_i(u_soup_if.rstn),
		.dbg_data_o ( /* FLOATING */ ),
		.cmd_done_o (u_soup_if.cmd_done)
	);

	// pass the interface into uvm-cfg-db
	initial begin
		uvm_config_db#(virtual soup_interface)::set(null, "*", "soup_vif", u_soup_if);
		run_test("soup_base_test");
	end
