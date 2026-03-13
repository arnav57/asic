class soup_agent extends uvm_agent;
    `uvm_component_utils(soup_agent)

    soup_sequencer sqr;
    soup_monitor   mon;
    soup_driver    drv;

    function new(string name = "soup_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        uvm_active_passive_enum active_passive;
        if (uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", active_passive)) begin
            is_active = active_passive;
        end
        super.build_phase(phase);
        mon = soup_monitor::type_id::create("mon", this);
        sqr = soup_sequencer::type_id::create("sqr", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv = soup_driver::type_id::create("drv", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction

endclass
