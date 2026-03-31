import serial
import time
import random
import msvcrt

class SoupInterface:
    SOUP_START = 0x33
    SOUP_STOP  = 0xCC
    CMD_DATA   = 0x00  
    DUMMY_CRC  = 0xAA  

    def __init__(self, port, baudrate=1e6):
        print(f"Opening physical bridge on {port} at {baudrate} baud...")
        self.ser = serial.Serial(port, baudrate, timeout=1.0) 
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()
        time.sleep(0.1) 

    def stress_test_engine(self):
        """Infinite loop that blasts data, verifies it, and calculates protocol metrics upon exit."""
        print("\n[System] 🚀 VISUAL STRESS TEST INITIATED 🚀")
        print("         - Blasting random payloads.")
        print("         - Tracking physical wire throughput vs actual data goodput.")
        print("         - Press and hold 'Q' to abort and generate report.\n")

        packets_sent = 0
        payload_bytes_transferred = 0
        total_wire_bytes = 0
        errors = 0
        
        start_time = time.time()

        try:
            while True:
                if msvcrt.kbhit() and msvcrt.getch().lower() == b'q':
                    print("\n[System] Abort sequence triggered by user.")
                    break

                tx_len = random.randint(0,255)
                tx_payload = [random.randint(0, 255) for _ in range(tx_len)]

                tx_frame = bytearray([self.SOUP_START, self.CMD_DATA, tx_len])
                tx_frame.extend(tx_payload)
                tx_frame.extend([self.DUMMY_CRC, self.SOUP_STOP])
                
                tx_hex_str = tx_frame.hex().upper()
                print(f"[TX] -> {tx_hex_str}")
                
                self.ser.write(tx_frame)
                self.ser.flush()

                rx_raw = bytearray()

                # --- PHASE 1: CATCH THE ACK ---
                char = self.ser.read(1)
                if not char or ord(char) != self.SOUP_START:
                    print(f"[!] TIMEOUT OR SYNC ERROR waiting for ACK.")
                    errors += 1
                    break
                rx_raw.extend(char)
                    
                cmd_type_bytes = self.ser.read(1)
                rx_raw.extend(cmd_type_bytes)
                
                if (ord(cmd_type_bytes) & 0x80) != 0:
                    stop_byte = self.ser.read(1) 
                    rx_raw.extend(stop_byte)
                else:
                    print("[FATAL] Expected ACK frame, received Data frame first!")
                    errors += 1
                    break

                # --- PHASE 2: CATCH THE LOOPBACK DATA ---
                char = self.ser.read(1)
                if not char or ord(char) != self.SOUP_START:
                    print(f"[!] TIMEOUT OR SYNC ERROR waiting for DATA.")
                    errors += 1
                    break
                rx_raw.extend(char)
                
                cmd_type_bytes2 = self.ser.read(1)
                rx_raw.extend(cmd_type_bytes2)
                
                if (ord(cmd_type_bytes2) & 0x80) == 0:
                    rx_len_bytes = self.ser.read(1)
                    rx_raw.extend(rx_len_bytes)
                    rx_len = ord(rx_len_bytes)
                    
                    if rx_len > 0:
                        rx_payload_bytes = self.ser.read(rx_len)
                        rx_raw.extend(rx_payload_bytes)
                        rx_payload = list(rx_payload_bytes)
                    else:
                        rx_payload = []
                        
                    crc_stop = self.ser.read(2) 
                    rx_raw.extend(crc_stop)
                else:
                    print("[FATAL] Expected Data frame, received second ACK!")
                    errors += 1
                    break

                rx_hex_str = rx_raw.hex().upper()
                print(f"[RX] <- {rx_hex_str}\n")

                # --- VERIFICATION ---
                if tx_payload != rx_payload:
                    print(f"[FATAL DATA CORRUPTION] on Packet {packets_sent}")
                    errors += 1
                    break

                # --- METRICS TRACKING ---
                packets_sent += 1
                payload_bytes_transferred += tx_len
                
                # Math for total bytes on the physical wire:
                # TX Frame (5 overhead + Payload) + RX ACK (3 bytes) + RX Loopback (5 overhead + Payload)
                bytes_this_cycle = (5 + tx_len) + 3 + (5 + tx_len)
                total_wire_bytes += bytes_this_cycle

        except KeyboardInterrupt:
            print("\n[System] Force halted by user.")
            
        finally:
            total_time = time.time() - start_time
            if total_time > 0 and packets_sent > 0:
                # 115200 baud / 10 bits per byte (8N1) = 11,520 bytes/sec max theoretical
                theoretical_max_kbps = 11.52 
                throughput_kbps = (total_wire_bytes / 1024) / total_time
                goodput_kbps = (payload_bytes_transferred / 1024) / total_time
                efficiency = (payload_bytes_transferred / total_wire_bytes) * 100
                baud_utilization = (throughput_kbps / theoretical_max_kbps) * 100
                avg_payload = payload_bytes_transferred / packets_sent

                print(f"\n=========================================")
                print(f"       SOUP PROTOCOL PERFORMANCE REPORT  ")
                print(f"=========================================")
                print(f" Test Duration      : {total_time:.2f} seconds")
                print(f" Packets Verified   : {packets_sent} packets")
                print(f" Data Errors        : {errors}")
                print(f" Avg Payload Size   : {avg_payload:.1f} bytes/packet")
                print(f"-----------------------------------------")
                print(f" Total Wire Traffic : {total_wire_bytes} bytes")
                print(f" Payload Data Moved : {payload_bytes_transferred} bytes")
                print(f" Protocol Overhead  : {100 - efficiency:.1f}%")
                print(f"-----------------------------------------")
                print(f" Raw Throughput     : {throughput_kbps:.2f} KB/s")
                print(f" Actual Goodput     : {goodput_kbps:.2f} KB/s")
                print(f" Baud Utilization   : {baud_utilization:.1f}% of 115200 limit")
                print(f"=========================================\n")
            else:
                print("\n[!] Not enough data collected to generate report.")

    def close(self):
        self.ser.close()
        print("Physical bridge closed.")

if __name__ == '__main__':
    FPGA_PORT = 'COM5' 
    try:
        fpga = SoupInterface(port=FPGA_PORT)
        fpga.stress_test_engine()
    except serial.SerialException as e:
        print(f"Hardware Error: Could not open {FPGA_PORT}. Is another program using it?")
    finally:
        if 'fpga' in locals():
            fpga.close()