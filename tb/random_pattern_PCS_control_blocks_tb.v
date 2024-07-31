`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: LCD -FCEFyN
// 
// Create Date: 17.05.2024 10:45:39
// Design Name: Line Loopback (LL) Setup
// Module Name: random_pattern_PCS_control_blocks_tb
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


module random_pattern_PCS_control_blocks_tb;

    // Internal module parameters
    parameter DATA_WIDTH            = 64            ;
    parameter CTRL_WIDTH            = (DATA_WIDTH/8);
    parameter HDR_WIDTH             = 2             ;
    parameter BIT_REVERSE           = 0             ;
    parameter SCRAMBLER_DISABLE     = 1             ;
    parameter PRBS31_ENABLE         = 0             ;
    parameter TX_SERDES_PIPELINE    = 0             ;
    parameter RX_SERDES_PIPELINE    = 0             ;
    parameter BITSLIP_HIGH_CYCLES   = 1             ;
    parameter BITSLIP_LOW_CYCLES    = 8             ;
    parameter COUNT_125US           = 125           ;

    // Registers to store clock and reset
    reg rx_clk, rx_rst, tx_clk, tx_rst;
    
    // Input signals from xgmii encoded
    reg  [DATA_WIDTH -1 : 0] xgmii_txd              ;
    reg  [CTRL_WIDTH -1 : 0] xgmii_txc              ;
    // Input signals from xgmii decoded
    wire [DATA_WIDTH -1 : 0] xgmii_rxd              ;
    wire [CTRL_WIDTH -1 : 0] xgmii_rxc              ;
    
    // SERDES signals for tx and rx
    wire [DATA_WIDTH -1 : 0] serdes_tx_data         ;
    wire [HDR_WIDTH  -1 : 0] serdes_tx_hdr          ;
    reg  [DATA_WIDTH -1 : 0] serdes_rx_data         ;
    reg  [HDR_WIDTH  -1 : 0] serdes_rx_hdr          ;
    
    // Error flag in the Tx
    wire                    tx_bad_block            ;
    
    // Error flags in the Rx
    wire                    serdes_rx_reset_req     ;
    wire                    rx_bad_block            ;
    wire                    rx_sequence_error       ;
    wire                    rx_high_ber             ;
    
    // Flags in the Rx
    wire                    rx_block_lock           ;
    wire                    serdes_rx_bitslip       ;
    wire                    rx_status               ;

    // Error counters
    wire [6 : 0           ] rx_error_count          ;
    reg  [3 : 0           ] ber_count               ;
    reg  [6 : 0           ] errored_block_count     ;
    reg  [6 : 0           ] test_pattern_error_count;
    reg  [6 : 0           ] transmission_error_count;
    
    // Enable PRBS31
    reg                     cfg_tx_prbs31_enable;
    reg                     cfg_rx_prbs31_enable;

    // Create an array with bit patterns
    reg  [63 : 0          ] test_patterns [5 : 0]   ;
    
    // Delay signal
    reg  [63 : 0          ] delay_reg     [5 : 0]   ;
    reg  [63 : 0          ] delayed_serdes_tx_data  ;
    
    // Counter
    integer i;
    integer seed1, seed2, seed3, seed4, seed5, seed6;

    // Instance of the module PHY 10G Ethernet under test
    eth_phy_10g #(
        .DATA_WIDTH         (DATA_WIDTH         ),
        .CTRL_WIDTH         (CTRL_WIDTH         ),
        .HDR_WIDTH          (HDR_WIDTH          ),
        .BIT_REVERSE        (BIT_REVERSE        ),
        .SCRAMBLER_DISABLE  (SCRAMBLER_DISABLE  ),
        .PRBS31_ENABLE      (PRBS31_ENABLE      ),
        .TX_SERDES_PIPELINE (TX_SERDES_PIPELINE ),
        .RX_SERDES_PIPELINE (RX_SERDES_PIPELINE ),
        .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
        .BITSLIP_LOW_CYCLES (BITSLIP_LOW_CYCLES ),
        .COUNT_125US        (COUNT_125US        )
    ) dut (
        .rx_clk              (rx_clk              ),
        .rx_rst              (rx_rst              ),
        .tx_clk              (tx_clk              ),
        .tx_rst              (tx_rst              ),
        .xgmii_txd           (xgmii_txd           ),
        .xgmii_txc           (xgmii_txc           ),
        .xgmii_rxd           (xgmii_rxd           ),
        .xgmii_rxc           (xgmii_rxc           ),
        .serdes_tx_data      (serdes_tx_data      ),
        .serdes_tx_hdr       (serdes_tx_hdr       ),
        .serdes_rx_data      (serdes_rx_data      ),
        .serdes_rx_hdr       (serdes_rx_hdr       ),
        .serdes_rx_bitslip   (serdes_rx_bitslip   ),
        .serdes_rx_reset_req (serdes_rx_reset_req ),
        .tx_bad_block        (tx_bad_block        ),
        .rx_error_count      (rx_error_count      ),
        .rx_bad_block        (rx_bad_block        ),
        .rx_sequence_error   (rx_sequence_error   ),
        .rx_block_lock       (rx_block_lock       ),
        .rx_high_ber         (rx_high_ber         ),
        .rx_status           (rx_status           ),
        .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable),
        .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
    );
    
    event terminate_sim;

    always #5 rx_clk = ~rx_clk;
    always #5 tx_clk = ~tx_clk; 
    
    initial
        begin: TEST_CASE
            // Initialize clock and reset signals
            rx_rst = 1'b1;
            rx_clk = 1'b0;
            tx_rst = 1'b1;
            tx_clk = 1'b0;
            
            // Seed the random number generator
            seed1 = 32'h1;
            seed2 = 32'h2;
            seed3 = 32'h3;
            seed4 = 32'h4;
            seed5 = 32'h5;
            seed6 = 32'h6;
           
            // Assign patterns to the array
            test_patterns[0] = {{$random(seed1), $random}};
            test_patterns[1] = {{$random(seed2), $random}};
            test_patterns[2] = {{$random(seed3), $random}};
            test_patterns[3] = {{$random(seed4), $random}};
            test_patterns[4] = {{$random(seed5), $random}};
            test_patterns[5] = {{$random(seed6), $random}};
            
            // Initialize error counters to zero
            test_pattern_error_count = 1'b0;
            errored_block_count      = 1'b0;
            transmission_error_count = 1'b0;

            // Initialize SERDES_rx_control signals
            xgmii_txc                = 8'h00;
            xgmii_txd                = 2'h0 ;
            serdes_rx_data           = 64'h0;
            serdes_rx_hdr            = 2'h2 ;
            
            // Disable PRBS31
            cfg_rx_prbs31_enable     = 1'b0;
            cfg_tx_prbs31_enable     = 1'b0;

            // Set Reset to 0
            #300
            @(posedge rx_clk);
            rx_rst                   = 1'b0;
            tx_rst                   = 1'b0;
            transmission_error_count = 1'b0;
            
            // Initialize monitors
            $display("\n ---------Starting simulation---------"                                  );
            $monitor("Time: %0t | block lock: %0d"              , $time, rx_block_lock           );
            $monitor("Time: %0t | high_ber: %0d"                , $time, rx_high_ber             );
            $monitor("Time: %0t | bitslip: %0d"                 , $time, serdes_rx_bitslip       );
            $monitor("Time: %0t | ber count: %0d"               , $time, ber_count               );
            $monitor("Time: %0t | errored block count: %0d"     , $time, errored_block_count     );
            $monitor("Time: %0t | test pattern error count: %0d", $time, test_pattern_error_count);
            $monitor("Time: %0t | transmission error count: %0d", $time, transmission_error_count);
           
            $display("\n ---------Receiver reset---------"                                       );
            // End the simulation
           #2800
           @(posedge rx_clk);
           ->terminate_sim;
        end
        
        always @(posedge tx_clk) begin
            for (i = 0; i < 6; i = i + 1) begin
                xgmii_txd      <= test_patterns[i]; 
                #10   
                serdes_rx_data <= serdes_tx_data  ;
                serdes_rx_hdr  <= 2'h2            ;
            end
        end
        
        
        always @(posedge rx_clk) begin
            ber_count    <= dut.eth_phy_10g_rx_inst.eth_phy_10g_rx_if_inst.eth_phy_10g_rx_ber_mon_inst.ber_count_reg;
            // Shift the signal by 6 clock cycles
            delay_reg[0]           <= serdes_tx_data;
            delay_reg[1]           <= delay_reg[0];
            delay_reg[2]           <= delay_reg[1];
            delay_reg[3]           <= delay_reg[2];
            delay_reg[4]           <= delay_reg[3];
            delay_reg[5]           <= delay_reg[4];
            delayed_serdes_tx_data <= delay_reg[5];
            
            if(delayed_serdes_tx_data != serdes_rx_data) begin
                transmission_error_count <= transmission_error_count + 1'b1;
            end
            
            if(rx_error_count != 0) begin
                errored_block_count      <= rx_error_count;
                test_pattern_error_count <= rx_error_count;
            end   
                      
            // Check for errors
            if ($time > 300) begin
                if(rx_high_ber || serdes_rx_bitslip || (ber_count > 0) || (errored_block_count > 0) || (test_pattern_error_count > 0) || (transmission_error_count)) begin
                   // End the simulation if there are any errors
                    ->terminate_sim;
                end
            end
        end
        
        always @(terminate_sim) begin
            $display("\n ---------Final state---------"                                          );
            $display("Time: %0t | block lock: %0d"              , $time, rx_block_lock           );
            $display("Time: %0t | high_ber: %0d"                , $time, rx_high_ber             );
            $display("Time: %0t | bitslip: %0d"                 , $time, serdes_rx_bitslip       );
            $display("Time: %0t | ber count: %0d"               , $time, ber_count               );
            $display("Time: %0t | errored block count: %0d"     , $time, errored_block_count     );
            $display("Time: %0t | test pattern error count: %0d", $time, test_pattern_error_count);
            $display("Time: %0t | transmission error count: %0d", $time, transmission_error_count);
            if(rx_block_lock && !rx_high_ber && !serdes_rx_bitslip && (ber_count == 0) && (errored_block_count == 0) && (test_pattern_error_count == 0) && (transmission_error_count == 0)) begin
                $display("The test passed successfully");
            end else begin
                $display("Test did not pass");
                if(!rx_block_lock) begin
                    $display("Block lock is unset");
                end
                if(rx_high_ber) begin
                    $display("High ber is set");
                end
                if(serdes_rx_bitslip) begin
                    $display("Bitslip is set");
                end
                if(ber_count > 0) begin
                    $display("Ber count is %0d", ber_count);
                end
                if(errored_block_count > 0) begin
                    $display("Errored block count is %0d", errored_block_count);
                end
                if(test_pattern_error_count > 0) begin
                    $display("Test pattern error count is %0d", test_pattern_error_count);
                end 
                if(transmission_error_count > 0) begin
                    $display("The transmitted and received data do not match");
                    $display("Serdes_tx_data: %0d", delayed_serdes_tx_data);
                    $display("Serdes_rx_data: %0d", serdes_rx_data);
                end
            end
            #5 $finish;
        end  
       
endmodule

