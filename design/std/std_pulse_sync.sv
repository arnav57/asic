module std_pulse_sync (
	input  wire clk_src, // Clock (Source Domain)
	input  wire clk_tgt, // Clock (Target Domain)
	input  wire d      , // Input Pulse (Source Domain)
	input  wire rstn   , // Asynchronous reset active low
	output wire q        // Output Pulse (Target Domain)
);

// 1 cycle pulse synchronizer works by:
//  1. Convery pulse to level on source domain
//  2. Synchronize the level to target domain
//  3. Generate a pulse form the level on target domain


// pulse -> level from source clock
logic q_level_src;
logic q_level_tgt;
always_ff @(posedge clk_src or negedge rstn) begin
	if(~rstn) begin
		q_level_src <= 1'b0;
	end else begin
		// basic toggle flop can convert pulse to a level
		q_level_src <= (d) ? ~q_level_src : q_level_src;
	end
end

// synchronizer the level on source to target clock
std_data_sync #(
	.N(2)
) I_data_sync_level (
	.clk(clk_tgt), 
	.rstn(rstn), 
	.d(q_level_src), 
	.q(q_level_tgt)
);

// generate a pulse on the new domain
logic q_pulse;
logic q_level_tgt_d1r;
always_ff @(posedge clk_tgt or negedge rstn) begin
	if(~rstn) begin
		q_pulse <= 1'b0;
		q_level_tgt_d1r <= 1'b0;
	end else begin
		q_level_tgt_d1r <= q_level_tgt;
		q_pulse <= (q_level_tgt_d1r ^ q_level_tgt);
	end
end

assign q = q_pulse;

endmodule : std_pulse_sync