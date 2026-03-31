import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, with_timeout
import random
from cocotbext.uart import UartSource, UartSink

class SOUPProtocol:
    """Helper class to generate SOUP protocol frames."""
    START_BYTE = 0x33
    STOP_BYTE  = 0xCC
    CRC_DUMMY  = 0xAA

    @staticmethod
    def create_data_frame(cmd, payload):
        """{ START 0x33, CMD_TYPE, LEN, PAYLOAD, CRC, STOP 0xCC }"""
        frame = [SOUPProtocol.START_BYTE]
        frame.append(cmd & 0x7F) # MSb 0 for Data
        frame.append(len(payload) & 0xFF)
        frame.extend(payload)
        frame.append(SOUPProtocol.CRC_DUMMY)
        frame.append(SOUPProtocol.STOP_BYTE)
        return frame

    @staticmethod
    def create_cmd_frame(cmd):
        """{ START 0x33, CMD_TYPE, STOP 0xCC }"""
        frame = [SOUPProtocol.START_BYTE]
        frame.append(cmd | 0x80) # MSb 1 for Response/Command
        frame.append(SOUPProtocol.STOP_BYTE)
        return frame

async def reset_dut(dut):
    """Reset the SOUP Top Level."""
    dut.soup_rstn_i.value = 0
    # Inputs initialization
    dut.PAD_RX.value = 1
    dut.start_data_i.value = 0
    dut.cmd_type_i.value = 0
    dut.fifo_wr_en_i.value = 0
    dut.fifo_wr_data_i.value = 0
    dut.soup_loopback_en_i.value = 0
    dut.tx_start_i.value = 0
    dut.fifo_rd_en_i.value = 0
    
    await Timer(100, units="ns")
    dut.soup_rstn_i.value = 1
    await Timer(100, units="ns")
    for _ in range(10):
        await RisingEdge(dut.soup_clk_i)

@cocotb.test()
async def test_soup_ack_response(dut):
    """Test that SOUP responds with an ACK after a valid data frame."""
    BAUD_RATE  = 1_000_000
    # Observed 1000ns per bit with 10ns clock in waves?
    # Let's try 100MHz logic freq (10ns period)
    cocotb.start_soon(Clock(dut.soup_clk_i, 20, units="ns").start()) 
    
    uart_source = UartSource(dut.PAD_RX, baud=BAUD_RATE, bits=8)
    uart_sink   = UartSink(dut.PAD_TX,   baud=BAUD_RATE, bits=8)
    
    await reset_dut(dut)
    
    # Monitor FSM states
    async def monitor_signals():
        last_rcv = None
        last_send = None
        last_tx = None
        while True:
            await RisingEdge(dut.soup_clk_i)
            t = cocotb.utils.get_sim_time(units="ns")
            rcv_st = int(dut.I_soup_rcv.soup_cmd_st_r.value)
            send_st = int(dut.I_soup_send.soup_tx_st_r.value)
            tx = int(dut.PAD_TX.value)
            if (rcv_st != last_rcv or send_st != last_send or tx != last_tx):
                cocotb.log.info(f"[{t:>10} ns] FSM: RCV={rcv_st}, SEND={send_st}, TX={tx}")
                last_rcv = rcv_st
                last_send = send_st
                last_tx = tx

    cocotb.start_soon(monitor_signals())

    # 1. Start read task early
    async def read_response(count):
        data = []
        for _ in range(count):
            data.extend(await uart_sink.read(count=1))
        return data

    read_task = cocotb.start_soon(read_response(3))

    # Wait for the UART line to be stable (idle high)
    await Timer(100, units="us")
    
    payload = [0x11, 0x22, 0x33, 0x44]
    frame = SOUPProtocol.create_data_frame(cmd=0x00, payload=payload)
    cocotb.log.info(f"Sending SOUP Data Frame: {[hex(b) for b in frame]}")
    
    for byte in frame:
        await uart_source.write([byte])
        await uart_source.wait()
        await Timer(10, units="us") # 10 bit periods gap
    
    cocotb.log.info("Waiting for SOUP ACK Response...")
    response = await with_timeout(read_task, 20, "ms")
    cocotb.log.info(f"Received Response: {[hex(b) for b in response]}")
    
    assert response[0] == 0x33, "Invalid Start Byte"
    assert response[1] == 0x80, f"Expected ACK (0x80), got {hex(response[1])}"
    assert response[2] == 0xCC, "Invalid Stop Byte"

@cocotb.test()
async def test_soup_loopback(dut):
    """Test SOUP Loopback: Receive Data -> Write to FIFO -> Send back from FIFO."""
    BAUD_RATE = 1_000_000
    cocotb.start_soon(Clock(dut.soup_clk_i, 20, units="ns").start())
    
    uart_source = UartSource(dut.PAD_RX, baud=BAUD_RATE, bits=8)
    uart_sink   = UartSink(dut.PAD_TX,   baud=BAUD_RATE, bits=8)
    
    await reset_dut(dut)
    dut.soup_loopback_en_i.value = 1
    
    async def read_response(count):
        data = []
        for _ in range(count):
            data.extend(await uart_sink.read(count=1))
        return data

    # Start reading for ACK
    ack_task = cocotb.start_soon(read_response(3))

    payload = [random.randint(0, 255) for _ in range(8)]
    frame = SOUPProtocol.create_data_frame(cmd=0x01, payload=payload)
    
    cocotb.log.info(f"Sending Loopback Frame: {[hex(b) for b in frame]}")
    for byte in frame:
        await uart_source.write([byte])
        await uart_source.wait()
        await Timer(10, units="us")
    
    cocotb.log.info("Waiting for ACK...")
    ack_response = await with_timeout(ack_task, 2, "ms")
    cocotb.log.info(f"Received ACK: {[hex(b) for b in ack_response]}")
    assert ack_response[1] == 0x80
    
    cocotb.log.info("Waiting for Loopback Data Frame back...")
    expected_len = 5 + len(payload)
    loop_task = cocotb.start_soon(read_response(expected_len))
    loopback_frame = await with_timeout(loop_task, 5, "ms")
    cocotb.log.info(f"Received Loopback Frame: {[hex(b) for b in loopback_frame]}")
    
    received_payload = loopback_frame[3:3+len(payload)]
    assert list(received_payload) == payload, f"Payload mismatch! Expected {payload}, got {list(received_payload)}"
    assert loopback_frame[1] == 0x00, "Command mismatch in loopback frame (hardcoded 0x00 in RTL)"
