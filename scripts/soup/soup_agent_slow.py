import serial
import time
import random
import msvcrt

class SoupInterface:
    SOUP_START = 0x33
    SOUP_STOP  = 0xCC
    CMD_DATA   = 0x00  
    DUMMY_CRC  = 0xAA  

    def __init__(self, port, baudrate=115200):
        print(f"Opening physical bridge on {port} at {baudrate} baud...")
        self.ser = serial.Serial(port, baudrate, timeout=0.1) 
        time.sleep(0.1) 

    def send_data_slowly(self, payload: list, delay_seconds: float = 0.25):
        """Constructs and transmits a SOUP frame, byte-by-byte with a labeled diagnostic print."""
        if len(payload) > 255:
            raise ValueError("Hardware constraint: Payload exceeds 255 bytes.")

        frame = bytearray([self.SOUP_START, self.CMD_DATA, len(payload)])
        frame.extend(payload)
        frame.extend([self.DUMMY_CRC, self.SOUP_STOP])

        print(f"\n>>> TX [SLOW MODE] : [{' '.join([f'0x{b:02X}' for b in frame])}]")
        print(f"    [!] Pushing 1 byte every {delay_seconds}s. Watch the FPGA LEDs...")

        frame_len = len(frame)
        for index, byte in enumerate(frame):
            # Dynamically label the byte based on its position in the frame
            if index == 0:
                label = "START byte "
            elif index == 1:
                label = "CMD byte   "
            elif index == 2:
                label = "LEN byte   "
            elif index == frame_len - 2:
                label = "CRC byte   "
            elif index == frame_len - 1:
                label = "STOP byte  "
            else:
                # Calculate which data byte this is (0-indexed relative to payload)
                data_index = index - 3
                label = f"DATA byte {data_index:02d}"

            print(f"  [+] Pushing {label:4s} : 0x{byte:02X}")
            self.ser.write(bytes([byte]))
            self.ser.flush()  
            time.sleep(delay_seconds) 
            
        print("    [!] Transmission complete. Switching to RX Listen...")

    def interactive_loop(self):
        """Asynchronous loop handling both keyboard interrupts and UART RX."""
        print("\n[System] Interactive Mode Active.")
        print("         - Press 'A' to generate and slowly transmit a random payload.")
        print("         - Press 'Q' or Ctrl+C to exit.")
        
        try:
            while True:
                # 1. Check for Keyboard Inputs
                if msvcrt.kbhit():
                    key = msvcrt.getch()
                    
                    if key.lower() == b'a':
                        # Generate random size between 1 and 16 bytes
                        length = random.randint(1, 16) 
                        payload = [random.randint(0, 255) for _ in range(length)]
                        
                        print(f"\n[KEYPRESS 'A'] Generating {length}-byte random payload...")
                        self.send_data_slowly(payload, delay_seconds=0.25)
                        
                    elif key.lower() == b'q':
                        print("\n[System] Quitting interactive loop...")
                        break

                # 2. Check for Incoming FPGA Data
                if self.ser.in_waiting > 0:
                    char = self.ser.read(1)
                    
                    if char and ord(char) == self.SOUP_START:
                        cmd_type_bytes = self.ser.read(1)
                        if not cmd_type_bytes: continue
                        cmd_type = ord(cmd_type_bytes)
                        
                        rx_frame = bytearray([self.SOUP_START, cmd_type])
                        is_response_cmd = (cmd_type & 0x80) != 0
                        
                        if is_response_cmd:
                            stop_byte = self.ser.read(1)
                            if stop_byte: rx_frame.append(ord(stop_byte))
                            error_flag = cmd_type & 0x01
                            print(f"<<< RX : [{' '.join([f'0x{b:02X}' for b in rx_frame])}]")
                            print(f"    [Status] {'NACK (Error)' if error_flag else 'ACK (Success)'}")
                        else:
                            length_bytes = self.ser.read(1)
                            if not length_bytes: continue
                            length = ord(length_bytes)
                            rx_frame.append(length)
                            
                            payload_data = []
                            if length > 0:
                                payload_bytes = self.ser.read(length)
                                payload_data = list(payload_bytes)
                                rx_frame.extend(payload_bytes)
                                
                            crc_stop = self.ser.read(2)
                            rx_frame.extend(crc_stop)
                            
                            print(f"<<< RX : [{' '.join([f'0x{b:02X}' for b in rx_frame])}]")
                            print(f"    [Payload Bytes] : [{' '.join([f'0x{b:02X}' for b in payload_data])}]")
                else:
                    time.sleep(0.005) 
                    
        except KeyboardInterrupt:
            print("\n[System] User interrupted listen loop.")

    def close(self):
        self.ser.close()
        print("Physical bridge closed.")


if __name__ == '__main__':
    FPGA_PORT = 'COM5' 
    
    try:
        fpga = SoupInterface(port=FPGA_PORT)
        fpga.interactive_loop()

    except serial.SerialException as e:
        print(f"Hardware Error: Could not open {FPGA_PORT}. Is another program using it?")
    finally:
        if 'fpga' in locals():
            fpga.close()