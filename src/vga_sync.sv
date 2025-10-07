/*******************************************************************************
 * CS220: Digital Circuit Lab
 * Computer Science Department
 * University of Crete
 * 
 * Date: 2025/03/29
 * Author: Anna Makridou
 * Filename: vga_sync.sv
 * Description: Implements VGA HSYNC and VSYNC timings and output RGB
 *
 ******************************************************************************/

import vga_pkg::*;

module vga_sync(
  input  logic         clk,
  input  logic         rst,
  input  logic         i_cfg_enable,
  input  vga_cfg_t     i_cfg,            // using the new struct
  output logic         o_pix_rgb_ready,
  input  logic         i_pix_rgb_valid,
  input  logic [11:0]  i_pix_rgb_data,
  output logic         o_hsync,
  output logic         o_vsync,
  output logic [11:0]  o_rgb
);

  logic [11:0] hcnt_q, hcnt_d;  
  logic [11:0] vcnt_q, vcnt_d; 
  logic hcnt_clr;              
  logic vcnt_clear;          
  logic hsync_d, hsync_q;       
  logic hsync_d2, hsync_q2;      
  logic vsync_d, vsync_q;    
  logic hs_set, hs_clr;          
  logic vs_set, vs_clr;         

  always_comb begin
    // counter input
    hcnt_d = hcnt_q + 1;
    vcnt_d = vcnt_q + 1;

    // counter clear
    hcnt_clr = (hcnt_q == i_cfg.hcnt + i_cfg.hfp + i_cfg.hsp + i_cfg.hbp);
    vcnt_clear = (vcnt_q == (i_cfg.vcnt + i_cfg.vfp + i_cfg.vsp + i_cfg.vbp)) & hcnt_clr;

    // sync set/clear
    hs_set = (hcnt_q == (i_cfg.hcnt + i_cfg.hfp - 1));
    hs_clr = (hcnt_q == (i_cfg.hcnt + i_cfg.hfp + i_cfg.hsp - 1));
    vs_set = (vcnt_q == (i_cfg.vcnt + i_cfg.vfp)) & hcnt_clr;
    vs_clr = (vcnt_q == (i_cfg.vcnt + i_cfg.vfp + i_cfg.vsp)) & hcnt_clr;
  end
  
// horizontal counter
always_ff @(posedge clk or posedge rst) begin
  if (rst || ~i_cfg_enable) begin
    hcnt_q <= 1;   //we should reset at value 1
  end
  else if (hcnt_clr) begin
    hcnt_q <= 1;        //if clear bit is 1, counter value is 1
  end
  else begin
    hcnt_q <= hcnt_d;  //else counter value is the previous value of the counter+1
  end
end

// vertical counter
always_ff @(posedge clk or posedge rst) begin
  if (rst || ~i_cfg_enable) begin
    vcnt_q <= 1;  //reset at value 1
  end
  else if (vcnt_clear) begin	//if clear bit is 1, counter value is 1
    vcnt_q <= 1;  
  end
  else if (hcnt_clr && ~vcnt_clear) begin	//else if hcnt clear bit is 1, counter value is the previous value+1
    vcnt_q <= vcnt_d; 
  end
end
  
// ready 
  assign o_pix_rgb_ready = i_cfg_enable & (hcnt_q <= i_cfg.hcnt) & (vcnt_q <= i_cfg.vcnt);   

// o_rgb
  always_comb begin
    if (o_pix_rgb_ready && i_pix_rgb_valid) begin  //if valid&ready we send the data
      o_rgb = i_pix_rgb_data;
    end
    else begin
      o_rgb = 0;
    end
  end

//flip - flops
  always_comb begin
    hsync_d  = (hs_set | hsync_q) & ~hs_clr;
    hsync_d2 = hsync_q;   //the input of the second hsync register is the output of the first hsync register
    vsync_d  = (vs_set | vsync_q) & ~vs_clr; 
  end

//hsync 
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      hsync_q  <= 0;   //we reset at value 0
      hsync_q2 <= 0;
    end
    else begin
      hsync_q  <= hsync_d;      
      hsync_q2 <= hsync_d2;   //the output of the second hsync register is the output of the first hsync register, delayed
    end
  end

//vsync
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      vsync_q <= 0;  //we reset at value 0
    end
    else begin
      vsync_q <= vsync_d;   //the output of the vsync register is the input of the vsync register
    end
  end

//final output : not gate
  assign o_hsync = ~hsync_q2;
  assign o_vsync = ~vsync_q;
  
endmodule
