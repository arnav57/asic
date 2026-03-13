`timescale 1ns/1ps

class fifo_driver extends uvm_driver #(fifo_transaction);
    `uvm_component_utils(fifo_driver)

    virtual fifo_interface vif;

    function new(string name = "fifo_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FIFO_DRV", "Could not get virtual interface")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.rd_en   <= 1'b0;
        vif.drv_cb.wr_data <= 8'h0;

        wait(vif.rstn);
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transaction(fifo_transaction tr);
        @(vif.drv_cb);
        case (tr.op)
            WRITE: begin
                vif.drv_cb.wr_en   <= 1'b1;
                vif.drv_cb.wr_data <= tr.data;
                vif.drv_cb.rd_en   <= 1'b0;
            end
            READ: begin
                vif.drv_cb.wr_en   <= 1'b0;
                vif.drv_cb.rd_en   <= 1'b1;
            end
            READ_WRITE: begin
                vif.drv_cb.wr_en   <= 1'b1;
                vif.drv_cb.wr_data <= tr.data;
                vif.drv_cb.rd_en   <= 1'b1;
            end
        endcase
        @(vif.drv_cb);
        vif.drv_cb.wr_en <= 1'b0;
        vif.drv_cb.rd_en <= 1'b0;
    endtask

endclass
