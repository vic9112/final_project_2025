import struct
import random

##########################################################################
#                       16 bit Integer mul pattern                       #
##########################################################################
int_pattern_num = 800
Q = 12289
Q_INV = 12287       # -Q^{-1} mod 2^16
N_INV = 12277
with  open("int_A.dat", "w") as int_A, open("int_B.dat", "w") as int_B ,open("golden_int.dat", "w") as int_g ,open("int_A_check.dat", "w") as int_A_check, open("int_B_check.dat", "w") as int_B_check ,open("golden_int_check.dat", "w") as int_g_check :
    chunk_A = chunk_B = chunk_G = 0   # 暫存 128-bit
    idx_in_chunk = 0                  # 0‥7
    line_cnt = 0
    for i in range(int_pattern_num):
        A = random.randint(0, Q)  # 16-bit A
        B = N_INV                     # 16-bit B
        tmp = ((A*B*Q_INV & 0x0000FFFF) * Q + A * B) >> 16
        tmp -= Q
        if (tmp < 0):
            tmp += Q
        
        result = tmp
        int_A_check.write(f"{A}\n")
        int_B_check.write(f"{B}\n")
        int_g_check.write(f"{result}\n")

        shift = idx_in_chunk * 16
        chunk_A |= A << shift
        chunk_B |= B << shift
        chunk_G |= result << shift
        idx_in_chunk += 1
   
        if idx_in_chunk == 8:         # 滿 8 筆 → 輸出一行
            int_A.write(f"{chunk_A:032X}\n")
            int_B.write(f"{chunk_B:032X}\n")
            int_g.write(f"{chunk_G:032X}\n")
            chunk_A = chunk_B = chunk_G = 0
            idx_in_chunk = 0
            line_cnt += 1
    

    int_pattern_num = int_pattern_num / 8
    print(f"{int_pattern_num} of int mul pattern generated !")