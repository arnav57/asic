class uart_monitor extends uvm_monitor;
    // Register the class with UVM
    `uvm_component_utils(uart_monitor)

    // 1. The "pointer" to our physical cable
    virtual uart_if vif;

    // 2. The Megaphone: This is how the monitor broadcasts the data it sees
    uvm_analysis_port #(uart_transaction) ap;

    // Standard constructor
    function new(string name = "uart_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase: Initialize the analysis port
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if(!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface not found for monitor!")
        end
    endfunction

    // 3. The run_phase: Sit and watch the pins forever
    virtual task run_phase(uvm_phase phase);
        // 1. First-principles safety check
        if (vif == null) begin
            `uvm_fatal("MON_VIF_NULL", "Monitor virtual interface is NULL at start of run_phase!")
        end

        // 2. Wait for the 'rstn' to actually be defined and go High
        // This prevents the 'Time 0' crash
        wait(vif.rstn === 1'b1);
        
        `uvm_info("MONITOR", "Reset released, monitor starting...", UVM_LOW)

        forever begin
            @(posedge vif.clk);
            
            // Use === to avoid X/Z state issues during startup
            if (vif.rx_data_valid_o === 1'b1) begin
                uart_transaction tr = uart_transaction::type_id::create("tr");
                tr.data = vif.rx_data_o;
                
                ap.write(tr);
                `uvm_info("MONITOR", $sformatf("Saw RTL output byte: 8'h%0h", tr.data), UVM_LOW)
            end
        end
    endtask

endclass