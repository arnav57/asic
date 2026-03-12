`timescale 1ns/1ps

import uvm_pkg::*;
import uart_env_pkg::*;
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


	// instantiate interfaces
	soup_interface u_soup_if (.clk(clk), .rstn(rstn));
	uart_rx_interface u_uart_rx_if (.clk(clk), .rstn(rstn));
	uart_tx_interface u_uart_tx_if (.clk(clk), .rstn(rstn));

	// instantiate DUT
	soup_top #(
		.LOGIC_FREQ (50_000_000),
		.BAUD_RATE  (115_200),
		.UART_LENGTH(10)
	) dut (
		.PAD_RX     (u_soup_if.rx_pad),
		.PAD_TX     (u_soup_if.tx_pad),
		.soup_clk_i (u_soup_if.clk),
		.soup_rstn_i(u_soup_if.rstn),
		.dbg_data_o ( /* FLOATING */ ),
		.cmd_done_o (u_soup_if.cmd_done),
		.error_flag_o(u_soup_if.error_flag)
	);

	// Instantiate UART BFMs to talk to the SOUP DUT
	uart_tx I_soup_driver_uart (
		.tx_clk_i       (clk),
		.rstn_tx_clk_i  (rstn),
		.tx_data_i      (u_uart_tx_if.tx_data_i),
		.tx_data_valid_i(u_uart_tx_if.tx_data_valid_i),
		.tx_data_o      (u_soup_if.rx_pad),
		.tx_busy_o      (u_uart_tx_if.tx_busy_o)
	);

	uart_rx I_soup_monitor_uart (
		.rx_clk_i       (clk),
		.rstn_rx_clk_i  (rstn),
		.rx_data_i      (u_soup_if.tx_pad),
		.rx_data_o      (u_uart_rx_if.rx_data_o),
		.rx_data_valid_o(u_uart_rx_if.rx_data_valid_o)
	);

	// pass the interfaces into uvm-cfg-db
	initial begin
		uvm_config_db#(virtual soup_interface)::set(null, "*", "soup_vif", u_soup_if);
		uvm_config_db#(virtual uart_rx_interface)::set(null, "*", "rx_vif", u_uart_rx_if);
		uvm_config_db#(virtual uart_tx_interface)::set(null, "*", "tx_vif", u_uart_tx_if);
		run_test("soup_base_test");
	end

endmodule
