`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: LCD -FCEFyN
// 
// Create Date: 17.05.2024 10:45:39
// Design Name: Line Loopback (LL) Setup
// Module Name: eth_phy_10g_block_lock_tb
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


module eth_phy_10g_block_lock_tb;

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
    parameter COUNT_125US = 125;

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
    
    // Enable PRBS31
    reg cfg_tx_prbs31_enable, cfg_rx_prbs31_enable;
    
    // Create an array with bit patterns
    reg [63:0] test_patterns [0:5];
    
    // Counter
    integer i;
    
    //
    reg [5:0] sh_cnt;
    reg [3:0] sh_invalid_cnt;

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
    
    always #10 rx_clk = ~rx_clk;
    always #10 tx_clk = ~tx_clk; 
    
    initial
        begin: TEST_CASE
            // Initialize clock and reset signals
            rx_rst = 1;
            rx_clk = 0;
            tx_rst = 1;
            tx_clk = 0;
            
            // Initialize the error flags to 0
            pcs_status = 1'b0;
            
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
            // Inicializa la data del tx
            xgmii_txc = 8'hxx;
            xgmii_txd = 64'hxxxxxxxxxxxxxxxx; 
        end 
        
        
        always @* begin
            ber_count <= dut.eth_phy_10g_rx_inst.eth_phy_10g_rx_if_inst.eth_phy_10g_rx_ber_mon_inst.ber_count_reg;
            sh_cnt <= dut.eth_phy_10g_rx_inst.eth_phy_10g_rx_if_inst.eth_phy_10g_rx_frame_sync_inst.sh_count_reg;
            sh_invalid_cnt <= dut.eth_phy_10g_rx_inst.eth_phy_10g_rx_if_inst.eth_phy_10g_rx_frame_sync_inst.sh_invalid_count_reg;
            if(rx_block_lock && !rx_high_ber) begin
                pcs_status = 1'b1;
            end else begin
                pcs_status = 1'b0;
            end
        end
        
        always @(terminate_sim) begin
            $display("\n ---------Final state---------");
            $display("block lock: %0d", rx_block_lock);
            $display("high_ber: %0d", rx_high_ber);
            $display("bitslip: %0d", serdes_rx_bitslip);
            $display("PCS status: %0d", pcs_status);
            $display("ber count: %0d", ber_count);
            
            #5 $finish;
        end  
        
        
        `define CASE_3_INVALID
        
        // Envia 63 validos, 1 invalido
        `ifdef CASE_1_VALID
            initial begin
                // Envia 63 bloques validos
                serdes_rx_hdr <= 2'h2;
               #1250;
               // Envia1 bloque invalido
               serdes_rx_hdr <= 2'h0;
               #20;
               // Envia bloques validos
                serdes_rx_hdr <= 2'h2;
            end
         // Envia 62 validos, 1 invalido, 1 valido
        `elsif CASE_2_VALID
            initial begin
                // Envia 62 bloques validos
                serdes_rx_hdr <= 2'h2;
               #1230;
               // Envia 1 bloque invalido
               serdes_rx_hdr <= 2'h0;
               #20;
               // Envia bloques validos
                serdes_rx_hdr <= 2'h2;
            end
        // Envia 64 validos, 1 invalido, resto validos
        `elsif CASE_3_VALID
            initial begin
                // Envia 64 bloques validos
                serdes_rx_hdr <= 2'h2;
               #1270;
               // Envia 1 bloque invalido
               serdes_rx_hdr <= 2'h0;
               #20;
               // Envia bloques validos
                serdes_rx_hdr <= 2'h2;
            end
        // Envia 64 validos, 15 invalido, resto validos
        `elsif CASE_1_INVALID
            initial begin
                // Envia 64 bloques validos
                serdes_rx_hdr <= 2'h2;
               #1270;
               // Envia 15 bloques invalidos
               serdes_rx_hdr <= 2'h0;
               #300;
               // Envia bloques validos
               serdes_rx_hdr <= 2'h2;
            end
        // Envia 64 validos, 15 invalido, 48 validos, 1 invalido
        `elsif CASE_2_INVALID
            initial begin
                // Envia 64 bloques validos
                serdes_rx_hdr <= 2'h2;
               #1270;
               // Envia 15 bloques invalidos
               serdes_rx_hdr <= 2'h0;
               #300;
               // Envia 48 bloques validos
               serdes_rx_hdr <= 2'h2;
               #960;
               // Envia 1 bloques invalido
               serdes_rx_hdr <= 2'h0;
               #20;
               // Envia bloques validos
               serdes_rx_hdr <= 2'h2;
            end
        `elsif CASE_3_INVALID
            initial begin
                // Envia 64 bloques validos
                serdes_rx_hdr <= 2'h2;
               #1270;
               // Envia 16 bloques invalidos
               serdes_rx_hdr <= 2'h0;
               #320;
               // Envia 8 bloques validos
               serdes_rx_hdr <= 2'h2;
               #180;
               // Envia 1 bloques invalido
               serdes_rx_hdr <= 2'h0;
               #20;
               // Envia bloques validos
               serdes_rx_hdr <= 2'h2;
            end
        `endif
            
       
endmodule

