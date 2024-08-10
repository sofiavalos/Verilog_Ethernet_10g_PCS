`timescale 1ns / 1ps
`default_nettype none

module eth_phy_10g_rx_aligner_tb();

    // Parameters
    parameter FRAME_WIDTH   = 66                                                                                            ;
    parameter DATA_WIDTH    = 64                                                                                            ;
    parameter HDR_WIDTH     = 2                                                                                             ;            

    // Status
    wire                      o_rx_block_lock                                                                               ;

    // Serdes interface
    wire [HDR_WIDTH   -1 : 0] o_serdes_rx_hdr                                                                               ;
    wire [DATA_WIDTH  -1 : 0] o_serdes_rx_data                                                                              ;
    reg  [FRAME_WIDTH -1 : 0] i_serdes_rx                                                                                   ;


    reg                       i_rst                                                                                         ;
    reg                       clk                                                                                           ;


    always #5 clk = ~clk                                                                                                    ;

    initial begin
        i_rst       = 1'b1                                                                                                  ;
        clk         = 1'b0                                                                                                  ;
        #1000                                                                                                               ;                                                                        
        @(posedge clk)                                                                                                      ;
        i_rst       = 1'b0                                                                                                  ;   
        @(posedge clk) 
        // Envia datos con el encabezado al inicio                                                                          
        i_serdes_rx = {2'b01, {DATA_WIDTH{1'b1}}}                                                                           ;
        #10000                                                                                                              ;
        @(posedge clk)                                                                                                      ;
        i_rst       = 1'b1                                                                                                  ;
        #1000                                                                                                               ;
        @(posedge clk)                                                                                                      ;
        i_rst       = 1'b0                                                                                                  ;
        @(posedge clk)                                                                                                      ;
        // Envia datos con encabezado en la posicion final
        i_serdes_rx = {{DATA_WIDTH{1'b0}}, 2'b01}                                                                           ;
        #10000                                                                                                              ;
        @(posedge clk)                                                                                                      ;
        i_rst       = 1'b1                                                                                                  ;
        #1000                                                                                                               ;
        @(posedge clk)                                                                                                      ;
        i_rst       = 1'b0                                                                                                  ;
        @(posedge clk)                                                                                                      ;
        // Envia datos con el encabezado al medio
        i_serdes_rx = {{32{1'b1}}, 2'b01,{32{1'b1}}}                                                                        ;
        #10000                                                                                                              ;
        i_rst       = 1'b1                                                                                                  ;
        #1000                                                                                                               ;
        @(posedge clk)                                                                                                      ;
        i_rst       = 1'b0                                                                                                  ;
        @(posedge clk)                                                                                                      ;
        // Envia 63 encabezados validos
        i_serdes_rx = {2'b01,   {DATA_WIDTH{1'b1}}}                                                                         ;
        #100                                                                                                                ;
        @(posedge clk)                                                                                                      ;
        // Cambia el encabezado a la segunda posicion
        i_serdes_rx = {4'b0001,  {DATA_WIDTH - 2{1'b1}}}                                                                     ;
        #10000                                                                                                              ;
        $finish                                                                                                             ;
    end


    eth_phy_10g_rx_aligner
    #(
        .FRAME_WIDTH       (FRAME_WIDTH         )                                                                           ,
        .DATA_WIDTH        (DATA_WIDTH          )                                                                           ,
        .HDR_WIDTH         (HDR_WIDTH           )                                                                                            
    )dut
    (
        // Status
        .o_rx_block_lock   (o_rx_block_lock     )                                                                           ,

        // Serdes interface
        .o_serdes_rx_hdr   (o_serdes_rx_hdr     )                                                                           ,
        .o_serdes_rx_data  (o_serdes_rx_data    )                                                                           ,
        .i_serdes_rx       (i_serdes_rx         )                                                                           ,


        .i_rst              (i_rst              )                                                                           ,
        .clk                (clk                )                                                                           
    );
    
endmodule