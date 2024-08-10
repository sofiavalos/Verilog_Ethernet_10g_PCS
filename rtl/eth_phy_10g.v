/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY
 */
module eth_phy_10g #
(
    parameter DATA_WIDTH = 64,			    //! Ancho de bus de datos de 64 bits
    parameter CTRL_WIDTH = (DATA_WIDTH/8),	//! Ancho de bus de control en bytes
    parameter HDR_WIDTH = 2,			    //! Ancho de header de sincronizacion (01 para bloques de data 10 para control), permiten establecer límites de bloques
    parameter BIT_REVERSE = 0,			    //! Flag para habilitar la inversión de bits
    parameter SCRAMBLER_DISABLE = 0,		//! Flag para habilitar el scrambler
    parameter PRBS31_ENABLE = 0,		    //! Flag para habilidar la secuencia pseudoaletoria PRBS31 para pruebas
    parameter TX_SERDES_PIPELINE = 0,		//! Flag para habilitar el pipeline en el transmisor
    parameter RX_SERDES_PIPELINE = 0,		//! Flag para habilitar el pipeline en el receptor
    parameter BITSLIP_HIGH_CYCLES = 1,		//! Ciclos de bitslip bajos
    parameter BITSLIP_LOW_CYCLES = 8,		//! Ciclos de bitslip altos
    parameter COUNT_125US = 125000/6.4		//! Contador de 125 us
)
(
    input  wire                  rx_clk,	// Señal de clock para el receptor
    input  wire                  rx_rst,	// Señal de reset del receptor
    input  wire                  tx_clk,	// Señal de clock para el transmisor
    input  wire                  tx_rst,	// Señal de reset del transmisor

    /*
     * XGMII interface
     */
    input  wire [DATA_WIDTH-1:0] xgmii_txd,	//! Entrada para transmitir datos a la capa fisica
    input  wire [CTRL_WIDTH-1:0] xgmii_txc,	//! Entrada para transmitir control a la capa fisica
    output wire [DATA_WIDTH-1:0] xgmii_rxd,	//! Salida para recibir datos de la capa fisica
    output wire [CTRL_WIDTH-1:0] xgmii_rxc,	//! Salida para recibir control de la capa fisica

    /*
     * SERDES interface
     */
    output wire [DATA_WIDTH-1:0] serdes_tx_data,	//! Salida para enviar datos serializados
    output wire [HDR_WIDTH-1:0]  serdes_tx_hdr,		//! Salida para enviar encabezados serializados
    input  wire [DATA_WIDTH-1:0] serdes_rx_data,	//! Entrada para recibir datos serializados
    input  wire [HDR_WIDTH-1:0]  serdes_rx_hdr,		//! Entrada para recibir encabezados serializados
    output wire                  serdes_rx_bitslip,	//! Señal de bitslip 
    output wire                  serdes_rx_reset_req, //! Señal de reset solicitado en el receptor

    /*
     * Status
     */
    output wire                  tx_bad_block,      //! Señal de estado para indicar un bloque defectuoso durante la transmisión
    output wire [6:0]            rx_error_count,    //! Contador de errores del receptor
    output wire                  rx_bad_block,      //! Señal de estado para indicar un bloque defectuoso durante la recepción
    output wire                  rx_sequence_error, //! Señal de error en la secuencia
    output wire                  rx_block_lock,     //! Señal de bloque alineado
    output wire                  rx_high_ber,       //! Señal que indica un BER alto
    output wire                  rx_status,         //! Señal que indica bloque alineado sin BER en 125us

    /*
     * Configuration
     */
    input  wire                  cfg_tx_prbs31_enable,  //! Señal que habilita PRBS31 en el transmisor
    input  wire                  cfg_rx_prbs31_enable   //! Señal que habilita PRBS31 en el receptor
);

//! Modulo que coordina la decodificación de datos XGMII y gestiona la interfaz con el SERDES del receptor
eth_phy_10g_rx #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_phy_10g_rx_inst (
    .clk(rx_clk),
    .rst(rx_rst),
    .xgmii_rxd(xgmii_rxd),
    .xgmii_rxc(xgmii_rxc),
    .serdes_rx_data(serdes_rx_data),
    .serdes_rx_hdr(serdes_rx_hdr),
    .serdes_rx_bitslip(serdes_rx_bitslip),
    .serdes_rx_reset_req(serdes_rx_reset_req),
    .rx_error_count(rx_error_count),
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
);

//! Modulo que coordina la codificación de datos XGMII y gestiona la interfaz con el SERDES de transmisión.
eth_phy_10g_tx #(			
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .SERDES_PIPELINE(TX_SERDES_PIPELINE)
)
eth_phy_10g_tx_inst (
    .clk(tx_clk),
    .rst(tx_rst),
    .xgmii_txd(xgmii_txd),
    .xgmii_txc(xgmii_txc),
    .serdes_tx_data(serdes_tx_data),
    .serdes_tx_hdr(serdes_tx_hdr),
    .tx_bad_block(tx_bad_block),
    .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable)
);

endmodule

`resetall