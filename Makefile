# make          <- runs simv (after compiling simv if needed)
# make all      <- runs simv (after compiling simv if needed)
# make simv     <- compile simv if needed (but do not run)
# make syn      <- runs syn_simv (after synthesizing if needed then 
#                                 compiling synsimv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be 
# similar to the information in those scripts but that seems hard to avoid.
#
#

SOURCE = test_progs/addonly.s

CRT = crt.s
LINKERS = linker.lds
ASLINKERS = aslinker.lds

DEBUG_FLAG = -g
CFLAGS =  -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align -mno-div 
OFLAGS = -O0
ASFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS = -SD -M no-aliases 
OBJDFLAGS = -SD -M numeric,no-aliases

##########################################################################
# IF YOU AREN'T USING A CAEN MACHINE, CHANGE THIS TO FALSE OR OVERRIDE IT
CAEN = 1
##########################################################################
ifeq (1, $(CAEN))
	GCC = riscv gcc
	OBJDUMP = riscv objdump
	AS = riscv as
	ELF2HEX = riscv elf2hex
else
	GCC = riscv64-unknown-elf-gcc
	OBJDUMP = riscv64-unknown-elf-objdump
	AS = riscv64-unknown-elf-as
	ELF2HEX = elf2hex
endif


VCS = vcs -V -sverilog +vc -Mupdate -line -full64 +vcs+vcdpluson -debug_pp
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

# Reservation Station
RSTESTBENCH = testbench/rs_test.sv testbench/rs_print.c
RSFILES = verilog/rs.sv verilog/ps.sv
RSSYNFILES = synth/RS.vg

# Maptables
MTTESTBENCH = testbench/test_maptable.sv testbench/mt-fl_sim.cpp
MTFILES = verilog/map_tables.sv
MTSYNFILES = synth/map_table.vg

# dis
DTESTBENCH = testbench/dis_test.sv testbench/mt-fl_sim.cpp testbench/pipe_print.c 
DFILES = verilog/dispatch.sv verilog/issue.sv verilog/pipeline.sv 
DSYNFILES = synth/pipeline.vg

#issue_fifo
ISFIFOFILE = verilog/issue_fifo.sv
ISFIFOSYN = syn/fu_FIFO_3.vg

ROBSYNFILES = synth/ROB.vg
FREELISTSYNFILES = synth/Freelist.vg

ROBTESTBENCH = testbench/rob_test.sv
ROBFILES = verilog/rob.sv

FREELISTTESTBENCH = testbench/freelist_test.sv
FREELISTFILES = verilog/freelist.sv
# SIMULATION CONFIG

HEADERS     = $(wildcard *.svh)
# TESTBENCH   = $(wildcard testbench/*.sv)
# TESTBENCH  += $(wildcard testbench/*.c)
# PIPEFILES   = $(wildcard verilog/*.sv)
# CACHEFILES  = $(wildcard verilog/cache/*.sv)

SIMFILES    = $(PIPEFILES) $(CACHEFILES)

# SYNTHESIS CONFIG
SYNTH_DIR = ./synth

export HEADERS
export PIPEFILES
export CACHEFILES
export MTFILES
export RSFILES
export DFILES
export ISFIFOFILE


export CACHE_NAME = cache
export PIPELINE_NAME = pipeline
export RS_NAME = RS
export MAP_TABLE_NAME = map_table
export IS_FIFO_NAME = fu_FIFO_3

export RSFILES
export ROBFILES
export FREELISTFILES
PIPELINE  = $(SYNTH_DIR)/$(PIPELINE_NAME).vg 
SYNFILES  = $(PIPELINE) $(SYNTH_DIR)/$(PIPELINE_NAME)_svsim.sv
CACHE     = $(SYNTH_DIR)/$(CACHE_NAME).vg

# Passed through to .tcl scripts:
export CLOCK_NET_NAME = clock
export RESET_NET_NAME = reset
export CLOCK_PERIOD   = 10	# TODO: You will need to make match SYNTH_CLOCK_PERIOD in sys_defs
                                #       and make this more aggressive

################################################################################
## RULES
################################################################################

# Default target:
all:    simv
	./simv | tee program.out

.PHONY: all

# Simulation:
rs: rs_simv
	./rs_simv | tee rs_sim_program.out
rs_simv: $(HEADERS) $(RSFILES) $(RSTESTBENCH)
	$(VCS) $^ -o rs_simv

# map_table:
mt: mt_simv
	./rs_simv | tee rs_sim_program.out
mt_simv: $(HEADERS) $(MTFILES) $(MTTESTBENCH)
	$(VCS) $^ -o rs_simv


#dispatch
#dis-pipeline
dis: dis_simv
	./dis_simv | tee dis_sim_program.out
dis_simv: $(HEADERS) $(DFILES) $(RSFILES) $(MTFILES) $(ISFIFOFILE) $(DTESTBENCH)
	$(VCS) $^ -o dis_simv
rob: rob_simv
	./rob_simv | tee rob_sim_program.out
rob_simv: $(HEADERS) $(ROBFILES) $(ROBTESTBENCH)
	$(VCS) $^ -o rob_simv

freelist: freelist_simv
	./freelist_simv | tee freelist_sim_program.out
freelist_simv: $(HEADERS) $(FREELISTFILES) $(FREELISTTESTBENCH)
	$(VCS) $^ -o freelist_simv

sim:	simv
	./simv | tee sim_program.out

simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) $^ -o simv

.PHONY: sim

# Programs

compile: $(CRT) $(LINKERS)
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.elf
	$(GCC) $(CFLAGS) $(DEBUG_FLAG) $(CRT) $(SOURCE) -T $(LINKERS) -o program.debug.elf
assemble: $(ASLINKERS)
	$(GCC) $(ASFLAGS) $(SOURCE) -T $(ASLINKERS) -o program.elf 
	cp program.elf program.debug.elf
disassemble: program.debug.elf
	$(OBJDUMP) $(OBJFLAGS) program.debug.elf > program.dump
	$(OBJDUMP) $(OBJDFLAGS) program.debug.elf > program.debug.dump
	rm program.debug.elf
hex: program.elf
	$(ELF2HEX) 8 8192 program.elf > program.mem

program: compile disassemble hex
	@:

debug_program:
	gcc -lm -g -std=gnu11 -DDEBUG $(SOURCE) -o debug_bin
assembly: assemble disassemble hex
	@:


# Synthesis

# $(CACHE): $(CACHEFILES) $(SYNTH_DIR)/$(CACHE_NAME).tcl
# 	cd $(SYNTH_DIR) && dc_shell-t -f ./$(CACHE_NAME).tcl | tee $(CACHE_NAME)_synth.out

# $(PIPELINE): $(SIMFILES) $(CACHE) $(SYNTH_DIR)/$(PIPELINE_NAME).tcl
# 	cd $(SYNTH_DIR) && dc_shell-t -f ./$(PIPELINE_NAME).tcl | tee $(PIPELINE_NAME)_synth.out
# 	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(PIPELINE)

$(RSSYNFILES): $(RSFILES) $(SYNTH_DIR)/rs.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./rs.tcl | tee rs_synth.out

$(MTSYNFILES): $(MTFILES) $(SYNTH_DIR)/maptables.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./maptables.tcl | tee maptable_synth.out

$(ROBSYNFILES): $(ROBFILES) $(SYNTH_DIR)/rob.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./rob.tcl | tee rob_synth.out

$(FREELISTSYNFILES): $(FREELISTFILES) $(SYNTH_DIR)/freelist.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./freelist.tcl | tee freelist_synth.out

rs_syn:	rs_syn_simv 
	./rs_syn_simv | tee rs_syn_program.out

rs_syn_simv:	$(HEADERS) $(RSSYNFILES) $(RSTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o rs_syn_simv

mt_syn:	mt_syn_simv 
	./mt_syn_simv | tee mt_syn_program.out

mt_syn_simv:	$(HEADERS) $(MTSYNFILES) $(MTTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o mt_syn_simv

rob_syn:	rob_syn_simv 
	./rob_syn_simv | tee rob_syn_program.out

rob_syn_simv:	$(HEADERS) $(ROBSYNFILES) $(ROBTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o rob_syn_simv

freelist_syn:	freelist_syn_simv 
	./freelist_syn_simv | tee freelist_syn_program.out

freelist_syn_simv:	$(HEADERS) $(FREELISTSYNFILES) $(FREELISTTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o freelist_syn_simv   

# dispatch pipeline test
$(DSYNFILES): $(MTSYNFILES) $(RSSYNFILES) $(ISFIFOSYN) $(SYNTH_DIR)/dis.tcl $(DFILES) 
	cd $(SYNTH_DIR) && dc_shell-t -f ./dis.tcl | tee dis_synth.out

is_fifo_syn_simv: $(ISFIFOSYN)


$(ISFIFOSYN): $(ISFIFOFILE) $(SYNTH_DIR)/is_fifo.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./is_fifo.tcl | tee is_fifo_synth.out

dis_syn: dis_syn_simv
	./dis_syn_simv | tee dis_syn_program.out

dis_syn_simv: $(HEADERS) $(DSYNFILES) $(DTESTBENCH) 
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o dis_syn_simv 



syn:	syn_simv 
	./syn_simv | tee syn_program.out

syn_simv:	$(HEADERS) $(SYNFILES) $(TESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv 

.PHONY: syn

# Debugging

dve:	sim
	./simv -gui &

dve_syn: syn_sim 
	./syn_simv -gui &

.PHONY: dve dve_syn 

clean:
	rm -rf *simv *simv.daidir csrc vcs.key program.out *.key
	rm -rf vis_simv vis_simv.daidir
	rm -rf dve* inter.vpd DVEfiles
	rm -rf syn_simv syn_simv.daidir syn_program.out
	rm -rf synsimv synsimv.daidir csrc vcdplus.vpd vcs.key synprog.out pipeline.out writeback.out vc_hdrs.h
	rm -f *.elf *.dump *.mem debug_bin

nuke:	clean
	rm -rf synth/*.vg synth/*.rep synth/*.ddc synth/*.chk synth/*.log synth/*.syn
	rm -rf synth/*.out command.log synth/*.db synth/*.svf synth/*.mr synth/*.pvl
