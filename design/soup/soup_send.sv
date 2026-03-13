// Module that encodes the SOUP structure
// DATA FRAME -> { START 0x33, CMD_TYPE, LEN, PAYLOAD, CRC, STOP 0xCC }
// CMD  FRAME -> { START 0x33, CMD_TYPE, STOP 0xCC }

`default_nettype none
`timescale 1ns/1ps

module soup_send (
	// Clock + Rstn
	input  wire         soup_clk_i          ,
	input  wire         soup_rstn_i         ,
	// To/From UART Tx
	input  wire         tx_busy_i           ,
	output wire         data_send_o         ,
	output wire [8-1:0] data_o              ,
	// To/From SOUP reciever
	input  wire         error_flag_i        ,
	input  wire         start_response_i    ,
	output wire         soup_response_done_o,
	// To/From External Source
	input  wire         start_data_i        ,
	input  wire [8-1:0] data_i              ,
	output wire         soup_data_done_o    ,
	// FIFO Control
	output wire         fifo_rd_en_o        ,
	input  wire [8-1:0] fifo_rd_data_i      ,
	input  wire [9-1:0] fifo_size_i
);


	typedef enum logic [2:0] {
		IDLE,       // 3'd0
		TX_START,   // 3'd1
		TX_CMD,     // 3'd2
		TX_LEN,     // 3'd3
		TX_PAYLOAD, // 3'd4
		TX_CRC,     // 3'd5
		TX_STOP,    // 3'd6
		TX_WAIT		// 3'd7
	} e_soup_cmd;

// Local Signals (FSM)
	e_soup_cmd  soup_tx_st_r        ;
	logic       error_flag_r        ;
	logic [7:0] tx_data_r           ;
	logic       tx_data_valid_r     ;
	e_soup_cmd  return_state_r      ;
	logic       waiting_on_tx_r     ;
	logic       cmd_type_response   ;
	logic       cmd_type_data       ;
	logic       soup_response_done_r;
	logic       soup_data_done_r    ;
// Local Signals (FIFO)
	logic       fifo_rd_en_r;
	logic [8:0] loop_cnt_r  ;

	always_ff @(posedge soup_clk_i) begin
		if(~soup_rstn_i) begin
			soup_tx_st_r         <= IDLE;
			error_flag_r         <= 1'b0;
			// things we send to the UART Tx
			tx_data_r            <= 8'b0;
			tx_data_valid_r      <= 1'b0;
			// distinguish between cmd types
			cmd_type_response    <= 1'b0;
			cmd_type_data        <= 1'b0;
			soup_response_done_r <= 1'b0;
			soup_data_done_r     <= 1'b0;
			// loop counter for TX_PAYLOAD state
			loop_cnt_r           <= 9'h0;
			fifo_rd_en_r         <= 1'b0;
		end else begin
			case (soup_tx_st_r)

				// In idle we wait for for the reciever to be done, and latch in the error flag
				IDLE : begin
					soup_response_done_r <= 1'b0;
					soup_data_done_r     <= 1'b0;
					if (start_data_i && ~start_response_i) begin
						cmd_type_data <= 1'b1;
						soup_tx_st_r  <= TX_START;
						error_flag_r  <= error_flag_i;
					end else if (~start_data_i && start_response_i) begin
						cmd_type_response <= 1'b1;
						soup_tx_st_r      <= TX_START;
						error_flag_r      <= error_flag_i;
					end else if (start_data_i && start_response_i) begin
						// If both go high, the response takes priority
						cmd_type_response <= 1'b1;
						soup_tx_st_r      <= TX_START;
						error_flag_r      <= error_flag_i;
					end
				end

				// In TX_WAIT we lower the data valid r signal, and wait for the tx to be done sending whatever its sending rn
				TX_WAIT : begin
					tx_data_valid_r <= 1'b0;
					fifo_rd_en_r    <= 1'b0;

					// If we just entered TX_WAIT, wait for tx_busy_i to go high
					if (!waiting_on_tx_r) begin
						if (tx_busy_i) begin
							waiting_on_tx_r <= 1'b1;
						end
					end else begin
						// Once it's high, wait for it to go low
						if (~tx_busy_i) begin
							waiting_on_tx_r <= 1'b0;
							soup_tx_st_r    <= return_state_r;
							if (return_state_r == IDLE) begin
								soup_response_done_r <= (cmd_type_response) ? 1'b1 : 1'b0;
								soup_data_done_r     <= (cmd_type_data    ) ? 1'b1 : 1'b0;
								cmd_type_data        <= 1'b0;
								cmd_type_response    <= 1'b0;
							end
						end
					end
				end

				// In TX_START we send the start byte (0x33), and then transition to TX_CMD after TX is done sending
				TX_START : begin
					if (~tx_busy_i) begin
						tx_data_r       <= 8'h33;
						tx_data_valid_r <= 1'b1;
						soup_tx_st_r    <= TX_WAIT;
						return_state_r  <= TX_CMD;
					end
				end

				// In TX_CMD we send the command type (MSb) ? CMD_DATA : CMD_RESPONSE
				// CMD_DATA 0x00 == ACK
				// CMD_DATA 0x01 == NACK
				TX_CMD : begin
					if (~tx_busy_i) begin
						if (cmd_type_response) begin
							tx_data_r       <= {1'b1, 6'b0, error_flag_r};
							tx_data_valid_r <= 1'b1;
							return_state_r  <= TX_STOP;
						end else begin
							tx_data_r       <= data_i;
							tx_data_valid_r <= 1'b1;
							return_state_r  <= TX_LEN;
						end
						soup_tx_st_r <= TX_WAIT;
					end
				end

				// In TX_STOP we send the stop byte (0xCC), and then transition back to IDLE after TX is done sending it
				TX_STOP : begin
					if (~tx_busy_i) begin
						tx_data_r       <= 8'hCC;
						tx_data_valid_r <= 1'b1;
						soup_tx_st_r    <= TX_WAIT;
						return_state_r  <= IDLE;
					end
				end

				// The fifo's read-reqest sends data out after 1 cc
				// the loop for entinering payload is LEN -> WAIT -> PAYLOAD -> WAIT -> PAYLOAD -> WAIT -> ... -> CRC
				// In order to have the data ready in PAYLOAD state, we need to have the fifo_rd_en high in WAIT state,
				// This means we must set it high in LEN state, and in PAYLOAD state. and can lower it in WAIT state
				// If we latch loop_cnt_r to fifo_size_i - 1, we go to payload state twice!

				// ex. for payload of fifo_size_i == 'd2
				// 		LEN     -> WAIT     -> PAYLOAD     -> WAIT     -> PAYLOAD     -> WAIT     -> CRC

				// In TX_LEN we send the length of the payload.
				// We ASSUME that the FIFO is filled with the payload data prior to reaching this state
				TX_LEN : begin
					if (~tx_busy_i) begin
						tx_data_r       <= (fifo_size_i == 9'd256) ? 8'd255 : fifo_size_i[7:0];
						loop_cnt_r      <= fifo_size_i - 9'd1;
						tx_data_valid_r <= 1'b1;
						soup_tx_st_r    <= TX_WAIT;
						return_state_r  <= (fifo_size_i == 9'd0) ? TX_CRC : TX_PAYLOAD;
						fifo_rd_en_r    <= (fifo_size_i == 9'd0) ? 1'b0   : 1'b1;
					end
				end

				// In TX_PAYLOAD we latch one byte of the payload at a time, until the fifo is empty!
				// We also launch a read from the FIFO in this state
				TX_PAYLOAD : begin
					if (~tx_busy_i) begin
						tx_data_r       <= fifo_rd_data_i;
						tx_data_valid_r <= 1'b1;
						soup_tx_st_r    <= TX_WAIT;
						return_state_r  <= (loop_cnt_r == 9'b0) ? TX_CRC : TX_PAYLOAD;
						loop_cnt_r      <= loop_cnt_r - 9'd1;
						fifo_rd_en_r    <= 1'b1;
					end
				end

				// In TX_CRC we send the CRC, right now we hard code the CRC to AA for passthru
				TX_CRC : begin
					fifo_rd_en_r <= 1'b0;
					if (~tx_busy_i) begin
						tx_data_r       <= 8'hAA;
						tx_data_valid_r <= 1'b1;
						soup_tx_st_r    <= TX_WAIT;
						return_state_r  <= TX_STOP;
					end
				end

				default : soup_tx_st_r <= IDLE;
			endcase
		end
	end


	// wire up stuff to TLIO
	assign data_o               = tx_data_r;
	assign data_send_o          = tx_data_valid_r;
	assign soup_data_done_o     = soup_data_done_r;
	assign soup_response_done_o = soup_response_done_r;
	assign fifo_rd_en_o         = fifo_rd_en_r;
	
endmodule