// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY RX
 */

 //! Modulo del receptor de 10g
module eth_phy_10g_rx #
(
    parameter DATA_WIDTH = 64,                                      //! Ancho del bus de datos
    parameter CTRL_WIDTH = (DATA_WIDTH/8),                          //! Ancho del bus de control
    parameter HDR_WIDTH = 2,			                            //! Ancho de bus de header
    parameter BIT_REVERSE = 0,			                            //! Flag para habilitar reversión de bits
    parameter SCRAMBLER_DISABLE = 0,		                        //! Flag para habilitar scrambler
    parameter PRBS31_ENABLE = 0,		                            //! Flag para habilitar PRBS31
    parameter SERDES_PIPELINE = 0,		                            //! Flag para habilitar profundidad del pipeline
    parameter BITSLIP_HIGH_CYCLES = 1,		                        //! Ciclos de bitslip alto
    parameter BITSLIP_LOW_CYCLES = 8,		                        //! Ciclos de bitslip bajo
    parameter COUNT_125US = 125000/10	                            //! Contador de 125 us
)
(
    input  wire                  clk,                               //! Señal de datos
    input  wire                  rst,                               //! Señal de control

    /*
     * XGMII interface
     */
    output wire [DATA_WIDTH-1:0] xgmii_rxd,                         //! Salida de datos de la interfaz xgmii
    output wire [CTRL_WIDTH-1:0] xgmii_rxc,                         //! Salida de control de la interfaz xgmii

    /*
     * SERDES interface
     */
    input  wire [DATA_WIDTH-1:0] serdes_rx_data,                    //! Datos de la interfaz serdes del receptor
    input  wire [HDR_WIDTH-1:0]  serdes_rx_hdr,                     //! Sync eader de la interfaz SERDES del receptor
    output wire                  serdes_rx_bitslip,                 //! Flag de bitslip del SERDES
    output wire                  serdes_rx_reset_req,               //! Flag de solicitud de reset del SERDES

    /*
     * Status
     */
    output wire [6:0]            rx_error_count,                    //! Contador de errores
    output wire                  rx_bad_block,                      //! Flag de bloque con error
    output wire                  rx_sequence_error,                 //! Flag de error de secuencia
    output wire                  rx_block_lock,                     //! Flag de bloque alineado
    output wire                  rx_high_ber,                       //! Flag de bit rate error alto
    output wire                  rx_status,                         //! Flag del estado del receptor

    /*
     * Configuration
     */
    input  wire                  cfg_rx_prbs31_enable               //! Entrada para habilitar la PRBS31
);


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

wire [DATA_WIDTH-1:0] encoded_rx_data;                          //! Datos codificados del rx
wire [HDR_WIDTH-1:0]  encoded_rx_hdr;                           //! Sync header codificado del rx

//! Instancia modulo if del receptor que utiliza interfaz SERDES
eth_phy_10g_rx_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .HDR_WIDTH(HDR_WIDTH),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_ENABLE(PRBS31_ENABLE),
    .SERDES_PIPELINE(SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_phy_10g_rx_if_inst (
    .clk(clk),
    .rst(rst),
    .encoded_rx_data(encoded_rx_data),
    .encoded_rx_hdr(encoded_rx_hdr),
    .serdes_rx_data(serdes_rx_data),
    .serdes_rx_hdr(serdes_rx_hdr),
    .serdes_rx_bitslip(serdes_rx_bitslip),
    .serdes_rx_reset_req(serdes_rx_reset_req),
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error),
    .rx_error_count(rx_error_count),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
);

//! Instancia modulo que convierte interfaz XGMII a SERDES
xgmii_baser_dec_64 #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(HDR_WIDTH)
)
xgmii_baser_dec_inst (
    .clk(clk),
    .rst(rst),
    .encoded_rx_data(encoded_rx_data),
    .encoded_rx_hdr(encoded_rx_hdr),
    .xgmii_rxd(xgmii_rxd),
    .xgmii_rxc(xgmii_rxc),
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error)
);

endmodule

`resetall