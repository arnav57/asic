import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

# FIFO driver
from common.fifo.driver     import SyncFIFODriver
from common.fifo.scoreboard import SyncFIFOScoreboard

async def reset_dut(dut):
    """Helper function to reset the FIFO."""
    dut.fifo_rstn_i.value = 0
    await Timer(20, units="ns")
    dut.fifo_rstn_i.value = 1
    await Timer(20, units="ns")

@cocotb.test()
async def test_fifo_basic(dut):
    """Test basic FIFO push and pop functionality."""
    
    # 1. Start a 100MHz clock in the background (10ns period)
    cocotb.start_soon(Clock(dut.fifo_clk_i, 10, units="ns").start())
    await reset_dut(dut)

    driver      = SyncFIFODriver(dut)
    scoreboard  = SyncFIFOScoreboard(f"{dut._path}_SB")

    # Wait a couple of clock cycles before starting traffic
    for _ in range(2):
        await RisingEdge(dut.fifo_clk_i)

    # 4. Push some data!
    test_data = []
    for i in range(0,200):
        test_data.append(random.randint(0,200))
    
    cocotb.log.info("--- STARTING PUSH PHASE ---")
    for word in test_data:
        await driver.push(word)
        scoreboard.push(word)

    # Let the FIFO settle for a cycle
    await RisingEdge(dut.fifo_clk_i)

    cocotb.log.info("--- STARTING POP PHASE ---")
    for _ in range(len(test_data)):
        actual_word = await driver.pop()
        ideal_word  = scoreboard.pop()
        scoreboard.check(ideal_word, actual_word)

    cocotb.log.info("TEST DONE!")

