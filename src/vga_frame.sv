module vga_frame
  import vga_pkg::*;
(
  input logic           clk,
  input logic           rst,

  input logic [5:0]     i_player_bcol,
  input logic [5:0]     i_player_brow,

  input logic [5:0]     i_exit_bcol,
  input logic [5:0]     i_exit_brow,

  input logic           i_cfg_enable,
  input vga_cfg_t       i_cfg,

  input  logic          i_pix_rgb_ready,
  output logic          o_pix_rgb_valid,
  output logic [11:0]   o_pix_rgb_data  
);

  logic [11:0] pixel_column, pixel_row;
  logic [5:0] block_column, block_row;
  logic [3:0] offset_col, offset_row;
  logic maze_en, player_en, exit_en;
  logic [11:0] maze_addr;
  logic [7:0] player_addr, exit_addr;
  logic [15:0] maze_pixel, player_pixel, exit_pixel;
  logic [11:0] rgb_data;
  logic is_player_block, is_exit_block;
  
  // calculate fetch coordinates one pixel ahead to fix the shift
  logic [11:0] fetch_pixel_column, fetch_pixel_row;
  logic [5:0] fetch_block_column, fetch_block_row;
  logic [3:0] fetch_offset_col, fetch_offset_row;
  logic is_fetch_player_block, is_fetch_exit_block;
  logic rom_cmd_maze_en, rom_cmd_player_en, rom_cmd_exit_en;
  logic prev_pix_rgb_ready, prev_cfg_enable;
  
  // calculate pixel coordinates 
  always_ff @(posedge clk or posedge rst) begin
    if (rst || ~i_cfg_enable) begin
      pixel_column <= 1;  
      pixel_row <= 1;  
    end else if (i_pix_rgb_ready) begin
      // update pixel coordinates
      if (pixel_column == i_cfg.hcnt) begin  
        pixel_column <= 1;
        if (pixel_row == i_cfg.vcnt) begin 
          pixel_row <= 1;
        end else begin
          pixel_row <= pixel_row + 1;  
        end
      end else begin
        pixel_column <= pixel_column + 1;  
      end
    end
  end
  
  // calculate fetch coordinates 
  always_comb begin
    fetch_pixel_column = pixel_column + 1;
    fetch_pixel_row = pixel_row;
  
    if (pixel_column == i_cfg.hcnt && i_cfg.hcnt > 0) begin // End of current line
      fetch_pixel_column = 1;                               // Fetch starts at beginning of next line
      if (pixel_row == i_cfg.vcnt && i_cfg.vcnt > 0) begin    // End of frame
        fetch_pixel_row = 1;                                // Fetch starts at beginning of frame
      end else begin
        fetch_pixel_row = pixel_row + 1;                    // Fetch for next line
      end
    end
  end
  
  // calculate block and offset
  assign offset_col = 4'((pixel_column - 12'd1) & 12'hF);  // extract lower 4 bits to get x in 16x16 block
  assign offset_row = 4'((pixel_row - 12'd1) & 12'hF);     // extract lower 4 bits to get y in 16x16 block
  assign block_column = 6'((pixel_column - 12'd1) >> 4);   // divide by 16 to get block column 
  assign block_row = 6'((pixel_row - 12'd1) >> 4);         // divide by 16 to get block row
  
  // calculate block and offset for fetch coordinates
  assign fetch_offset_col = 4'((fetch_pixel_column - 12'd1) & 12'hF);
  assign fetch_offset_row = 4'((fetch_pixel_row - 12'd1) & 12'hF);
  assign fetch_block_column = 6'((fetch_pixel_column - 12'd1) >> 4);
  assign fetch_block_row = 6'((fetch_pixel_row - 12'd1) >> 4);
  
  // check if player or exit block 
  assign is_player_block = (block_column == i_player_bcol) && (block_row == i_player_brow);
  assign is_exit_block = (block_column == i_exit_bcol) && (block_row == i_exit_brow);
  
  // check if player or exit block for fetch coordinates
  assign is_fetch_player_block = (fetch_block_column == i_player_bcol) && (fetch_block_row == i_player_brow);
  assign is_fetch_exit_block = (fetch_block_column == i_exit_bcol) && (fetch_block_row == i_exit_brow);

  // ROM command enable logic for prefetching
  always_comb begin
    rom_cmd_maze_en = 1'b0;
    rom_cmd_player_en = 1'b0;
    rom_cmd_exit_en = 1'b0;
    if (i_pix_rgb_ready) begin
      rom_cmd_maze_en = 1'b1; // Always try to fetch maze data
      rom_cmd_player_en = is_fetch_player_block;
      rom_cmd_exit_en = is_fetch_exit_block && !is_fetch_player_block;
    end
  end

  // ROM enable logic 
  always_ff @(posedge clk or posedge rst) begin
    if (rst || ~i_cfg_enable) begin
      maze_en <= 0;    
      player_en <= 0;  
      exit_en <= 0;
      prev_pix_rgb_ready <= 0;
      prev_cfg_enable <= 0;
      o_pix_rgb_valid <= 0;    
    end else begin
      prev_pix_rgb_ready <= i_pix_rgb_ready;
      prev_cfg_enable <= i_cfg_enable;
      
      if (i_cfg_enable) begin
        if (i_pix_rgb_ready) begin
          maze_en <= rom_cmd_maze_en;
          player_en <= rom_cmd_player_en;
          exit_en <= rom_cmd_exit_en;
        end
      end else begin
        maze_en <= 0;
        player_en <= 0;
        exit_en <= 0;
      end
      
      o_pix_rgb_valid <= prev_cfg_enable && prev_pix_rgb_ready;
    end
  end
  
  // priority: player > exit > maze
  always_comb begin
    // default
    o_pix_rgb_data = 12'hFFF;
    
    if (player_en) begin
      o_pix_rgb_data = {player_pixel[15:12], player_pixel[11:8], player_pixel[7:4]};
    end else if (exit_en) begin
      o_pix_rgb_data = {exit_pixel[15:12], exit_pixel[11:8], exit_pixel[7:4]};
    end else if (maze_en) begin
      o_pix_rgb_data = {maze_pixel[15:12], maze_pixel[11:8], maze_pixel[7:4]};
    end
  end
  
  // ROM address calculation
  always_comb begin
    maze_addr = {fetch_block_row, fetch_block_column};
    player_addr = 0;
    exit_addr = 0;

    // only valid inside player block
    if (is_fetch_player_block)
      player_addr = {fetch_offset_row, fetch_offset_col};

    // only valid inside exit block
    if (is_fetch_exit_block)
      exit_addr = {fetch_offset_row, fetch_offset_col};
  end

  rom #(
    .size(4096),
    .file("../src/roms/maze1.rom")
  )
  maze_rom (
    .clk(clk),
    .en(rom_cmd_maze_en),
    .addr(maze_addr),
    .dout(maze_pixel)
  );
  
  rom #(
    .size(256),
    .file("../src/roms/player.rom")
  )
  player_rom (
    .clk(clk),
    .en(rom_cmd_player_en),
    .addr(player_addr),
    .dout(player_pixel)
  );
  
  rom #(
    .size(256),
    .file("../src/roms/exit.rom")
  )
  exit_rom (
    .clk(clk),
    .en(rom_cmd_exit_en),
    .addr(exit_addr),
    .dout(exit_pixel)
  );
  
endmodule
