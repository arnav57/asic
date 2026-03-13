class soup_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soup_scoreboard)
    `uvm_analysis_imp_decl(_drv)
    `uvm_analysis_imp_decl(_mon)

    soup_transaction want_q[$];
    soup_transaction got_q[$];

    uvm_analysis_imp_drv #(soup_transaction, soup_scoreboard) drv_imp;
    uvm_analysis_imp_mon #(soup_transaction, soup_scoreboard) mon_imp;

    function new(string name = "soup_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    bit loopback_mode = 0;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv_imp = new("drv_imp", this);
        mon_imp = new("mon_imp", this);
        void'(uvm_config_db#(bit)::get(this, "", "loopback_mode", loopback_mode));
    endfunction

    virtual function void write_drv(soup_transaction tr);
        soup_transaction clone;
        $cast(clone, tr.clone());
        want_q.push_back(clone);
        `uvm_info("SOUP-SB", $sformatf("Added to want_q: %s", clone.convert2string()), UVM_LOW)
    endfunction

    virtual function void write_mon(soup_transaction tr);
        soup_transaction clone;
        $cast(clone, tr.clone());
        got_q.push_back(clone);
        `uvm_info("SOUP-SB", $sformatf("Added to got_q: %s", clone.convert2string()), UVM_LOW)
    endfunction

    virtual function void check_phase(uvm_phase phase);
        int got_idx = 0;

        if (!loopback_mode) begin
            if (want_q.size() != got_q.size()) begin
                `uvm_error("SOUP-SB", $sformatf("Size mismatch! Want: %0d, Got: %0d", want_q.size(), got_q.size()))
            end

            foreach (want_q[i]) begin
                if (got_q.size() > i) begin
                    compare_items(i, want_q[i], got_q[i]);
                end
            end
        end else begin
            // In loopback mode, for each sent packet, we expect:
            // 1. An ACK (is_response = 1, cmd_type = 0x80)
            // 2. The original packet (is_response = 0, same cmd_type and payload)
            
            foreach (want_q[i]) begin
                // Check for ACK
                if (got_q.size() > got_idx) begin
                    if (!got_q[got_idx].is_response || got_q[got_idx].cmd_type != 8'h80) begin
                        `uvm_error("SOUP-SB", $sformatf("Item %0d: Expected ACK, Got: %s", i, got_q[got_idx].convert2string()))
                    end
                    got_idx++;
                end else begin
                    `uvm_error("SOUP-SB", $sformatf("Item %0d: Missing ACK", i))
                end

                // Check for Looped Back Packet
                if (got_q.size() > got_idx) begin
                    compare_items(i, want_q[i], got_q[got_idx]);
                    got_idx++;
                end else begin
                    `uvm_error("SOUP-SB", $sformatf("Item %0d: Missing Looped Data", i))
                end
            end
            
            if (got_q.size() > got_idx) begin
                `uvm_error("SOUP-SB", $sformatf("Extra packets received! Expected: %0d, Got: %0d", got_idx, got_q.size()))
            end
        end
    endfunction

    virtual function void compare_items(int i, soup_transaction want, soup_transaction got);
        if (want.cmd_type !== got.cmd_type)
            `uvm_error("SOUP-SB", $sformatf("Item %0d: cmd_type mismatch! Want: 0x%h, Got: 0x%h", i, want.cmd_type, got.cmd_type))
        
        if (want.payload.size() !== got.payload.size())
            `uvm_error("SOUP-SB", $sformatf("Item %0d: payload size mismatch! Want: %0d, Got: %0d", i, want.payload.size(), got.payload.size()))
        else begin
            foreach (want.payload[j]) begin
                if (want.payload[j] !== got.payload[j])
                    `uvm_error("SOUP-SB", $sformatf("Item %0d: payload[%0d] mismatch! Want: 0x%h, Got: 0x%h", i, j, want.payload[j], got.payload[j]))
            end
        end
    endfunction

endclass
