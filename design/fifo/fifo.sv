// Synchronous FIFO (cant be used for CDC)

module fifo #(
	parameter  FIFO_DEPTH = 256                   ,
	parameter  FIFO_WIDTH = 8                     ,
	parameter  _PTR_SIZE   = $clog2(FIFO_DEPTH) + 1  // derived, DO NOT OVERRIDE!
) (
	input  wire                  fifo_clk_i ,
	input  wire                  fifo_rstn_i,
	// Writing
	input  wire                  wr_en_i    ,
	input  wire [FIFO_WIDTH-1:0] wr_data_i  ,
	// Reading
	input  wire                  rd_en_i    ,
	output wire [FIFO_WIDTH-1:0] rd_data_o  ,
	// FIFO State
	output wire [  _PTR_SIZE-1:0] rd_ptr_o   ,
	output wire [  _PTR_SIZE-1:0] wr_ptr_o   ,
	output wire [  _PTR_SIZE-1:0] fifo_sz_o	,
	output wire 				 fifo_full_o,
	output wire 				 fifo_empty_o
);

// Declare the FIFO!
	reg [FIFO_WIDTH-1:0] mem [FIFO_DEPTH-1:0];

// Local Signals
	logic [  _PTR_SIZE-1:0] rd_ptr_r ;
	logic [  _PTR_SIZE-1:0] wr_ptr_r ;
	logic [FIFO_WIDTH-1:0] rd_data_r;
	logic [  _PTR_SIZE-1:0] fifo_sz_r;

	wire actually_read, actually_write;
	assign actually_write = (wr_en_i && !fifo_full_o);
	assign actually_read  = (rd_en_i && !fifo_empty_o);

// Write Logic
	always_ff @(posedge fifo_clk_i) begin
		if(~fifo_rstn_i) begin
			rd_ptr_r  <= '0;
			wr_ptr_r  <= '0;
			fifo_sz_r <= '0;
			rd_data_r <= '0;
		end else begin

			case ({actually_read, actually_write})
				
				(2'b00): begin
					// if we dont need to do anything, we literally do nothing (shocker!)
				end

				(2'b01): begin
					// if we need to only write, we just increment the write ptr and the size
					wr_ptr_r  <= (wr_ptr_r == FIFO_DEPTH-1) ? 'd0 : (wr_ptr_r + 'd1);
					fifo_sz_r <= fifo_sz_r + 'd1;

					mem[wr_ptr_r[_PTR_SIZE-2:0]] <= wr_data_i;
				end

				(2'b10): begin
					// if we need to only read we just increment the read ptr, and decrement the size
					rd_ptr_r  <= (rd_ptr_r == FIFO_DEPTH-1) ? 'd0 : (rd_ptr_r + 'd1);
					fifo_sz_r <= fifo_sz_r - 'd1;

					rd_data_r <= mem[rd_ptr_r[_PTR_SIZE-2:0]];
				end

				(2'b11): begin
					// if we need to do both we increment both pointers but not the size
					rd_ptr_r  <= (rd_ptr_r == FIFO_DEPTH-1) ? 'd0 : (rd_ptr_r + 'd1);
					wr_ptr_r  <= (wr_ptr_r == FIFO_DEPTH-1) ? 'd0 : (wr_ptr_r + 'd1);

					rd_data_r <= mem[rd_ptr_r[_PTR_SIZE-2:0]];
					mem[wr_ptr_r[_PTR_SIZE-2:0]] <= wr_data_i;
				end

				default: begin
					// reuse the idle state explicitly here (2'b00)
					rd_ptr_r  <= rd_ptr_r;
					wr_ptr_r  <= wr_ptr_r;
					fifo_sz_r <= fifo_sz_r;
				end
			endcase
		end
	end

	// FIFO size can be found with a dedicated counter. Counts up on a write, and counts down on a read	
	// define empty and full flags
	assign fifo_empty_o = (fifo_sz_r == 9'b0); 			// FIFO is empty when the read and write points are the same 
	assign fifo_full_o  = (fifo_sz_r == FIFO_DEPTH);	// FIFO is full when the difference between them is the FIFO length
	assign fifo_sz_o    = fifo_sz_r;
	assign rd_ptr_o     = rd_ptr_r;
	assign wr_ptr_o     = wr_ptr_r;

	assign rd_data_o    = rd_data_r;

endmodule : fifo