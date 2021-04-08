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

SOURCE := test_progs/rv32_copy.s

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

# Pipeline without fetch
PLTESTBENCH = testbench/pipeline_test.sv testbench/mt-fl_sim.cpp testbench/pipe_print.c testbench/mem.sv testbench/cache_simv.cpp
PLFILES = verilog/dispatch.sv verilog/issue.sv verilog/pipeline.sv verilog/complete_stage.sv verilog/re_stage.sv verilog/ps.sv verilog/fetch_stage.sv cache/cachemem.sv cache/icache.sv
PLSYNFILES = synth/pipeline.vg

# Reservation Station
RSTESTBENCH = testbench/rs_test.sv testbench/rs_print.c
RSFILES = verilog/rs.sv verilog/ps.sv
RSSYNFILES = synth/RS.vg

# Maptables
MTTESTBENCH = testbench/test_maptable.sv testbench/mt-fl_sim.cpp
MTFILES = verilog/map_tables.sv
MTSYNFILES = synth/map_table.vg

# ArchMaptables
ARCHMTTESTBENCH = testbench/test_maptable.sv
ARCHMTFILES = verilog/map_tables.sv
ARCHMTSYNFILES = synth/arch_maptable.vg

# dis
DTESTBENCH = testbench/dis_test.sv testbench/mt-fl_sim.cpp testbench/pipe_print.c 
DFILES = verilog/dispatch.sv verilog/issue.sv verilog/pipeline.sv 
DSYNFILES = synth/pipeline.vg

#issue_fifo
ISFIFOFILE = verilog/issue_fifo.sv
ISFIFOSYN = synth/fu_FIFO_3.vg

ROBSYNFILES = synth/ROB.vg
FREELISTSYNFILES = synth/Freelist.vg

ROBTESTBENCH = testbench/rob_test.sv
ROBFILES = verilog/rob.sv

FREELISTTESTBENCH = testbench/freelist_test.sv
FREELISTFILES = verilog/freelist.sv

PRFILES = verilog/physical_regfile.sv
PRSYNFILES = synth/physical_regfile.vg

# functional units
LOADFILES = verilog/fu_load.sv
# TODO: synfile missed

ALUFILES = verilog/fu_alu.sv
ALUSYNFILES = synth/fu_alu.vg

MULTFILES = verilog/fu_mult.sv
MULTSYNFILES = synth/fu_mult.vg
MULTTESTBENCH = testbench/mult_test.sv


# fetch stage
FSTESTBENCH = testbench/fetch_test.sv
FSFILES = verilog/pipeline_fetch.sv verilog/fetch_stage.sv cache/icache.sv cache/cachemem.sv

# retire stage
REFILES = verilog/re_stage.sv
RETESTBENCH = testbench/retire_test.sv
RESYNFILES = synth/retire_stage.vg

BRANCHFILES = verilog/branch_fu.sv
BRANCHTESTBENCH = testbench/branchfu_test.sv
BRANCHSYNFILES = synth/branch_stage.vg

# Load Store Queue
SQFILES = verilog/lsque.sv verilog/ps.sv
SQTESTBENCH = testbench/SQ_test.sv

LSFILES = $(SQFILES) verilog/fu_alu.sv verilog/fu_load.sv
LSTESTBENCH = testbench/ls_test.sv
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
export FSFILES
export REFILES
export PLFILES
export ARCHMTFILES
export PRFILES
# FUs
export ALUFILES
export MULTFILES
export BRANCHFILES


export CACHE_NAME = cache
export PIPELINE_NAME = pipeline
export RS_NAME = RS
export MAP_TABLE_NAME = map_table
export ARCH_MT_NAME = arch_maptable
export IS_FIFO_NAME = fu_FIFO_3
export FREELIST_NAME = Freelist
export ROB_NAME = ROB
export PR_NAME = physical_regfile
# FUs
export ALU_NAME = fu_alu
export MULT_NAME = fu_mult
export BRANCH_NAME = branch_stage

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
# pipeline(currently no fetch)
pipeline: pl_simv
	./pl_simv | tee pl_sim_program.out
pl_simv: $(HEADERS) $(PLFILES) $(RSFILES) $(MTFILES) $(ISFIFOFILE) $(FREELISTFILES) $(ROBFILES) $(PRFILES) $(ALUFILES) $(LSFILES) $(BRANCHFILES) $(MULTFILES) $(PLTESTBENCH)
	$(VCS) $^ -o pl_simv

# RS
rs: rs_simv
	./rs_simv | tee rs_sim_program.out
rs_simv: $(HEADERS) $(RSFILES) $(RSTESTBENCH)
	$(VCS) $^ -o rs_simv

# map_table:
mt: mt_simv
	./mt_simv | tee mt_sim_program.out
mt_simv: $(HEADERS) $(MTFILES) $(MTTESTBENCH)
	$(VCS) $^ -o mt_simv

# fetch stage:
fs: fs_simv
	./fs_simv | tee fs_sim_program.out
fs_simv: $(HEADERS) $(FSFILES) $(FSTESTBENCH)
	$(VCS) $^ -o fs_simv

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

pr_simv: $(HEADERS) $(PRFILES)
	$(VCS) $^ -o pr_simv

# retire_stage:
ret: ret_simv
	./ret_simv | tee ret_sim_program.out
ret_simv: $(HEADERS) $(REFILES) $(RETESTBENCH)
	$(VCS) $^ -o ret_simv

# branch_fu:
branch: branch_simv
	./branch_simv | tee branch_sim_program.out
branch_simv: $(HEADERS) $(BRANCHFILES) $(BRANCHTESTBENCH)
	$(VCS) $^ -o branch_simv

# multiply fu
mult: mult_simv
	./mult_simv | tee mult_sim_program.out
mult_simv: $(HEADERS) $(MULTFILES) $(MULTTESTBENCH)
	$(VCS) $^ -o mult_simv

# sq
sq: sq_simv
	./sq_simv | tee sq_sim_program.out
sq_simv: $(HEADERS) $(SQFILES) $(SQTESTBENCH)
	$(VCS) $^ -o sq_simv

#ls
ls: ls_simv
	./ls_simv | tee sq_sim_program.out
ls_simv: $(HEADERS) $(LSFILES) $(LSTESTBENCH)
	$(VCS) $^ -o ls_simv


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

$(ARCHMTSYNFILES): $(ARCHMTFILES) $(SYNTH_DIR)/archmaptables.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./archmaptables.tcl | tee archmaptable_synth.out

$(ROBSYNFILES): $(ROBFILES) $(SYNTH_DIR)/rob.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./rob.tcl | tee rob_synth.out

$(FREELISTSYNFILES): $(FREELISTFILES) $(SYNTH_DIR)/freelist.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./freelist.tcl | tee freelist_synth.out

$(ISFIFOSYN): $(ISFIFOFILE) $(SYNTH_DIR)/is_fifo.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./is_fifo.tcl | tee is_fifo_synth.out

$(PRSYNFILES): $(PRFILES) $(SYNTH_DIR)/pr.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./pr.tcl | tee pr_synth.out

# FUs
$(ALUSYNFILES): $(ALUFILES) $(SYNTH_DIR)/fu_alu.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./fu_alu.tcl | tee alu_synth.out
$(MULTSYNFILES): $(MULTFILES) $(SYNTH_DIR)/mult.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./mult.tcl | tee mult_synth.out

rs_syn:	rs_syn_simv 
	./rs_syn_simv | tee rs_syn_program.out

rs_syn_simv:	$(HEADERS) $(RSSYNFILES) $(RSTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o rs_syn_simv

mt_syn:	mt_syn_simv 
	./mt_syn_simv | tee mt_syn_program.out

mt_syn_simv:	$(HEADERS) $(MTSYNFILES) $(MTTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o mt_syn_simv


archmt_syn:	archmt_syn_simv 
	./archmt_syn_simv | tee archmt_syn_program.out

archmt_syn_simv:	$(HEADERS) $(ARCHMTSYNFILES) $(ARCHMTTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o archmt_syn_simv

rob_syn:	rob_syn_simv 
	./rob_syn_simv | tee rob_syn_program.out

rob_syn_simv:	$(HEADERS) $(ROBSYNFILES) $(ROBTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o rob_syn_simv

freelist_syn:	freelist_syn_simv 
	./freelist_syn_simv | tee freelist_syn_program.out

freelist_syn_simv:	$(HEADERS) $(FREELISTSYNFILES) $(FREELISTTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o freelist_syn_simv   

# dispatch pipeline test
# $(DSYNFILES):	$(RSSYNFILES) $(MTSYNFILES) $(ISFIFOSYN) $(FREELISTSYNFILES) $(ROBSYNFILES) $(DFILES) $(SYNTH_DIR)/dis.tcl  
# 	cd $(SYNTH_DIR) && dc_shell-t -f ./dis.tcl | tee dis_synth.out


dis_syn: dis_syn_simv
	./dis_syn_simv | tee dis_syn_program.out

dis_syn_simv: $(HEADERS) $(DSYNFILES) $(DTESTBENCH) 
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o dis_syn_simv 


$(RESYNFILES):	$(REFILES) $(SYNTH_DIR)/retire.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./retire.tcl | tee ret_synth.out

ret_syn: ret_syn_simv
	./ret_syn_simv | tee ret_syn_program.out

ret_syn_simv: $(HEADERS) $(RESYNFILES) $(RETESTBENCH) 
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o dis_syn_simv 

$(BRANCHSYNFILES):	$(BRANCHFILES) $(SYNTH_DIR)/branch.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./branch.tcl | tee branch_synth.out

branch_syn: $(BRANCHSYNFILES)

mult_syn: mult_syn_simv
	./mult_syn_simv | tee mult_syn_program.out
mult_syn_simv: $(HEADERS) $(MULTSYNFILES) $(MULTTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o mult_syn_simv
 

$(PLSYNFILES):	$(PLFILES) $(RSSYNFILES) $(MTSYNFILES) $(ARCHMTSYNFILES) $(ISFIFOSYN) $(FREELISTSYNFILES) $(ROBSYNFILES) $(PRSYNFILES) $(ALUSYNFILES) $(BRANCHSYNFILES) $(MULTSYNFILES) $(SYNTH_DIR)/pl.tcl 
	cd $(SYNTH_DIR) && dc_shell-t -f ./pl.tcl | tee pl_synth.out

pl_syn: pl_syn_simv
	./pl_syn_simv | tee pl_syn_program.out

pl_syn_simv: $(HEADERS) $(PLSYNFILES) $(PLTESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST +error+20 -o pl_syn_simv

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
	rm -f *.elf *.dump *.mem debug_bin *.out

nuke:	clean
	rm -rf synth/*.vg synth/*.rep synth/*.ddc synth/*.chk synth/*.log synth/*.syn
	rm -rf synth/*.out command.log synth/*.db synth/*.svf synth/*.mr synth/*.pvl
