`timescale 1ns/1ps

package soup_env_pkg;

	import uvm_pkg::*;
	import uart_env_pkg::*;
	`include "uvm_macros.svh"

	`include "soup_transaction.sv"
	
	// Add these for the agent
	`include "soup_sequencer.sv"
	`include "soup_monitor.sv"
	`include "soup_driver.sv"
	`include "soup_scoreboard.sv"
	`include "soup_agent.sv"
	`include "soup_sequence.sv"

	`include "soup_env.sv"

endpackage : soup_env_pkg
