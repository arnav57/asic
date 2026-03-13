class uart_scoreboard extends uvm_scoreboard;

	// register in UVM
	`uvm_component_utils(uart_scoreboard)
	`uvm_analysis_imp_decl(_tx)
	`uvm_analysis_imp_decl(_rx)

	// constructor
	function new (string name = "uart_scoreboard", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	uart_transaction want_q[$];
	uart_transaction got_q[$];
	bit disable_check = 0;

	uvm_analysis_imp_tx #(uart_transaction, uart_scoreboard) tx_ap;
	uvm_analysis_imp_rx #(uart_transaction, uart_scoreboard) rx_ap;

    function void build_phase (uvm_phase phase);
    	rx_ap = new("rx_ap", this);
    	tx_ap = new("tx_ap", this);
    	void'(uvm_config_db#(bit)::get(this, "", "disable_check", disable_check));
    endfunction

    // TX sequence will write to the WANT queue
    virtual function void write_tx(uart_transaction tr);
    	`uvm_info("UART-BRD", $sformatf("Tx Sending Data = 0x%0h", tr.data), UVM_LOW)
    	want_q.push_back(tr);
    endfunction

    // RX side writes to the GOT queue
    virtual function void write_rx (uart_transaction tr);
    	`uvm_info("UART-BRD", $sformatf("Rx Got Data = 0x%0h", tr.data), UVM_LOW)
    	got_q.push_back(tr);
    endfunction

    virtual function void check_phase (uvm_phase phase);
    	if (disable_check) return;
    	if (got_q.size() != want_q.size()) begin
    		`uvm_error("UART-BRD", $sformatf("Rx got %d bytes, Tx sent %d bytes!", got_q.size(), want_q.size()))
    		return;
    	end

    	for (int i = 0; i < got_q.size(); i++) begin
    		// compare the data packets
    		`uvm_info("UART-BRD", $sformatf("Comparing item %d in stored transactions", i), UVM_LOW)
    		if (got_q[i].data === want_q[i].data) begin
    			`uvm_info("UART-BRD", "Data Matches!", UVM_LOW)
    		end else begin
    			`uvm_error("UART-BRD", $sformatf("Data Mismatch! Tx sent 0x%H, Rx got 0x%H", want_q[i].data, got_q[i].data))
    		end
    	end

	endfunction






endclass : uart_scoreboard