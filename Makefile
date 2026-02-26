# Nibble 4-bit CPU — Build & Test
#
#   make test       Run RTL testbench (requires iverilog)
#   make synth      Synthesize to IHP SG13G2 cells (requires yosys + IHP PDK)
#   make test_gl    Run gate-level testbench (requires iverilog + IHP PDK)
#   make wave       Open waveform in GTKWave
#   make clean      Remove generated files
#   make help       Show this help

IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave
YOSYS    ?= yosys

# IHP PDK path (clone from https://github.com/IHP-GmbH/IHP-Open-PDK)
IHP_PDK  ?= $(HOME)/IHP-Open-PDK
IHP_LIB   = $(IHP_PDK)/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib

SRC = src/cpu_core.v src/project.v
TB  = test/tb.v

.PHONY: test synth test_gl wave clean help

test:
	@echo "========== RTL Simulation =========="
	$(IVERILOG) -o test/tb.out -g2012 $(SRC) $(TB)
	$(VVP) test/tb.out
	@echo ""

synth:
	@echo "========== Synthesis (IHP SG13G2) =========="
	@mkdir -p outputs
	@echo "read_verilog src/cpu_core.v" > /tmp/_synth.ys
	@echo "read_verilog src/project.v" >> /tmp/_synth.ys
	@echo "synth -top tt_um_fidel_makatia_4bit_cpu -flatten" >> /tmp/_synth.ys
	@echo "dfflibmap -liberty $(IHP_LIB)" >> /tmp/_synth.ys
	@echo "abc -liberty $(IHP_LIB)" >> /tmp/_synth.ys
	@echo "opt_clean -purge" >> /tmp/_synth.ys
	@echo "tee -o outputs/synth_stats.txt stat -liberty $(IHP_LIB)" >> /tmp/_synth.ys
	@echo "tee -o outputs/synth_check.txt check" >> /tmp/_synth.ys
	@echo "write_verilog -noattr outputs/synth_netlist.v" >> /tmp/_synth.ys
	$(YOSYS) -s /tmp/_synth.ys
	@echo ""
	@echo "Stats: outputs/synth_stats.txt"
	@echo "Netlist: outputs/synth_netlist.v"
	@echo ""

test_gl: synth
	@echo "========== Gate-Level Simulation (IHP SG13G2) =========="
	$(IVERILOG) -o test/tb_gl.out -g2012 test/sg13g2_functional.v outputs/synth_netlist.v $(TB)
	$(VVP) test/tb_gl.out
	@echo ""

wave: test
	$(GTKWAVE) tb.vcd &

clean:
	rm -f test/tb.out test/tb_gl.out tb.vcd
	rm -f outputs/synth_stats.txt outputs/synth_check.txt outputs/synth_netlist.v
	rm -f /tmp/_synth.ys

help:
	@echo "Nibble 4-bit CPU"
	@echo ""
	@echo "  make test      - RTL simulation (requires iverilog)"
	@echo "  make synth     - Synthesize to IHP SG13G2 (requires yosys + IHP PDK)"
	@echo "  make test_gl   - Gate-level simulation (requires iverilog + IHP PDK)"
	@echo "  make wave      - Open waveform viewer (requires gtkwave)"
	@echo "  make clean     - Remove generated files"
	@echo ""
	@echo "  Set IHP_PDK to your IHP-Open-PDK clone path (default: ~/IHP-Open-PDK)"
