/*******************************************************************************
 * CS220: Digital Circuit Lab
 * Computer Science Department
 * University of Crete
 * 
 * Date: 2025/03/10
 * Author: CS220 Instructors
 * Filename: vga_tb.sv
 * Description: A testbench that generates clock and reset and 
 *              captures VGA output in VGA Simulator format
 *
 ******************************************************************************/

`timescale 1ns / 1ns

// 40 ns -> 25 MHz
`define VGA_CLK_PERIOD  40
`define SIM_CYCLES      400000
`define MOVE_CYCLES     2000


module vga_tb;

integer fileout;

logic clk;
logic rst;

always #(`VGA_CLK_PERIOD/2) clk = ~clk;

logic enable;
logic mode;
logic [11:0] dip;
logic [15:0] leds;

logic hsync;
logic vsync;
logic [11:0] rgb;
logic up,down,left,right,control;

vga_maze_top vga0 (
  .sys_clk(clk),
  .rst(rst),
  .i_enable(enable),
  .i_mode(mode),
  .o_leds(),
  .i_control(control),
  .i_up(up),
  .i_down(down),
  .i_left(left),
  .i_right(right),
  .o_hsync(hsync),
  .o_vsync(vsync),
  .o_rgb(rgb),
  .o_seg(),
  .o_seg_en()
);


localparam BTN_UP      = 1;
localparam BTN_DOWN    = 2;
localparam BTN_LEFT    = 3;
localparam BTN_RIGHT   = 4;
localparam BTN_CONTROL = 5;

task push_button;
  input integer button;
  input integer up_time;
  input integer down_time;
  input integer times;
  integer i;
  begin
    for (i=0; i<times ; i=i+1) begin
      case(button)
        BTN_UP:      up = 1;
        BTN_DOWN:    down = 1;
        BTN_LEFT:    left = 1;
        BTN_RIGHT:   right = 1;
        BTN_CONTROL: control = 1;
      endcase
      repeat(up_time) @(posedge clk);
      case(button)
        BTN_UP:      up = 0;
        BTN_DOWN:    down = 0;
        BTN_LEFT:    left = 0;
        BTN_RIGHT:   right = 0;
        BTN_CONTROL: control = 0;
      endcase
      repeat(down_time) @(posedge clk);
    end
  end
endtask

task push(input integer button);
  push_button(button,10,5,10);
  repeat (`MOVE_CYCLES) @(posedge clk);
endtask

// clk and reset
initial begin
  $dumpfile("tb_waves.vcd");
  $dumpvars;

  fileout = $fopen("vga_log.txt");
  $timeformat(-9, 0, " ns", 6);

  up = 0;
  down = 0;
  left = 0;
  right = 0;
  control = 0;

  clk = 0;
  rst = 1;

  enable = 0;
  mode = 0;
  @(posedge clk);
  @(posedge clk);
  @(posedge clk);
  #1;
  rst = 0;
  @(posedge clk);

  repeat (10) @(posedge clk);
  #1;
  enable = 1;

  repeat (`MOVE_CYCLES) @(posedge clk);
  push(BTN_CONTROL);
  push(BTN_CONTROL);
  push(BTN_CONTROL);

  @(negedge vsync);

  push(BTN_UP);
  push(BTN_UP);
  push(BTN_UP);

  repeat (`SIM_CYCLES/4) @(posedge clk);

  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_UP);
  @(negedge vsync);

  repeat (`SIM_CYCLES/2) @(posedge clk);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_UP);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_UP);

  repeat (`SIM_CYCLES/2) @(posedge clk);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_UP);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_UP);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_UP);
  repeat (10) push(BTN_RIGHT);
  repeat (30) push(BTN_DOWN);
  @(negedge vsync);

  repeat (`SIM_CYCLES/4) @(posedge clk);
  repeat (10) push(BTN_LEFT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_LEFT);
  repeat (10) push(BTN_UP);
  repeat (10) push(BTN_LEFT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  repeat (10) push(BTN_DOWN);
  repeat (10) push(BTN_RIGHT);
  @(negedge vsync);

  repeat (10) push(BTN_DOWN);

  @(negedge vsync);
  @(posedge clk);
  #1;

  $fclose(fileout);
  $finish;
end

always @(posedge clk) begin
  if ( ~rst & enable) begin
    $fdisplay(fileout, "%t: %b %b %b %b %b", $time, hsync, vsync, rgb[11:8], rgb[7:4], rgb[3:0]);
  end
end

endmodule
