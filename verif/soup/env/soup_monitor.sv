class soup_monitor extends uvm_monitor;

	// register with UVM
	`uvm_component_utils(soup_monitor)

	virtual soup_interface soup_vif;

	// Analysis Port for broadcasting SOUP transactions
	uvm_analysis_port #(soup_transaction) soup_ap;

	// Implementation port for receiving UART transactions from the layered monitor
	uvm_analysis_imp #(uart_transaction, soup_monitor) uart_imp;

	// Internal Monitor State
	typedef enum {
		M_IDLE,
		M_RCV_CMD,
		M_RCV_LEN,
		M_RCV_PAYLOAD,
		M_RCV_CRC,
		M_CHECK_STOP
	} mon_state_t;

	mon_state_t state_r = M_IDLE;
	soup_transaction current_tr;
	int payload_count = 0;

	function new (string name = "soup_monitor", uvm_component parent = null);
		super.new(name, parent);
		uart_imp = new("uart_imp", this);
		soup_ap  = new("soup_ap", this);
	endfunction : new

	// BUILD PHASE
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if( !uvm_config_db#(virtual soup_interface)::get(this, "", "soup_vif", soup_vif)) begin
			`uvm_fatal("NOVIF", "Virtual interface not found for SOUP monitor!")
		end
	endfunction : build_phase

	// The "write" function is called by the UART monitor whenever a byte is received
	virtual function void write(uart_transaction tr);
		case (state_r)
			M_IDLE: begin
				if (tr.data == 8'h33) begin
					current_tr = soup_transaction::type_id::create("current_tr");
					state_r = M_RCV_CMD;
					`uvm_info("SOUP-MON", "Detected SOUP START (0x33)", UVM_HIGH)
				end
			end

			M_RCV_CMD: begin
				current_tr.cmd_type = tr.data;
				current_tr.is_response = tr.data[7];
				if (current_tr.is_response == 1'b0) begin
					state_r = M_RCV_LEN;
				end else begin
					state_r = M_CHECK_STOP;
				end
			end

			M_RCV_LEN: begin
				current_tr.payload = new[tr.data]; // Initialize the dynamic array size
				payload_count = 0;
				if (tr.data == 0) begin
					state_r = M_RCV_CRC;
				end else begin
					state_r = M_RCV_PAYLOAD;
				end
			end

			M_RCV_PAYLOAD: begin
				current_tr.payload[payload_count] = tr.data;
				payload_count++;
				if (payload_count == current_tr.payload.size()) begin
					state_r = M_RCV_CRC;
				end
			end

			M_RCV_CRC: begin
				current_tr.crc = tr.data;
				state_r = M_CHECK_STOP;
			end

			M_CHECK_STOP: begin
				if (tr.data == 8'hCC) begin
					`uvm_info("SOUP-MON", $sformatf("Packet Complete: %s", current_tr.convert2string()), UVM_LOW)
					soup_ap.write(current_tr); // Broadcast the completed transaction
				end else begin
					`uvm_error("SOUP-MON", $sformatf("Framing Error: Expected 0xCC, Got 0x%0h", tr.data))
				end
				state_r = M_IDLE; // Always return to IDLE after a packet attempt
			end

			default: state_r = M_IDLE;
		endcase
	endfunction

	// RUN PHASE: Used to monitor status signals from the interface
	virtual task run_phase(uvm_phase phase);
		if (soup_vif == null) begin
			`uvm_fatal("MON_VIF_NULL", "Monitor virtual interface is NULL at start of run_phase!")
		end

		wait(soup_vif.rstn === 1'b1);

		`uvm_info("SOUP-MONITOR", "Reset released, monitor starting status check...", UVM_LOW)

		forever begin
			@(posedge soup_vif.clk);
			if (soup_vif.cmd_done) begin
				`uvm_info("SOUP-MON", "Detected cmd_done pulse from DUT!", UVM_MEDIUM)
				// Wait for the signal to go low again so we don't spam the log for every clock cycle the pulse is high
				wait(soup_vif.cmd_done === 1'b0);
			end
		end
	endtask : run_phase

endclass : soup_monitor
