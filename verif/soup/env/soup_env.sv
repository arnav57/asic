class soup_env extends uvm_env;
    `uvm_component_utils(soup_env)

    // Components
    uart_env   u_env;
    soup_agent s_agent;

    function new(string name = "soup_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        u_env   = uart_env::type_id::create("u_env", this);
        s_agent = soup_agent::type_id::create("s_agent", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // we need the uart's rx ap to connect to the soup's uart_imp thing
        u_env.rx_agent.mon.ap.connect (s_agent.mon.uart_imp);

    endfunction

endclass
