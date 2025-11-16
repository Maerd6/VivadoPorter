VivadoPorter

========================



This tool collects all essential project files and organizes them into a portable structure, enabling seamless project restoration using the provided Tcl script. Ideal for FPGA designers who need to share, archive, or transfer Vivado projects without dependency issues.

You can generate a package following two steps:
1. Collect all neccesary file into a folder(e.g. ./examlpe/src).
2. Use this program in Terminal with arguments, including FPGA part, top module name, and direction of source file.

Here is an example: ***python3 VivadoPorter.py -t top_module_name -p FPGA_part -d direction_of_file***.

Then, a folder named top_module_name_package is generated, which contians all project file. In this folder, a tcl script named non_project.tcl can be used in none project mode in Vivado. Here is the usage: ***Vivado -mode batch -source non_project.tcl***.

In future version, a tcl script for project mode will be also provided.