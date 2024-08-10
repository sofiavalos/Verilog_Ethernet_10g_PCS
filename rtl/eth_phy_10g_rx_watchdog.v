// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY serdes watchdog
 */
//! Modulo que verifica el estado del header, pidiendo reset si es necesario o activando rx_status si no hay más de 16 errores en 125us
module eth_phy_10g_rx_watchdog #
(
    parameter HDR_WIDTH = 2,		                            //! Ancho de header
    parameter COUNT_125US = 125000/6.4	                        //! Contador de 125 us
)
(
    input  wire                  clk,	                        //! Señal de clock
    input  wire                  rst,	                        //! Señal de reinicio

    /*
     * ! SERDES interface
     */
    input  wire [HDR_WIDTH-1:0]  serdes_rx_hdr,		            //! Serdes sync header del rx
    output wire                  serdes_rx_reset_req,	        //! Solicitud de reset del serdes

    /*
     * ! Monitor inputs
     */
    input  wire                  rx_bad_block,		            //! Indicador de error en el bloque recibido
    input  wire                  rx_sequence_error,	            //! Indicador de error en la secuencia recibida
    input  wire                  rx_block_lock,		            //! Indicador de si el bloque está alineado
    input  wire                  rx_high_ber,		            //! Indicador si el ber rate error es alto

    /*
     * ! Status
     */
    output wire                  rx_status		                //! Salida del estado del receptor
);

// Bus width assertions
initial begin
    if (HDR_WIDTH != 2) begin
        $error("Error: HDR_WIDTH must be 2");
        $finish;
    end
end

parameter COUNT_WIDTH = $clog2($rtoi(COUNT_125US));	                    //! Determina la cantidad de bits necesarios para representar COUNT_125US

localparam [1:0]		                                                //! Encabezados de sync headers de bloques de datos y control
    SYNC_DATA = 2'b10,		
    SYNC_CTRL = 2'b01;

reg [COUNT_WIDTH-1:0] time_count_reg = 0, time_count_next;	            //! Registro de contador de tiempo, se inicializa en COUNT_125US.
reg [3:0] error_count_reg = 0, error_count_next;		                //! Registro de contador de errores. Máximo 16 bits
reg [3:0] status_count_reg = 0, status_count_next;		                //! Registro de contador de estado. Máximo 16 bits

reg saw_ctrl_sh_reg = 1'b0, saw_ctrl_sh_next;			                //! Indicador de control
reg [9:0] block_error_count_reg = 0, block_error_count_next;	        //! Contador de errores de bloque

reg serdes_rx_reset_req_reg = 1'b0, serdes_rx_reset_req_next;	        //! Indicador de solicitud de reinicio.

reg rx_status_reg = 1'b0, rx_status_next;			                    //! Indicador del estado de la recepcion.

assign serdes_rx_reset_req = serdes_rx_reset_req_reg;		            

assign rx_status = rx_status_reg;				                         

//! Si el sync header es de bloques de control, verifica que no haya errores, si hay menos de 16 por 125us, activa el rx_status.
//! Si antes de los 125us los errores son mayores a 16, activa el reset_req
always @* begin
    error_count_next = error_count_reg;			                        
    status_count_next = status_count_reg;

    saw_ctrl_sh_next = saw_ctrl_sh_reg;
    block_error_count_next = block_error_count_reg;

    serdes_rx_reset_req_next = 1'b0;	

    rx_status_next = rx_status_reg;

    if (rx_block_lock) begin			                                                // si el bloque está alineado
        if (serdes_rx_hdr == SYNC_CTRL) begin	                                        // si el header es de control
            saw_ctrl_sh_next = 1'b1;		                                            // se establece en 1 el indicador de control
        end
        if ((rx_bad_block || rx_sequence_error) && !(&block_error_count_reg)) begin	    // hay un error de bloque o secuencia y no hay overflow en el contador de errores de bloque
            block_error_count_next = block_error_count_reg + 1;				            // se incrementa en uno el contador de error de bloque
        end
    end else begin			                                                            // si el bloque no está bloqueado
        rx_status_next = 1'b0;		                                                    // el estado del receptor se pone en 0
        status_count_next = 0;		                                                    // el contador de estado se reinicia
    end

    if (time_count_reg != 0) begin		                                                // si la cuenta no terminó
        time_count_next = time_count_reg-1;	                                            // se decrementa en uno la cuenta
    end else begin				                                                        // si la cuenta terminó
        time_count_next = COUNT_125US;		                                            // el contador se reinicia

        if (!saw_ctrl_sh_reg || &block_error_count_reg) begin	                        // si no se vio un encabezado de control o hay un overflow de cuenta de error de bloque
            error_count_next = error_count_reg + 1;		                                // se incrementa en uno el contador de error
            status_count_next = 0;				                                        // se reinicia el contador de estado
        end else begin						                                            //sino
            error_count_next = 0;				                                        // se reinicia el contador de error
            if (!(&status_count_reg)) begin			                                    // si no hay overflow del contador de estado
                status_count_next = status_count_reg + 1;	                            // se incrementa en uno el contador de estado
            end
        end

        if (&error_count_reg) begin		                                                // si hay overflow del contador de error
            error_count_next = 0;		                                                // se reinicia el contador de error
            serdes_rx_reset_req_next = 1'b1;	                                        // se pone en 1 el indicador de solicitud de reset
        end

        if (&status_count_reg) begin		                                            // si hay overflow del estado de contador
            rx_status_next = 1'b1;		                                                // se pone en 1 el estado del receptor
        end

        saw_ctrl_sh_next = 1'b0;		                                                // se reinicia el indicador de control
        block_error_count_next = 0;		                                                // se reinicia el contador de error de bloque
    end
end

always @(posedge clk) begin			                                                    //! En cada flanco positivo de clock se actualizan los valores de los registros y se verifica la señal de reinicio
    time_count_reg <= time_count_next;
    error_count_reg <= error_count_next;
    status_count_reg <= status_count_next;
    saw_ctrl_sh_reg <= saw_ctrl_sh_next;
    block_error_count_reg <= block_error_count_next;
    rx_status_reg <= rx_status_next;

    if (rst) begin
        time_count_reg <= COUNT_125US;
        error_count_reg <= 0;
        status_count_reg <= 0;
        saw_ctrl_sh_reg <= 1'b0;
        block_error_count_reg <= 0;
        rx_status_reg <= 1'b0;
    end
end

always @(posedge clk or posedge rst) begin	                                            //! En cada flanco positivo de clock o señal de reinicio actualiza el reset req
    if (rst) begin				                                                        // si la señal de reinicio es 1
        serdes_rx_reset_req_reg <= 1'b0;	                                            // se reinicia la solicitud de reinicio para SERDES
    end else begin				                                                        // sino
        serdes_rx_reset_req_reg <= serdes_rx_reset_req_next;	                        // el registro actual toma el valor del siguiente
    end
end

endmodule

`resetall