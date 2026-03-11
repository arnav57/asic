class uart_agent extends uvm_agent;
    // Register with UVM
    `uvm_component_utils(uart_agent)

    // 1. Declare the components that live inside this Agent
    uvm_sequencer #(uart_transaction) sqr; // Notice we use the built-in UVM sequencer!
    uart_driver                       drv;
    uart_monitor                      mon;

    // Standard constructor
    function new(string name = "uart_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 2. Build Phase: Instantiate the components
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // ALWAYS build the monitor. Even if we aren't transmitting, we want to listen.
        mon = uart_monitor::type_id::create("mon", this);
        
        // ONLY build the Driver and Sequencer if this Agent is configured to be ACTIVE
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = uvm_sequencer#(uart_transaction)::type_id::create("sqr", this);
            drv = uart_driver::type_id::create("drv", this);
        end
    endfunction

    // 3. Connect Phase: Wire them together
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if (get_is_active() == UVM_ACTIVE) begin
            // Connect the Sequencer's export to the Driver's port. 
            // This is the "pipe" the transactions flow through!
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction

endclass