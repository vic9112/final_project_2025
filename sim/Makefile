sim:
	@vcs -R +v2k -full64 \
	../tb/fiFFNTT_tb.v \
	../rtl/bram2048x32.v \
	../rtl/bram32.v \
	../rtl/fadd64.v \
	../rtl/fiFFNTT.v \
	../rtl/fmul64.v \
	../rtl/fsub64.v \
	../rtl/kernel.v \
	../rtl/kernel_FFT.v \
	../rtl/kernel_NTT.v \
	../rtl/kernel_merged.v \
	../rtl/kernel_top.v \
	../rtl/stage_top.v \
	../rtl/uadd16.v \
	../rtl/umul16.v \
	../rtl/usub16.v \
	../rtl/butterfly/hdl/wallace_131.v \
	../rtl/butterfly/hdl/sub_107.v \
	../rtl/butterfly/hdl/mul_64.v \
	../rtl/butterfly/hdl/mul_16.v \
	../rtl/butterfly/hdl/mul16_array_ntt.v \
	../rtl/butterfly/hdl/mul16_array.v \
	../rtl/butterfly/hdl/mul.v \
	../rtl/butterfly/hdl/mont_sub.v \
	../rtl/butterfly/hdl/mont_add.v \
	../rtl/butterfly/hdl/LOD_64.v \
	../rtl/butterfly/hdl/LOD_128.v \
	../rtl/butterfly/hdl/HA.v \
	../rtl/butterfly/hdl/fp_add.v \
	../rtl/butterfly/hdl/fmul_rounder.v \
	../rtl/butterfly/hdl/fmul_exp.v \
	../rtl/butterfly/hdl/FA.v \
	../rtl/butterfly/hdl/CLA_8.v \
	../rtl/butterfly/hdl/CLA33.v \
	../rtl/butterfly/hdl/CLA17.v \
	../rtl/butterfly/hdl/butterfly.v \
	../rtl/butterfly/hdl/add_54.v \
	../rtl/butterfly/hdl/add_53_overflow.v \
	../rtl/butterfly/hdl/add_53.v \
	../rtl/butterfly/hdl/add_13_overflow.v \
	../rtl/butterfly/hdl/add_11_overflow.v \
	../rtl/butterfly/hdl/add_107.v \
	../rtl/cmul/LOD.v \
	../rtl/cmul/fmul.v \
	../rtl/cmul/fadd.v \
	../rtl/cmul/cmul.v \
	../rtl/divN/hdl/mul_64.v \
	../rtl/divN/hdl/mul_16.v \
	../rtl/divN/hdl/mul16_array_intt.v \
	../rtl/divN/hdl/mul16_array.v \
	../rtl/divN/hdl/HA.v \
	../rtl/divN/hdl/FA.v \
	../rtl/divN/hdl/divN.v \
	../rtl/divN/hdl/CLA_8.v \
	../rtl/divN/hdl/CLA17.v \
	../rtl/divN/hdl/CLA33.v \
	-debug_acc +nospecify

clean:
	rm -rf ./csrc
	rm -rf simv*
	rm -rf ucli.key
	rm -rf *.vcd
