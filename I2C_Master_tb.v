`timescale 1ns / 1ps

module I2C_Master_tb;

reg clk_i, rst_i, m_w_r_i, m_start_i, m_stop_i, m_ack_i;
reg [6:0] m_slv_add_i;
reg [7:0] m_data_i;
wire SCL, m_busy_o, m_data_ready_o, m_error_o;
wire [7:0] m_data_o;

wire SDA;
reg sda_tb;
reg sda_control_tb;

assign SDA = sda_control_tb ? sda_tb : 1'bz;

always #10 clk_i = ~clk_i;

I2C_Master DUT ( .clk_i(clk_i), .rst_i(rst_i), .m_w_r_i(m_w_r_i), .m_start_i(m_start_i), .m_stop_i(m_stop_i),
    .m_ack_i(m_ack_i), .m_slv_add_i(m_slv_add_i), .m_data_i(m_data_i), .SDA(SDA), .SCL(SCL), .m_busy_o(m_busy_o), 
    .m_data_ready_o(m_data_ready_o), .m_error_o(m_error_o), .m_data_o(m_data_o) 
);

initial begin
    clk_i = 0; 
    rst_i = 0;
    m_stop_i = 0;
    m_start_i = 0;
    m_w_r_i = 0;
    m_ack_i = 1;
    sda_tb = 1;
    sda_control_tb = 0;
    m_slv_add_i = 7'b1010101;
    m_data_i = 8'b11001100;
    
    #100 rst_i = 1;
    
    // Wait for stable
    #1000;
    
    // Test write
    $display("Starting WRITE test at time %t", $time);
    m_start_i = 1;
    m_w_r_i = 0;
    #100 m_start_i = 0;
    
    // Wait for transaction to complete
    wait(m_busy_o == 1'b0);
    $display("WRITE test complete at time %t", $time);
    
    #1000;
    
    // Test READ
    $display("Starting READ test at time %t", $time);
    m_start_i = 1;
    m_w_r_i = 1;
    m_ack_i = 1;  // Send ACK to continue reading
    #100 m_start_i = 0;
    
    // Simulate slave sending data
    repeat(100) @(posedge clk_i);
    
    // Send data as slave
    sda_control_tb = 1;
    sda_tb = 1; // Bit 7
    @(posedge clk_i);
    sda_tb = 0; // Bit 6
    @(posedge clk_i);
    sda_tb = 1; // Bit 5
    @(posedge clk_i);
    sda_tb = 0; // Bit 4
    @(posedge clk_i);
    sda_tb = 1; // Bit 3
    @(posedge clk_i);
    sda_tb = 0; // Bit 2
    @(posedge clk_i);
    sda_tb = 1; // Bit 1
    @(posedge clk_i);
    sda_tb = 0; // Bit 0
    @(posedge clk_i);
    
    // Release SDA for master ACK
    sda_control_tb = 0;
    
    // Wait for transaction to complete
    wait(m_busy_o == 1'b0);
    $display("READ test complete at time %t", $time);
    
    #1000;
    $finish;
end

initial begin
    $monitor("Time: %t | State: %d | SCL: %b SDA: %b | Busy: %b | Data: %h", 
             $time, DUT.current_state, SCL, SDA, m_busy_o, m_data_o);
end

endmodule