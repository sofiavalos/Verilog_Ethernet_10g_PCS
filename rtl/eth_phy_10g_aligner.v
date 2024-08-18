`timescale 1ns / 1ps

/*
 * 10G Ethernet PHY aligner
 */
module eth_phy_10g_rx_aligner
#(
    parameter DATA_WIDTH        = 64                                                                                            ,
    parameter HDR_WIDTH         = 2                                                                                             ,
    parameter FRAME_WIDTH       = DATA_WIDTH + HDR_WIDTH
)
(
    // Status
    output                      o_rx_block_lock                                                                                 ,

    // Serdes interface
    output [HDR_WIDTH   -1 : 0] o_serdes_rx_hdr                                                                                 ,
    output [DATA_WIDTH  -1 : 0] o_serdes_rx_data                                                                                ,
    input  [FRAME_WIDTH -1 : 0] i_serdes_rx                                                                                     ,


    input                       i_rst                                                                                           ,
    input                       clk                                                                                           
);

    localparam SH_HDR_VALID     = $clog2(64)                                                                                    ;
    localparam SH_HDR_INVALID   = $clog2(16)                                                                                    ;

    localparam[2:0]
        STATE_LOCK_INIT         = 3'd0                                                                                          ,
        STATE_RESET_CNT         = 3'd1                                                                                          ,
        STATE_TEST_SH           = 3'd2                                                                                          ,
        STATE_VALID_SH          = 3'd3                                                                                          ,
        STATE_INVALID_SH        = 3'd4                                                                                          ,
        STATE_64_GOOD           = 3'd5                                                                                          ,
        STATE_SLIP              = 3'd6                                                                                          ;

    reg [HDR_WIDTH      - 1 : 0] serdes_rx_hdr_r                                                                                ;
    reg [DATA_WIDTH     - 1 : 0] serdes_rx_data_r                                                                               ;
    reg [(FRAME_WIDTH *2)-1 : 0] serdes_rx_frames                                                                               ;
    reg [(FRAME_WIDTH *2)-1 : 0] serdes_rx_frames_next                                                                          ;
    reg [FRAME_WIDTH    - 1 : 0] serdes_rx_prev                                                                                 ;
    reg [SH_HDR_VALID   - 1 : 0] sh_count                                                                                       ;
    reg [SH_HDR_VALID   - 1 : 0] sh_count_next                                                                                  ;
    reg [SH_HDR_INVALID - 1 : 0] sh_invalid_count                                                                               ;
    reg [SH_HDR_INVALID - 1 : 0] sh_invalid_count_next                                                                          ;
    reg [FRAME_WIDTH    - 1 : 0] slip                                                                                           ;
    reg [FRAME_WIDTH    - 1 : 0] slip_next                                                                                      ;
    reg                          sh_valid_next                                                                                  ;
    reg                          rx_block_lock_r                                                                                ;
    reg                          rx_block_lock_next                                                                             ;
    reg [2:0]                    state                                                                                          ;
    reg [2:0]                    state_next                                                                                     ;

    always @* begin
        case(state) 
            STATE_LOCK_INIT: begin
                rx_block_lock_next    = 1'b0                                                                                    ;
                sh_count_next         = sh_count                                                                                ;
                sh_invalid_count_next = sh_invalid_count                                                                        ;
                slip_next             = slip                                                                                    ;
                state_next            = STATE_RESET_CNT                                                                         ;
            end
            STATE_RESET_CNT: begin
                rx_block_lock_next    = rx_block_lock_r                                                                         ;
                sh_count_next         = {SH_HDR_VALID   - 1{1'b0}}                                                              ;
                sh_invalid_count_next = {SH_HDR_INVALID - 1{1'b0}}                                                              ;
                slip_next             = slip                                                                                    ;
                state_next            = STATE_TEST_SH                                                                           ;
            end
            STATE_TEST_SH: begin
                rx_block_lock_next    = rx_block_lock_r                                                                         ;
                sh_count_next         = sh_count                                                                                ;
                sh_invalid_count_next = sh_invalid_count                                                                        ;
                slip_next             = slip                                                                                    ;
                if(slip < FRAME_WIDTH - 1) begin
                    if(i_serdes_rx[FRAME_WIDTH - slip - 1] ^ i_serdes_rx[FRAME_WIDTH - slip -2]) 
                        state_next    = STATE_VALID_SH                                                                          ;
                    else
                        state_next    = STATE_INVALID_SH                                                                        ;  
                end      
                else begin
                    if(serdes_rx_prev[0] ^ i_serdes_rx[FRAME_WIDTH - 1])
                        state_next    = STATE_VALID_SH                                                                          ;
                    else
                        state_next    = STATE_INVALID_SH                                                                        ;  
                end
            end
            STATE_VALID_SH: begin
                rx_block_lock_next    = rx_block_lock_r                                                                         ;
                sh_count_next         = sh_count + {{SH_HDR_INVALID {1'b0}}    , 1'b1}                                                                         ;
                sh_invalid_count_next = sh_invalid_count                                                                        ;
                slip_next             = slip                                                                                    ;
                if(sh_count < 'd63)
                    state_next        = STATE_TEST_SH                                                                           ;
                else if(sh_count == 'd63 && sh_invalid_count == 'd0)
                    state_next        = STATE_64_GOOD                                                                           ;
                else 
                    state_next        = STATE_RESET_CNT                                                                         ;
            end
            STATE_INVALID_SH: begin
                rx_block_lock_next    = rx_block_lock_r                                                                         ;
                sh_count_next         = sh_count         + {{SH_HDR_VALID  {1'b0}}    , 1'b1}                                   ;
                sh_invalid_count_next = sh_invalid_count + {{SH_HDR_INVALID{1'b0}}    , 1'b1}                                   ;
                slip_next             = slip                                                                                    ;
                if(sh_count < 'd63 && sh_invalid_count < 'd15 && rx_block_lock_r)                  
                    state_next        = STATE_TEST_SH                                                                           ;
                else if(sh_count == 'd63 && sh_invalid_count < 'd15 && rx_block_lock_r)
                    state_next        = STATE_RESET_CNT                                                                         ;
                else
                    state_next        = STATE_SLIP                                                                              ;
            end
            STATE_SLIP: begin
                rx_block_lock_next    = 1'b0                                                                                    ;
                sh_count_next         = sh_count                                                                                ;
                sh_invalid_count_next = sh_invalid_count                                                                        ;
                if(slip < FRAME_WIDTH -1)
                    slip_next         = slip + {{FRAME_WIDTH  - 2{1'b0}},1'b1}                                                  ;
                else
                    slip_next         = 1'b0;             
                state_next            = STATE_RESET_CNT                                                                         ;
            end
            STATE_64_GOOD: begin
                rx_block_lock_next    = 1'b1                                                                                    ;
                sh_invalid_count_next = sh_invalid_count                                                                        ;
                slip_next             = slip                                                                                    ;
                sh_count_next         = sh_count                                                                                ;
                state_next            = STATE_RESET_CNT                                                                         ;
            end
            default: begin
                rx_block_lock_next    = rx_block_lock_r                                                                         ;
                sh_invalid_count_next = sh_invalid_count                                                                        ;
                slip_next             = slip                                                                                    ;
                sh_count_next         = sh_count                                                                                ;
                state_next            = STATE_LOCK_INIT                                                                         ;
            end
        endcase


    end


    always @(posedge clk) begin
        if(i_rst) begin
            rx_block_lock_r             <= 'd0                                                                                  ;
            sh_count                    <= 'd0                                                                                  ;
            sh_invalid_count            <= 'd0                                                                                  ;
            slip                        <= 'd0                                                                                  ;
            state                       <= STATE_LOCK_INIT                                                                      ;
            serdes_rx_prev              <= 'd0                                                                                  ;      
        end
        else begin
            rx_block_lock_r             <= rx_block_lock_next;
            sh_count                    <= sh_count_next                                                                        ;
            sh_invalid_count            <= sh_invalid_count_next                                                                ;
            slip                        <= slip_next;
            state                       <= state_next;
            serdes_rx_prev              <= i_serdes_rx                                                                          ;
        end

        if(rx_block_lock_r) begin
            serdes_rx_frames            <= {serdes_rx_prev, i_serdes_rx}                                                        ;
            serdes_rx_frames_next       <= serdes_rx_frames << slip                                                             ;
            serdes_rx_data_r            <= serdes_rx_frames_next[(FRAME_WIDTH *2)-1 -  HDR_WIDTH : FRAME_WIDTH - 1]             ;
            serdes_rx_hdr_r             <= serdes_rx_frames_next[(FRAME_WIDTH *2)-1 -: HDR_WIDTH                  ]             ;
        end
        else begin
            serdes_rx_hdr_r             <= {HDR_WIDTH{1'b0}     }                                                               ;
            serdes_rx_data_r            <= {DATA_WIDTH/2 {8'h07}}                                                               ;
            serdes_rx_frames            <= 'd0                                                                                  ;
            serdes_rx_frames_next       <= 'd0                                                                                  ;
        end

    end

    

    assign o_rx_block_lock  = rx_block_lock_r                                                                                   ;
    assign o_serdes_rx_data = serdes_rx_data_r                                                                                  ;
    assign o_serdes_rx_hdr  = serdes_rx_hdr_r                                                                                   ;



endmodule