# Nibble 4-bit CPU — Build & Test
#
#   make test      Run testbench (requires iverilog)
#   make wave      Open waveform in GTKWave
#   make clean     Remove generated files
#   make help      Show this help

IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave

SRC = src/cpu_core.v src/project.v
TB  = test/tb.v

.PHONY: test wave clean help

test:
	@echo "========== Nibble 4-bit CPU — Testbench =========="
	$(IVERILOG) -o test/tb.out -g2012 $(SRC) $(TB)
	$(VVP) test/tb.out
	@echo ""

wave: test
	$(GTKWAVE) tb.vcd &

clean:
	rm -f test/tb.out tb.vcd

help:
	@echo "Nibble 4-bit CPU"
	@echo ""
	@echo "  make test   - Run verification (requires iverilog)"
	@echo "  make wave   - Open waveform viewer (requires gtkwave)"
	@echo "  make clean  - Remove generated files"
