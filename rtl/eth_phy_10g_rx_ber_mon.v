// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY BER monitor
 */

 //! Modulo que controla el bit error rate y activa dicha señal cuando hay más de 15 sync headers validos en 125us
module eth_phy_10g_rx_ber_mon #
(
    parameter HDR_WIDTH = 2,			        //! Ancho del header
    parameter COUNT_125US = 125000/10		    //! Contador de 125 us
)
(
    input  wire                  clk,		    //! Señal de clock
    input  wire                  rst,		    //! Señal de reset

    /*
     * ! SERDES interface
     */
    input  wire [HDR_WIDTH-1:0]  serdes_rx_hdr,	//! Serdes sync header del receptor

    /*
     * ! Status
     */
    output wire                  rx_high_ber	//! Tasa de error de bit
);

// Bus width assertions	
initial begin			
    if (HDR_WIDTH != 2) begin
        $error("Error: HDR_WIDTH must be 2");
        $finish;
    end
end

parameter COUNT_WIDTH = $clog2($rtoi(COUNT_125US));	                    //! Determina la cantidad de bits necesarios para representar COUNT_125US

localparam [1:0]		                                                //! Sync headers de sincronizacion de bloques de datos y control
    SYNC_DATA = 2'b10,
    SYNC_CTRL = 2'b01;

reg [COUNT_WIDTH-1:0] time_count_reg = COUNT_125US, time_count_next;	//! Registro de contador de tiempo, se inicializa en COUNT_125US.
reg [3:0] ber_count_reg = 4'd0, ber_count_next;				            //! Registro de contador de errores de header. Máximo 4 bits

reg rx_high_ber_reg = 1'b0, rx_high_ber_next;				            //! Registro que indica una ber alta.

assign rx_high_ber = rx_high_ber_reg;					             

//! Verifica si hay mas de 15 sync headers validos en un intervalo de 125us
always @* begin
    if (time_count_reg > 0) begin		                                // si la cuenta ya empezo
        time_count_next = time_count_reg-1;	                            // resta en uno el valor del contador de tiempo
    end else begin				                                        // si termino la cuenta
        time_count_next = time_count_reg;	                            // permanece el valor del contador de tiepo
    end	
    ber_count_next = ber_count_reg;		                                // se asigna el valor de ber_count en el proximo ciclo

    rx_high_ber_next = rx_high_ber_reg;		                            // se asigna el valor de rx_high_ber en el proximo ciclo

    if (serdes_rx_hdr == SYNC_CTRL || serdes_rx_hdr == SYNC_DATA) begin	// si los header son validos
        //! Valid header
        if (ber_count_reg != 4'd15) begin				                // si la cuenta de ber no alcanzó su valor límite 15
            if (time_count_reg == 0) begin				                // si termino la cuenta
                rx_high_ber_next = 1'b0;				                // no hay una tasa alta de error de bit
            end
        end
    end else begin				                                        // si el header no es valido
        //! Invalid header
        if (ber_count_reg == 4'd15) begin	                            // si la cuenta de ber alcanzó su valor límite de 15
            rx_high_ber_next = 1'b1;		                            // hay tasa alta de error de bit
        end else begin				                                    // si la cuenta de ber no alcanzó su valor límite de 15
            ber_count_next = ber_count_reg + 1;                     	// se incrementa en uno la cuenta de ber
            if (time_count_reg == 0) begin	                            // si terminó la cuenta
                rx_high_ber_next = 1'b0;	                            // no hay tasa alta de error de bit
            end
        end
    end
    if (time_count_reg == 0) begin		                                // si terminó la cuenta
        // 125 us timer expired
        ber_count_next = 4'd0;			                                // se resetea la cuenta de ber
        time_count_next = COUNT_125US;		                            // se resetea el timer a 125 us
    end
end

always @(posedge clk) begin			                                    //! En cada flanco positivo de clock se actualizan los valores de los registros y se verifica la señal de reinicio
    time_count_reg <= time_count_next;
    ber_count_reg <= ber_count_next;
    rx_high_ber_reg <= rx_high_ber_next;

    if (rst) begin
        time_count_reg <= COUNT_125US;
        ber_count_reg <= 4'd0;
        rx_high_ber_reg <= 1'b0;
    end
end

endmodule

`resetall