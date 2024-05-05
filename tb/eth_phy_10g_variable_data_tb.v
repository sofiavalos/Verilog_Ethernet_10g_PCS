`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Module: eth_phy_10g_variable_data_tb                                       
// LCD - FCEFyN
////////////////////////////////////////////////////////////////////////////////

module eth_phy_10g_variable_data_tb;

// Clock and Reset signals
reg rx_clk;
reg rx_rst;
reg tx_clk;
reg tx_rst;

// Communication signals between modules
reg [63:0] xgmii_txd;   // XGMII input data
reg [7:0] xgmii_txc;    // XGMII control signals
wire tx_bad_block;      // Signal for bad blocks
wire [1:0] serdes_tx_hdr; // Transmitter header
wire [63:0] serdes_tx_data; // Transmitter data
reg [1:0] serdes_rx_hdr; // Receiver header
reg [63:0] serdes_rx_data; // Receiver data
wire [63:0] xgmii_rxd;  // XGMII output data
wire [7:0] xgmii_rxc;   // XGMII output control signals

//
integer delay_count; // Delay counter


// Instance of the PHY 10G Ethernet module
eth_phy_10g #(
    .DATA_WIDTH(64),
    .CTRL_WIDTH(8),
    .HDR_WIDTH(2)
) dut (
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),
    .xgmii_txd(xgmii_txd),
    .xgmii_txc(xgmii_txc),
    .xgmii_rxd(xgmii_rxd),
    .xgmii_rxc(xgmii_rxc),
    .serdes_tx_data(serdes_tx_data),
    .serdes_tx_hdr(serdes_tx_hdr),
    .serdes_rx_data(serdes_rx_data),
    .serdes_rx_hdr(serdes_rx_hdr),
    .serdes_rx_bitslip(),
    .serdes_rx_reset_req(),
    .tx_bad_block(tx_bad_block),
    .rx_error_count(rx_error_count),
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),
    .cfg_tx_prbs31_enable(1'b0),
    .cfg_rx_prbs31_enable(1'b0)
);

// Initialize parameters
initial begin
    // Initialize signals
    rx_rst = 1;
    rx_clk = 0;
    tx_rst = 1;
    tx_clk = 0;
    
    // Start delay counter at 0
    delay_count = 0;
    
    // Deassert Reset after 10 time units
    fork
        #10 rx_rst = 0;
        #10 tx_rst = 0;
    join
    
    // Initialize XGMII data after 10s of reset
    xgmii_txd = 64'h0FA58D310FA58D31;
    // Initialize XGMII control signals
    xgmii_txc = 8'h00;
end

// Update data on positive edge of tx_clk
always @(posedge tx_clk) begin
    serdes_rx_data <= serdes_tx_data;
    serdes_rx_hdr <= serdes_tx_hdr;

    // Delay synchronization counter
    if (xgmii_txc != xgmii_rxc) begin
        delay_count = delay_count + 1;
    end
    
end

// Clock generator
always begin
    fork
        #10 rx_clk = ~rx_clk;
        #10 tx_clk = ~tx_clk;
    join
end 

// Change data
always begin
    #100
    xgmii_txd = 64'hCAFEBABECAFEBABE;
    xgmii_txc = 8'h00;
    #100
    xgmii_txd = 64'hBAADF00DBAADF00D;
    xgmii_txc = 8'h00;
    #100
    xgmii_txd = 64'h4A4F414F4A4F414F;
    xgmii_txc = 8'h00;
end

// Finish simulation, display message
initial begin
    #1000; // Wait to ensure simulation is finished
    $display("ciclos de reloj desfazados" + delay_count);
    $finish; // Terminate simulation
end

endmodule
