class soup_agent extends uvm_agent;
    `uvm_component_utils(soup_agent)

    soup_sequencer sqr;
    soup_monitor   mon;

    function new(string name = "soup_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = soup_monitor::type_id::create("mon", this);
        sqr = soup_sequencer::type_id::create("sqr", this);
    endfunction

endclass
