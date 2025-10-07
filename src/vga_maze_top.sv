/*******************************************************************************
 * CS220: Digital Circuit Lab
 * Computer Science Department
 * University of Crete
 * 
 * Date: 2025/03/10
 * Author: CS220 Instructors
 * Filename: vga_maze_top.sv
 * Description: The Lab3 top module that instantiates 
 *              vga_sync, vga_frame, and maze_controller 
 *
 ******************************************************************************/

module vga_maze_top
  import vga_pkg::*;
(
  input logic           sys_clk,
  input logic           rst,

  input  logic          i_enable,
  input  logic          i_mode,
  output logic [15:0]   o_leds,

  input  logic          i_control,
  input  logic          i_up,
  input  logic          i_down,
  input  logic          i_left,
  input  logic          i_right,

  output logic [7:0]    o_seg,
  output logic [3:0]    o_seg_en,

  output logic          o_hsync,
  output logic          o_vsync,
  output logic [11:0]   o_rgb
);
/////////////////////////////////////////////////////////////
// Clocking
logic clk;
logic clk_sel;
`ifdef SYNTHESIS
  // generate two clock here (25MHz and 65MHz)
  logic clk25, clk65;
  clk_wiz_x2 u0_clk_wiz ( .clk_in1(sys_clk), .clk_out1(clk25), .clk_out2(clk65) );

  // instantiate a glitch-free clock mux directly from xilinx primitives
  BUFGMUX BUFGMUX_inst (
      .O(clk),          // 1-bit output: Clock output
      .I0(clk25),       // 1-bit input: Clock input (S=0)
      .I1(clk65),       // 1-bit input: Clock input (S=1)
      .S(clk_sel)       // 1-bit input: Clock select
   );
`else
  assign clk = sys_clk;
`endif // SYNTHESIS
/////////////////////////////////////////////////////////////

logic pix_rgb_valid;
logic pix_rgb_ready;
logic [11:0] pix_rgb_data;

logic [5:0] p_bcol;
logic [5:0] p_brow;
logic [5:0] e_bcol;
logic [5:0] e_brow;

vga_cfg_t cfg;

always_comb begin
  // 640x480 @60Hz - 25MHz settings
  if ( ~clk_sel ) begin
    cfg = vga_640x480_cfg;
  end
  // 1024x768 @60Hz - 65MHz settings
  else begin
    cfg = vga_1024x768_cfg;
  end
end

///////////////////////////////////////////////////////////////////////////////
// DIP SWITCHES

// take care of metastability of asynchronous enable signal from dip switch
logic [2:0] enable_q;
logic enable_int;
always_ff @(posedge clk or posedge rst) begin
  if (rst)   enable_q <= 0;
  else       enable_q <= {i_enable, enable_q[2:1]};
end

assign enable_int = enable_q[0];

// take care of metastability of asynchronous mode signal from dip switch
logic [2:0] mode_q;
always_ff @(posedge clk or posedge rst) begin
  if (rst)   mode_q <= 0;
  else       mode_q <= {i_mode, mode_q[2:1]};
end

logic mode_int;
assign mode_int = mode_q[0];
assign clk_sel = mode_int;


///////////////////////////////////////////////////////////////////////////////
// LEDS

always_comb begin
  o_leds = '0;

  o_leds[15] = rst;
  o_leds[14] = enable_int;
  o_leds[13] = mode_int;

  o_leds[11:0] = {p_brow, p_bcol};
end


///////////////////////////////////////////////////////////////////////////////
// BUTTON DEBOUNCERS
logic control,up,down,left,right;
debouncer control_dbnc (
  .clk(clk),
  .rst(rst),
  .i_button(i_control),
  .o_pulse(control)
);

debouncer up_dbnc (
  .clk(clk),
  .rst(rst),
  .i_button(i_up),
  .o_pulse(up)
);

debouncer down_dbnc (
  .clk(clk),
  .rst(rst),
  .i_button(i_down),
  .o_pulse(down)
);

debouncer left_dbnc (
  .clk(clk),
  .rst(rst),
  .i_button(i_left),
  .o_pulse(left)
);

debouncer right_dbnc (
  .clk(clk),
  .rst(rst),
  .i_button(i_right),
  .o_pulse(right)
);


///////////////////////////////////////////////////////////////////////////////

assign e_bcol = (mode_int) ? 6'd01 : 6'd37;
assign e_brow = (mode_int) ? 6'd47 : 6'd29;

vga_frame vf (
  .clk(clk),
  .rst(rst),

  .i_cfg_enable(enable_int),
  .i_cfg(cfg),

  .i_player_bcol(p_bcol),
  .i_player_brow(p_brow),
  .i_exit_bcol(e_bcol),
  .i_exit_brow(e_brow),

  .i_pix_rgb_ready(pix_rgb_ready),
  .o_pix_rgb_valid(pix_rgb_valid),
  .o_pix_rgb_data (pix_rgb_data)
);

vga_sync vs (
  .clk(clk),
  .rst(rst),

  .i_cfg_enable(enable_int),
  .i_cfg(cfg),

  .o_pix_rgb_ready(pix_rgb_ready),
  .i_pix_rgb_valid(pix_rgb_valid),
  .i_pix_rgb_data (pix_rgb_data),

  .o_hsync(o_hsync),
  .o_vsync(o_vsync),
  .o_rgb(o_rgb)
);

maze_controller vc (
  .clk(clk),
  .rst(rst),

  .i_mode(mode_int),
  .i_control(control),
  .i_up(up),
  .i_down(down),
  .i_left(left),
  .i_right(right),

  .o_player_bcol(p_bcol),
  .o_player_brow(p_brow),

  .i_exit_bcol(e_bcol),
  .i_exit_brow(e_brow),

  .o_seg(o_seg),
  .o_seg_en(o_seg_en)
);

endmodule
