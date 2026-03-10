module std_clkdiv #(
	parameter N = 4 // Div counter width
) (
	input  wire 		iclk,    
	input  wire 		rstn, 
	input  wire [N-1:0] div,  	// Divider Value, expected to change synchronously to iclk, must be >=1
	output wire 		oclk
);

// Start by latching in the div value
logic [N-1:0] div_r;
always_ff @(posedge iclk) begin
	if (~rstn) begin
		div_r <= 1'b1;
	end else begin
		div_r <= div;
	end
end

// Counter to track clock cycles
logic [N-1:0] cnt_r;
always_ff @(posedge iclk) begin
	if (~rstn) begin
		cnt_r <= {N{1'b0}};
	end else begin
		// Reset counter when divider value has changed, or if we reach the maxwioshfduil
		if (div != div_r || cnt_r == div_r) begin
			cnt_r <= {N{1'b0}};
		end else begin
			cnt_r <= cnt_r + 1'b1;
		end
	end
end

// Generation of Output Clock with a kinda even duty cycle
logic clk_int;
always_comb begin
	// if true set clock to 0, also ensures oclk is parked low on reset
	clk_int = (cnt_r < (div_r >> 1)) ? 1'b0 : 1'b1;
end

assign oclk = clk_int;

endmodule : std_clkdiv