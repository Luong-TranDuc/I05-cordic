set lib_file $::env(LIBERTY)

read_liberty $lib_file
read_verilog 06_GDSII/synthesis/netlist.v
link_design i05_cordic_core
read_sdc 04_IMPLEMENTATION/constraints/design.sdc

report_checks -path_delay max
report_checks -path_delay min
report_wns
report_tns
