\# FPGA BRAM Project



This project implements a memory-based FPGA design using the Xilinx/Vivado Block Memory Generator IP.



\## Project Description



The design uses a Block Memory Generator IP initialized using a `.coe` file. The memory contents are read during simulation and verified using testbench results.



\## Tools Used



\- Vivado

\- Verilog/VHDL

\- Block Memory Generator IP

\- COE memory initialization file



\## Main Files



\- `.xpr` - Vivado project file

\- `.v` / `.sv` / `.vhd` - HDL source files

\- `.xdc` - constraint file

\- `.coe` - memory initialization file

\- `.xci` - IP configuration file



\## Simulation



The design was simulated in Vivado. Instead of including all waveforms, representative waveform screenshots and verification tables are used in the report.



\## Notes



Generated Vivado folders such as `.runs`, `.sim`, `.cache`, `.gen`, and `.Xil` are excluded using `.gitignore`.

