// Quartus Prime Verilog Template (Single Port RAM)
// Single port RAM with single read/write address 
// Arnav's Note: This is updated with sv constructs

module sp_ram #(
	parameter DATA_WIDTH=8,
	parameter ADDR_WIDTH=6
)(
	input wire [(DATA_WIDTH-1):0] data,
	input wire [(ADDR_WIDTH-1):0] addr,
	input wire we,
	input wire clk,
	output wire [(DATA_WIDTH-1):0] q
);

	// Declare the RAM variable
	logic [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

	// Variable to hold the registered read address
	logic [ADDR_WIDTH-1:0] addr_reg;

	always_ff @ (posedge clk) begin
		// Write
		if (we)
			ram[addr] <= data;

		addr_reg <= addr;
	end

	// Continuous assignment implies read returns NEW data.
	// This is the natural behavior of the TriMatrix memory
	// blocks in Single Port mode.  
	assign q = ram[addr_reg];

endmodule
