class uart_tx_driver extends uvm_driver #(uart_transaction);

    // register class
    `uvm_component_utils(uart_tx_driver)

    // create vif to tx-interface
    virtual uart_tx_interface vif;
    uvm_analysis_port #(uart_transaction) ap;

    // constructor
    function new(string name = "uart_tx_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    // build phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual uart_tx_interface)::get(this, "", "tx_vif", vif)) begin
            `uvm_fatal("NO_DRIVER_VIF", "Virtual interface not found for TX driver!")
        end
        ap = new("ap", this);
    endfunction : build_phase

    // run phase
    virtual task run_phase(uvm_phase phase);

        if (vif == null) begin
            `uvm_fatal("NULL_VIF", "Virtual interface is NULL for TX driver!")
        end

        // init signals safely
        vif.tx_data_i       = 8'b0;
        vif.tx_data_valid_i = 1'b0;

        wait(vif.rstn === 1'b1);

        forever begin
            seq_item_port.get_next_item(req);
            drive_packet(req);
            ap.write(req);
            seq_item_port.item_done();
        end
 
    endtask : run_phase

    // the thing that puts the packet into the tx and starts transmission
    localparam CLOCK_PERIOD = 1_000_000_000/50_000_000;
    task drive_packet(uart_transaction tr);
        vif.tx_data_i <= tr.data;
        vif.tx_data_valid_i <= 1'b0;
        #CLOCK_PERIOD;
        #CLOCK_PERIOD;
        vif.tx_data_valid_i <= 1'b1;
        #CLOCK_PERIOD;
        #CLOCK_PERIOD;
        vif.tx_data_valid_i <= 1'b0;
        #CLOCK_PERIOD;
        #CLOCK_PERIOD;
        wait(vif.tx_busy_o === 1'b0);
    endtask : drive_packet

endclass