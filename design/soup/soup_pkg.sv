package soup_pkg;

// localparam stuff because i like my code being readable :)
	localparam CMD_LENGTH     = 8                 ; // Length of soup command
	localparam CMD_HEADER_IDX = CMD_LENGTH - 1    ; // MSb of command determines if this is a data (0) or response (1) command
	localparam CMD_BODY_START = CMD_HEADER_IDX - 1; // Everything but the MSb

// Data Commands (excl. MSb)
	typedef enum logic [7-1:0] {
		DATA_IDLE     = 7'd0,
		DATA_LOOPBACK = 7'd1
		// Rest unused
	} e_soup_data_cmd;

// Response Commands (excl. MSb)
	typedef enum logic [7-1:0] {
		RESP_ACK  = 7'd0,
		RESP_NACK = 7'd1
		// Rest Unused
	} e_soup_resp_cmd;

endpackage : soup_pkg