# ============================================================================
# Yosys Synthesis Script — Nibble 4-bit CPU targeting IHP SG13G2
# ============================================================================
# Usage: IHP_PDK=/path/to/IHP-Open-PDK yosys -s flow/synth.tcl
# ============================================================================

# Read IHP standard cell Liberty file
set ihp_pdk $::env(IHP_PDK)
set lib_file "$ihp_pdk/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"

# Read RTL
read_verilog src/cpu_core.v
read_verilog src/project.v

# Synthesize
synth -top tt_um_fidel_makatia_4bit_cpu -flatten

# Map to IHP SG13G2 standard cells
dfflibmap -liberty $lib_file
abc -liberty $lib_file

# Clean up
opt_clean -purge

# Reports
tee -o outputs/synth_stats.txt stat -liberty $lib_file
tee -o outputs/synth_check.txt check

# Write gate-level netlist
write_verilog -noattr outputs/synth_netlist.v

puts ""
puts "============================================================"
puts "  Synthesis Complete (IHP SG13G2)"
puts "  Stats:   outputs/synth_stats.txt"
puts "  Netlist: outputs/synth_netlist.v"
puts "============================================================"
