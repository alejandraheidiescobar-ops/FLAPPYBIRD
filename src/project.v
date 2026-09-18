`default_nettype none

module tt_um_flappy_bird (
    input  wire [7:0] ui_in,    // Entradas: Cualquier switch/botón en ui_in activa el salto
    output wire [7:0] uo_out,   // Salida VGA: {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
    input  wire [7:0] uio_in,   // No usados
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

    // Mapeo flexible: Cualquier botón/switch presionado en ui_in activa el salto
    wire jump_button = |ui_in;

    // Señales de sincronía y posición VGA (10 BITS para resolución 640x480)
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;
    wire reset = ~rst_n;

    // Generador de sincronía VGA
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(display_on),
        .hpos(hpos),
        .vpos(vpos)
    );

    // Manejo de pines bidireccionales y no usados
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused_ok = &{ena, uio_in};

    // -------------------------------------------------------------
    // CONSTANTES DEL JUEGO
    // -------------------------------------------------------------
    localparam [9:0] BIRD_X     = 10'd100;  // Posición X del pájaro
    localparam [9:0] BIRD_SIZE  = 10'd16;   // Tamaño del pájaro (16x16 píxeles)
    localparam [9:0] PIPE_WIDTH = 10'd48;   // Ancho de tuberías
    localparam [9:0] GAP_HEIGHT = 10'd110;  // Altura del hueco entre tuberías
    localparam [9:0] FLOOR_Y    = 10'd380;  // Inicio del piso

    localparam [1:0] STATE_START    = 2'd0;
    localparam [1:0] STATE_PLAY     = 2'd1;
    localparam [1:0] STATE_GAMEOVER = 2'd2;

    reg [1:0] state;

    // -------------------------------------------------------------
    // VARIABLES FÍSICAS Y CONTADORES
    // -------------------------------------------------------------
    reg signed [12:0] bird_y_fp; // Punto fijo (13 bits: 9 entero + 4 fracción)
    reg signed [7:0]  bird_vy;   // Velocidad vertical

    reg [9:0] pipe_x;               
    reg [9:0] gap_y;                

    reg [7:0] rng_counter;
    reg [9:0] ground_scroll;
    reg [9:0] cloud_scroll;
    reg [5:0] anim_frame;

    always @(posedge clk) begin
        if (reset)
            rng_counter <= 8'd0;
        else
            rng_counter <= rng_counter + 1'b1;
    end

    reg jump_btn_prev;
    wire jump_pressed = jump_button && !jump_btn_prev;

    // Animación de flotado suave cuando está en pantalla de inicio
    wire [9:0] idle_hover = {6'b0, anim_frame[4:1]};
    wire [9:0] bird_y = (state == STATE_START) ? (10'd180 + idle_hover) : {1'b0, bird_y_fp[12:4]};

    // -------------------------------------------------------------
    // LÓGICA Y ESTADOS DEL JUEGO (Sincronizado a VSYNC - 60 Hz)
    // -------------------------------------------------------------
    always @(posedge vsync or posedge reset) begin
        if (reset) begin
            state         <= STATE_START;
            jump_btn_prev <= 1'b0;
            ground_scroll <= 10'd0;
            cloud_scroll  <= 10'd0;
            anim_frame    <= 6'd0;
            bird_y_fp     <= 13'sd2880; // ~180 en entero (180 * 16 = 2880)
            bird_vy       <= 8'sd0;
            pipe_x        <= 10'd600;
            gap_y         <= 10'd120;
        end else begin
            jump_btn_prev <= jump_button;
            anim_frame    <= anim_frame + 1'b1;

            if (state == STATE_START || state == STATE_PLAY) begin
                ground_scroll <= ground_scroll + 10'd2;
                cloud_scroll  <= cloud_scroll + 10'd1;
            end

            case (state)
                STATE_START: begin
                    bird_y_fp <= 13'sd2880; 
                    bird_vy   <= 8'sd0;
                    pipe_x    <= 10'd600;
                    gap_y     <= 10'd120;
                    
                    if (jump_pressed) begin
                        state   <= STATE_PLAY;
                        bird_vy <= -8'sd28; // Primer salto al iniciar
                    end
                end

                STATE_PLAY: begin
                    bird_vy   <= bird_vy + 8'sd1; // Gravedad
                    bird_y_fp <= bird_y_fp + {{5{bird_vy[7]}}, bird_vy};

                    if (jump_pressed) begin
                        bird_vy <= -8'sd28; // Salto hacia arriba
                    end

                    // Movimiento de tuberías
                    if (pipe_x <= 10'd4 || pipe_x > 10'd700) begin
                        pipe_x <= 10'd640; 
                        gap_y  <= 10'd60 + {3'b000, rng_counter[6:0]};
                    end else begin
                        pipe_x <= pipe_x - 10'd3; 
                    end

                    // Colisiones (Piso / Techo / Tuberías)
                    if ((bird_y + BIRD_SIZE >= FLOOR_Y) || (bird_y <= 10'd10) ||
                        ((pipe_x <= BIRD_X + BIRD_SIZE) && (pipe_x + PIPE_WIDTH >= BIRD_X) && 
                         (bird_y < gap_y || bird_y + BIRD_SIZE > gap_y + GAP_HEIGHT))) begin
                        state <= STATE_GAMEOVER;
                    end
                end

                STATE_GAMEOVER: begin
                    if (jump_pressed) begin
                        state <= STATE_START; // Reiniciar
                    end
                end

                default: state <= STATE_START;
            endcase
        end
    end

    // -------------------------------------------------------------
    // SPRITE DEL PÁJARO (8x8 base escalado a 16x16)
    // -------------------------------------------------------------
    function [7:0] get_bird_row(input [2:0] row);
        case (row)
            3'd0: get_bird_row = 8'b00011110;
            3'd1: get_bird_row = 8'b00111111;
            3'd2: get_bird_row = 8'b01111111;
            3'd3: get_bird_row = 8'b01111111;
            3'd4: get_bird_row = 8'b01111111;
            3'd5: get_bird_row = 8'b00111111;
            3'd6: get_bird_row = 8'b00011000;
            default: get_bird_row = 8'b00000000;
        endcase
    endfunction

    // -------------------------------------------------------------
    // RENDERIZADO VISUAL
    // -------------------------------------------------------------
    // 1. PÁJARO
    wire in_bird_box = (hpos >= BIRD_X) && (hpos < BIRD_X + BIRD_SIZE) &&
                       (vpos >= bird_y) && (vpos < bird_y + BIRD_SIZE);
                       
    wire [9:0] diff_bx = hpos - BIRD_X;
    wire [9:0] diff_by = vpos - bird_y;
    wire [2:0] bx = diff_bx[3:1]; // Escala 2x
    wire [2:0] by = diff_by[3:1];

    wire [7:0] bird_row = get_bird_row(by);
    wire bird_pixel = in_bird_box ? bird_row[3'd7 - bx] : 1'b0;
    
    wire is_eye   = (bx >= 3'd5 && bx <= 3'd6) && (by >= 3'd1 && by <= 3'd2);
    wire is_pupil = (bx == 3'd6) && (by == 3'd2);
    wire is_wing  = (bx >= 3'd1 && bx <= 3'd2) && (by >= 3'd3 && by <= 3'd4);
    wire is_beak  = (bx >= 3'd5) && (by >= 3'd4 && by <= 3'd5);

    // 2. TUBERÍAS
    wire in_pipe_x   = (hpos >= pipe_x) && (hpos < pipe_x + PIPE_WIDTH);
    wire in_cap_x    = (hpos >= pipe_x - 10'd4) && (hpos < pipe_x + PIPE_WIDTH + 10'd4);
    
    wire in_gap      = (vpos >= gap_y) && (vpos < gap_y + GAP_HEIGHT);
    wire in_cap_top  = (vpos >= gap_y - 10'd16) && (vpos < gap_y);
    wire in_cap_bot  = (vpos >= gap_y + GAP_HEIGHT) && (vpos < gap_y + GAP_HEIGHT + 10'd16);
    
    wire pipe_body_gfx = in_pipe_x && !(in_gap || in_cap_top || in_cap_bot) && (vpos < FLOOR_Y);
    wire pipe_cap_gfx  = in_cap_x && (in_cap_top || in_cap_bot) && (vpos < FLOOR_Y);
    wire any_pipe_gfx  = pipe_body_gfx || pipe_cap_gfx;
    
    wire pipe_border    = (hpos == pipe_x) || (hpos == pipe_x + PIPE_WIDTH - 1'b1) ||
                          (in_cap_x && (vpos == gap_y - 10'd16 || vpos == gap_y - 1'b1 || 
                                       vpos == gap_y + GAP_HEIGHT || vpos == gap_y + GAP_HEIGHT + 10'd15));
    wire pipe_highlight = (hpos >= pipe_x + 10'd4) && (hpos <= pipe_x + 10'd10);

    // 3. NUBES (Fondo)
    wire [9:0] cloud1_x = (hpos + cloud_scroll) % 10'd320;
    wire is_cloud1 = (vpos >= 10'd40) && (vpos < 10'd70) && (cloud1_x < 10'd80) &&
                     ((vpos >= 10'd50) || (cloud1_x >= 10'd20 && cloud1_x <= 10'd60));

    wire [9:0] cloud2_x = (hpos + {cloud_scroll[8:0], 1'b0}) % 10'd500;
    wire is_cloud2 = (vpos >= 10'd120) && (vpos < 10'd145) && (cloud2_x < 10'd60) &&
                     ((vpos >= 10'd130) || (cloud2_x >= 10'd15 && cloud2_x <= 10'd45));

    wire any_cloud = is_cloud1 || is_cloud2;

    // 4. PISO / SUELO (PASTO + FRANJAS DIAGONALES ANIMADAS)
    wire floor_gfx       = (vpos >= FLOOR_Y);
    wire is_grass        = floor_gfx && (vpos < FLOOR_Y + 10'd16);
    wire is_grass_border = floor_gfx && (vpos >= FLOOR_Y + 10'd16) && (vpos < FLOOR_Y + 10'd20);
    
    // Franjas diagonales a 45° animadas
    wire [9:0] diag_pattern = hpos + vpos + ground_scroll;
    wire is_dirt_stripe  = floor_gfx && (vpos >= FLOOR_Y + 10'd20) && (diag_pattern[4] == 1'b1);

    // -------------------------------------------------------------
    // GENERACIÓN DE COLOR Y SALIDA VGA (RGB 2:2:2)
    // -------------------------------------------------------------
    reg [1:0] R, G, B;

    always @(*) begin
        if (!display_on) begin
            R = 2'b00; G = 2'b00; B = 2'b00;
        end 
        // 1. PÁJARO
        else if (bird_pixel) begin
            if (is_pupil)       begin R = 2'b00; G = 2'b00; B = 2'b00; end // Negro
            else if (is_eye)    begin R = 2'b11; G = 2'b11; B = 2'b11; end // Blanco
            else if (is_wing)   begin R = 2'b11; G = 2'b11; B = 2'b11; end // Blanco
            else if (is_beak)   begin R = 2'b11; G = 2'b01; B = 2'b00; end // Naranja
            else                begin R = 2'b11; G = 2'b11; B = 2'b00; end // Amarillo
        end 
        // 2. TUBERÍAS
        else if (any_pipe_gfx) begin
            if (pipe_border)         begin R = 2'b00; G = 2'b01; B = 2'b00; end // Borde verde oscuro
            else if (pipe_highlight) begin R = 2'b01; G = 2'b11; B = 2'b01; end // Brillo verde claro
            else                     begin R = 2'b00; G = 2'b10; B = 2'b00; end // Verde
        end 
        // 3. PISO
        else if (floor_gfx) begin
            if (is_grass)            begin R = 2'b01; G = 2 'b11; B = 2'b00; end // Pasto brillante
            else if (is_grass_border) begin R = 2'b00; G = 2'b10; B = 2'b00; end // Sombra de pasto
            else if (is_dirt_stripe)  begin R = 2'b10; G = 2'b01; B = 2'b00; end // Franja tierra marrón
            else                      begin R = 2'b11; G = 2'b10; B = 2'b01; end // Tierra dorada
        end 
        // 4. NUBES
        else if (any_cloud) begin
            R = 2'b11; G = 2'b11; B = 2'b11; // Blanco
        end 
        // 5. FONDO
        else begin
            if (state == STATE_GAMEOVER) 
                begin R = 2'b01; G = 2'b00; B = 2'b00; end // Pantalla tintada de rojo
            else                         
                begin R = 2'b01; G = 2'b10; B = 2'b11; end // Cielo azul
        end
    end

    // Asignación de salidas VGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

endmodule
