module I2C_Master (
    input wire clk_i, rst_i, m_w_r_i, m_start_i, m_stop_i, m_ack_i,
    input wire [6:0] m_slv_add_i, 
    input wire [7:0] m_data_i,
    inout SDA,  // Bidirectional
    output reg SCL, m_busy_o, m_data_ready_o, m_error_o, 
    output reg [7:0] m_data_o
);

// 0 - IDLE // 1 - start // 2 - address // 3 - ack_1 // 4 - write // 5 - read // 6 - ack_2 // 7 - stop 
localparam   S0 = 3'b000, S1 = 3'b001, S2 = 3'b010, S3 = 3'b011, S4 = 3'b100, S5 = 3'b101, S6 = 3'b110, S7 = 3'b111;

reg [2:0] current_state, next_state;
reg [2:0] bit_count; 
reg bit_counter;
reg [7:0] shift_reg;
reg sda_enable;         // 1=drive, 0=release
reg sda_output;         // output when enabled

// Tri-state buffer
assign SDA = sda_enable ? sda_output : 1'bz;

always@(posedge clk_i or negedge rst_i) begin
    if (!rst_i) begin
        current_state <= S0;
        
        SCL <= 1'b1;           // Idle in high
        m_busy_o <= 1'b0;
        m_data_ready_o <= 1'b0;
        m_error_o <= 1'b0;
        m_data_o <= 8'b0;      // Clear out
        
        // reset counter and shifting register
        bit_count <= 3'b0;
        bit_counter <= 1'b0;
        shift_reg <= 8'b0;

        sda_enable <= 1'b0;
        sda_output <= 1'b1;
        
    end else begin
        current_state <= next_state;
    end
end

always@(*) begin
    case (current_state)
    S0: begin // IDLE

        SCL = 1'b1;
        m_busy_o = 1'b0;
        m_data_ready_o = 1'b0;
        m_error_o = 1'b0;

        sda_enable = 1'b0;
        sda_output = 1'b1;
    
        // Check for start
        if (m_start_i) begin
            next_state = S1;
            m_busy_o = 1'b1;     // busy active
            shift_reg = {m_slv_add_i, m_w_r_i}; // Address + R/W
            bit_count = 3'b0;
            sda_enable = 1'b1;
        end else begin
            next_state = S0;
        end
    end

    S1: begin // start
        SCL = 1'b1;
        m_busy_o = 1'b1;

        sda_enable = 1'b1;
        sda_output = 1'b0; // SDA low while SCL high

        next_state = S2;
        bit_count = 3'b0; // Reset counter for address bits
    end

    S2: begin // address
        m_busy_o = 1'b1;
        sda_enable = 1'b1; // Master drives SDA
    
    // each bit requires at least 2 clock cycles (SCL low → SCL high) 
    // bit counter used once as 1 and once as 0 to send one bit
    
    if (bit_counter == 1'b0) begin
        // from waveform SCL low - set up sending of 1 bit
        SCL = 1'b0;
        sda_output = shift_reg[7 - bit_count];
        bit_counter = 1'b1;
        next_state = S2;
    end
    else if (bit_counter == 1'b1) begin
        // from waveform SCL high - data stable, send bit of data
        SCL = 1'b1;
        sda_output = shift_reg[7 - bit_count];
        bit_counter = 1'b0;
        bit_count = bit_count + 1; // Move to next bit
        
        if (bit_count == 3'd7) begin
            next_state = S3;
            sda_enable = 1'b0; // Release SDA for ACK
        end else begin
            next_state = S2;
        end
    end
    end 

    S3: begin // ack_1
        m_busy_o = 1'b1;
        m_data_ready_o = 1'b0;
        m_error_o = 1'b0;
        sda_enable = 1'b0; // Release SDA for slave
    
        if (bit_counter == 1'b0) begin
            SCL = 1'b0;
            bit_counter = 1'b1;
            next_state = S3;
        end

        else begin // bit_counter == 1'b1
            SCL = 1'b1; // SDA is driven by slave
        
            if (SDA == 1'b0) begin // ACK received
                m_error_o = 1'b0;
            
                if (m_w_r_i == 1'b0) begin
                    next_state = S4;  // Go to write
                    bit_count = 3'b0; // Reset for data byte
                    shift_reg = m_data_i; // Load data to send
                    sda_enable = 1'b1; // Master drives SDA
                end else begin  // m_w_r_i == 1'b1
                    next_state = S5;  // Go to read
                    bit_count = 3'b0; // Reset for receiving data
                    shift_reg = 8'b0; // Clear shift register for received data
                    sda_enable = 1'b0; // Slave drives SDA
                end
            end else begin // NACK received
                m_error_o = 1'b1;
                next_state = S7;  // Go to stop
                sda_enable = 1'b1; // Master drives SDA
                sda_output = 1'b1;
            end
        
            bit_counter = 1'b0;
        end
    end

    S4: begin // write
        m_busy_o = 1'b1;
        m_data_ready_o = 1'b0;
        m_error_o = 1'b0;
        sda_enable = 1'b1; // Master drives SDA
    
        if (bit_counter == 1'b0) begin
            SCL = 1'b0;
            sda_output = shift_reg[7 - bit_count]; // MSB first
            bit_counter = 1'b1;
            next_state = S4;
        end
        else begin // bit_counter == 1'b1
            SCL = 1'b1;
            sda_output = shift_reg[7 - bit_count];
            bit_counter = 1'b0;
        
            if (bit_count == 3'd7) begin
                next_state = S6; // ack_2 state
                bit_count = 3'b000;
                bit_counter = 1'b0;
                sda_enable = 1'b0; // Release SDA for slave ACK
            end else begin
                bit_count = bit_count + 1;
                next_state = S4;
            end
        end
    end

    S5: begin // read
        m_busy_o = 1'b1;
        m_data_ready_o = 1'b0;
        m_error_o = 1'b0;
        sda_enable = 1'b0; // Slave drives SDA
            
        if (bit_counter == 1'b0) begin
            SCL = 1'b0;
            bit_counter = 1'b1;
            next_state = S5;
        end else begin
            SCL = 1'b1;
                
            // Read SDA and store in shift register
            shift_reg[7 - bit_count] = SDA;
            bit_counter = 1'b0;
                
            if (bit_count == 3'd7) begin
                m_data_o = shift_reg;
                m_data_ready_o = 1'b1;
                    
                // Master sends ACK or NACK
                if (m_ack_i == 1'b1) begin // Send ACK
                    next_state = S6; // ack_2 state
                    sda_enable = 1'b1;
                    sda_output = 1'b0; // ACK = 0
                end 
                else begin // Send NACK
                    next_state = S7;
                    sda_enable = 1'b1;
                    sda_output = 1'b1; // NACK = 1
                end
                bit_count = 3'b0;
            end else begin
                bit_count = bit_count + 1;
                next_state = S5;
            end
        end
    end

    S6: begin // ack_2
        m_busy_o = 1'b1;
        sda_enable = 1'b1; // Master drives SDA
            
        // This is similar to ack_1 but master drives SDA
        if (bit_counter == 1'b0) begin
            SCL = 1'b0;
            bit_counter = 1'b1;
            next_state = S6;
        end else begin
            SCL = 1'b1;
            bit_counter = 1'b0;
                
            if (m_w_r_i == 1'b0) begin // write
                next_state = S7;
                sda_enable = 1'b1;
                sda_output = 1'b1;
            end else begin // read
                if (m_ack_i == 1'b1) begin
                    next_state = S5;
                    bit_count = 3'b0;
                    shift_reg = 8'b0;
                    sda_enable = 1'b0;
                end else begin
                    next_state = S7;
                    sda_enable = 1'b1;
                    sda_output = 1'b1;
                end
            end
        end
    end

    S7: begin // stop
        // stop condintion: SDA rises while SCL is high
        SCL = 1'b1;
        sda_enable = 1'b1;
        sda_output = 1'b1;
        
        m_busy_o = 1'b0;
        next_state = S0;
        sda_enable = 1'b0;
        bit_counter = 1'b0;
    end

    default: begin next_state = S0; end
endcase
end

    
endmodule