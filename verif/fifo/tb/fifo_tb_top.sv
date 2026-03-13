`timescale 1ns/1ps

import uvm_pkg::*;
import fifo_env_pkg::*;
`include "uvm_macros.svh"

module fifo_tb_top;

    reg clk, rstn;

    initial begin
        clk = 1;
        forever #10 clk = ~clk;
    end

    initial begin
        rstn = 0;
        #300;
        rstn = 1;
    end

    fifo_interface vif (.clk(clk), .rstn(rstn));

    fifo #(
        .FIFO_DEPTH(256),
        .FIFO_WIDTH(8)
    ) dut (
        .fifo_clk_i  (vif.clk),
        .fifo_rstn_i (vif.rstn),
        .wr_en_i     (vif.wr_en),
        .wr_data_i   (vif.wr_data),
        .rd_en_i     (vif.rd_en),
        .rd_data_o   (vif.rd_data),
        .rd_ptr_o    (vif.rd_ptr),
        .wr_ptr_o    (vif.wr_ptr),
        .fifo_sz_o   (vif.fifo_sz),
        .fifo_full_o (vif.fifo_full),
        .fifo_empty_o(vif.fifo_empty)
    );

    initial begin
        if ($test$plusargs("WAVE")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, fifo_tb_top);
        end
    end

    initial begin
        uvm_config_db#(virtual fifo_interface)::set(null, "*", "vif", vif);
        run_test("fifo_base_test");
    end

endmodule
