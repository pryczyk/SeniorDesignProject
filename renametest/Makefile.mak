VCS = SW_VCS=2013.06-sp1 vcs -sverilog +vc -Mupdate -line -full64
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

all:    simv
	./simv | tee program.out

##### 
# Modify starting here
#####

TESTBENCH = sys_defs.vh testbench/rename_test.v
SIMFILES = verilog/rrat.v verilog/prf.v verilog/rat.v

synth/rat.vg:    $(SIMFILES) synth/rat.tcl
	cd synth && dc_shell-t -f ./rat.tcl | tee synth.out 

synth/rrat.vg:    $(SIMFILES) synth/rrat.tcl
	cd synth && dc_shell-t -f ./rrat.tcl | tee synth.out 
	
synth/prf.vg:    $(SIMFILES) synth/prf.tcl
	cd synth && dc_shell-t -f ./prf.tcl | tee synth.out 

SYNFILES = synth/rat.vg synth/rrat.vg synth/prf.vg
#####
# Should be no need to modify after here
#####
simv:	$(SIMFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SIMFILES)	-o simv

dve:	$(SIMFILES) $(TESTBENCH) 
	$(VCS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve -R -gui

.PHONY: dve

syn_simv:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv

syn_dve:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) -o dve -R -gui

syn:	syn_simv
	./syn_simv | tee syn_program.out

clean:
	rm -rvf simv *.daidir csrc vcs.key program.out \
	  syn_simv syn_simv.daidir syn_program.out \
          dve *.vpd *.vcd *.dump ucli.key 

nuke:	clean
	rm -rvf *.vg *.rep *.db *.chk *.log *.out DVEfiles/
	
