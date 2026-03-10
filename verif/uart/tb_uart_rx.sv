`timescale 1ns/1ps

module uart_rx_tb;

// Parameters
localparam BAUD_PERIOD = 1_000_000_000 / 115_200;

// DUT signals
reg clk, rstn, rx_data;
wire [7:0] rx_data_o;
wire rx_data_valid_o;

// Instantiate DUT
uart_rx #(
    .LOGIC_FREQ  (50_000_000),
    .BAUD_RATE   (115_200   ),
    .UART_LENGTH (10        )
) dut (
    .rx_clk_i        ( clk              ),
    .rstn_rx_clk_i   ( rstn             ),
    .rx_data_i       ( rx_data          ),
    .rx_data_o       ( rx_data_o        ),
    .rx_data_valid_o ( rx_data_valid_o  )
);

// Clock generator
always #10 clk = ~clk;
reg [7:0] data = $random();
reg [7:0] data_2 = $random();

// Waveform dump
initial begin
    $dumpfile("uart_rx.vcd");
    $dumpvars(0, uart_rx_tb);
end

task send_uart_byte(input [7:0] data);
    rx_data <= 1'd0; // start
    #BAUD_PERIOD;
    for (int i = 0; i < 8; i++) begin
        rx_data <= data[i];
        #BAUD_PERIOD ;
    end
    rx_data <= 1'd1; // stop
    #BAUD_PERIOD;
    #BAUD_PERIOD;
    #BAUD_PERIOD;
endtask : send_uart_byte

// Stimulus
initial begin
    clk = 1'd0;
    rstn = 1'd1;
    rx_data = 1'd1;
    # 10;
    rstn = 1'd0;
    # 10;
    rstn = 1'd1;
    #200;
    send_uart_byte(data);
    #550
    send_uart_byte(data_2);
    #BAUD_PERIOD
    $finish;
end

endmodule