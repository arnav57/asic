import cocotb
import collections

class SyncFIFOScoreboard:
	def __init__(self, name="FIFO_Scoreboard"):
		self.name = name
		self.reference = collections.deque()

		# stats
		self.passed_count = 0
		self.failed_count = 0

	def log(self, msg, level="info"):
		"""Custom logger for the scoreboard."""
		formatted_msg = f"[{self.name}] {msg}"
		if level == "info":
			cocotb.log.info(formatted_msg)
		elif level == "warning":
			cocotb.log.warning(formatted_msg)
		elif level == "error":
			cocotb.log.error(formatted_msg)
	
	def push(self, transaction):
		""" Pushes into the reference q """
		self.reference.append(transaction)

	def pop(self):
		""" Pops from the reference q """
		try:
			rval =  self.reference.popleft()
			return rval
		except IndexError:
			self.log(f"Reference FIFO is already empty!", level="error")
			return None

	def check(self, reference_pop, implementation_pop):
		if reference_pop == implementation_pop:
			self.log(f"PASS: Expected pop {reference_pop}, got {implementation_pop}")
			self.passed_count += 1
		else:
			self.log(f"ERROR: Expected pop {reference_pop}, got {implementation_pop}", level="error")
			self.failed_count += 1