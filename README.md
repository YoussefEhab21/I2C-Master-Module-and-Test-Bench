# I2C-Master-Module-and-Test-Bench
I2C Master Module and Test Bench, developed in short time due to tight deadlines and still under updating and fixing issues

A I2C Master Controller module written in Verilog HDL. This module implements a single-master I2C bus controller capable of performing both write and read operations to slave devices. Designed for FPGA implementation, it follows the standard I2C protocol with proper START/STOP conditions, ACK/NACK handling, and byte-by-byte data transfer.

Standard I2C Transaction Flow

START → [7-bit Address + R/W] → ACK → [Data Byte] → ACK → STOP

# Module Logic Description: FSM implementation

S0: Idle: Wait for start command, bus idle

S1: Start: Generate a start condition (SDA is low while SCL is high)

S2: Address: Send 7-bit address + R/W bit (each bit sent over 2 cycles of SCL)

S3: Ack_1: Wait for slave acknowledge (after address)

S4: Write: Send data byte to slave (bit-by-bit using parallel to serial communication)

S5: Read: Receive data byte from slave (bit-by-bit using serial to parallel communication)

S6: Ack_2: Send ACK/NACK to slave (after read)

S7: Stop: Generate a stop condition (SDA is high while SCL is high)
