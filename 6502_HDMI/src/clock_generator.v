module clock_generator
  (input wire clk,
   output wire clk_usb,
   output wire reset_usb,
   output wire clk_vga,
   output wire reset_vga
   );

   wire locked;
   reg vga_clk_divider;
   reg usb_clock;

   

   // Generate reset signal
   reg [5:0] reset_cnt = 0;
   assign reset_usb = ~reset_cnt[5];

    always @(posedge clk)
      usb_clock <= ~usb_clock;
   
   always @(posedge clk)
     if (locked) reset_cnt <= reset_cnt + reset_usb;

   // divide usb clock by by two to get vga clock
   always @(posedge clk) begin
      if (reset_usb) vga_clk_divider <= 0;
      else vga_clk_divider <= ~vga_clk_divider;
   end

   assign clk_vga = vga_clk_divider;
   assign reset_vga = reset_usb;
   assign clk_usb = usb_clock;
   assign locked = 1;
endmodule
