sim:
	@vcs -R +v2k -full64 \
	../tb/fiFFNTT_tb.v \
	../rtl/bram2048x32.v \
	../rtl/fiFFNTT.v \
	../rtl/kernel_FFT.v \
	../rtl/kernel_NTT.v \
	../rtl/kernel_top.v \
	../rtl/stage_top.v \
  ../rtl/butterfly/hdl/add_107.v \
  ../rtl/butterfly/hdl/add_11_overflow.v \
  ../rtl/butterfly/hdl/add_12_overflow.v \
  ../rtl/butterfly/hdl/add_13_overflow.v \
  ../rtl/butterfly/hdl/add_53.v \
  ../rtl/butterfly/hdl/add_53_overflow.v \
  ../rtl/butterfly/hdl/add_58.v \
  ../rtl/butterfly/hdl/butterfly.v \
  ../rtl/butterfly/hdl/CLA17.v \
  ../rtl/butterfly/hdl/CLA33.v \
  ../rtl/butterfly/hdl/CLA_8.v \
  ../rtl/butterfly/hdl/fmul_exp.v \
  ../rtl/butterfly/hdl/fmul_rounder.v \
  ../rtl/butterfly/hdl/fp_add.v \
  ../rtl/butterfly/hdl/HA.v \
  ../rtl/butterfly/hdl/LOD_128.v \
  ../rtl/butterfly/hdl/LOD_64.v \
  ../rtl/butterfly/hdl/mont_add.v \
  ../rtl/butterfly/hdl/mont_sub.v \
  ../rtl/butterfly/hdl/mul.v \
  ../rtl/butterfly/hdl/mul16_array.v \
  ../rtl/butterfly/hdl/mul16_array_ntt.v \
  ../rtl/butterfly/hdl/mul_16.v \
  ../rtl/butterfly/hdl/mul_64.v \
  ../rtl/butterfly/hdl/sub_107.v \
  ../rtl/butterfly/hdl/sub_12.v \
  ../rtl/butterfly/hdl/sub_58.v \
  ../rtl/butterfly/hdl/wallace_131.v \
	../rtl/divN/hdl/mul16_array_intt.v \
	../rtl/divN/hdl/divN.v \
     ram_behav/bram512x128.v \
     ram_behav/bram64x128.v \
     ram_behav/bram32x128.v \
     ram_behav/bram128x128.v \
  ../tb/mailbox.v
	-debug_acc +nospecify

clean:
	rm -rf ./csrc
	rm -rf simv*
	rm -rf ucli.key
	rm -rf *.vcd

