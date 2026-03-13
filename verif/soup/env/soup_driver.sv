`timescale 1ns/1ps

class soup_driver extends uvm_driver #(soup_transaction);
    `uvm_component_utils(soup_driver)

    virtual soup_interface vif;
    uvm_analysis_port #(soup_transaction) ap;

    function new(string name = "soup_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual soup_interface)::get(this, "", "soup_vif", vif)) begin
            `uvm_fatal("SOUP_DRV", "Could not get virtual interface")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        // reset signals
        vif.drv_cb.start_data   <= 1'b0;
        vif.drv_cb.data_in      <= 8'h0;
        vif.drv_cb.fifo_wr_en   <= 1'b0;
        vif.drv_cb.fifo_wr_data <= 8'h0;

        wait(vif.rstn);
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            ap.write(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transaction(soup_transaction tr);
        if (tr.is_response) begin
            `uvm_error("SOUP_DRV", "soup_driver is for driving SOUP-Send Data Packets, not responses!")
            return;
        end

        `uvm_info("SOUP_DRV", $sformatf("Driving data packet: cmd_type=0x%h, len=%0d", tr.cmd_type, tr.payload.size()), UVM_LOW)

        // 1. Load FIFO
        foreach (tr.payload[i]) begin
            @(vif.drv_cb);
            vif.drv_cb.fifo_wr_en   <= 1'b1;
            vif.drv_cb.fifo_wr_data <= tr.payload[i];
        end
        @(vif.drv_cb);
        vif.drv_cb.fifo_wr_en   <= 1'b0;

        // 2. Trigger soup_send
        @(vif.drv_cb);
        vif.drv_cb.start_data <= 1'b1;
        vif.drv_cb.data_in    <= tr.cmd_type;
        
        @(vif.drv_cb);
        vif.drv_cb.start_data <= 1'b0;

        // 3. Wait for done
        while (!vif.drv_cb.soup_data_done) begin
            @(vif.drv_cb);
        end
        `uvm_info("SOUP_DRV", "Transaction completed", UVM_LOW)
    endtask

endclass
