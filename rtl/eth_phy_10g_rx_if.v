// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY RX IF
 */

//! Modulo que controla los bloques del receptor con interfaz SERDES
 
module eth_phy_10g_rx_if #
(
    parameter DATA_WIDTH = 64,			                            //! Ancho de bus de datos
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
    input  wire                  clk,		                        //! Señal del clock
    input  wire                  rst,		                        //! Señal de reset

    /*
     *! 10GBASE-R encoded interface
     */
    output wire [DATA_WIDTH-1:0] encoded_rx_data,	                // Datos de salida codificados
    output wire [HDR_WIDTH-1:0]  encoded_rx_hdr,	                // Header de salida codificado

    /*
     *! SERDES interface
     */
    input  wire [DATA_WIDTH-1:0] serdes_rx_data,	                //! Entrada de bloques de datos interfaz serdes
    input  wire [HDR_WIDTH-1:0]  serdes_rx_hdr,		                //! Entrada del sync header interfaz serdes
    output wire                  serdes_rx_bitslip,	                //! Salida del bitslip
    output wire                  serdes_rx_reset_req,	            //! Salida de solicitud de reinicio

    /*
     * Status
     */
    input  wire                  rx_bad_block,		                //! Flag de bloque con error
    input  wire                  rx_sequence_error,	                //! Flag de error de secuencia
    output wire [6:0]            rx_error_count,	                //! Contador de errores
    output wire                  rx_block_lock,		                //! Flag de bloque alineado
    output wire                  rx_high_ber,		                //! Flag de bit rate error alto
    output wire                  rx_status,		                    //! Flag del estado del receptor

    /*
     * Configuration
     */
    input  wire                  cfg_rx_prbs31_enable	            //! Entrada para habilitar la PRBS31
);

// Bus width assertions
initial begin
    if (DATA_WIDTH != 64) begin
        $error("Error: Interface width must be 64");
        $finish;
    end

    if (HDR_WIDTH != 2) begin
        $error("Error: HDR_WIDTH must be 2");
        $finish;
    end
end

wire [DATA_WIDTH-1:0] serdes_rx_data_rev, serdes_rx_data_int;	                //! Señales para procesar los datos del SERDES
wire [HDR_WIDTH-1:0]  serdes_rx_hdr_rev, serdes_rx_hdr_int;	                    //! Señales para procesar el encabezado del SERDES

generate
    genvar n;

    if (BIT_REVERSE) begin							                            //! Si BIT_REVERSE está activado, se invierten el orden de los bits de los datos y el encabezado en serdes_rx_data_int y serdes_rx_hdr_int
        for (n = 0; n < DATA_WIDTH; n = n + 1) begin
            assign serdes_rx_data_rev[n] = serdes_rx_data[DATA_WIDTH-n-1];
        end

        for (n = 0; n < HDR_WIDTH; n = n + 1) begin
            assign serdes_rx_hdr_rev[n] = serdes_rx_hdr[HDR_WIDTH-n-1];
        end
    end else begin
        assign serdes_rx_data_rev = serdes_rx_data;
        assign serdes_rx_hdr_rev = serdes_rx_hdr;
    end

    if (SERDES_PIPELINE > 0) begin						                        //! Si SERDES_PIPELINE > 0, implementa un pipeline en serie para serdes_rx_data y serdes_rx_hdr
        (* srl_style = "register" *)
        reg [DATA_WIDTH-1:0] serdes_rx_data_pipe_reg[SERDES_PIPELINE-1:0];      // crea tantos registros como profundidad tiene el pipeline
        (* srl_style = "register" *)
        reg [HDR_WIDTH-1:0]  serdes_rx_hdr_pipe_reg[SERDES_PIPELINE-1:0];

        for (n = 0; n < SERDES_PIPELINE; n = n + 1) begin
            initial begin
                serdes_rx_data_pipe_reg[n] <= {DATA_WIDTH{1'b0}};               // iniciamente coloca el valor de los registros en 0
                serdes_rx_hdr_pipe_reg[n] <= {HDR_WIDTH{1'b0}};
            end

            always @(posedge clk) begin
                serdes_rx_data_pipe_reg[n] <= n == 0 ? serdes_rx_data_rev : serdes_rx_data_pipe_reg[n-1]; //si n es igual a 0, a la data del pipeline le asigna data_rev, en caso contrario deja la misma
                //! Se asignan los datos por las diferentes etapas del pipeline
                serdes_rx_hdr_pipe_reg[n] <= n == 0 ? serdes_rx_hdr_rev : serdes_rx_hdr_pipe_reg[n-1];
            end
        end

        assign serdes_rx_data_int = serdes_rx_data_pipe_reg[SERDES_PIPELINE-1]; // la salida final es el utimo registro del pipeline del serdes
        assign serdes_rx_hdr_int = serdes_rx_hdr_pipe_reg[SERDES_PIPELINE-1];
    end else begin
        assign serdes_rx_data_int = serdes_rx_data_rev;
        assign serdes_rx_hdr_int = serdes_rx_hdr_rev;
    end

endgenerate

wire [DATA_WIDTH-1:0] descrambled_rx_data;			            //! Almacena los datos descifrados despues del proceso de descambler

reg [DATA_WIDTH-1:0] encoded_rx_data_reg = {DATA_WIDTH{1'b0}};	//! Registro para almacenar los datos codificados
reg [HDR_WIDTH-1:0] encoded_rx_hdr_reg = {HDR_WIDTH{1'b0}};	    //! Registro para almacenar el encabezado codificado

reg [57:0] scrambler_state_reg = {58{1'b1}};			        //! Registro de estado del scrambler
wire [57:0] scrambler_state;					

reg [30:0] prbs31_state_reg = 31'h7fffffff;			            //! Estado del generador de PRBS31
wire [30:0] prbs31_state;
wire [DATA_WIDTH+HDR_WIDTH-1:0] prbs31_data;			        //! Almacena los datos de salida del generador PRBS31
reg [DATA_WIDTH+HDR_WIDTH-1:0] prbs31_data_reg = 0;

//! Contadores de errores
reg [6:0] rx_error_count_reg = 0;	
reg [5:0] rx_error_count_1_reg = 0;
reg [5:0] rx_error_count_2_reg = 0;
reg [5:0] rx_error_count_1_temp = 0;
reg [5:0] rx_error_count_2_temp = 0;

//! Instancia un módulo LFSR (Linear Feedback Shift Register) llamado para el scrambler
lfsr #(
    .LFSR_WIDTH(58),
    .LFSR_POLY(58'h8000000001),
    .LFSR_CONFIG("FIBONACCI"),
    .LFSR_FEED_FORWARD(1),
    .REVERSE(1),
    .DATA_WIDTH(DATA_WIDTH),
    .STYLE("AUTO")
)
descrambler_inst (
    .data_in(serdes_rx_data_int),
    .state_in(scrambler_state_reg),
    .data_out(descrambled_rx_data),
    .state_out(scrambler_state)
);

//! Instancia un módulo LFSR (Linear Feedback Shift Register) para la generación de PRBS31
lfsr #(
    .LFSR_WIDTH(31),
    .LFSR_POLY(31'h10000001),
    .LFSR_CONFIG("FIBONACCI"),
    .LFSR_FEED_FORWARD(1),
    .REVERSE(1),
    .DATA_WIDTH(DATA_WIDTH+HDR_WIDTH),
    .STYLE("AUTO")
)
prbs31_check_inst (
    .data_in(~{serdes_rx_data_int, serdes_rx_hdr_int}),
    .state_in(prbs31_state_reg),
    .data_out(prbs31_data),
    .state_out(prbs31_state)
);

integer i;

always @* begin  //! Calcula el conteo de errores a partir de los datos del generador PRBS31, actualiza los registros de error_count
    rx_error_count_1_temp = 0;
    rx_error_count_2_temp = 0;
    for (i = 0; i < DATA_WIDTH+HDR_WIDTH; i = i + 1) begin
        if (i & 1) begin
            rx_error_count_1_temp = rx_error_count_1_temp + prbs31_data_reg[i]; // cuenta la cantidad de bits en alto cuando i es impar
        end else begin
            rx_error_count_2_temp = rx_error_count_2_temp + prbs31_data_reg[i]; // cuenta la cantidad de bits en alto cuando i es par
        end
    end
end

always @(posedge clk) begin	//! En cada flanco positivo del clock se actualizan los registros y si PRBS31 está activado calcula el conteo de errores acumulativo
    scrambler_state_reg <= scrambler_state;

    encoded_rx_data_reg <= SCRAMBLER_DISABLE ? serdes_rx_data_int : descrambled_rx_data; // si no esta activado el scrambler, el registro tiene el valor de serdes, de lo contrario tiene el valos de los datos de descrambled
    encoded_rx_hdr_reg <= serdes_rx_hdr_int;

    if (PRBS31_ENABLE) begin
        if (cfg_rx_prbs31_enable) begin
            prbs31_state_reg <= prbs31_state; 
            prbs31_data_reg <= prbs31_data;
        end else begin
            prbs31_data_reg <= 0;
        end

        rx_error_count_1_reg <= rx_error_count_1_temp; // coloca el error temp en el conteo de error
        rx_error_count_2_reg <= rx_error_count_2_temp;
        rx_error_count_reg <= rx_error_count_1_reg + rx_error_count_2_reg;
    end else begin
        rx_error_count_reg <= 0;
    end
end

assign encoded_rx_data = encoded_rx_data_reg; //! Se asignan registros a las salidas correspondientes
assign encoded_rx_hdr = encoded_rx_hdr_reg;

assign rx_error_count = rx_error_count_reg;

wire serdes_rx_bitslip_int;
wire serdes_rx_reset_req_int;
assign serdes_rx_bitslip = serdes_rx_bitslip_int && !(PRBS31_ENABLE && cfg_rx_prbs31_enable);
assign serdes_rx_reset_req = serdes_rx_reset_req_int && !(PRBS31_ENABLE && cfg_rx_prbs31_enable);

//! Instancia un módulo de sincronizacion del frame
eth_phy_10g_rx_frame_sync #(
    .HDR_WIDTH(HDR_WIDTH),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES)
)
eth_phy_10g_rx_frame_sync_inst (
    .clk(clk),
    .rst(rst),
    .serdes_rx_hdr(serdes_rx_hdr_int),
    .serdes_rx_bitslip(serdes_rx_bitslip_int),
    .rx_block_lock(rx_block_lock)
);

//! Instancia un módulo para monitorear el BER 
eth_phy_10g_rx_ber_mon #(
    .HDR_WIDTH(HDR_WIDTH),
    .COUNT_125US(COUNT_125US)
)
eth_phy_10g_rx_ber_mon_inst (
    .clk(clk),
    .rst(rst),
    .serdes_rx_hdr(serdes_rx_hdr_int),
    .rx_high_ber(rx_high_ber)
);

//! Instancia un modulo para monitoreo de los errores y estado del receptor
eth_phy_10g_rx_watchdog #(
    .HDR_WIDTH(HDR_WIDTH),
    .COUNT_125US(COUNT_125US)
)
eth_phy_10g_rx_watchdog_inst (
    .clk(clk),
    .rst(rst),
    .serdes_rx_hdr(serdes_rx_hdr_int),
    .serdes_rx_reset_req(serdes_rx_reset_req_int),
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status)
);

endmodule

`resetall
