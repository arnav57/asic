class uart_env extends uvm_env;
    // Register with UVM
    `uvm_component_utils(uart_env)

    // 1. Declare the components that live on this "motherboard"
    uart_rx_agent rx_agent;
    
    // (Later, you'd add: uart_agent tx_agent;)
    // (Later, you'd add: uart_scoreboard scoreboard;)

    // Standard constructor
    function new(string name = "uart_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 2. Build Phase: Instantiate the components
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Create the RX Agent
        rx_agent = uart_rx_agent::type_id::create("rx_agent", this);
        
        // By default, UVM components are ACTIVE unless we say otherwise.
        // We want our RX agent to drive pins, so we leave it active!
    endfunction

endclass