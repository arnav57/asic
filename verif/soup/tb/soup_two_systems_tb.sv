`timescale 1ns/1ps

import uvm_pkg::*;
import uart_env_pkg::*;
import soup_env_pkg::*;
`include "uvm_macros.svh"


module soup_two_systems_tb;

// clock and rstn
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
uart_tx_interface u_uart_tx_if (.clk(clk), .rstn(rstn)); // Satisfy driver requirement
// We use these to monitor the UART lines between the systems
uart_rx_interface u_uart_rx_if_a (.clk(clk), .rstn(rstn)); // Monitor Sys A's RX (from Sys B)
uart_rx_interface u_uart_rx_if_b (.clk(clk), .rstn(rstn)); // Monitor Sys B's RX (from Sys A)

wire pad_a_to_b;
wire pad_b_to_a;

// System A (TB-Controlled)
soup_top #(
	.LOGIC_FREQ (50_000_000),
	.BAUD_RATE  (115_200   ),
	.UART_LENGTH(10        )
) dut_a (
	.PAD_RX          (pad_b_to_a          ),
	.PAD_TX          (pad_a_to_b          ),
	.soup_clk_i      (clk                 ),
	.soup_rstn_i     (rstn                ),
	.dbg_data_o      (/* FLOATING */      ),
	.cmd_done_o      (u_soup_if.cmd_done  ),
	.error_flag_o    (u_soup_if.error_flag),
	.start_data_i    (u_soup_if.start_data),
	.data_i          (u_soup_if.data_in   ),
	.soup_data_done_o(u_soup_if.soup_data_done),
	.fifo_wr_en_i    (u_soup_if.fifo_wr_en  ),
	.fifo_wr_data_i  (u_soup_if.fifo_wr_data),
	.soup_loopback_en_i (1'b0) // NOT in loopback
);

// System B (Loopback-Enabled)
soup_top #(
	.LOGIC_FREQ (50_000_000),
	.BAUD_RATE  (115_200   ),
	.UART_LENGTH(10        )
) dut_b (
	.PAD_RX          (pad_a_to_b          ),
	.PAD_TX          (pad_b_to_a          ),
	.soup_clk_i      (clk                 ),
	.soup_rstn_i     (rstn                ),
	.dbg_data_o      (/* FLOATING */      ),
	.cmd_done_o      (/* FLOATING */      ),
	.error_flag_o    (/* FLOATING */      ),
	.start_data_i    (1'b0                ),
	.data_i          (8'h0                ),
	.soup_data_done_o(/* FLOATING */      ),
	.fifo_wr_en_i    (1'b0                ),
	.fifo_wr_data_i  (8'h0                ),
	.soup_loopback_en_i (1'b1) // Loopback enabled
);

// Instantiate UART BFMs to MONITOR the UART lines
// Monitor Sys A's RX line (which is Sys B's TX)
uart_rx I_soup_monitor_uart_a (
	.rx_clk_i       (clk                           ),
	.rstn_rx_clk_i  (rstn                          ),
	.rx_data_i      (pad_b_to_a                    ),
	.rx_data_o      (u_uart_rx_if_a.rx_data_o      ),
	.rx_data_valid_o(u_uart_rx_if_a.rx_data_valid_o)
);

// Monitor Sys B's RX line (which is Sys A's TX)
uart_rx I_soup_monitor_uart_b (
	.rx_clk_i       (clk                           ),
	.rstn_rx_clk_i  (rstn                          ),
	.rx_data_i      (pad_a_to_b                    ),
	.rx_data_o      (u_uart_rx_if_b.rx_data_o      ),
	.rx_data_valid_o(u_uart_rx_if_b.rx_data_valid_o)
);


// pass the interfaces into uvm-cfg-db
initial begin
	uvm_config_db#(virtual soup_interface)::set(null, "*", "soup_vif", u_soup_if);
	uvm_config_db#(virtual uart_tx_interface)::set(null, "*", "tx_vif", u_uart_tx_if);
	// We only need one RX interface for the soup_env's monitor
	// Let's connect the soup_env monitor to Sys A's RX (to see ACK and looped data)
	uvm_config_db#(virtual uart_rx_interface)::set(null, "*", "rx_vif", u_uart_rx_if_a);
	
	run_test("soup_two_systems_test");
end

initial begin
    if ($test$plusargs("WAVE")) begin
        $dumpfile("waves.vcd");
        $dumpvars(0, soup_two_systems_tb);
    end
end


endmodule
