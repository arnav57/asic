module soup_top #(
	parameter LOGIC_FREQ  = 50_000_000,
	parameter BAUD_RATE   = 1_000_000   ,
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

// SOUP TO/FROM FIFO
	wire       fifo_rd_en_int  ;
	wire [7:0] fifo_rd_data_int;
	wire [8:0] fifo_size_int   ;
	wire       fifo_wr_en_rcv  ;
	wire [7:0] fifo_wr_data_rcv;
	wire       fifo_wr_en_int  ;
	wire [7:0] fifo_wr_data_int;


// If SOUP is configured to be in loopback, the RX Controls the FIFO.
// Otherwise the User controls it with TLIO
	assign fifo_wr_en_int   = (soup_loopback_en_i) ? fifo_wr_en_rcv   : fifo_wr_en_i;
	assign fifo_wr_data_int = (soup_loopback_en_i) ? fifo_wr_data_rcv : fifo_wr_data_i;


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
		.soup_loopback_en_i  (soup_loopback_en_i    )
	);


// SOUP Sender FSM
	wire soup_data_done_int;
	logic start_data_loopback_r;
	always_ff @(posedge soup_clk_i) begin
		if (~soup_rstn_i) begin
			start_data_loopback_r <= 1'b0;
		end else begin
			if (soup_loopback_en_i && soup_response_done_int) begin
				start_data_loopback_r <= 1'b1;
			end else begin
				start_data_loopback_r <= 1'b0;
			end
		end
	end

	soup_send I_soup_send (
		.soup_clk_i          (soup_clk_i            ),
		.soup_rstn_i         (soup_rstn_i           ),
		.tx_busy_i           (tx_busy_int           ),
		.data_send_o         (tx_data_valid_int     ),
		.data_o              (tx_data_int           ),
		.error_flag_i        (error_flag_int        ),
		.start_response_i    (cmd_done_int          ),
		.soup_response_done_o(soup_response_done_int),
		.start_data_i        (soup_loopback_en_i ? start_data_loopback_r : start_data_i),
		.data_i              (soup_loopback_en_i ? 8'h00 : data_i),
		.soup_data_done_o    (soup_data_done_int),
		.fifo_rd_en_o        (fifo_rd_en_int        ),
		.fifo_rd_data_i      (fifo_rd_data_int      ),
		.fifo_size_i         (fifo_size_int         )
	);

	assign soup_data_done_o = soup_data_done_int;

// SOUP FIFO!
	fifo #(
		.FIFO_DEPTH(256),   // max number of payload length!
		.FIFO_WIDTH(8  )    // UART FSM is 8N1, thus need 8 bits per slot here
	) I_soup_fifo (
		.fifo_clk_i  (soup_clk_i      ),
		.fifo_rstn_i (soup_rstn_i     ),
		.wr_en_i     (fifo_wr_en_int  ),
		.wr_data_i   (fifo_wr_data_int),
		.rd_en_i     (fifo_rd_en_int  ),
		.rd_data_o   (fifo_rd_data_int),
		.rd_ptr_o    (/*		    */      ),
		.wr_ptr_o    (/*		    */      ),
		.fifo_sz_o   (fifo_size_int   ),
		.fifo_full_o (/*            */),
		.fifo_empty_o(/*            */)
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


	assign error_flag_o = error_flag_int;
	assign cmd_done_o   = cmd_done_int;

endmodule : soup_top
