/*******************************************************************************
 * CS220: Digital Circuit Lab
 * Computer Science Department
 * University of Crete
 * * Date: 2025/05/19
 * Author: Anna Makridou
 * Filename: maze_controller.sv
 * Description: Maze controller module
 ******************************************************************************/

module maze_controller(
  input  logic clk,
  input  logic rst,

  input  logic i_mode,         
  input  logic i_control,      
  input  logic i_up,           
  input  logic i_down,
  input  logic i_left,
  input  logic i_right,
  output logic [5:0] o_player_bcol,  
  output logic [5:0] o_player_brow,
  input  logic [5:0] i_exit_bcol,    
  input  logic [5:0] i_exit_brow,
  output logic [7:0] o_seg,          
  output logic [3:0] o_seg_en
);

  // fsm states
  typedef enum logic [3:0] {
    IDLE,
    PLAY,
    UP,
    DOWN,
    LEFT,
    RIGHT,
    READROM,
    WAIT,
    CHECK,
    UPDATE,
    ENDD
  } state_t;
  
  state_t state, next_state;
  
  // player position
  logic [5:0] player_bcol, player_brow;  
  
  logic [5:0] rom_target_bcol, rom_target_brow;  
  
  logic [5:0] new_bcol_comb, new_brow_comb;     
  
  // control counters
  logic [2:0] control_count; // Unified counter for start/end game
  logic i_mode_prev; // previous i_mode
  
  // timeout counter
  logic [13:0] timeout_counter;         
  logic [13:0] timeout_max;             
  logic [19:0] clk_div_counter;       
  logic clk_div_enable;      

  // signals
  logic start_condition;              
  logic reach_exit;                     
  logic move_valid;                      
  logic timeout;                       
  
  // rom signals
  logic [11:0] rom_addr;               
  logic [15:0] rom_data;                
  logic rom_en;     

  localparam REFRESH_CYCLES_PER_DIGIT_25MHZ = 62_500; 
  localparam REFRESH_CYCLES_PER_DIGIT_65MHZ = 162_500;

  logic [17:0] max;
  logic [17:0] count;         
  logic [1:0] digit_select;            

  logic [3:0] bcd_thousands, bcd_hundreds, bcd_tens, bcd_units; 
  logic [3:0] current;       
  logic [7:0] pattern;        

  // clock frequency-based config
  always_comb begin
    if (i_mode) begin
        max = REFRESH_CYCLES_PER_DIGIT_65MHZ - 1;
    end else begin   
        max = REFRESH_CYCLES_PER_DIGIT_25MHZ - 1;
    end
  end


  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      count <= 18'd0;
      digit_select <= 2'd0;
    end else begin
      if (count == max) begin
        count <= 18'd0;
        digit_select <= digit_select + 1; 
      end else begin
        count <= count + 1;
      end
    end
  end

  // convert timeout to BCD digits 
  always_comb begin
    automatic int centisec;
    automatic int sec;
    automatic int min;
    automatic int seconds; 

    centisec = int'(timeout_counter);

    seconds = centisec / 100;

    min = seconds / 60;
    seconds = seconds % 60;

    bcd_units     = 4'(seconds % 10);
    bcd_tens      = 4'(seconds / 10);

    bcd_hundreds  = 4'(min % 10);
    bcd_thousands = 4'(min / 10);
  end

  // select which BCD digit to display
  always_comb begin
    case (digit_select)
      2'd0: current = bcd_units;     
      2'd1: current = bcd_tens;      
      2'd2: current = bcd_hundreds;  
      2'd3: current = bcd_thousands; 
      default: current = 4'd0; 
    endcase
  end
  
  // 7-segment display patterns 
  always_comb begin
    case (current)
      4'd0:   pattern = 8'b11000000; // 0
      4'd1:   pattern = 8'b11111001; // 1
      4'd2:   pattern = 8'b10100100; // 2
      4'd3:   pattern = 8'b10110000; // 3
      4'd4:   pattern = 8'b10011001; // 4
      4'd5:   pattern = 8'b10010010; // 5
      4'd6:   pattern = 8'b10000010; // 6
      4'd7:   pattern = 8'b11111000; // 7
      4'd8:   pattern = 8'b10000000; // 8
      4'd9:   pattern = 8'b10010000; // 9
      default: pattern = 8'b11111111; // all off
    endcase
  end

  assign o_seg = pattern;

  // active-low digit enable signals
  always_comb begin
    case (digit_select)
      2'd0:   o_seg_en = 4'b1110; 
      2'd1:   o_seg_en = 4'b1101; 
      2'd2:   o_seg_en = 4'b1011; 
      2'd3:   o_seg_en = 4'b0111; 
      default: o_seg_en = 4'b1111; 
    endcase
  end                    

  // rom address
  assign rom_addr = {rom_target_brow, rom_target_bcol};  
  
  rom #(
    .size(4096),   
    .file("../src/roms/maze1.rom")       
  ) maze_rom (
    .clk(clk),
    .en(rom_en),
    .addr(rom_addr),
    .dout(rom_data)
  );
  
  assign o_player_bcol = player_bcol;   
  assign o_player_brow = player_brow;
  
  assign start_condition = (state == IDLE && control_count == 3'd3);     
  assign reach_exit = (player_bcol == i_exit_bcol) && (player_brow == i_exit_brow);  
  assign timeout = (timeout_counter == 14'd0);
  
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end
  
  // start/end game
  always_ff @(posedge clk or posedge rst) begin
  if (rst) begin
    control_count <= 3'd0;
  end else begin
    if (next_state == PLAY && state == IDLE) begin
      // reset when transitioning from IDLE to PLAY
      control_count <= 3'd0;
    end else if (state == IDLE) begin
      // start game
      if (i_control) begin
        if (control_count < 3'd3) begin
          control_count <= control_count + 3'd1;
        end
      end else if (i_up || i_down || i_left || i_right) begin
        control_count <= 3'd0;
      end
    end else if (state == PLAY) begin
      // end game condition
      if (i_control) begin
        if (control_count < 3'd6) begin
          control_count <= control_count + 3'd1;
        end
      end else if (i_up || i_down || i_left || i_right) begin
        control_count <= 3'd0;
      end
    end else begin
      control_count <= 3'd0;
    end
  end
end
  
  // timeout logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      if (i_mode) begin // large maze
        timeout_max <= 14'd15000;  
        timeout_counter <= 14'd15000;
      end else begin      // small maze
        timeout_max <= 14'd9000;   
        timeout_counter <= 14'd9000;
      end
    end else begin
      if (state == IDLE) begin // reset timer in idle
        if (i_mode) begin
          timeout_max <= 14'd15000; 
          timeout_counter <= 14'd15000;
        end else begin
          timeout_max <= 14'd9000;   
          timeout_counter <= 14'd9000;
        end
      end else if (state == PLAY || state == UP || state == DOWN || state == LEFT || state == RIGHT || state == READROM || state == WAIT || state == CHECK || state == UPDATE) begin // decrement timer during play
        if (clk_div_enable && timeout_counter > 14'd0) begin 
          timeout_counter <= timeout_counter - 14'd1; 
        end
      end
    end
  end
  
  // clock divider for 0.01s
  localparam CLK_DIV_MAX_VAL_25MHZ_FOR_0_01S = 25_000_000 / 100 - 1; 
  localparam CLK_DIV_MAX_VAL_65MHZ_FOR_0_01S = 65_000_000 / 100 - 1; 
  logic [19:0] clk_div_current_max_val;

  always_comb begin
      if(i_mode) begin // 65mhz
          clk_div_current_max_val = 20'(CLK_DIV_MAX_VAL_65MHZ_FOR_0_01S);
      end else begin // 25mhz
          clk_div_current_max_val = 20'(CLK_DIV_MAX_VAL_25MHZ_FOR_0_01S);
      end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      clk_div_counter <= 20'd0;
      clk_div_enable <= 1'b0;
    end else begin
      if (clk_div_counter >= clk_div_current_max_val) begin
        clk_div_counter <= 20'd0;
        clk_div_enable <= 1'b1;
      end else begin
        clk_div_counter <= clk_div_counter + 20'd1;
        clk_div_enable <= 1'b0;
      end
    end
  end
  
  // player position logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      player_bcol <= 6'd1;              
      player_brow <= 6'd0; 
    end else if (state == IDLE) begin
      player_bcol <= 6'd1;              
      player_brow <= 6'd0;
    end else if (state == UPDATE) begin 
        player_bcol <= rom_target_bcol; 
        player_brow <= rom_target_brow;
    end
  end

  // rom target logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        rom_target_bcol <= 6'd1;         
        rom_target_brow <= 6'd0;
    end else if (state == UP || state == DOWN || state == LEFT || state == RIGHT) begin
        rom_target_bcol <= new_bcol_comb; 
        rom_target_brow <= new_brow_comb;
    end
  end
  
  // fsm logic
  always_comb begin
    next_state = state;
    rom_en = 1'b0; 
    move_valid = 1'b0; 

    new_bcol_comb = player_bcol; 
    new_brow_comb = player_brow;
    
    case (state)
      IDLE: begin  // wait for start
        if (start_condition) begin
          next_state = PLAY;  
        end
      end
      
      PLAY: begin  // main play state
        if (reach_exit) begin
          next_state = ENDD;             
        end else if (state == PLAY && control_count == 3'd6) begin // Check for end game via control
          next_state = IDLE;             
        end else if (timeout) begin
          next_state = ENDD;           
        end else if (i_up && player_brow > 6'd0) begin 
          next_state = UP;               
        end else if (i_down && player_brow < (i_mode ? 6'd63 : 6'd39)) begin 
          next_state = DOWN;             
        end else if (i_left && player_bcol > 6'd0) begin 
          next_state = LEFT;            
        end else if (i_right && player_bcol < (i_mode ? 6'd63 : 6'd39)) begin 
          next_state = RIGHT;            
        end
      end
      
      UP: begin  // move up
        if (player_brow > 6'd0) begin
          new_brow_comb = player_brow - 6'd1; 
        end else begin
          new_brow_comb = player_brow;        
        end
        new_bcol_comb = player_bcol;           
        next_state = READROM;
      end
      
      DOWN: begin  // move down
        if (i_mode) begin
          if (player_brow < 6'd63) begin
            new_brow_comb = player_brow + 6'd1;  
          end else begin
            new_brow_comb = player_brow;  
          end
        end else begin
          if (player_brow < 6'd39) begin
            new_brow_comb = player_brow + 6'd1;  
          end else begin
            new_brow_comb = player_brow;       
          end
        end
        new_bcol_comb = player_bcol;           
        next_state = READROM;
      end
      
      LEFT: begin  // move left
        if (player_bcol > 6'd0) begin
          new_bcol_comb = player_bcol - 6'd1;  
        end else begin
          new_bcol_comb = player_bcol;        
        end
        new_brow_comb = player_brow;        
        next_state = READROM;
      end
      
      RIGHT: begin  // move right
        if (i_mode) begin
          if (player_bcol < 6'd63) begin
            new_bcol_comb = player_bcol + 6'd1;  
          end else begin
            new_bcol_comb = player_bcol;        
          end
        end else begin
          if (player_bcol < 6'd39) begin
            new_bcol_comb = player_bcol + 6'd1;  
          end else begin
            new_bcol_comb = player_bcol;        
          end
        end
        new_brow_comb = player_brow;       
        next_state = READROM;
      end
      
      READROM: begin  // read rom
        rom_en = 1'b1;                 
        next_state = WAIT;
      end
      
      WAIT: begin  // wait for rom data
        rom_en = 1'b1;                 
        next_state = CHECK;
      end
      
      CHECK: begin  // check for wall
        if (rom_data == 16'h0000) begin  
          move_valid = 1'b0; 
          next_state = PLAY;   
        end else begin                   
          move_valid = 1'b1; 
          next_state = UPDATE; 
        end
      end
      
      UPDATE: begin  // update player pos
        next_state = PLAY;               
      end
      
      ENDD: begin  // game over
        if (i_control) begin 
          next_state = IDLE;           
        end
      end
      
      default: next_state = IDLE;
    endcase
  end

endmodule
