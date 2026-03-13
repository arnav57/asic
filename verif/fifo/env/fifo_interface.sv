`timescale 1ns/1ps

interface fifo_interface #(
    parameter FIFO_WIDTH = 8,
    parameter FIFO_DEPTH = 256,
    localparam PTR_SIZE = $clog2(FIFO_DEPTH) + 1
) (input logic clk, input logic rstn);

    // Writing
    logic                  wr_en;
    logic [FIFO_WIDTH-1:0] wr_data;
    
    // Reading
    logic                  rd_en;
    logic [FIFO_WIDTH-1:0] rd_data;
    
    // FIFO State
    logic [  PTR_SIZE-1:0] rd_ptr;
    logic [  PTR_SIZE-1:0] wr_ptr;
    logic [  PTR_SIZE-1:0] fifo_sz;
    logic                  fifo_full;
    logic                  fifo_empty;

    // synchronous driving
    clocking drv_cb @(posedge clk);
        default input #1ns output #1ns;
        output wr_en;
        output wr_data;
        output rd_en;
        input  rd_data;
        input  fifo_full;
        input  fifo_empty;
    endclocking

    // synchronous monitoring
    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;
        input wr_en;
        input wr_data;
        input rd_en;
        input rd_data;
        input rd_ptr;
        input wr_ptr;
        input fifo_sz;
        input fifo_full;
        input fifo_empty;
    endclocking

endinterface : fifo_interface
