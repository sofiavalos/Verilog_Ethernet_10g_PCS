`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: LCD -FCEFyN
// 
// Create Date: 17.05.2024 10:45:39
// Design Name: Line Loopback (LL) Setup
// Module Name: eth_phy_10g_block_lock_prob_tb
// Project Name: Ethernet 10GBASE PCS Blocks
// Description: Check block_lock conditions
// 
// Dependencies: eth_phy_10g
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module eth_phy_10g_block_lock_prob_tb;

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
    reg  [DATA_WIDTH -1 : 0] xgmii_txd         ;
    reg  [CTRL_WIDTH -1 : 0] xgmii_txc         ;
    // Input signals from xgmii decoded
    wire [DATA_WIDTH -1 : 0] xgmii_rxd         ;
    wire [CTRL_WIDTH -1 : 0] xgmii_rxc         ;
    
    // SERDES signals for tx and rx
    wire [DATA_WIDTH -1 : 0] serdes_tx_data    ;
    wire [HDR_WIDTH  -1 : 0] serdes_tx_hdr     ;
    reg  [DATA_WIDTH -1 : 0] serdes_rx_data    ;
    reg  [HDR_WIDTH  -1 : 0] serdes_rx_hdr     ;
    
    // Error flag in the Tx
    wire                    tx_bad_block       ;
    
    // Error flags in the Rx
    wire                    serdes_rx_reset_req;
    wire                    rx_bad_block       ;
    wire                    rx_sequence_error  ;
    wire                    rx_high_ber        ;
    
    // Flags in the Rx
    wire                    rx_block_lock      ;
    wire                    serdes_rx_bitslip  ;
    wire                    rx_status          ;
    
    // Error counters
    wire [6 : 0           ] rx_error_count     ;
    reg  [3 : 0           ] ber_count          ;
    
    // Enable PRBS31
    reg                     cfg_tx_prbs31_enable;
    reg                     cfg_rx_prbs31_enable;
    
    // Counter
    integer j;
    integer k;
    
    //
    reg [5:0] sh_cnt        ;
    reg [5:0] sh_valid_cnt  ;
    reg [3:0] sh_invalid_cnt;
    reg [3:0] bitslip       ;
    reg [9:0] random_number ;
    reg [9:0] random_seed   ;
    reg [9:0] prob          ;
    reg [1:0] sync_hdr      ; 
    reg [9:0] min           ;
    reg [9:0] max           ;
    reg [6:0] test_ok_cnt   ;
    reg [11:0] percentage;

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
    
    initial begin: TEST_CASE
        // Initialize clock and reset signals
        rx_rst               = 1'b1 ;
        rx_clk               = 1'b0 ;
        tx_rst               = 1'b1 ;
        tx_clk               = 1'b0 ;
        
        // Disable PRBS31
        cfg_tx_prbs31_enable = 1'b0 ;
        cfg_rx_prbs31_enable = 1'b0 ;
        
        serdes_rx_hdr        = 2'b01;
        sh_cnt               = 1'b0 ;
        sh_valid_cnt         = 1'b0 ;
        sh_invalid_cnt       = 1'b0 ;
        test_ok_cnt          = 1'b0 ;

        // Set Reset to 0
        #200;
        @(posedge rx_clk);
        rx_rst               = 1'b0 ;
        tx_rst               = 1'b0 ;
        
        // Loop through 100 test cases
        for (k = 0; k < 100; k = k + 1) begin
            // Reset
            @(posedge rx_clk);
            rx_rst              = 1'b1 ;
            #200;
            @(posedge rx_clk);
            rx_rst               = 1'b0 ;
            // Set different values for min and max for each test case
            min = k*100;         
            max = min + 'd100    ;
            // Run the test for the current values of min and max
            run_test(min, max);
            
            if(rx_block_lock) begin
                $display("Test %0d: PASSED", k);
                test_ok_cnt = test_ok_cnt + 1'b1;
            end
            else
                $display("Test %0d: FAILED", k);
        end
        
        -> terminate_sim;
    end 
    
    always @(terminate_sim) begin
        $display("With a probability of %0d/1000, %0d%% of the tests pass", prob, test_ok_cnt);
        #5 $finish;
    end  

    task run_test(input [9:0] min_val, input [9:0] max_val);
        begin
            min = min_val;
            max = max_val;
            if (!rx_rst) begin
                sh_cnt         = 1'b0;
                sh_invalid_cnt = 1'b0;
                for (j = 0; j < 64; j = j + 1) begin
                    random_seed   = $urandom_range(min, max);
                    random_number = $dist_uniform(random_seed, 1, 1000);
                    sync_hdr      = 2'b01;
                    if (random_number <= prob) begin
                        sync_hdr[0]    = 1'b0;
                        sh_cnt         = 1'b0;
                        sh_invalid_cnt = sh_invalid_cnt + 'd1;
                        bitslip        = 3'b111;
                    end else begin
                        sync_hdr[0] = 1'b1;
                        if (bitslip) begin
                            bitslip = bitslip - 'd1;
                            j       = 'd0;
                        end else
                            sh_valid_cnt  = sh_valid_cnt + 'd1;
                        sh_cnt            = sh_cnt       + 'd1;
                        #10;
                        @(posedge rx_clk);
                    end
                    serdes_rx_hdr = sync_hdr;
                end
            end
        end
    endtask
    
    
    `define TEST_1
    
    `ifdef TEST_1
        initial begin
            prob = 'd1;
        end
    `elsif TEST_2
        initial begin
            prob = 'd5;
        end
    `elsif TEST_3
        initial begin
            prob = 'd10;
        end
    `endif

endmodule