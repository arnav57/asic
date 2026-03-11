class uart_rx_driver extends uvm_driver #(uart_transaction);
    // Register the class with UVM
    `uvm_component_utils(uart_rx_driver)

    // 1. The "pointer" to our physical cable
    virtual uart_rx_interface vif;

    // We use the exact same math you used in your RTL!
    localparam CYCLES_PER_BIT = 50_000_000 / 115_200;

    // Standard constructor
    function new(string name = "uart_rx_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual uart_rx_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NODRVVIF", "Virtual interface not found for driver!")
        end
    endfunction

    // 2. The run_phase: This task runs automatically when the simulation starts
    virtual task run_phase(uvm_phase phase);
        // 1. Safety check
        if (vif == null) begin
            `uvm_fatal("DRV_VIF_NULL", "Driver virtual interface is NULL!")
        end

        // 2. Initialize signals to a safe state
        vif.rx_data_i <= 1'b1; // Idle state for UART is High

        // 3. Wait for reset to clear before driving anything
        wait(vif.rstn === 1'b1);
        
        forever begin
            seq_item_port.get_next_item(req);
            drive_packet(req);
            seq_item_port.item_done();
        end
    endtask

    // 3. The actual pin-wiggling logic
    task drive_packet(uart_transaction tr);
        // Start Bit: Drive the line LOW to signal a new frame
        vif.rx_data_i <= 1'b0;
        repeat(CYCLES_PER_BIT) @(posedge vif.clk);

        // Data Bits: Your RTL shifts in LSB first, so we drive LSB first
        for (int i = 0; i < 8; i++) begin
            vif.rx_data_i <= tr.data[i];
            repeat(CYCLES_PER_BIT) @(posedge vif.clk);
        end

        // Stop Bit: Drive the line HIGH to close the frame
        vif.rx_data_i <= 1'b1;
        repeat(CYCLES_PER_BIT) @(posedge vif.clk);
    endtask

endclass