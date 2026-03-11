class uart_sequence extends uvm_sequence #(uart_transaction);
    // Register with UVM (Notice it's object_utils, not component_utils, because it's dynamic!)
    `uvm_object_utils(uart_sequence)

    // Standard constructor
    function new(string name = "uart_sequence");
        super.new(name);
    endfunction

    // 1. The Body Task: This is the "main()" function of your sequence
    virtual task body();
        `uvm_info("SEQ", "Starting UART sequence...", UVM_LOW)

        // Let's shoot 10 random UART frames into the RTL
        for (int i = 0; i < 10; i++) begin
            
            // A. Create a blank transaction object
            req = uart_transaction::type_id::create("req");

            // B. Handshake Part 1: Ask the Sequencer/Driver for permission to send
            // This blocks until the Driver calls `get_next_item()`
            start_item(req);

            // C. Randomize the data when we have access to real Questa (This fills req.data with a random 8-bit value)
            // if (!req.randomize()) begin
            //     `uvm_error("SEQ", "Randomization failed!")
            // end
            req.data = 8'hA5 + i;
            
            // D. Handshake Part 2: Push the object to the Driver and wait for it to finish
            // This blocks until the Driver calls `item_done()`
            finish_item(req);

            // Print a message so we can see what we generated
            `uvm_info("SEQ", $sformatf("Sent random byte %0d/10: 8'h%0h", i+1, req.data), UVM_LOW)
        end
        
        `uvm_info("SEQ", "UART sequence finished!", UVM_LOW)
    endtask

endclass