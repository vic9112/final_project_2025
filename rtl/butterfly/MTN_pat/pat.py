import struct
import random
       
##########################################################################
#                       16 bit Integer mul pattern                       #
##########################################################################
int_pattern_num = 1600
Q = 12289
Q_INV = 12287       # -Q^{-1} mod 2^16
one = 1
R2 = 10952
with open("mtn_ai.dat", "w") as int_ai, \
     open("mtn_bi.dat", "w") as int_bi, \
     open("mtn_gm.dat", "w") as int_gm, \
     open("mtn_ao.dat", "w") as int_ao, \
     open("mtn_bo.dat", "w") as int_bo, \
     open("mtn_ai_check.dat", "w") as int_ai_check, \
     open("mtn_bi_check.dat", "w") as int_bi_check, \
     open("mtn_gm_check.dat", "w") as int_gm_check, \
     open("mtn_ao_check.dat", "w") as int_ao_check, \
     open("mtn_bo_check.dat", "w") as int_bo_check:
     
    ...

    chunk_ai = chunk_bi = chunk_gm = chunk_ao = chunk_bo = 0   # 暫存 128-bit
    idx_in_chunk = 0                  # 0‥7
    line_cnt = 0
    for i in range(int_pattern_num):
        ai  = random.randint(0, Q)  # 16-bit ai
        bi  = one                   # 16-bit bi
        gm  = random.randint(0, Q)  # 16-bit gm
        tmp = ((gm * bi * Q_INV & 0x0000FFFF) * Q + gm * bi) >> 16
        tmp -= Q
        if (tmp < 0):
            tmp += Q
        
        result1 = tmp
        result2 = tmp
        int_ai_check.write(f"{ai}\n")
        int_bi_check.write(f"{bi}\n")
        int_gm_check.write(f"{gm}\n")
        int_ao_check.write(f"{result1}\n")
        int_bo_check.write(f"{result2}\n")

        shift = idx_in_chunk * 16
        chunk_ai |= ai << shift
        chunk_bi |= bi << shift
        chunk_gm |= gm << shift
        chunk_ao |= result1 << shift
        chunk_bo |= result2 << shift
        idx_in_chunk += 1
   
        if idx_in_chunk == 8:         # 滿 8 筆 → 輸出一行
            int_ai.write(f"{chunk_ai:032X}\n")
            int_bi.write(f"{chunk_bi:032X}\n")
            int_gm.write(f"{chunk_gm:032X}\n")
            int_ao.write(f"{chunk_ao:032X}\n")
            int_bo.write(f"{chunk_bo:032X}\n")
            chunk_ai = chunk_bi = chunk_gm = chunk_ao = chunk_bo = 0
            idx_in_chunk = 0
            line_cnt += 1
    

    int_pattern_num = int_pattern_num / 8
    print(f"{int_pattern_num} of int mul pattern generated !")