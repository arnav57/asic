class soup_base_test extends uvm_test;

	`uvm_component_utils(soup_base_test)

	soup_env env;

	function new (string name = "soup_base_test", uvm_component parent);
		super.new(name, parent);
	endfunction : new

	virtual function void build_phase (uvm_phase phase);
		super.build_phase(phase);
		env = soup_env::type_id::create("env", this);
	endfunction : build_phase

	virtual task run_phase (uvm_phase phase);
		// declare sequences
		soup_to_uart_seq layering_seq;

		// declare a basic soup sequence
		soup_sanity_seq test_seq;

		phase.raise_objection(this);

		layering_seq = soup_to_uart_seq::type_id::create("layering_seq");
		layering_seq.s_sqr = env.s_agent.sqr;

		fork
			layering_seq.start(env.u_env.tx_agent.sqr);
		join_none

		`uvm_info("TEST", "Starting SOUP Sanity Sequence...", UVM_LOW)

		test_seq = soup_sanity_seq::type_id::create("test_seq");
		test_seq.start(env.s_agent.sqr);

		#5000 ns;
		phase.drop_objection(this);
	endtask : run_phase
endclass : soup_base_test