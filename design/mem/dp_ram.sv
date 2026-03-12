// Quartus Prime Verilog Template (True Dual Port RAM, Single Clock)
// True Dual Port RAM with single clock
// Arnav's Note: This is updated with sv constructs

module dp_ram #(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 6
) (
	input  wire       [(DATA_WIDTH-1):0] data_a,
	input  wire       [(DATA_WIDTH-1):0] data_b,
	input  wire       [(ADDR_WIDTH-1):0] addr_a,
	input  wire       [(ADDR_WIDTH-1):0] addr_b,
	input  wire                          we_a  ,
	input  wire                          we_b  ,
	input  wire                          clk   ,
	output      logic [(DATA_WIDTH-1):0] q_a   ,
	output      logic [(DATA_WIDTH-1):0] q_b
);

	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

	// Port A
	always_ff @ (posedge clk) begin
			if (we_a)
				begin
					ram[addr_a] <= data_a;
					q_a         <= data_a;
				end
			else
				begin
					q_a <= ram[addr_a];
				end
	end

	// Port B
	always_ff @ (posedge clk) begin
			if (we_b)
				begin
					ram[addr_b] <= data_b;
					q_b         <= data_b;
				end
			else
				begin
					q_b <= ram[addr_b];
				end
	end

endmodule
