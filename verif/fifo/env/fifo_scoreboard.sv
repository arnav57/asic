`timescale 1ns/1ps

class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)
    `uvm_analysis_imp_decl(_mon)

    uvm_analysis_imp_mon #(fifo_transaction, fifo_scoreboard) mon_imp;

    byte fifo_mem_q[$];
    byte expected_rd_q[$];
    int fifo_depth = 256;

    function new(string name = "fifo_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_imp = new("mon_imp", this);
    endfunction

    virtual function void write_mon(fifo_transaction tr);
        // 1. Check if a read happened in the PREVIOUS cycle
        if (expected_rd_q.size() > 0) begin
            byte want = expected_rd_q.pop_front();
            if (tr.rd_data !== want) begin
                `uvm_error("FIFO_SB", $sformatf("Mismatch! Want: 0x%h, Got: 0x%h", want, tr.rd_data))
            end else begin
                `uvm_info("FIFO_SB", $sformatf("Read Match: 0x%h", tr.rd_data), UVM_MEDIUM)
            end
        end

        // 2. Process current transaction
        case (tr.op)
            WRITE: begin
                if (fifo_mem_q.size() < fifo_depth) begin
                    fifo_mem_q.push_back(tr.data);
                    `uvm_info("FIFO_SB", $sformatf("Write: 0x%h. Mem Count: %0d", tr.data, fifo_mem_q.size()), UVM_HIGH)
                end
            end
            READ: begin
                if (fifo_mem_q.size() > 0) begin
                    expected_rd_q.push_back(fifo_mem_q.pop_front());
                end
            end
            READ_WRITE: begin
                // Both happen simultaneously
                if (fifo_mem_q.size() > 0) begin
                    expected_rd_q.push_back(fifo_mem_q.pop_front());
                end
                if (fifo_mem_q.size() < fifo_depth) begin
                    fifo_mem_q.push_back(tr.data);
                end
            end
        endcase
    endfunction

endclass
