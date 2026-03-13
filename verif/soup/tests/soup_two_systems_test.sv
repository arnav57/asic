import uvm_pkg::*;
import uart_env_pkg::*;
import soup_env_pkg::*;
`include "uvm_macros.svh"

class soup_two_systems_test extends uvm_test;

	`uvm_component_utils(soup_two_systems_test)

	soup_env env;

	function new (string name = "soup_two_systems_test", uvm_component parent);
		super.new(name, parent);
	endfunction : new

	virtual function void build_phase (uvm_phase phase);
		super.build_phase(phase);
        // Enable loopback mode in scoreboard
        uvm_config_db#(bit)::set(this, "env.s_sb", "loopback_mode", 1);
		env = soup_env::type_id::create("env", this);
	endfunction : build_phase

	virtual task run_phase (uvm_phase phase);
		soup_sanity_seq test_seq;

		phase.raise_objection(this);

		`uvm_info("TEST", "Starting SOUP Two Systems Test...", UVM_LOW)
		`uvm_info("TEST", "Sys A sends packet to Sys B. Sys B sends ACK then loops packet back to Sys A.", UVM_LOW)

		test_seq = soup_sanity_seq::type_id::create("test_seq");
		test_seq.start(env.s_agent.sqr);

		// Wait for both the Data packet, ACK, and the looped back packet
		// 115200 baud is ~11.5 bytes/ms. 
        // 256 bytes * 2 packets + 3 bytes ACK = ~515 bytes.
        // ~45ms. 
		#60000000;
		
		`uvm_info("TEST", "SOUP Two Systems Test Finished", UVM_LOW)
		phase.drop_objection(this);
	endtask : run_phase
endclass : soup_two_systems_test
