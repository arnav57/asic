module soup_top #(
	parameter LOGIC_FREQ  = 50_000_000,
	parameter BAUD_RATE   = 1_000_000 ,
	parameter UART_LENGTH = 10
) (
	input  wire       PAD_RX            ,
	output wire       PAD_TX            ,
	input  wire       soup_clk_i        ,
	input  wire       soup_rstn_i       ,
	output wire [7:0] dbg_data_o        ,
	output wire       cmd_done_o        ,
	output wire       error_flag_o      ,
	input  wire       start_data_i      ,
	input  wire [7:0] data_i            ,
	output wire       soup_data_done_o  ,
	input  wire       fifo_wr_en_i      ,
	input  wire [7:0] fifo_wr_data_i    ,
	input  wire       soup_loopback_en_i
);


// Connect UART Rx to SOUP Sender/Reciever INPUTS
	wire [7:0] rx_data_int           ;
	wire       rx_data_valid_int     ;
	wire       tx_busy_int           ;
	wire       tx_data_valid_int     ;
	wire [7:0] tx_data_int           ;
	wire       error_flag_int        ;
	wire       cmd_done_int          ;
	wire       soup_response_done_int;
	wire       soup_data_done_int    ;

// SOUP TO/FROM CMD DECODER (FIFO)
	wire       fifo_rd_en_send      ;
	wire       fifo_wr_en_rcv       ;
	wire [7:0] fifo_wr_data_rcv     ;
	wire [7:0] soup_cmd_int_rcv     ;
	wire       direct_fifo_wr_en    ;
	wire [7:0] direct_fifo_wr_data  ;
	wire       direct_fifo_rd_en    ;
	wire [7:0] direct_fifo_rd_data  ;
	wire [8:0] direct_fifo_sz       ;
	wire [8:0] consumer_fifo_sz     ;
	wire [7:0] consumer_fifo_rd_data;

// SOUP Reciever FSM
	soup_rcv I_soup_rcv (
		.soup_clk_i          (soup_clk_i            ),
		.soup_rstn_i         (soup_rstn_i           ),
		.data_rcv_i          (rx_data_int           ),
		.data_rcv_valid_i    (rx_data_valid_int     ),
		.cmd_done_o          (cmd_done_int          ),
		.error_flag_o        (error_flag_int        ),
		.soup_response_done_i(soup_response_done_int),
		.fifo_wr_en_o        (fifo_wr_en_rcv        ),
		.fifo_wr_data_o      (fifo_wr_data_rcv      ),
		.soup_cmd_o          (soup_cmd_int_rcv      )
	);

// Soup Transmitter FSM
	soup_send I_soup_send (
		.soup_clk_i          (soup_clk_i            ),
		.soup_rstn_i         (soup_rstn_i           ),
		.tx_busy_i           (tx_busy_int           ),
		.data_send_o         (tx_data_valid_int     ),
		.data_o              (tx_data_int           ),
		.error_flag_i        (error_flag_int        ),
		.start_response_i    (cmd_done_int          ),
		.soup_response_done_o(soup_response_done_int),
		.start_data_i        (tx_start_loopback_int ),
		.data_i              (tx_loopback_data_int  ),
		.soup_data_done_o    (soup_data_done_int    ),
		.fifo_rd_en_o        (fifo_rd_en_send       ),
		.fifo_rd_data_i      (consumer_fifo_rd_data ),
		.fifo_size_i         (consumer_fifo_sz      )
	);

// SOUP Command Decoder (FIFO Abstraction MUX)

	soup_cmd_decode I_soup_cmd_decode (
		.soup_cmd_i             (soup_cmd_int_rcv     ),
		.direct_fifo_wr_en_o    (direct_fifo_wr_en    ),
		.direct_fifo_wr_data_o  (direct_fifo_wr_data  ),
		.direct_fifo_rd_en_o    (direct_fifo_rd_en    ),
		.direct_fifo_rd_data_i  (direct_fifo_rd_data  ),
		.direct_fifo_sz_i       (direct_fifo_sz       ),
		.consumer_fifo_rd_data_o(consumer_fifo_rd_data),
		.consumer_fifo_sz_o     (consumer_fifo_sz     ),
		.user_fifo_wr_en_i      (fifo_wr_en_i         ),
		.user_fifo_wr_data_i    (fifo_wr_data_i       ),
		.rcv_fifo_wr_en_i       (fifo_wr_en_rcv       ),
		.rcv_fifo_wr_data_i     (fifo_wr_data_rcv     ),
		.user_fifo_rd_en_i      (fifo_rd_en_i         ),
		.send_fifo_rd_en_i      (fifo_rd_en_send      )
	);


// SOUP FIFO!
	fifo #(
		.FIFO_DEPTH(256),   // max number of payload length!
		.FIFO_WIDTH(8  )    // UART FSM is 8N1, thus need 8 bits per slot here
	) I_soup_fifo (
		.fifo_clk_i  (soup_clk_i         ),
		.fifo_rstn_i (soup_rstn_i        ),
		.wr_en_i     (direct_fifo_wr_en  ),
		.wr_data_i   (direct_fifo_wr_data),
		.rd_en_i     (direct_fifo_rd_en  ),
		.rd_data_o   (direct_fifo_rd_data),
		.rd_ptr_o    (/*		    */         ),
		.wr_ptr_o    (/*		    */         ),
		.fifo_sz_o   (direct_fifo_sz     ),
		.fifo_full_o (/*            */   ),
		.fifo_empty_o(/*            */   )
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
		.tx_data_i      (tx_data_int      ),
		.tx_data_valid_i(tx_data_valid_int),
		.tx_busy_o      (tx_busy_int      ),
		.rx_data_o      (rx_data_int      ),
		.rx_data_valid_o(rx_data_valid_int),
		.uart_lbpk_en_i (1'b0             ),
		.dbg_data_o     (dbg_data_o       )
	);


	assign error_flag_o     = error_flag_int;
	assign cmd_done_o       = cmd_done_int;
	assign soup_data_done_o = soup_data_done_int;

endmodule : soup_top
