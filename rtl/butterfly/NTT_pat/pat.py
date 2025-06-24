import struct
import random

def bits_to_float(b):
    return struct.unpack(">d", struct.pack(">Q", b))[0]

def float_to_bits(f):
    bits = struct.unpack(">Q", struct.pack(">d", f))[0]
    return f'{bits:064b}'

def encode_IEEE754 (s , e , m ):# sign, exponent, mantissa
    m_funct = m & ( (1<<52) -1 )
    bits = (s << 63) | (e << 52) | m_funct 
    return bits

def assemble_float(sign, exponent, mantissa):
    s_funct = sign
    e_funct = exponent
    m_funct = mantissa
    
    if e_funct >= 2047:
        e_funct = 2047
        m_funct = 0
    elif e_funct < 0:
        e_funct = 0
        m_funct = 0
    else:
        m_funct &= ~(1 << 52)
    bits = (s_funct << 63) | (e_funct << 52) | m_funct
    return bits_to_float(bits)

def extract_components(bits):
    sign_funct = (bits >> 63) & 1
    exponent_funct = (bits >> 52) & 0x7FF
    mantissa_funct = bits & ((1 << 52) - 1)
    if exponent_funct != 0:
        mantissa_funct |= (1 << 52)  # hidden bit
    return sign_funct, exponent_funct, mantissa_funct

##########################################################################
#             Rounding 、 normalization 、 alignment                      #
##########################################################################

def round_to_nearest_even_with_sticky(m, lsb_position=52): #in hardware LSB is at [52]
    m_funct   = m
    guard     = (m_funct >> (lsb_position-1)) & 1
    round_bit = (m_funct >> (lsb_position-2)) & 1

    sticky_mask = (1 << (lsb_position - 2)) - 1
    sticky = (m_funct & sticky_mask) != 0
    lsb = (m_funct >> (lsb_position)) & 1
    # print("stick :",sticky)
    if guard and (round_bit or sticky or lsb):
        m_funct += (1 << (lsb_position))  # 往 lsb 進位
    return m_funct >> (lsb_position)  # 去除 GRS bits

def normalize(m, e , position_move):
    m_funct = m
    e_funct = e
    if m_funct ==0 :
        return 0 , 0
    while m_funct >= (1 << (53 + position_move)):
        m_funct >>= 1
        e_funct += 1
    while m_funct and (m_funct < (1 << (52 + position_move))):
        if e_funct == 0:
            return m_funct ,e_funct
        else :
            m_funct <<= 1
            e_funct -= 1 
    return m_funct, e_funct

def align_exponents(m1, e1, m2, e2,position_move):
    m1_funct = m1
    m2_funct = m2
    e1_funct = e1
    e2_funct = e2
    # we shift left 52bit before op in hardware
    if e1_funct > e2_funct:
        shift = e1_funct - e2_funct
        if shift >= (53 + position_move) :
            m2_funct =  0 
        else : m2_funct >>= shift
        return m1_funct, m2_funct, e1_funct
    else:
        shift = e2_funct - e1_funct
        if shift >= (53 + position_move) :
            m1_funct = 0 
        else : m1_funct >>= shift
        return m1_funct, m2_funct, e2_funct

####################################################################
#                   mul 、 add operation (fp)                       #
####################################################################
def fp64_mul(ma, mb, ea, eb, sa, sb):
    ###########################################
    #               Denormal                  #
    ###########################################    
    # NaN case
    if ea == 2047 and  ( (ma & ((1<<52) -1)) != 0 ):
        return 0 , 2047 ,1
    if eb == 2047 and  ( (mb & ((1<<52) -1)) != 0 ):
        return 0 , 2047 ,1
    # zero case
    if ma == 0 and ea == 0 :
        return 0, 0, 0
    if mb == 0 and eb == 0 :
        return 0, 0, 0
    # inf case
    if ea == 2047 and ( (ma & ((1<<52) -1)) == 0 ):
        return sa^sb , 2047 ,0
    if eb == 2047 and ( (mb & ((1<<52) -1)) == 0 ):
        return sa^sb , 2047 ,0
    ##########################################
    #               Normal                   #
    ##########################################
    result_m = ma * mb
    if sa == sb :
        result_s = 0
    else :
        result_s = 1
    mul_e = ea + eb - 1023

    result_m, result_e = normalize(result_m, mul_e , position_move=52)

    result_m = round_to_nearest_even_with_sticky(result_m , lsb_position=52)
    result_m_final , result_e_final = normalize(result_m , result_e , position_move=0)
    # Zero case or inf case               
    if result_e_final >= 2047 :
        return result_s , 2047 , 0
    elif result_e_final < 0 :
        return 0 , 0 , 0

    elif result_e_final == 0 and result_m_final  == 0 :
        return 0 , 0 , 0
    else :
        return result_s, result_e_final, result_m_final


def fp64_add(ma, mb, ea, eb, sa, sb):
    ma_funct = ma
    mb_funct = mb
    
    ea_funct = ea
    eb_funct = eb
    
    sa_funct = sa
    sb_funct = sb
    ###########################################
    #               Denormal                  #
    ###########################################
    # NaN case
    if ea_funct == 2047 and ( (ma_funct & ((1<<52) -1)) != 0 ):
        return 0 , 2047 , 1
    if eb_funct == 2047 and ( (mb_funct & ((1<<52) -1)) != 0 ):
        return 0 , 2047 , 1
    # double inf case
    if ea_funct == 2047 and eb_funct == 2047:
        if(sa_funct != sb_funct):
            return 0 , 2047 , 1
        else :
            return sa_funct , 2047 , 0
    # single inf case
    if ea_funct == 2047 :
        return sa_funct , 2047 , 0
    if eb_funct == 2047 :
        return sb_funct , 2047 , 0
    ##########################################
    #               Normal                   #
    ##########################################
    ma_funct <<= 52
    mb_funct <<= 52
    ma_funct, mb_funct, e_funct = align_exponents(ma_funct, ea_funct, mb_funct, eb_funct , position_move=52)
    if sa_funct == sb_funct:
        result_m = ma_funct + mb_funct
        result_s = sa_funct
    else:
        if ma_funct >= mb_funct:
            result_m = ma_funct - mb_funct
            result_s = sa_funct
        else:
            result_m = mb_funct - ma_funct
            result_s = sb_funct
    
    result_m, result_e = normalize(result_m, e_funct , position_move=52)
    result_m = round_to_nearest_even_with_sticky(result_m , lsb_position=52)
    result_m_final , result_e_final = normalize(result_m , result_e , position_move=0)
    # Zero case or inf case  
    if result_e_final  >= 2047 :
        return result_s , 2047 , 0
    elif result_e_final < 0  :
        return 0 , 0 , 0
    elif result_e_final == 0 and result_m_final == 0 :
        return 0 , 0 , 0
    else :
        return result_s, result_e_final, result_m_final
    
def fp64_cmul (ma_re , ea_re , sa_re , ma_im , ea_im , sa_im , mb_re , eb_re , sb_re , mb_im , eb_im , sb_im ) :
    s_numa , e_numa , m_numa = fp64_add(mb_re, mb_im, eb_re, eb_im , sb_re, sb_im)       # numa = b_re + b_im
    s_numb , e_numb , m_numb = fp64_add(ma_re, ma_im, ea_re, ea_im , sa_re, (1 -sa_im) ) # numb =  a_re - a_im
    s_numc , e_numc , m_numc = fp64_add(mb_re, mb_im, eb_re, eb_im , sb_re, (1 -sb_im) ) # numc = b_re - b_im
    
    s_numd , e_numd , m_numd = fp64_mul(m_numa , ma_im , e_numa , ea_im , s_numa , sa_im) #numd = a_im *(b_re + b_im)
    s_nume , e_nume , m_nume = fp64_mul(m_numb , mb_im , e_numb , eb_im , s_numb , sb_im) #nume = b_im *(a_re - a_im)
    s_numf , e_numf , m_numf = fp64_mul(m_numc , ma_re , e_numc , ea_re , s_numc , sa_re) #numf = a_re *(b_re - b_im)

    s_im   , e_im    , m_im  = fp64_add(m_numd, m_nume, e_numd , e_nume , s_numd , s_nume) 
    s_re   , e_re    , m_re  = fp64_add(m_numf, m_nume, e_numf , e_nume , s_numf , s_nume)
    return  s_re   , e_re    , m_re , s_im   , e_im    , m_im  
    
    
##########################################################################
#               double precision complex mul pattern                     #
##########################################################################
def generate_random_sign():
    return random.randint(0, 1)

def generate_random_exp():
    return random.randint(0, 2047)  

def generate_random_mantissa():
    return random.randint(0, (1 << 52) - 1)

def ieee754_double_to_hex(sign, exponent, mantissa):
    bits = (sign << 63) | (exponent << 52) | mantissa
    return f"{bits:016X}"


with open("complex_A.dat", "w") as ca_in, open("complex_B.dat", "w") as cb_in , open("golden_complex.dat", "w") as cg_in , open("com_A_float.dat", "w") as fa_in, open("com_B_float.dat", "w") as fb_in , open("golden_com_float.dat", "w") as fg_in :
    for i in range(100):
        ###############################
        #   Generate complex num A    #
        ###############################
        a0_sign = generate_random_sign()
        b0_sign = generate_random_sign()

        a0_exp =  generate_random_exp()
        b0_exp = generate_random_exp()
        
        a0_frac = generate_random_mantissa()
        b0_frac = generate_random_mantissa()

        a0_val = assemble_float(a0_sign, a0_exp, a0_frac) # a0 = real part of com_A 
        b0_val = assemble_float(b0_sign, b0_exp, b0_frac) # b0 = img  part of com_A

        a0_bits = float_to_bits(a0_val)  # bit form of real part com_A
        b0_bits = float_to_bits(b0_val)  # bit form of img  part com_A  
        
        A_re   = int(a0_bits, 2) << 64  
        A_im   = int(b0_bits, 2)
        
        COM_A_bits  = A_re | A_im         
        ###############################
        #   Generate complex num B    #
        ###############################
        a1_sign = generate_random_sign()
        b1_sign = generate_random_sign()

        a1_exp =  generate_random_exp()
        b1_exp = generate_random_exp()
        
        a1_frac = generate_random_mantissa()
        b1_frac = generate_random_mantissa()

        a1_val = assemble_float(a1_sign, a1_exp, a1_frac)   # a1 = real part of com_B
        b1_val = assemble_float(b1_sign, b1_exp, b1_frac)   # b1 = img  part of com_B

        a1_bits = float_to_bits(a1_val) # bit form of real part com_B
        b1_bits = float_to_bits(b1_val) # bit form of img  part com_B

        B_re   = int(a1_bits, 2) << 64 
        B_im   = int(b1_bits, 2)

        COM_B_bits  = B_re | B_im 

        ###################################################
        #      write hex type of IEEE754 for testbench    #
        ###################################################
        ca_in.write(f"{COM_A_bits:032X}\n")
        cb_in.write(f"{COM_B_bits:032X}\n")

        ##############################################
        #       wirte visible type for debugging     #
        ##############################################
        fa_in.write(f"{a0_val:.16e}   +  j * {b0_val:.16e}\n")
        fb_in.write(f"{a1_val:.16e}   +  j * {b1_val:.16e}\n")
        sa_re , ea_re , ma_re = extract_components(int(a0_bits, 2))
        sa_im , ea_im , ma_im = extract_components(int(b0_bits, 2))
        sb_re , eb_re , mb_re = extract_components(int(a1_bits, 2))
        sb_im , eb_im , mb_im = extract_components(int(b1_bits, 2))
        sy_re , ey_re , my_re , sy_im ,ey_im , my_im = fp64_cmul (ma_re , ea_re , sa_re , ma_im , ea_im , sa_im , mb_re , eb_re , sb_re , mb_im , eb_im , sb_im )
        y_real_bits = encode_IEEE754 (sy_re , ey_re , my_re )
        y_img_bits  = encode_IEEE754 (sy_im , ey_im , my_im )
        Y_re   = (y_real_bits) << 64 
        Y_im   = (y_img_bits)

        Y_re_val = bits_to_float(y_real_bits)
        Y_im_val = bits_to_float(y_img_bits)
        if ey_re == 2047 and my_re != 0 :
            if(ey_im == 2047 and my_im != 0):    
                fg_in.write(f"NaN  +  j *  NaN \n")
            else :
                fg_in.write(f"NaN  +  j * {Y_im_val:.16e} \n")
        elif ey_im == 2047 and my_im != 0 :   
            fg_in.write(f"{Y_re_val:.16e}  +  j * NaN \n")
        else :       
            fg_in.write(f"{Y_re_val:.16e}  +  j * {Y_im_val:.16e} \n")
        COM_Y_bits  = Y_re | Y_im
        cg_in.write(f"{COM_Y_bits:032X}\n")

print ("complex mul pattern generated !")
       
##########################################################################
#                       16 bit Integer mul pattern                       #
##########################################################################
int_pattern_num = 1600
Q = 12289
Q_INV = 12287       # -Q^{-1} mod 2^16
with open("ntt_ai.dat", "w") as int_ai, \
     open("ntt_bi.dat", "w") as int_bi, \
     open("ntt_gm.dat", "w") as int_gm, \
     open("ntt_ao.dat", "w") as int_ao, \
     open("ntt_bo.dat", "w") as int_bo, \
     open("ntt_ai_check.dat", "w") as int_ai_check, \
     open("ntt_bi_check.dat", "w") as int_bi_check, \
     open("ntt_gm_check.dat", "w") as int_gm_check, \
     open("ntt_ao_check.dat", "w") as int_ao_check, \
     open("ntt_bo_check.dat", "w") as int_bo_check:
     
    ...

    chunk_ai = chunk_bi = chunk_gm = chunk_ao = chunk_bo = 0   # 暫存 128-bit
    idx_in_chunk = 0                  # 0‥7
    line_cnt = 0
    for i in range(int_pattern_num):
        ai  = random.randint(0, Q)  # 16-bit ai
        bi  = random.randint(0, Q)  # 16-bit bi
        gm  = random.randint(0, Q)  # 16-bit gm
        tmp = ((gm * bi * Q_INV & 0x0000FFFF) * Q + gm * bi) >> 16
        tmp -= Q
        if (tmp < 0):
            tmp += Q
        tmp1 = ai + tmp - Q
        tmp2 = ai - tmp
        if (tmp1 < 0):
            tmp1 += Q
        if (tmp2 < 0):
            tmp2 += Q
        
        result1 = tmp1
        result2 = tmp2
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