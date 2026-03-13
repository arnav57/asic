`timescale 1ns/1ps

import uvm_pkg::*;
import uart_env_pkg::*;
`include "uvm_macros.svh"


module uart_tb_top;

    // [TODO 2: Declare your physical clock and active-low reset variables here]
    reg rstn, clk;    

    initial begin
        clk  = 1;
        forever #10 clk = ~clk;
    end

    // [TODO 4: Write an initial block to handle the reset. 
    // Hint: Assert reset (LOW), wait a bit, then de-assert it (HIGH).]
    initial begin
        rstn = 0;
        #300;
        rstn = 1;
    end
    

    // [TODO 5: Instantiate your physical 'uart_interface' here. 
    // What arguments does it need?]
    uart_rx_interface u_uart_rx_if (
        .clk(clk),
        .rstn(rstn)
    );
    
    uart_tx_interface u_uart_tx_if (
        .clk(clk),
        .rstn(rstn)
    );

    // [TODO 6: Instantiate your RTL ('uart_rx'). 
    // Map the module's ports to the signals inside your interface instance.]

    wire [7:0] rx_data_o;
    wire rx_data_valid_o;

    uart_rx I_rx_dut (
        .rx_clk_i       (u_uart_rx_if.clk            ),
        .rstn_rx_clk_i  (u_uart_rx_if.rstn           ),
        .rx_data_i      (u_uart_rx_if.rx_data_i      ),
        .rx_data_o      (u_uart_rx_if.rx_data_o      ),
        .rx_data_valid_o(u_uart_rx_if.rx_data_valid_o)
    );

    uart_tx I_tx_dut (
        .tx_clk_i       (u_uart_tx_if.clk            ),
        .rstn_tx_clk_i  (u_uart_tx_if.rstn           ),
        .tx_data_i      (u_uart_tx_if.tx_data_i      ),
        .tx_data_valid_i(u_uart_tx_if.tx_data_valid_i),
        .tx_data_o      (u_uart_tx_if.tx_data_o      ),
        .tx_busy_o      (u_uart_tx_if.tx_busy_o      )
    );

    // Set up as loopback!
    assign u_uart_rx_if.rx_data_i = u_uart_tx_if.tx_data_o;
    
    
    initial begin
        // [TODO 7: The Bridge. Use the uvm_config_db to pass your interface 
        // instance into the UVM world so your Driver and Monitor can find it.]

        // uvm_config_db#( TYPE )::set( context, "instance_path", "string_name", value );
        uvm_config_db#(virtual uart_rx_interface)::set(null, "*", "rx_vif", u_uart_rx_if);
        uvm_config_db#(virtual uart_tx_interface)::set(null, "*", "tx_vif", u_uart_tx_if);
        
        // [TODO 8: Tell UVM to start the simulation and run your specific test class.]
        run_test("uart_loopback_test");
        
    end

    initial begin
        if ($test$plusargs("WAVE")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, uart_tb_top);
        end
    end


endmodule