import uvm_pkg::*;
import uart_env_pkg::*;
import soup_env_pkg::*;
`include "uvm_macros.svh"

class soup_loopback_test extends uvm_test;

	`uvm_component_utils(soup_loopback_test)

	soup_env env;

	function new (string name = "soup_loopback_test", uvm_component parent);
		super.new(name, parent);
	endfunction : new

	virtual function void build_phase (uvm_phase phase);
		super.build_phase(phase);
		env = soup_env::type_id::create("env", this);
	endfunction : build_phase

	virtual task run_phase (uvm_phase phase);
		soup_sanity_seq test_seq;

		phase.raise_objection(this);

		`uvm_info("TEST", "Starting SOUP Loopback Test...", UVM_LOW)
		`uvm_info("TEST", "This test loops PAD_TX to PAD_RX. RTL will send Data -> Rcv Data -> Send ACK", UVM_LOW)

		test_seq = soup_sanity_seq::type_id::create("test_seq");
		test_seq.start(env.s_agent.sqr);

		// Wait for both the Data packet and the resulting ACK to be sent and received
		// Data packet (256 bytes) + ACK (3 bytes)
		// Total time should be around 25ms
		#30000000;
		
		`uvm_info("TEST", "SOUP Loopback Test Finished", UVM_LOW)
		phase.drop_objection(this);
	endtask : run_phase
endclass : soup_loopback_test
