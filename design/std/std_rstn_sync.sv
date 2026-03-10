//// Basic Active-Low Reset Synchronizer

module std_rstn_sync #(
	parameter N = 2  // Num of sync flops
)(
	input  wire clk,
	input  wire arstn,
	output wire orstn
	
);

std_data_sync #(
	.N (N) 
) I_rst_sync (
	.clk (clk),
	.rstn (arstn),
	.d (1'b1),
	.q (orstn)
);

endmodule : std_rstn_sync