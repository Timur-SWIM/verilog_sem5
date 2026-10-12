PROJECT = sem5_dclkfifo
TOP = tb_sem5_dclkfifo

RTL = $(wildcard rtl/*.v)
TB  = $(wildcard tb/*.v)

BUILD_DIR = build
SIM = $(BUILD_DIR)/sim
VCD = wave.vcd


.PHONY: all lint sim wave verilator clean


all: lint sim


lint:
	verilator --lint-only \
		-Wall \
		--language 1364-2005 \
		$(RTL)


sim:
	mkdir -p $(BUILD_DIR)
	iverilog \
		-g2005 \
		-o $(SIM) \
		$(RTL) $(TB)

	vvp $(SIM)


wave: sim
	gtkwave $(VCD)


verilator:
	verilator \
		--binary \
		--trace \
		--timing \
		--language 1364-2005 \
		$(RTL) $(TB) \
		--top-module $(TOP)

	./obj_dir/V$(TOP)


clean:
	rm -rf $(BUILD_DIR)
	rm -rf obj_dir
	rm -f $(VCD)
