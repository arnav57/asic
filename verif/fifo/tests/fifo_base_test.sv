`timescale 1ns/1ps

import uvm_pkg::*;
import fifo_env_pkg::*;
`include "uvm_macros.svh"

class fifo_basic_seq extends uvm_sequence #(fifo_transaction);
    `uvm_object_utils(fifo_basic_seq)

    function new(string name = "fifo_basic_seq");
        super.new(name);
    endfunction

    virtual task body();
        fifo_transaction tr;

        // Simple sequence: 10 writes, then 10 reads
        for (int i = 0; i < 10; i++) begin
            tr = fifo_transaction::type_id::create("tr");
            start_item(tr);
            tr.op = WRITE;
            tr.data = i + 8'hA0;
            finish_item(tr);
        end

        for (int i = 0; i < 10; i++) begin
            tr = fifo_transaction::type_id::create("tr");
            start_item(tr);
            tr.op = READ;
            finish_item(tr);
        end

        // Random operations (Manual randomization to bypass license issue)
        for (int i = 0; i < 50; i++) begin
            int r_op = $urandom_range(0, 2);
            tr = fifo_transaction::type_id::create("tr");
            start_item(tr);
            tr.op = fifo_op_t'(r_op);
            tr.data = $urandom();
            finish_item(tr);
        end
    endtask
endclass

class fifo_base_test extends uvm_test;
    `uvm_component_utils(fifo_base_test)

    fifo_env env;

    function new(string name = "fifo_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_basic_seq seq;
        phase.raise_objection(this);
        
        `uvm_info("FIFO_TEST", "Starting FIFO Base Test...", UVM_LOW)

        seq = fifo_basic_seq::type_id::create("seq");
        seq.start(env.agent.sqr);

        // Final wait to capture the last read data (since it has 1 cycle latency)
        #100;
        
        `uvm_info("FIFO_TEST", "FIFO Base Test Finished", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass
