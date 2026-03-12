class uart_env extends uvm_env;
    // Register with UVM
    `uvm_component_utils(uart_env)

    // 1. Declare the components that live on this "motherboard"
    uart_rx_agent rx_agent;
    uart_tx_agent tx_agent;
    
    uart_scoreboard scoreboard;

    // Standard constructor
    function new(string name = "uart_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 2. Build Phase: Instantiate the components
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Create the agents + scorebaord
        rx_agent = uart_rx_agent::type_id::create("rx_agent", this);
        tx_agent = uart_tx_agent::type_id::create("tx_agent", this);
        scoreboard = uart_scoreboard::type_id::create("scoreboard", this);
        
    endfunction

    virtual function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        // connect rx analysis port to scoreboard
        rx_agent.mon.ap.connect (scoreboard.rx_ap);
        tx_agent.drv.ap.connect (scoreboard.tx_ap);
    endfunction

endclass