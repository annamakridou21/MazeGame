/*******************************************************************************
 * CS220: Digital Circuit Lab
 * Computer Science Department
 * University of Crete
 * 
 * Date: 2025/03/10
 * Author: CS220 Instructors
 * Filename: vga_pkg.sv
 * Description: The package with types and VGA configurations
 *
 ******************************************************************************/
package vga_pkg;

typedef struct packed {
  logic [11:0] hcnt;
  logic [11:0] hfp;
  logic [11:0] hsp;
  logic [11:0] hbp;
  logic [11:0] vcnt;
  logic [11:0] vfp;
  logic [11:0] vsp;
  logic [11:0] vbp;
} vga_cfg_t;

// 640x480 @60Hz - 25MHz settings
localparam vga_cfg_t vga_640x480_cfg = '{
  hcnt : 640,
  hfp  : 16,
  hsp  : 96,
  hbp  : 48,
  vcnt : 480,
  vfp  : 10,
  vsp  : 2,
  vbp  : 29
};

// 1024x768 @60Hz - 65MHz settings
localparam vga_cfg_t vga_1024x768_cfg = '{
  hcnt : 1024,
  hfp  : 24,
  hsp  : 136,
  hbp  : 160,
  vcnt : 768,
  vfp  : 3,
  vsp  : 6,
  vbp  : 29
};

endpackage
