`default_nettype none
import soup_pkg::*;

// Design should never directly interact with the FIFO, it should always go thru this block
// This is basically a big MUX. Theres probably a better word for it but i have no clue what that word is.
// so yes, this is a big mux :)

module soup_cmd_decode (
	// SOUP Command from rcv
	input  wire [8-1:0] soup_cmd_i             ,

	// Direct to FIFO
	output wire         direct_fifo_wr_en_o    ,
	output wire [8-1:0] direct_fifo_wr_data_o  ,
	output wire         direct_fifo_rd_en_o    ,
	input  wire [8-1:0] direct_fifo_rd_data_i  ,
	input  wire [9-1:0] direct_fifo_sz_i       ,
	// Direct to Consumers
	output wire [8-1:0] consumer_fifo_rd_data_o,
	output wire [9-1:0] consumer_fifo_sz_o     ,

// Interfaces to blocks that want to WRITE to the FIFO
	// FIFO Writing Input [USER]
	input  wire         user_fifo_wr_en_i      ,
	input  wire [8-1:0] user_fifo_wr_data_i    ,
	// FIFO Writing Input [SOUP-RCV]
	input  wire         rcv_fifo_wr_en_i       ,
	input  wire [8-1:0] rcv_fifo_wr_data_i     ,
// Interfaces to blocks that want to READ from the FIFO
	// FIFO Reading Input [USER]
	input  wire         user_fifo_rd_en_i      ,
	// FIFO Reading Input [SOUP-SEND]
	input  wire         send_fifo_rd_en_i
);

// now we make the big mux
	wire 		cmd_is_response = soup_cmd_i[CMD_HEADER_IDX]  ;
	wire [6:0] 	cmd_body        = soup_cmd_i[CMD_BODY_START:0];
	wire 		rcv_wr_allowed;

// WRITE MUX, here we decide which block gets to write to the FIFO
	always_comb begin
		// by default we never write to the FIFO
		direct_fifo_wr_en_o   = 1'b0;
		direct_fifo_wr_data_o = 8'b0;

		// SOUP-RCV takes priority here
		if (rcv_fifo_wr_en_i && rcv_wr_allowed) begin
			direct_fifo_wr_en_o   = rcv_fifo_wr_en_i;
			direct_fifo_wr_data_o = rcv_fifo_wr_data_i;
		end else if (user_fifo_wr_en_i) begin
			direct_fifo_wr_en_o   = user_fifo_wr_en_i;
			direct_fifo_wr_data_o = user_fifo_wr_data_i;
		end
	end


// READ MUX, here we decide which block gets to read from this big boy
	always_comb begin
		// by default never read from the FIFO
		direct_fifo_rd_en_o = 1'b0;

		if (~cmd_is_response) begin
			// here cmd_body should be casted to the 'e_soup_data_cmd' type
			// we decide who reads from the FIFO case by case
			case (cmd_body)
				DATA_IDLE     : direct_fifo_rd_en_o = 1'b0; 			 // FIFO Never gets written to here in the first place
				DATA_LOOPBACK : direct_fifo_rd_en_o = send_fifo_rd_en_i; // For loopback SOUP-SEND needs access
				default       : direct_fifo_rd_en_o = 1'b0; 
			endcase
		end

	end

	assign consumer_fifo_sz_o      = direct_fifo_sz_i;
	assign consumer_fifo_rd_data_o = direct_fifo_rd_data_i;
	assign rcv_wr_allowed          = (~cmd_is_response) & (cmd_body != DATA_IDLE);

endmodule : soup_cmd_decode