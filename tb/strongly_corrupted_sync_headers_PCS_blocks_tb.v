`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: LCD -FCEFyN
// 
// Create Date: 17.05.2024 10:45:39
// Design Name: Line Loopback (LL) Setup
// Module Name: strongly_corrupted_sync_headers_PCS_blocks_tb
// Project Name: Ethernet 10GBASE PCS Blocks
// Description: Check that the same data sent from Host PCS TX is received in Host PCS RX.
// 
// Dependencies: eth_phy_10g
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module strongly_corrupted_sync_headers_PCS_blocks_tb;

    // Internal module parameters
    parameter DATA_WIDTH = 64;
    parameter CTRL_WIDTH = (DATA_WIDTH/8);
    parameter HDR_WIDTH = 2;
    parameter BIT_REVERSE = 0;
    parameter SCRAMBLER_DISABLE = 1;
    parameter PRBS31_ENABLE = 0;
    parameter TX_SERDES_PIPELINE = 0;
    parameter RX_SERDES_PIPELINE = 0;
    parameter BITSLIP_HIGH_CYCLES = 1;
    parameter BITSLIP_LOW_CYCLES = 8;
    parameter COUNT_125US = 125000/6.4;

    // Registers to store clock and reset
    reg rx_clk, rx_rst, tx_clk, tx_rst;
    
    // Input signals from xgmii encoded
    reg [DATA_WIDTH-1:0] xgmii_txd;
    reg [CTRL_WIDTH-1:0] xgmii_txc;
    // Input signals from xgmii decoded
    wire [DATA_WIDTH-1:0] xgmii_rxd;
    wire [CTRL_WIDTH-1:0] xgmii_rxc;
    
    // SERDES signals for tx and rx
    wire [DATA_WIDTH-1:0] serdes_tx_data;
    wire [HDR_WIDTH-1:0]  serdes_tx_hdr;
    reg [DATA_WIDTH-1:0] serdes_rx_data;
    reg [HDR_WIDTH-1:0]  serdes_rx_hdr;
    
    // Error flag in the Tx
    wire tx_bad_block;
    
    // Error flags in the Rx
    wire serdes_rx_reset_req;
    wire rx_bad_block;
    wire rx_sequence_error;
    wire rx_high_ber;
    
    // Flags in the Rx
    wire rx_block_lock;
    wire serdes_rx_bitslip;
    wire rx_status;
    reg pcs_status;
    
    // Error counters
    wire [6:0] rx_error_count;
    reg [3:0] ber_count;
    reg [6:0] errored_block_count;
    reg [6:0] test_pattern_error_count;
    reg [6:0] transmission_error_count;
    
    // Enable PRBS31
    reg cfg_tx_prbs31_enable, cfg_rx_prbs31_enable;
    
    // Create an array with bit patterns
    reg [63:0] test_patterns [0:5];
    
    // Delay signal
    reg [63:0] delay_reg [5:0];
    reg [63:0] delayed_serdes_tx_data;
    
    // Counter
    integer i;

    // Instance of the module PHY 10G Ethernet under test
    eth_phy_10g #(
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .HDR_WIDTH(HDR_WIDTH),
        .BIT_REVERSE(BIT_REVERSE),
        .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
        .PRBS31_ENABLE(PRBS31_ENABLE),
        .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
        .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
        .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
        .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
        .COUNT_125US(COUNT_125US)
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
        .serdes_rx_bitslip(serdes_rx_bitslip),
        .serdes_rx_reset_req(serdes_rx_reset_req),
        .tx_bad_block(tx_bad_block),
        .rx_error_count(rx_error_count),
        .rx_bad_block(rx_bad_block),
        .rx_sequence_error(rx_sequence_error),
        .rx_block_lock(rx_block_lock),
        .rx_high_ber(rx_high_ber),
        .rx_status(rx_status),
        .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable),
        .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
    );
    
    event terminate_sim;
    
    initial
        begin: TEST_CASE
            // Initialize clock and reset signals
            rx_rst = 1;
            rx_clk = 0;
            tx_rst = 1;
            tx_clk = 0;
            
            // Assign patterns to the array
            test_patterns[0] = 64'hFFFFFFFFFFFFFFFF; 
            test_patterns[1] = 64'h0000000000000000; 
            test_patterns[2] = 64'h5555555555555555; 
            test_patterns[3] = 64'hAAAAAAAAAAAAAAAA; 
            test_patterns[4] = 64'hFEFEFEFEFEFEFEFE; 
            test_patterns[5] = 64'h0707070707070707; 
            
            // Initialize the error flags to 0
            pcs_status = 1'b0;
            
            // Initialize error counters to zero
            test_pattern_error_count = 0;
            errored_block_count = 0;
            transmission_error_count = 0;
            
            // Disable PRBS31
            cfg_tx_prbs31_enable = 0;
            cfg_rx_prbs31_enable = 0;

            // Set Reset to 0
            #10 
            rx_rst = 0;
            tx_rst = 0;
            
            // Initialize monitors
            $display("\n ---------Starting simulation---------");
            $monitor("Time: %0t | block lock: %0d", $time, rx_block_lock);
            $monitor("Time: %0t | high_ber: %0d", $time, rx_high_ber);
            $monitor("Time: %0t | bitslip: %0d", $time, serdes_rx_bitslip);
            $monitor("Time: %0t | PCS status: %0d", $time, pcs_status);
            $monitor("Time: %0t | ber count: %0d", $time, ber_count);
            $monitor("Time: %0t | errored block count: %0d", $time, errored_block_count);
            $monitor("Time: %0t | test pattern error count: %0d", $time, test_pattern_error_count);
            // Initialize SERDES_rx_control signals
            xgmii_txc = 8'h00;
           
            // Wait for enough time for the transmission to settle          
            #120
            rx_rst = 1;
            // Reset Rx to clear any setup errors
            #10 
            rx_rst = 0;
            $display("\n ---------Receiver reset---------");
            #40
            transmission_error_count = 0;
            $monitor("Time: %0t | transmission error count: %0d", $time, transmission_error_count);
            
            // End the simulation
           #2800
           ->terminate_sim;
        end
        
        always begin
            #10 
            rx_clk = ~rx_clk;
            tx_clk = ~tx_clk;
         end        
        
        
        always @(posedge tx_clk) begin
            for (i = 0; i < 6; i = i + 1) begin
                xgmii_txd <= test_patterns[i];    
            #20
                serdes_rx_data <= serdes_tx_data;
            end
        end
        
        initial begin
            serdes_rx_hdr <= 2'h2;
            #1200;
            serdes_rx_hdr <= 2'h0;
            #1000;
            serdes_rx_hdr <= 2'h1;
            #100;
            serdes_rx_hdr <= 2'h3;
            #600;
            serdes_rx_hdr <= 2'h2;
            #100;
            serdes_rx_hdr <= 2'h3;
        end
        
        
        always @(posedge rx_clk) begin
            ber_count <= dut.eth_phy_10g_rx_inst.eth_phy_10g_rx_if_inst.eth_phy_10g_rx_ber_mon_inst.ber_count_reg;
            // Shift the signal by 6 clock cycles
            delay_reg[0] <= serdes_tx_data;
            delay_reg[1] <= delay_reg[0];
            delay_reg[2] <= delay_reg[1];
            delay_reg[3] <= delay_reg[2];
            delay_reg[4] <= delay_reg[3];
            delay_reg[5] <= delay_reg[4];
            delayed_serdes_tx_data <= delay_reg[5];
            
            if(delayed_serdes_tx_data != serdes_rx_data) begin
                transmission_error_count = transmission_error_count + 1;
            end
            
            if(rx_error_count != 0) begin
                errored_block_count <= rx_error_count;
                test_pattern_error_count <= rx_error_count;
            end   
                
            if(rx_block_lock && !rx_high_ber) begin
                pcs_status = 1'b1;
            end else begin
                pcs_status = 1'b0;
            end
            
            // Check for errors
            if ($time > 200) begin
                if((errored_block_count > 0) || (test_pattern_error_count > 0)) begin
                   // End the simulation if there are any errors
                    ->terminate_sim;
                end
            end
            
            if ($time > 1440) begin
                if(pcs_status || rx_block_lock) begin
                   // End the simulation if there are any errors
                    ->terminate_sim;
                end
            end
        end
        
        always @(terminate_sim) begin
            $display("\n ---------Final state---------");
            $display("block lock: %0d", rx_block_lock);
            $display("high_ber: %0d", rx_high_ber);
            $display("bitslip: %0d", serdes_rx_bitslip);
            $display("PCS status: %0d", pcs_status);
            $display("ber count: %0d", ber_count);
            $display("errored block count: %0d", errored_block_count);
            $display("test pattern error count: %0d", test_pattern_error_count);
            if(!pcs_status && !rx_block_lock && rx_high_ber && (errored_block_count == 0) && (test_pattern_error_count == 0)) begin
                $display("The test passed successfully");
            end else begin
                $display("Test did not pass");
                if(rx_block_lock) begin
                    $display("Block lock is set");
                end
                if(!rx_high_ber) begin
                    $display("High ber is unset");
                end
                if(!serdes_rx_bitslip) begin
                    $display("Bitslip is unset");
                end
                if(pcs_status) begin
                    $display("PCS status is set");
                end
                if(ber_count == 0) begin
                    $display("Ber count is %0d", ber_count);
                end
                if(errored_block_count > 0) begin
                    $display("Errored block count is %0d", errored_block_count);
                end
                if(test_pattern_error_count > 0) begin
                    $display("Test pattern error count is %0d", test_pattern_error_count);
                end 
            end
            #5 $finish;
        end  
       
endmodule
