`timescale 1ns/1ps

package uart_env_pkg;
    // 1. Bring in the UVM library
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // 2. Include our files in the exact order of dependency
    
    // Data must come first
    `include "uart_transaction.sv"
    
    // The Brain needs to know about the Data
    `include "./tx/uart_tx_sequence.sv"
    
    // The Workers need to know about the Data
    `include "./tx/uart_tx_driver.sv"
    `include "./rx/uart_rx_monitor.sv"
    
    // The Controller needs to know about the Workers
    `include "./rx/uart_rx_agent.sv"
    `include "./tx/uart_tx_agent.sv"

    `include "uart_scoreboard.sv"
    
    // The Motherboard needs to know about the Controller
    `include "uart_env.sv"

endpackage : uart_env_pkg