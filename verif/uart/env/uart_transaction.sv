class uart_transaction extends uvm_sequence_item;
    // This macro registers the class with UVM's internal database
    `uvm_object_utils(uart_transaction)

    // 1. The Payload: What data are we moving?
    // We use 'rand' so UVM can automatically generate random test bytes for us later.
    rand logic [7:0] data;

    // 2. The Constructor: Standard boilerplate to initialize the object
    function new(string name = "uart_transaction");
        super.new(name);
    endfunction

endclass