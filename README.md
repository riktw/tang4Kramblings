# tang4Kramblings

The corresponding code for the blog post: https://justanotherelectronicsblog.com/?p=986

To use: upload the included binary to the FPGA, or load the project in Gowin IDE, Synthesize, place and route and use the resulting binary.

For the NEORV32 software. Checkout their git repo: https://github.com/stnolting/neorv32
 
Copy the NEORV32_Software/example to the sw/example/ directory. Copy the NEORV32_Software/common over the sw/common directory. Running "make exe" in the sw/example/HyperRAM directory should result in the binary.

The license included only counts for code added by me. Please check the VT52, Grant's 6502 and the NEORV32 websites for their latest licenses.
