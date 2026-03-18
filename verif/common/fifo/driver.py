##### verif/common/fifo/driver.py
# for: design/fifo/fifo.sv

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly

class SyncFIFODriver:
    def __init__(self, dut):
        """
        Initializes the Synchronous FIFO Driver. Assumes my naming convention :)
        """
        self.dut = dut
        self.tag = self.dut._path

        #### Assign them as objects now
        # general
        self.clk                = getattr(self.dut, "fifo_clk_i"   )
        self.rstn               = getattr(self.dut, "fifo_rstn_i"  )
        self.write_en           = getattr(self.dut, "wr_en_i"      )
        self.write_data         = getattr(self.dut, "wr_data_i"    )
        self.read_en            = getattr(self.dut, "rd_en_i"      )
        self.read_data          = getattr(self.dut, "rd_data_o"    )
        # pointers and flags
        self.read_ptr           = getattr(self.dut, "rd_ptr_o"     )
        self.write_ptr          = getattr(self.dut, "wr_ptr_o"     )
        self.fifo_size          = getattr(self.dut, "fifo_sz_o"    )
        self.fifo_full          = getattr(self.dut, "fifo_full_o"  )
        self.fifo_empty         = getattr(self.dut, "fifo_empty_o" )
        # parameters
        self.p_fifo_depth       = getattr(self.dut, "FIFO_DEPTH"   )
        self.p_fifo_width       = getattr(self.dut, "FIFO_WIDTH"   )
        self.p_ptr_size         = None # can be derived if needed.
    
        ## SAFELY INITIALIZE SIGNALS
        self.write_en.value   = 0
        self.write_data.value = 0
        self.read_en.value    = 0

    def log(self, msg, level="info"):
        """Wraps the global logger to automatically prepend the DUT path."""
        formatted_msg = f"[{self.tag}] {msg}"
        if level == "info":
            cocotb.log.info(formatted_msg)
        elif level == "warning":
            cocotb.log.warning(formatted_msg)
        elif level == "error":
            cocotb.log.error(formatted_msg)

    def log_pointer_info(self):
        """ Logs current FIFO pointer/status info """
        self.log(f"Current Status: full={self.fifo_full.value}, empty={self.fifo_empty.value}, size={self.fifo_size.value.integer}, write_ptr={self.write_ptr.value.integer}, read_ptr={self.read_ptr.value.integer}")

    async def push(self, data):
        """ Pushes a single item into the FIFO """
        self.log(f"Attemping to write {data} into the FIFO...")
        self.log_pointer_info()

        # if the fifo is full we wait
        while self.fifo_full.value == 1:
            await RisingEdge(self.clk)

        self.write_data.value   = data
        self.write_en.value     = 1
        await RisingEdge(self.clk)
        self.write_en.value     = 0

        self.log(f"Wrote {data} into the FIFO\n")
        self.log_pointer_info()

    async def pop(self):
        """ Pops a single item from the FIFO """
        self.log(f"Attemping to read from the FIFO...")
        self.log_pointer_info()

        # if the fifo is empty we do nothing
        if (self.fifo_empty.value == 1):
            return

        self.read_en.value = 1
        await RisingEdge(self.clk)
        self.read_en.value = 0
        await ReadOnly()

        await FallingEdge(self.clk) # switches out of readonly mode before returning

        self.log(f"Read {self.read_data.value.integer} from the FIFO...\n")
        self.log_pointer_info()
        return self.read_data.value.integer
