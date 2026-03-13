`timescale 1ns/1ps

class fifo_monitor extends uvm_monitor;
    `uvm_component_utils(fifo_monitor)

    virtual fifo_interface vif;
    uvm_analysis_port #(fifo_transaction) ap;

    function new(string name = "fifo_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FIFO_MON", "Could not get virtual interface")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (vif.rstn) begin
                if (vif.mon_cb.wr_en || vif.mon_cb.rd_en) begin
                    fifo_transaction tr = fifo_transaction::type_id::create("tr");
                    if (vif.mon_cb.wr_en && vif.mon_cb.rd_en) tr.op = READ_WRITE;
                    else if (vif.mon_cb.wr_en) tr.op = WRITE;
                    else tr.op = READ;
                    
                    tr.data = vif.mon_cb.wr_data;
                    tr.rd_data = vif.mon_cb.rd_data;
                    
                    if (vif.mon_cb.wr_en && vif.mon_cb.fifo_full)
                        `uvm_info("FIFO_MON", "Write skipped (FIFO Full)", UVM_HIGH)
                    if (vif.mon_cb.rd_en && vif.mon_cb.fifo_empty)
                        `uvm_info("FIFO_MON", "Read skipped (FIFO Empty)", UVM_HIGH)
                        
                    ap.write(tr);
                end
            end
        end
    endtask

endclass
