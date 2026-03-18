import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, with_timeout
import random
# Import the VIP!
from cocotbext.uart import UartSource, UartSink

# At 115200 baud, 1 bit is ~8.6us.
IDLE_GAP_TIME = 20 

async def reset_dut(dut):
    """ Standard active-low reset with signal initialization """
    dut.tx_data_i.value = 0
    dut.tx_data_valid_i.value = 0
    dut.rx_data_i.value = 1 

    dut.uart_rstn_i.value = 0
    await Timer(100, units="ns")
    dut.uart_rstn_i.value = 1
    await Timer(100, units="ns")
    
    # Wait for the RX synchronizer to flush and the line to be stable IDLE
    for _ in range(10):
        await RisingEdge(dut.uart_clk_i)
    
    cocotb.log.info("--- Reset and Initialization Complete ---")

@cocotb.test()
async def test_uart_rx(dut):
    """ Test RX: Drive 10 serial bytes into RTL """
    cocotb.start_soon(Clock(dut.uart_clk_i, 20, units="ns").start())
    uart_source = UartSource(dut.rx_data_i, baud=115200, bits=8)
    dut.uart_lbpk_en_i.value = 0
    await reset_dut(dut)

    test_data = [random.randint(0, 255) for _ in range(10)]
    
    for i, val in enumerate(test_data):
        cocotb.log.info(f"[Iteration {i}] Python Source -> Sending Serial Byte: {hex(val)}")
        await uart_source.write([val])
        
        # Wait for the RTL to pulse its 'valid' signal
        while not dut.rx_data_valid_o.value:
            await RisingEdge(dut.uart_clk_i)
        
        actual_val = dut.rx_data_o.value.integer
        cocotb.log.info(f"[Iteration {i}] RTL Receiver -> Captured Parallel Byte: {hex(actual_val)}")
        
        assert actual_val == val, f"Mismatch on byte {i}!"
        
        # Ensure the bit-banging is finished before starting the gap
        await uart_source.wait()
        await Timer(IDLE_GAP_TIME, units="ns")

    cocotb.log.info("RX Test Passed: Successfully received 10 bytes")

@cocotb.test()
async def test_uart_tx(dut):
    """ Test TX: Drive 10 parallel bytes into RTL """
    cocotb.start_soon(Clock(dut.uart_clk_i, 20, units="ns").start())
    uart_sink = UartSink(dut.tx_data_o, baud=115200, bits=8)
    dut.uart_lbpk_en_i.value = 0
    await reset_dut(dut)

    test_data = [random.randint(0, 255) for _ in range(10)]

    for i, val in enumerate(test_data):
        cocotb.log.info(f"[Iteration {i}] RTL Driver -> Loading Parallel Byte: {hex(val)}")
        dut.tx_data_i.value = val
        dut.tx_data_valid_i.value = 1

        await RisingEdge(dut.uart_clk_i)
        await RisingEdge(dut.uart_clk_i) 
        dut.tx_data_valid_i.value = 0

        # Wait for VIP to decode (with a 1ms safety timeout)
        try:
            received = await with_timeout(uart_sink.read(count=1), 1, "ms")
            cocotb.log.info(f"[Iteration {i}] Python Sink -> Decoded Serial Byte: {hex(received[0])}")
            assert received[0] == val
        except Exception as e:
            cocotb.log.error(f"TX Timeout/Failure on byte {i}: {e}")
            raise
        
        await Timer(100, units="us")

    cocotb.log.info("TX Test Passed: Successfully transmitted 10 bytes")

@cocotb.test()
async def test_uart_loopback(dut):
    """ Test Full Loopback: VIP -> RX -> Loopback Mux -> TX -> VIP """
    cocotb.start_soon(Clock(dut.uart_clk_i, 20, units="ns").start())
    uart_source = UartSource(dut.rx_data_i, baud=115200, bits=8)
    uart_sink   = UartSink(dut.tx_data_o,   baud=115200, bits=8)
    
    dut.uart_lbpk_en_i.value = 1 
    await reset_dut(dut)

    test_data = [random.randint(0, 255) for _ in range(10)]
    
    # Send all bytes into the hardware loopback
    for i, val in enumerate(test_data):
        cocotb.log.info(f"[Loopback {i}] Sending Byte: {hex(val)}")
        await uart_source.write([val])
        await uart_source.wait()
        await Timer(IDLE_GAP_TIME, units="ns") 
    
    # Collect them all back
    results = []
    for i in range(10):
        # Use a 2ms timeout for the loopback path
        val = await with_timeout(uart_sink.read(count=1), 2, "ms")
        cocotb.log.info(f"[Loopback {i}] Received Byte: {hex(val[0])}")
        results.append(val[0])
        
    assert results == test_data, f"Loopback Mismatch! Expected {test_data}, got {results}"
    cocotb.log.info("Full Loopback Passed!")