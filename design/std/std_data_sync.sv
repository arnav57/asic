//// Basic Data (single-bit) Synchronizer 

module std_data_sync #(
	parameter N = 2 // Number of sync flops
) (
	input  wire clk, 
	input  wire rstn,
	input  wire d,
	output wire q
);

logic [N-1:0] flop_r;

// chain N flops together
always_ff @(posedge clk) begin
	if(~rstn) begin
		flop_r <= {N{1'b0}};
	end else begin
		flop_r[0] <= d;
		for (int i = 1; i < N; i++) begin
			flop_r[i] <= flop_r[i-1];
		end
	end
end

assign q = flop_r[N-1];

endmodule : std_data_sync