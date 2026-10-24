# I05 CORDIC 8-bit — Project Run Log

## 1. Environment
- OS: Ubuntu on WSL
- Synthesis: Yosys 0.52
- STA: OpenSTA 2.0.17
- PDK: SKY130A
- Standard-cell library: sky130_fd_sc_hd
- Liberty corner: tt_025C_1v80
- Clock period assumption: 10 ns

## 2. RTL Simulation
- Result: I05 RTL TB PASS

## 3. Synthesis
- Result: Completed
- Reported cell count: 883
- Reported flip-flops: 66
- Estimated cell area: 6581.312
- Netlist: 06_GDSII/synthesis/netlist.v

## 4. STA — Initial Run
- Original script: 04_IMPLEMENTATION/scripts/03_run_sta.tcl
- Error: report_checks rejected positional arguments
- Backup: 04_IMPLEMENTATION/scripts/03_run_sta.tcl.bak
- Test script: 04_IMPLEMENTATION/scripts/03_run_sta_test.tcl
- Log: 06_GDSII/sta/sta_test.log

### Reported timing paths
- Max path startpoint: _1693_
- Max path endpoint: _1649_
- Data arrival: 7.97 ns
- Data required: 9.89 ns
- Setup slack: 1.93 ns
- Min path startpoint: _1635_
- Min path endpoint: _1635_
- Data arrival: 0.38 ns
- Data required: -0.06 ns
- Hold slack: 0.44 ns
- Reported WNS: 0.00 ns
- Reported TNS: 0.00 ns

### Outstanding issue
- OpenSTA warns that default operating condition
  tt_025C_1v80 is not found, despite its declaration
  in the Liberty file. Root cause not yet confirmed.

## 5. Physical Design
- Floorplan: Not yet verified
- Placement: Not yet verified
- Clock-tree synthesis: Not yet verified
- Routing: Not yet verified
- DRC/LVS: Not yet verified
- Final GDSII: Not yet generated or verified

## 6. Reporting Rules
- Distinguish measured results from prefilled configuration values.
- Record each file changed, original error, correction, and rerun result.
- Record tool versions, library corner, constraints, and report paths.
- Do not claim final timing closure or GDSII completion before verification.
