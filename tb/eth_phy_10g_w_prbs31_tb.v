module eth_phy_10g_w_prbs31_tb;

// Señales de Clock y Reset
reg rx_clk;
reg rx_rst;
reg tx_clk;
reg tx_rst;

// Señales para la comunicación entre los módulos
reg [63:0] xgmii_txd;   // Datos de entrada XGMII
reg [7:0] xgmii_txc;    // Señales de control XGMII
wire tx_bad_block;     // Señal de estado para bloques defectuosos
wire [1:0] serdes_tx_hdr; // Cabezal de salida del transmisor
wire [63:0] serdes_tx_data; // Datos de salida del transmisor
reg [1:0] serdes_rx_hdr; // Cabezal de salida del transmisor
reg [63:0] serdes_rx_data; // Datos de salida del transmisor
wire [63:0] xgmii_rxd;  // Datos de salida XGMII
wire [7:0] xgmii_rxc;  // Señales de control de salida XGMII
reg cfg_tx_prbs31_enable; // Booleano que activa el prbs31 para el transmisor
reg cfg_rx_prbs31_enable; // Booleano que activa el prbs31 para el transmisor

// Instancia del módulo PHY 10G Ethernet
eth_phy_10g #(
    .DATA_WIDTH(64),
    .CTRL_WIDTH(8),
    .HDR_WIDTH(2),
    .PRBS31_ENABLE(1)
) eth_phy_10g_inst (
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
    .serdes_rx_bitslip(),
    .serdes_rx_reset_req(),
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

// Generador de Clock cada 10 ut
always 
    fork
        #5 rx_clk = ~rx_clk; 
        #5 tx_clk = ~tx_clk;
    join 
    
// Actualiza las señales en los flancos positivos
always @(posedge tx_clk) begin

    serdes_rx_data <= serdes_tx_data;
    serdes_rx_hdr <= serdes_tx_hdr;
    
end

// Inicializa parametros
initial begin
    // Inicialización de las señales
    
    // Configurar generación de PRBS31
    cfg_tx_prbs31_enable = 1'b0;
    cfg_rx_prbs31_enable = 1'b0;
        
    // Configura inicialmente clock y reset        
    rx_rst = 1;
    rx_clk = 0;
    tx_rst = 1;
    tx_clk = 0;
    
    // Coloca Reset en 0 después de 10 unidades de tiempo(ut)
    fork
        #10 rx_rst = 0;
        #10 tx_rst = 0;
    join
    
    // Inicialización de los datos XGMII
    xgmii_txd = 64'hxxxxxxxxxxxxxxxx; // Inicializa todos los bits después de 10s de reset
    
    // Inicialización de las señales de control XGMII
    xgmii_txc = 8'hxx; // Asigna a los bits xxh
    
    // Habilita el PRBS31
    fork   
        #100 cfg_tx_prbs31_enable = 1'b1;
        #100 cfg_rx_prbs31_enable = 1'b1;  
    join

end

endmodule