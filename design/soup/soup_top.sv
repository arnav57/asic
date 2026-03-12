module soup_top #(
	parameter LOGIC_FREQ  = 50_000_000,
	parameter BAUD_RATE   = 115_200   ,
	parameter UART_LENGTH = 10
) (
	input  wire       PAD_RX     ,
	output wire       PAD_TX     ,
	input  wire       soup_clk_i ,
	input  wire       soup_rstn_i,
	output wire [7:0] dbg_data_o,
	output wire 	  cmd_done_o,
	output wire		  error_flag_o
);


// Connect UART Rx to SOUP COMMAND INPUTS
	wire [7:0] rx_data_int      ;
	wire       rx_data_valid_int;

// Z
	wire tx_busy_int;


// SOUP Command FSM
	soup_cmd_proc I_soup_cmd_proc (
		.soup_clk_i      (soup_clk_i       ),
		.soup_rstn_i     (soup_rstn_i      ),
		.data_rcv_i      (rx_data_int      ),
		.data_rcv_valid_i(rx_data_valid_int),
		.cmd_done_o      (cmd_done_o       ),
		.error_flag_o    (error_flag_o     ) 
	);


// UART TxRx
	uart_top #(
		.LOGIC_FREQ (LOGIC_FREQ ),
		.BAUD_RATE  (BAUD_RATE  ),
		.UART_LENGTH(UART_LENGTH)
	) I_uart (
		.uart_clk_i     (soup_clk_i       ),
		.uart_rstn_i    (soup_rstn_i      ),
		.tx_data_o      (PAD_TX           ),
		.rx_data_i      (PAD_RX           ),
		.tx_data_i      (8'b0             ),
		.tx_data_valid_i(1'b0             ),
		.tx_busy_o      (tx_busy_int      ),
		.rx_data_o      (rx_data_int      ),
		.rx_data_valid_o(rx_data_valid_int),
		.uart_lbpk_en_i (1'b0             ),
		.dbg_data_o     (dbg_data_o       )
	);


endmodule : soup_top