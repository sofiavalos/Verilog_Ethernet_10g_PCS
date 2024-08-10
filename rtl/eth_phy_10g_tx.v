// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY TX
 */
module eth_phy_10g_tx #
(
    parameter DATA_WIDTH = 64,			        //! Ancho de datos
    parameter CTRL_WIDTH = (DATA_WIDTH/8),	    //! Ancho de control
    parameter HDR_WIDTH = 2,			        //! Ancho de header
    parameter BIT_REVERSE = 0,			        //! Flag que habilita la inversión de bits
    parameter SCRAMBLER_DISABLE = 0,		    //! Flag que habilita el scrambler
    parameter PRBS31_ENABLE = 0,		        //! Flag que habilita la generacion de patrones pseudoaleatorios PRBS31
    parameter SERDES_PIPELINE = 0		        //! Flag que habilita el uso de pipeline en el SERDES
)
(
    input  wire                  clk,		    //! Señal de clock
    input  wire                  rst,		    //! Señal de reset

    /*
     * XGMII interface
     */
    input  wire [DATA_WIDTH-1:0] xgmii_txd	            //! Datos de entrada de XGMII a transmitirse
    input  wire [CTRL_WIDTH-1:0] xgmii_txc,	            //! Señales de control de la interfaz XGMII

    /*
     * SERDES interface
     */
    output wire [DATA_WIDTH-1:0] serdes_tx_data,	    //! Datos de salida para SERDES
    output wire [HDR_WIDTH-1:0]  serdes_tx_hdr,		    //! Header de salida para SERDES

    /*
     * Status
     */
    output wire                  tx_bad_block,		    //! Señal de estado para indicar un bloque defectuoso durante la transmisión

    /*
     * Configuration
     */
    input  wire                  cfg_tx_prbs31_enable	//! Entrada para habilitar la generacion de patrones PRBS31
);

// bus width assertions
initial begin
    if (DATA_WIDTH != 64) begin
        $error("Error: Interface width must be 64");
        $finish;
    end

    if (CTRL_WIDTH * 8 != DATA_WIDTH) begin
        $error("Error: Interface requires byte (8-bit) granularity");
        $finish;
    end

    if (HDR_WIDTH != 2) begin
        $error("Error: HDR_WIDTH must be 2");
        $finish;
    end
end

wire [DATA_WIDTH-1:0] encoded_tx_data;		//! Señal para datos codificados
wire [HDR_WIDTH-1:0]  encoded_tx_hdr;		//! Señal para encabezado codificado

//! Instancia de modulo para la codificacion de datos segun estandar XGMII
xgmii_baser_enc_64 #(				
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH)
)
xgmii_baser_enc_inst (
    .clk(clk),
    .rst(rst),
    .xgmii_txd(xgmii_txd),
    .xgmii_txc(xgmii_txc),
    .encoded_tx_data(encoded_tx_data),
    .encoded_tx_hdr(encoded_tx_hdr),
    .tx_bad_block(tx_bad_block)
);

//! Instancia para la recepción de datos codificados desde la capa XGMII, la configuración de la transmisión según parámetros como el bit reverse, la habilitación o deshabilitación de scrambler y la generación de PRBS31, así como la transmisión de estos datos codificados y la configuración del SERDES.
eth_phy_10g_tx_if #(				
    .DATA_WIDTH(DATA_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .SERDES_PIPELINE(SERDES_PIPELINE)
)
eth_phy_10g_tx_if_inst (
    .clk(clk),
    .rst(rst),
    .encoded_tx_data(encoded_tx_data),
    .encoded_tx_hdr(encoded_tx_hdr),
    .serdes_tx_data(serdes_tx_data),
    .serdes_tx_hdr(serdes_tx_hdr),
    .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable)
);

endmodule

`resetall