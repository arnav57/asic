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
	output wire         soup_data_done_o
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

	e_soup_cmd  soup_tx_st_r        ;
	logic       error_flag_r        ;
	logic [7:0] tx_data_r           ;
	logic       tx_data_valid_r     ;
	logic [2:0] return_state_r      ;
	logic       waiting_on_tx_r     ;
	logic       cmd_type_response   ;
	logic       cmd_type_data       ;
	logic       soup_response_done_r;
	logic       soup_data_done_r    ;

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
					if (tx_busy_i) begin
						waiting_on_tx_r <= 1'b1;
					end

					if (~tx_busy_i && waiting_on_tx_r) begin
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
							tx_data_r       <= {7'b0, error_flag_r};
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


				// In TX_LEN we send the length of the payload. Right now we hard code it to 1 for passthru
				TX_LEN : begin
					if (~tx_busy_i) begin
						tx_data_r       <= 8'h01;
						tx_data_valid_r <= 1'b1;
						soup_tx_st_r    <= TX_WAIT;
						return_state_r  <= TX_PAYLOAD;
					end
				end

				// In TX_PAYLOAD we send the payload, right now we hard code the payload to FF for passthru
				TX_PAYLOAD : begin
					if (~tx_busy_i) begin
						tx_data_r       <= 8'hFF;
						tx_data_valid_r <= 1'b1;
						soup_tx_st_r    <= TX_WAIT;
						return_state_r  <= TX_CRC;
					end
				end

				// In TX_CRC we send the CRC, right now we hard code the CRC to AA for passthru
				TX_CRC : begin
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
endmodule