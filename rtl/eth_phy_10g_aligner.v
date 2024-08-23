`timescale 1ns / 1ps

/*
 * 10G Ethernet PHY aligner
 *
 * Establece block_lock en falso cuando:
 *      - El contador de encabezados invalidos es 16
 *      - Cuando 16 tramas dentro de una ventana de 64 tienen headers invalidos. Se realiza un nuevo intento de alineacion
 *
 * Establece block_lock en verdadero cuando:
 *      - No hay headers invalidos en una ventana de 64 tramas.
 */
module eth_phy_10g_rx_aligner
#(
    parameter DATA_WIDTH        = 64                                                                                            ,   //! Longitud del payload
    parameter HDR_WIDTH         = 2                                                                                             ,   //! Longitud del header
    parameter FRAME_WIDTH       = DATA_WIDTH + HDR_WIDTH                                                                            //! Longitud total del frame
)
(
    // Status
    output                      o_rx_block_lock                                                                                 ,   //! Bandera del estado Alineado

    // Serdes interface
    output [HDR_WIDTH   -1 : 0] o_serdes_rx_hdr                                                                                 ,   //! Salida del Header
    output [DATA_WIDTH  -1 : 0] o_serdes_rx_data                                                                                ,   //! Salida de datos
    input  [FRAME_WIDTH -1 : 0] i_serdes_rx                                                                                     ,   //! Señal de entrada de 66 bits


    input                       i_rst                                                                                           ,   //! Reset
    input                       clk                                                                                                 //! Clock      
);

    localparam SH_HDR_VALID     = $clog2(64)                                                                                    ;   //! Numero de bits del contador de headers validos
    localparam SH_HDR_INVALID   = $clog2(16)                                                                                    ;   //! Numero de bits del contador de headers invalidos

    localparam[2:0]
        STATE_LOCK_INIT         = 3'd0                                                                                          ,   //! Estado: Inicializacion
        STATE_RESET_CNT         = 3'd1                                                                                          ,   //! Estado: Reset de contadores
        STATE_TEST_SH           = 3'd2                                                                                          ,   //! Estado: Test de header
        STATE_VALID_SH          = 3'd3                                                                                          ,   //! Estado: Header valido
        STATE_INVALID_SH        = 3'd4                                                                                          ,   //! Estado: Header invalido
        STATE_64_GOOD           = 3'd5                                                                                          ,   //! Estado: 64 Headers validos (block_lock en 1)
        STATE_SLIP              = 3'd6                                                                                          ;   //! Estado: Slip (cambiar posicion del header en el frame)

    reg [HDR_WIDTH      - 1 : 0] serdes_rx_hdr_r                                                                                ;   //! Salida del header
    reg [DATA_WIDTH     - 1 : 0] serdes_rx_data_r                                                                               ;   //! Salida de datos
    reg [(FRAME_WIDTH *2)-1 : 0] serdes_rx_frames                                                                               ;   //! Concatenacion de 2 frames
    reg [(FRAME_WIDTH *2)-1 : 0] serdes_rx_frames_next                                                                          ;   //! Concatenacion con slip aplicado
    reg [FRAME_WIDTH    - 1 : 0] serdes_rx_prev                                                                                 ;   //! Frame anterior
    reg [SH_HDR_VALID   - 1 : 0] sh_count                                                                                       ;   //! Contador de headers testeados (valor actual)
    reg [SH_HDR_VALID   - 1 : 0] sh_count_next                                                                                  ;   //! Contador de headers testeados (valor siguiente)
    reg [SH_HDR_INVALID - 1 : 0] sh_invalid_count                                                                               ;   //! Contador de headers invalidos (valor actual)
    reg [SH_HDR_INVALID - 1 : 0] sh_invalid_count_next                                                                          ;   //! Contador de headers invalidos (valor siguiente)
    reg [FRAME_WIDTH    - 1 : 0] slip                                                                                           ;   //! Posicion del header (valor actual)
    reg [FRAME_WIDTH    - 1 : 0] slip_next                                                                                      ;   //! Posicion del header (valor siguiente)
    reg                          sh_valid_next                                                                                  ;   //! Indica si el header testeado es valido (01 o 10)
    reg                          rx_block_lock_r                                                                                ;   //! Bandera del estado Alineado (valor actual)
    reg                          rx_block_lock_next                                                                             ;   //! Bandera del estado Alineado (valor siguiente)
    reg [2:0]                    state                                                                                          ;   //! Estado actual
    reg [2:0]                    state_next                                                                                     ;   //! Estado siguiente

    always @* begin
        case(state) 
            STATE_LOCK_INIT: begin                                                                                                  
                // Estado: Inicializacion
                // Estado Inicial luego de reset, se resetea la bandera de estado de alineacion.
                // El siguiente estado sera el de reset de contadores
                rx_block_lock_next    = 1'b0                                                                                    ;
                sh_count_next         = sh_count                                                                                ;
                sh_invalid_count_next = sh_invalid_count                                                                        ;
                slip_next             = slip                                                                                    ;
                state_next            = STATE_RESET_CNT                                                                         ;
            end
            STATE_RESET_CNT: begin                                                                                                  
                // Estado: Reset de contadores
                // Estado de reinicio de contadores de encabezados.
                // El siguiente estado sera el de testeo de encabezado
                rx_block_lock_next    = rx_block_lock_r                                                                         ;
                sh_count_next         = {SH_HDR_VALID   - 1{1'b0}}                                                              ;
                sh_invalid_count_next = {SH_HDR_INVALID - 1{1'b0}}                                                              ;
                slip_next             = slip                                                                                    ;
                state_next            = STATE_TEST_SH                                                                           ;
            end
            STATE_TEST_SH: begin                                                                                                    
                // Estado: Test de header
                // Estado donde se compara los bits de la posible ubicacion del encabezado de la señal de entrada con los posibles encabezados validos.
                // Si los bits del posible encabezado son distintos, el siguiente estado sera el de encabezado valido
                // Si los bits del posible encabezado son iguales, el siguiente estado sera el de encabezado invalido
                // La posible ubicacion del encabezado de la señal de entrada se calcula restado al valor de la longitud de la trama total el valor de slip.
                // Si slip = 0: Se comparan los bits 65 y 64 de i_serdes_rx
                    //  [X X X X X X X X X X X X X X X X]
                    //   ^ ^
                // Si slip = 3: Se comparan los bits 62 y 61 de i_serdes_rx
                    //  [X X X X X X X X X X X X X X X X]
                    //         ^ ^
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
                // Estado: Encabezado valido
                // Estado en el que se incrementa en 1 la cantidad de headers testeados.
                // El contador de slip permanece igual
                // Si la cantidad de headers testeados es menor a 64, el siguiente estado sera el de Test de Header
                // Si la cantidad de headers testeados es 64 y la cantidad de headers invalidos es 0, el siguiente estado sera el de 64 Headers Validos
                // Si la cantidad de headers testeados es igual a 64 y la cantidad headers invalidos no es 0, el siguiente estado sera el de Reset de Contadores
                rx_block_lock_next    = rx_block_lock_r                                                                         ;
                sh_count_next         = sh_count + {{SH_HDR_INVALID {1'b0}}    , 1'b1}                                          ;
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
                // Estado: Encabezado invalido
                // Estado en el que se incrementa en 1 la cantidad de headers testeados y la cantidad de headers invalidos.
                // El contador de slip permanece igual
                // Si la cantidad de headers testeados es menor a 64, la cantidad de headers invalidos es menor a 16 y se encuentra en estado de alineacion, el siguiente estado sera el de Test de Header.
                // Si la cantidad de headers testeados es igual a 64, la cantidad de headers invalidos es menor a 16 y se encuentra en estado de alineacion, el siguiente estado sera el de Reset de Contadores.
                // Si la cantidad de headers invalidos es igual a 16 o no se encuentra en estado de alineacion, el siguiente estado sera el de Slip.
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
                // Estado: Slip
                // Estado en el que se deshabilita el estado de alineacion y se incrementa en 1 el contador de slip.
                // El siguiente estado es el de Reset de Contadores
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
                // Estado: 64 Headers Validos
                // Estado en el que se establece el estado de alineacion
                // El siguiente estado es el de Reset de Contadores
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
        // Logica secuencial de los contadores, del estado y de la bandera de alineacion
        if(i_rst) begin                                                                                                             
            // Reset sincrono. Se inician todos los registros y se establece el estado de Inicializacion
            rx_block_lock_r             <= 'd0                                                                                  ;
            sh_count                    <= 'd0                                                                                  ;
            sh_invalid_count            <= 'd0                                                                                  ;
            slip                        <= 'd0                                                                                  ;
            state                       <= STATE_LOCK_INIT                                                                      ;
            serdes_rx_prev              <= 'd0                                                                                  ;      
        end
        else begin                                                                                                                  
            // Se actualizan los registros, se almacena el valor de la señal de entrada
            rx_block_lock_r             <= rx_block_lock_next;
            sh_count                    <= sh_count_next                                                                        ;
            sh_invalid_count            <= sh_invalid_count_next                                                                ;
            slip                        <= slip_next                                                                            ;
            state                       <= state_next                                                                           ;
            serdes_rx_prev              <= i_serdes_rx                                                                          ;
        end

        if(rx_block_lock_r) begin
            // Si el sistema se encuentra en estado de alineacion, se concatena la entrada actual con la ultima entrada, se desplaza la trama segun el valor de slip y se seleccionan el header y los datos
            serdes_rx_frames            <= {serdes_rx_prev, i_serdes_rx}                                                        ;
            serdes_rx_frames_next       <= serdes_rx_frames << slip                                                             ;
            serdes_rx_data_r            <= serdes_rx_frames_next[(FRAME_WIDTH *2)-1 -  HDR_WIDTH : FRAME_WIDTH - 1]             ;
            serdes_rx_hdr_r             <= serdes_rx_frames_next[(FRAME_WIDTH *2)-1 -: HDR_WIDTH                  ]             ;
        end
        else begin
            // Si el sistema no se encuentra en estado de alineacion, se envia IDLE y el encabezado vale 0
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