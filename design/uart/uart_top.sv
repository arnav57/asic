module uart_top #(
	parameter LOGIC_FREQ  = 50_000_000,
	parameter BAUD_RATE   = 1_000_000 ,
	parameter UART_LENGTH = 10
) (
	// CLK + RSTN
	input wire uart_clk_i,
	input wire uart_rstn_i,

	// PAD Signals
	output wire tx_data_o,
	input  wire rx_data_i,

	// TX Signals
	input wire [8-1:0] 	tx_data_i,
	input wire 		   	tx_data_valid_i,
	output wire 		tx_busy_o,

	// RX Signals
	output wire [8-1:0] rx_data_o,
	output wire 		rx_data_valid_o,

	// Configuration
	input  wire 		uart_lbpk_en_i,

	// Debug
	output wire [8-1:0]	dbg_data_o
);

// Loopback here means RX sends its recieved data to TX
// To pull this off:
//   1. we connect tx_data_i to rx_data_o
//   2. Connect the data_valid signals
// We pipeline stuff here so we can meet timing

wire     	tx_data_valid_int;
wire [7:0] 	tx_data_int;
wire		rx_data_valid_int;
wire [7:0]  rx_data_int;
logic [7:0] rx_data_r;
logic 		rx_data_valid_r;

assign rx_data_valid_o = rx_data_valid_r;
assign rx_data_o = rx_data_r;

always_ff @(posedge uart_clk_i) begin
	if(~uart_rstn_i) begin
		rx_data_r <= 8'b0;
		rx_data_valid_r <= 1'b0;
	end else begin
		rx_data_r       <= rx_data_int;
		rx_data_valid_r <= rx_data_valid_int;
	end
end

assign tx_data_valid_int = (uart_lbpk_en_i) ? rx_data_valid_r : tx_data_valid_i;
assign tx_data_int       = (uart_lbpk_en_i) ? rx_data_r       : tx_data_i      ;

uart_tx #(
	.LOGIC_FREQ     (LOGIC_FREQ ),
	.BAUD_RATE      (BAUD_RATE  ),
	.UART_LENGTH    (UART_LENGTH)
) I_tx (
	.tx_clk_i       (uart_clk_i       ),
	.rstn_tx_clk_i  (uart_rstn_i      ),
	.tx_data_i      (tx_data_int      ),
	.tx_data_valid_i(tx_data_valid_int),
	.tx_data_o      (tx_data_o        ),
	.tx_busy_o      (tx_busy_o        )
);


uart_rx #(
	.LOGIC_FREQ     (LOGIC_FREQ ),
	.BAUD_RATE      (BAUD_RATE  ),
	.UART_LENGTH    (UART_LENGTH)
) I_rx (
	.rx_clk_i       (uart_clk_i       ),
	.rstn_rx_clk_i  (uart_rstn_i  	  ),
	.rx_data_i      (rx_data_i        ),
	.rx_data_o      (rx_data_int      ),
	.rx_data_valid_o(rx_data_valid_int)
);

assign dbg_data_o [7:0] = rx_data_r;

endmodule : uart_top