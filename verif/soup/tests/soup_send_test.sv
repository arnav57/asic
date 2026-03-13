import uvm_pkg::*;
import uart_env_pkg::*;
import soup_env_pkg::*;
`include "uvm_macros.svh"

class soup_send_test extends uvm_test;

	`uvm_component_utils(soup_send_test)

	soup_env env;

	function new (string name = "soup_send_test", uvm_component parent);
		super.new(name, parent);
	endfunction : new

	virtual function void build_phase (uvm_phase phase);
		super.build_phase(phase);
		env = soup_env::type_id::create("env", this);
	endfunction : build_phase

	virtual task run_phase (uvm_phase phase);
		// declare a basic soup sequence
		soup_sanity_seq test_seq;

		phase.raise_objection(this);

		`uvm_info("TEST", "Starting SOUP Send Test Sequence (Driving RTL directly)...", UVM_LOW)

		test_seq = soup_sanity_seq::type_id::create("test_seq");
		test_seq.start(env.s_agent.sqr);

		// Wait for some time for UART transmission to complete
		// 115200 baud is ~8.6us per bit, 10 bits per byte = 86us per byte.
		// 256 bytes * 86us = ~22ms. 
		// Sim clock is 50MHz (20ns), so 22ms / 20ns = 1,100,000 cycles.
		// UVM time is 1ns/1ps. 22ms = 22,000,000 ns.
		#30000000;
		
		`uvm_info("TEST", "SOUP Send Test Finished", UVM_LOW)
		phase.drop_objection(this);
	endtask : run_phase
endclass : soup_send_test
