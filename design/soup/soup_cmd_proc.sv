// Module that decodes the SOUP structure
// DATA FRAME -> { START 0x33, CMD_TYPE, LEN, PAYLOAD, CRC, STOP 0xCC } 
// CMD  FRAME -> { START 0x33, CMD_TYPE, STOP 0xCC }

module soup_cmd_proc (
	input  wire         soup_clk_i      , // Clock for SOUP
	input  wire         soup_rstn_i     , // RSTN for SOUP
	input  wire [8-1:0] data_rcv_i      ,
	input  wire         data_rcv_valid_i,
	output wire         cmd_done_o,
	output wire 		error_flag_o
);

typedef enum logic [2:0] {
	IDLE,      	// 3'd0
	RCV_CMD,   	// 3'd1
	RCV_LEN,    // 3'd2
	RCV_PAYLOAD,// 3'd3
	RCV_CRC,   	// 3'd4
	CHECK_STOP,	// 3'd5
	RESPOND    	// 3'd6
} e_soup_cmd;
e_soup_cmd soup_cmd_st_r;

// Payload counter logic
logic [8-1:0] 	payload_size_r;
logic 			error_flag_r;

// Payload Down Counter
logic [8-1:0] payload_remaining_r;
wire  cnt_done;
wire  cnt_enable = (soup_cmd_st_r == RCV_PAYLOAD);

always_ff @(posedge soup_clk_i) begin
	if(~soup_rstn_i) begin
		payload_remaining_r <= 8'h00;
	end else begin
		if (cnt_enable) begin
			if (data_rcv_valid_i) begin
				payload_remaining_r <= payload_remaining_r - 1'b1;
			end else begin
				payload_remaining_r <= payload_remaining_r;
			end
		end else begin
			payload_remaining_r <= payload_size_r;
		end
	end
end
assign cnt_done = (cnt_enable && payload_remaining_r == 8'b0);

always_ff @(posedge soup_clk_i) begin
	if(~soup_rstn_i) begin
		 soup_cmd_st_r  <= IDLE;
		 payload_size_r <= 8'b0;
		 error_flag_r   <= 1'b0;
	end else begin
		 case (soup_cmd_st_r)
		 	
	 		// In IDLE State wait to recieve a start bit 0x33
		 	IDLE: begin
		 		if (data_rcv_i == 8'h33 && data_rcv_valid_i) begin
		 			soup_cmd_st_r <= RCV_CMD;
		 		end else begin
		 			soup_cmd_st_r <= IDLE;
		 		end
		 	end

		 	// in RCV_CMD state we decode the frame as a type of CMD_DATA (MSb 0) or CMD_RESP (MSb 1)
		 	RCV_CMD: begin
		 		if (data_rcv_valid_i) begin
			 		if (~data_rcv_i[7]) begin
			 			// This is a CMD_DATA type packet so we move to RCV_LEN
			 			soup_cmd_st_r <= RCV_LEN;
			 		end else begin
			 			// This is a CMD_RESP type packet so we move to CHECK_STOP
			 			soup_cmd_st_r <= CHECK_STOP;
			 		end
			 	end else begin
			 		soup_cmd_st_r <= RCV_CMD;
			 	end
		 	end

		 	// in RCV_LEN state we have established we are sending a data frame, we need to properly configure the counter here
		 	RCV_LEN: begin
		 		if (data_rcv_valid_i) begin
		 			if (data_rcv_i == 8'b0) begin
		 				payload_size_r <= 8'b0;
		 				soup_cmd_st_r  <= RCV_CRC;
		 			end else begin
		 				payload_size_r <= data_rcv_i;
		 				soup_cmd_st_r  <= RCV_PAYLOAD;
		 			end
		 		end else begin
		 			payload_size_r <= payload_size_r;
		 			soup_cmd_st_r  <= RCV_LEN;
		 		end
		 	end

		 	// in RCV payload we start the counter to count pulses of data_rcv_valid_i, once that is done we reset the counter and move forward!
		 	RCV_PAYLOAD: begin
		 		// basically just polling the counter here! the counter should automatically start when the FSM enters this state
		 		if (~cnt_done) begin
		 			// if the counter is still running we wait
		 			soup_cmd_st_r <= RCV_PAYLOAD;
		 		end else begin
		 			// if the count is active and done, we can move to next state
		 			soup_cmd_st_r <= RCV_CRC;
		 		end
		 	end

		 	// for now this will be transparent
		 	RCV_CRC: begin
		 		if (data_rcv_valid_i) begin
		 			soup_cmd_st_r <= CHECK_STOP;
		 		end
		 	end

		 	// in stop we make sure the stop bit is given
		 	CHECK_STOP: begin
		 		if (data_rcv_valid_i) begin
		 			if (data_rcv_i == 8'hCC) begin
		 				soup_cmd_st_r <= RESPOND;
		 				error_flag_r  <= 1'b0;
		 			end else begin
		 				soup_cmd_st_r <= RESPOND;
		 				error_flag_r  <= 1'b1;
		 			end
		 		end
		 	end

 			// also keep this transparent for now
		 	RESPOND: begin
		 		soup_cmd_st_r <= IDLE;
		 	end


		 	// Default fallback!
		 	default : soup_cmd_st_r <= IDLE;
		 endcase
	end
end



assign cmd_done_o = (soup_cmd_st_r == RESPOND);
assign error_flag_o = error_flag_r;


endmodule : soup_cmd_proc