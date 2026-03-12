`timescale 1ns/1ps
`default_nettype none

module uart_tx #(
	parameter LOGIC_FREQ  = 50_000_000,
	parameter BAUD_RATE   = 115_200   ,
	parameter UART_LENGTH = 10
) (
	input  wire         tx_clk_i       ,
	input  wire         rstn_tx_clk_i  ,
	input  wire [8-1:0] tx_data_i      ,
	input  wire         tx_data_valid_i,
	output wire         tx_data_o,
	output wire 		tx_busy_o    
);


// Localparam stuff
	localparam CYCLES_PER_BIT = LOGIC_FREQ / BAUD_RATE; // define number of cycles per UART bit
	localparam FULL_PERIOD    = CYCLES_PER_BIT        ; // same as FULL_PERIOD, just better readability
	localparam HALF_PERIOD    = FULL_PERIOD/2         ; // defines optimal sampling point
	localparam CYC_CNT_WIDTH  = $clog2(CYCLES_PER_BIT); // width of the cycle counter
	localparam BIT_CNT_WIDTH  = $clog2(UART_LENGTH)   ; // width of the bit counter
	localparam DATA_START_IDX = 1                     ; // idx 0 is the start bit, idx 1 is the data beginning
	localparam DATA_END_IDX   = (UART_LENGTH - 2)     ; // end of UART has a stop bit right after data ends

// assume the pulse on tx_data_valid_i is synchronized to our tx-clk
// our TX latches the byte in, and starts sending it when it recieves this pulse
	logic 					cnt_enable_r;
	logic [UART_LENGTH-1:0] uart_frame;
// use the same counter as the RX side
	logic [CYC_CNT_WIDTH-1:0] cycle_cnt_r ; // Counter to track bit count accurately
	logic [BIT_CNT_WIDTH-1:0] bit_cnt_r   ; // Counter to track index in UART packet

	wire cycle_cnt_full;
	wire bit_cnt_full  ;

	wire [CYC_CNT_WIDTH-1:0] cycle_cnt_next;
	wire [BIT_CNT_WIDTH-1:0] bit_cnt_next  ;

	always_ff @(posedge tx_clk_i) begin
		if (~rstn_tx_clk_i) begin
			cnt_enable_r <= 1'd0;
			uart_frame   <= '1; // uart idles high so i think this makes sense (ts so tuff fr)
		end else begin
			if (tx_data_valid_i && ~cnt_enable_r) begin
				uart_frame [UART_LENGTH-1:0] <= {1'b1, tx_data_i, 1'b0};
				cnt_enable_r <= 1'b1;
			end else begin
				uart_frame   <= uart_frame;
				cnt_enable_r <= (bit_cnt_full && cycle_cnt_full) ? (1'b0) : cnt_enable_r;
			end
		end
	end

// define counter full conditions
	assign cycle_cnt_full = (cycle_cnt_r == FULL_PERIOD - 1);
	assign bit_cnt_full   = (bit_cnt_r   == UART_LENGTH - 1);

// define counter increment/reset conditions
	assign cycle_cnt_next = (cycle_cnt_full) ? ('0) : (cycle_cnt_r + 'd1);
	assign bit_cnt_next   = (bit_cnt_full && cycle_cnt_full)   ? ('0) : ( (cycle_cnt_full) ? (bit_cnt_r + 'd1) : (bit_cnt_r) );

// implement counter
	always_ff @(posedge tx_clk_i) begin
		if (~rstn_tx_clk_i) begin
			cycle_cnt_r <= '0;
			bit_cnt_r   <= '0;
		end else begin
			if (cnt_enable_r) begin
				cycle_cnt_r <= cycle_cnt_next;
				bit_cnt_r   <= bit_cnt_next;
			end else begin
				cycle_cnt_r <= cycle_cnt_r;
				bit_cnt_r   <= bit_cnt_r;
			end
		end
	end


// Shift stuff out based on the bit_cnt_r index
	logic tx_data_r;

	always_ff @(posedge tx_clk_i) begin
		if(~rstn_tx_clk_i) begin
			tx_data_r <= 1'b1;
		end else begin
			if (cnt_enable_r) begin
				tx_data_r <= uart_frame[bit_cnt_r];
			end else begin
				tx_data_r <= 1'b1;
			end
		end
	end

assign tx_data_o = tx_data_r;
assign tx_busy_o = (cnt_enable_r);

endmodule : uart_tx
