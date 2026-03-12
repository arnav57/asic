// Bring in UVM and our custom package!
import uvm_pkg::*;
import uart_env_pkg::*;

class uart_loopback_test extends uvm_test;
    `uvm_component_utils(uart_loopback_test)

    // 1. Declare the Environment
    uart_env u_uart_env;

    function new(string name = "uart_loopback_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 2. Build Phase: Create the Environment
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_uart_env = uart_env::type_id::create("u_uart_env", this);
    endfunction

    // 3. Run Phase: Where the magic happens
    virtual task run_phase(uvm_phase phase);
        uart_tx_sequence seq;
        
        // A. Raise Objection: "Hey simulator, don't stop! I have a test to run!"
        phase.raise_objection(this);

        `uvm_info("TEST", "Starting UART Loopback Test...", UVM_LOW)

        // B. Create the sequence
        seq = uart_tx_sequence::type_id::create("seq");

        // C. Start the sequence ON the RX Agent's sequencer
        // Notice how we navigate down the hierarchy: env -> rx_agent -> sqr
        seq.start(u_uart_env.tx_agent.sqr);

        // D. Wait a little bit for the final physical bits to drain out of the RTL pins
        // Since we are running at 50MHz, let's wait a few thousand ns.
        #30000;

        `uvm_info("TEST", "Test finished!", UVM_LOW)

        // E. Drop Objection: "Okay simulator, my sequence is done. You can shut down now."
        phase.drop_objection(this);
    endtask

endclass