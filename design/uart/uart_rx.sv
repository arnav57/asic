`timescale 1ns/1ps
`default_nettype none

module uart_rx #(
	parameter LOGIC_FREQ  = 50_000_000,
	parameter BAUD_RATE   = 115_200   ,
	parameter UART_LENGTH = 11
) (
	input  wire         rx_clk_i       ,
	input  wire         rstn_rx_clk_i  ,
	input  wire         rx_data_i      ,
	output wire [8-1:0] rx_data_o      ,
	output wire         rx_data_valid_o
);


// Localparam stuff
	localparam CYCLES_PER_BIT = LOGIC_FREQ / BAUD_RATE; // define number of cycles per UART bit
	localparam FULL_PERIOD    = CYCLES_PER_BIT        ; // same as FULL_PERIOD, just better readability
	localparam HALF_PERIOD    = FULL_PERIOD/2         ; // defines optimal sampling point
	localparam CYC_CNT_WIDTH  = $clog2(CYCLES_PER_BIT); // width of the cycle counter
	localparam BIT_CNT_WIDTH  = $clog2(UART_LENGTH)   ; // width of the bit counter
	localparam DATA_START_IDX = 1                     ; // idx 0 is the start bit, idx 1 is the data beginning
	localparam DATA_END_IDX   = (UART_LENGTH - 2) - 1 ; // end of UART features parity and stop bit right after data ends


// Local Signals
	logic                     cnt_enable_r;
	logic [CYC_CNT_WIDTH-1:0] cycle_cnt_r ; // Counter to track optimal sample point
	logic [BIT_CNT_WIDTH-1:0] bit_cnt_r   ; // Counter to track index in UART packet

	wire cycle_cnt_full;
	wire bit_cnt_full  ;

	wire [CYC_CNT_WIDTH-1:0] cycle_cnt_next;
	wire [BIT_CNT_WIDTH-1:0] bit_cnt_next  ;

	wire  sample_window    ;
	logic sample_window_d1r;

	logic         rx_sample_r;
	logic [8-1:0] rx_data_r  ;

// define counter full conditions
	assign cycle_cnt_full = (cycle_cnt_r >= FULL_PERIOD - 1);
	assign bit_cnt_full   = (bit_cnt_r   >= UART_LENGTH - 1);

// define counter increment/reset conditions
	assign cycle_cnt_next = (cycle_cnt_full) ? ('0) : (cycle_cnt_r + 'd1);
	assign bit_cnt_next   = (bit_cnt_full)   ? ('0) : ( (cycle_cnt_full) ? (bit_cnt_r + 'd1) : (bit_cnt_r) );

// we are in the sample window if we are in the middle of the count (at the half period)
// since cnt_enable_r goes high one CC after negedge, we subtract one here to make sure it samples
// as close to the halfway point as possible
	assign sample_window = (cycle_cnt_r == (HALF_PERIOD - 1));

// implement counter
	always_ff @(posedge rx_clk_i) begin
		if (~rstn_rx_clk_i) begin
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

// define logic to enable counter above
	wire rx_data_s2r;
	std_data_sync I_data_sync_rx_data (
		.clk (rx_clk_i     ),
		.rstn(rstn_rx_clk_i),
		.d   (rx_data_i    ),
		.q   (rx_data_s2r  )
	);

	always_ff @(posedge rx_clk_i) begin
		if (~rstn_rx_clk_i) begin
			cnt_enable_r <= 1'd0;
		end else begin
			// if we notice that we are in idle (cycle cnt is 0) we start the counter
			if (rx_data_s2r == 1'b0 && cycle_cnt_r == '0) begin
				cnt_enable_r <= 1'b1;
			end else begin
				// otherwise we check if the bit cnt is full and then stop the counter
				cnt_enable_r <= (bit_cnt_full) ? 1'd0 : cnt_enable_r;
			end
		end
	end

// define logic to latch in the bit being samples
	always_ff @(posedge rx_clk_i) begin
		if (~rstn_rx_clk_i) begin
			rx_sample_r <= 1'b0;
		end else begin
			rx_sample_r       <= (sample_window) ? rx_data_s2r : rx_sample_r;
			sample_window_d1r <= sample_window;
		end
	end

// shift stuff in to create the final data. Assume each uart frame transmits a byte (8 bits)
// Note that this assumes the LSb is sent first, meaning we do a LSR in the cat below
	always_ff @(posedge rx_clk_i) begin
		if (~rstn_rx_clk_i) begin
			rx_data_r <= 8'b0;
		end else begin
			if (bit_cnt_r >= DATA_START_IDX && bit_cnt_r <= DATA_END_IDX) begin
				rx_data_r <= (sample_window_d1r) ? {rx_sample_r, rx_data_r >> 1} : rx_data_r;
			end else begin
				rx_data_r <= rx_data_r;
			end
		end
	end

// passthrough the rx-data-r flops
// also send out a valid pulse whenever we are done parsing the entire UART frame
	assign rx_data_o       = rx_data_r;
	assign rx_data_valid_o = bit_cnt_full;


endmodule : uart_rx