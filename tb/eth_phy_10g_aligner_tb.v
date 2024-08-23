`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: LCD -FCEFyN
// 
// Create Date: 17.05.2024 10:45:39
// Design Name: Line Loopback (LL) Setup
// Module Name: eth_phy_10g_aligner_tb
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

module eth_phy_10g_aligner_tb;

    // Internal module parameters
    parameter DATA_WIDTH            = 64                                                                        ;
    parameter CTRL_WIDTH            = (DATA_WIDTH/8)                                                            ;
    parameter HDR_WIDTH             = 2                                                                         ;
    parameter FRAME_WIDTH           = DATA_WIDTH + HDR_WIDTH                                                    ;                                  
    parameter BIT_REVERSE           = 0                                                                         ;
    parameter SCRAMBLER_DISABLE     = 1                                                                         ;
    parameter PRBS31_ENABLE         = 0                                                                         ;
    parameter TX_SERDES_PIPELINE    = 0                                                                         ;
    parameter RX_SERDES_PIPELINE    = 0                                                                         ;
    parameter BITSLIP_HIGH_CYCLES   = 1                                                                         ;
    parameter BITSLIP_LOW_CYCLES    = 8                                                                         ;
    parameter COUNT_125US           = 125                                                                       ;

    // Registers to store clock and reset
    reg rx_clk, rx_rst                                                                                          ;
    
    // Output signals from xgmii decoded                                                                    
    wire [DATA_WIDTH -1 : 0] xgmii_rxd                                                                          ;
    wire [CTRL_WIDTH -1 : 0] xgmii_rxc                                                                          ;

    // SERDES signals foR rx                                                                    
    reg  [FRAME_WIDTH -1 : 0] serdes_rx                                                                         ;

    // Error flags in the Rx                                                                    
    wire                    serdes_rx_reset_req                                                                 ;
    wire                    rx_bad_block                                                                        ;
    wire                    rx_sequence_error                                                                   ;
    wire                    rx_high_ber                                                                         ;

    // Flags in the Rx                                                                  
    wire                    rx_block_lock                                                                       ;
    wire                    o_rx_block_lock                                                                     ;
    wire                    serdes_rx_bitslip                                                                   ;
    wire                    rx_status                                                                           ;
    
    // Enable PRBS31
    reg                     cfg_rx_prbs31_enable                                                                ;
    
    reg [9              : 0] random_number                                                                      ;
    reg [9              : 0] random_seed                                                                        ;
    reg [9              : 0] prob                                                                               ;
    reg [9              : 0] min                                                                                ;
    reg [9              : 0] max                                                                                ;
    reg [6              : 0] test_ok_cnt                                                                        ;
    reg [11             : 0] percentage                                                                         ;

    integer i;
    integer j;
    integer k;
    
    event terminate_sim;

    `define TEST8
    `define PROB3
    
    always #5 rx_clk = ~rx_clk                                                                                  ; 
    
    initial
        begin: TEST_CASE
            // Initialize clock and reset signals
            rx_rst               = 1'b1                                                                         ;
            rx_clk               = 1'b0                                                                         ;
            
            // Disable PRBS31
            cfg_rx_prbs31_enable = 1'b0                                                                         ;

            // 
            test_ok_cnt          = 'd0                                                                          ;
            serdes_rx            = 'd0                                                                          ;
            max                  = 'd0                                                                          ;
            min                  = 'd0                                                                          ;
            random_seed          = 'd0                                                                          ;
            random_number        = 'd0                                                                          ;
            test_ok_cnt          = 'd0                                                                          ;
            i                    = 'd0                                                                          ;
            j                    = 'd0                                                                          ;
            k                    = 'd0                                                                          ;
            percentage           = 'd0                                                                          ;
            
            // Set Reset to 0
            #200
            @(posedge rx_clk)                                                                                   ; 
            rx_rst               = 1'b0                                                                         ;
           
            // Initialize monitors
            $display("\n ---------Starting simulation---------"             )                                   ;
            //$monitor("Time: %0t | Block Lock: %0d", $time, rx_block_lock    )                                   ;
            //$monitor("Time: %0t | High Ber: %0d"  , $time, rx_high_ber      )                                   ;
            //$monitor("Time: %0t | Aligner: %0d"   , $time, o_rx_block_lock  )                                   ;
        end 
        
        
    always @(terminate_sim) begin
        if(o_rx_block_lock)
            $display("\n----------------TEST PASSED----------------")                                           ;
        else                                            
            $display("\n----------------TEST FAILED----------------")                                           ;
        $display("\n FINAL STATE"                                   )                                           ;
        $display("-Block Lock: %0d", rx_block_lock                  )                                           ;
        $display("-High Ber: %0d"  , rx_high_ber                    )                                           ;
        $display("-Aligner: %0d"   , o_rx_block_lock                )                                           ;
        
        #5 $finish;
    end  
        
        
    // Envia el encabezado en la primera posicion
    `ifdef TEST1
        initial begin
            #200                                                                                                ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}}}                                                            ;
            #1700                                                                                               ;
            @(posedge rx_clk)                                                                                   ;          
            ->terminate_sim                                                                                     ;
        end
    // Envia el encabezado al medio
    `elsif TEST2
        initial begin
            #200                                                                                                ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {{DATA_WIDTH/2{1'b0}}, 2'b10, {DATA_WIDTH/2{1'b0}}}                                    ;
            #2780                                                                                               ;
            @(posedge rx_clk)                                                                                   ;
            ->terminate_sim                                                                                     ;
        end
    // Envia el encabezado en la ultima posicion
    `elsif TEST3
        initial begin
            #200                                                                                                ;
            @(posedge rx_clk)                                                                                   ;  
            serdes_rx <= {{FRAME_WIDTH - 1{1'b0}}, 1'b1}                                                        ;
            #4000                                                                                               ;
            @(posedge rx_clk)                                                                                   ;
            ->terminate_sim                                                                                     ;
        end
    // Envia el encabezado separado en 2 paquetes
    `elsif TEST4
        initial begin
            #210                                                                                                ;
            @(posedge rx_clk)                                                                                   ;
            for(i = 0; i < 400; i = i + 1) begin                                                                
                serdes_rx <= {FRAME_WIDTH{1'b0}}                                                                ;
                #10                                                                                             ;
                @(posedge rx_clk)                                                                               ;  
                serdes_rx <= {FRAME_WIDTH{1'b1}}                                                                ;
                #10                                                                                             ;
                @(posedge rx_clk)                                                                               ;
            end
            ->terminate_sim;
        end
    // Alinea el bloque y luego envia 15 encabezados invalidos
    `elsif TEST5
        initial begin
            #200                                                                                                ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}}}                                                            ;
            #1500                                                                                               ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {FRAME_WIDTH{1'b0}}                                                                    ;
            #300                                                                                                ;   
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}}}                                                            ;       
            ->terminate_sim                                                                                     ;
        end
    // Envia 64 encabezados validos y luego 1 invalido
    `elsif TEST6
        initial begin
            #200                                                                                                ;
            @(posedge rx_clk)                                                                                   ;      
            serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}}}                                                            ;
            #1290                                                                                               ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {FRAME_WIDTH{1'b0}}                                                                    ;
            #10                                                                                                 ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}}}                                                            ;
            #300                                                                                                ;  
            @(posedge rx_clk)                                                                                   ;      
            ->terminate_sim                                                                                     ;
        end
    // Envia 63 encabezados validos y luego 1 invalido
    `elsif TEST7
        initial begin
            #200                                                                                                ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}}}                                                            ;
            // 64 sync headers = 64*20 = 1280                                                       
            #1270                                                                                               ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {FRAME_WIDTH{1'b0}}                                                                    ;
            #10                                                                                                 ;
            @(posedge rx_clk)                                                                                   ;
            serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}}}                                                            ;
            #300                                                                                                ;  
            @(posedge rx_clk)                                                                                   ;      
            ->terminate_sim                                                                                     ; 
        end
    // Test con valores aleatorios
    `elsif TEST8
        initial begin
            #200                                                                                                ;
            @(posedge rx_clk)                                                                                   ;
            // Loop through 100 test cases
            for (k = 0; k < 100; k = k + 1) begin
                // Reset
                @(posedge rx_clk);
                rx_rst              = 1'b1                                                                      ;
                #200                                                                                            ;
                @(posedge rx_clk);
                rx_rst               = 1'b0                                                                     ;
                // Set different values for min and max for each test case
                min = k*100                                                                                     ;         
                max = min + 'd100                                                                               ;
                // Run the test for the current values of min and max
                run_test(min, max)                                                                              ;
                
                if(o_rx_block_lock) begin
                    $display("Test %0d: PASSED", k)                                                             ;
                    test_ok_cnt = test_ok_cnt + 1'b1                                                            ;
                end
                else
                    $display("Test %0d: FAILED", k)                                                             ;
            end
            $display("With a probability of %0d/1000, %0d%% of the tests pass", prob, test_ok_cnt)              ;
            $finish                                                                                             ;
        end
    `endif

    `ifdef PROB1
        initial begin
            prob = 'd1                                                                                          ;                                                                                                                      
        end
    `elsif PROB2
        initial begin
            prob = 'd5                                                                                          ;
        end
    `elsif PROB3
        initial begin
            prob = 'd10                                                                                         ;
        end
    `endif

    task run_test(input [9:0] min_val, input [9:0] max_val);
    begin
        min = min_val                                                                                           ;
        max = max_val                                                                                           ;
        if (!rx_rst) begin
            for (j = 0; j < 140; j = j + 1) begin
                random_seed    = $urandom_range(min, max            )                                           ;
                random_number  = $dist_uniform (random_seed, 1, 1000)                                           ;
                serdes_rx     <= {2'b01, {DATA_WIDTH{1'b0}} }                                                   ;
                if (random_number <= prob) begin
                    serdes_rx <= {FRAME_WIDTH{1'b0}         }                                                   ;
                end 
                else begin
                    serdes_rx <= {2'b01, {DATA_WIDTH{1'b0}} }                                                   ;
                end
                #10                                                                                             ;
                @(posedge rx_clk)                                                                               ;
            end
        end
    end
    endtask

    // Instance of the module PHY 10G Ethernet under test
    eth_phy_10g #(
        .DATA_WIDTH         (DATA_WIDTH         )                                                               ,
        .CTRL_WIDTH         (CTRL_WIDTH         )                                                               ,
        .HDR_WIDTH          (HDR_WIDTH          )                                                               ,
        .FRAME_WIDTH        (FRAME_WIDTH        )                                                               ,
        .BIT_REVERSE        (BIT_REVERSE        )                                                               ,
        .SCRAMBLER_DISABLE  (SCRAMBLER_DISABLE  )                                                               ,
        .PRBS31_ENABLE      (PRBS31_ENABLE      )                                                               ,
        .TX_SERDES_PIPELINE (TX_SERDES_PIPELINE )                                                               ,
        .RX_SERDES_PIPELINE (RX_SERDES_PIPELINE )                                                               ,
        .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES)                                                               ,
        .BITSLIP_LOW_CYCLES (BITSLIP_LOW_CYCLES )                                                               ,
        .COUNT_125US        (COUNT_125US        )
    ) dut (
        .rx_clk              (rx_clk              )                                                             ,
        .rx_rst              (rx_rst              )                                                             ,
        .tx_clk              (                    )                                                             ,
        .tx_rst              (                    )                                                             ,
        .xgmii_txd           (                    )                                                             ,
        .xgmii_txc           (                    )                                                             ,
        .xgmii_rxd           (xgmii_rxd           )                                                             ,
        .xgmii_rxc           (xgmii_rxc           )                                                             ,
        .serdes_tx_data      (serdes_tx_data      )                                                             ,
        .serdes_tx_hdr       (serdes_tx_hdr       )                                                             ,
        .serdes_rx           (serdes_rx           )                                                             ,
        .serdes_rx_bitslip   (serdes_rx_bitslip   )                                                             ,
        .serdes_rx_reset_req (serdes_rx_reset_req )                                                             ,
        .tx_bad_block        (                    )                                                             ,
        .rx_error_count      (rx_error_count      )                                                             ,
        .rx_bad_block        (rx_bad_block        )                                                             ,
        .rx_sequence_error   (rx_sequence_error   )                                                             ,
        .rx_block_lock       (rx_block_lock       )                                                             ,
        .o_rx_block_lock     (o_rx_block_lock     )                                                             ,
        .rx_high_ber         (rx_high_ber         )                                                             ,
        .rx_status           (rx_status           )                                                             ,
        .cfg_tx_prbs31_enable(                    )                                                             ,
        .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
    );


endmodule