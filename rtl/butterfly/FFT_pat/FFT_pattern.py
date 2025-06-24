import struct
import random

def bits_to_float(b):
    return struct.unpack(">d", struct.pack(">Q", b))[0]

def float_to_bits(f):
    bits = struct.unpack(">Q", struct.pack(">d", f))[0]
    return f'{bits:064b}'

def encode_IEEE754 (s , e , m ):
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

def round_to_nearest_even_with_sticky(m, lsb_position): #in hardware LSB is at [52]
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
            return m_funct  , e_funct
        else :
            m_funct <<= 1
            e_funct -= 1 
    return m_funct, e_funct



def normalize_fmul1(m, e , position_move):
    m_funct = m
    e_funct = e
    if m_funct >= (1 << (53 + position_move)):
        m_funct >>= 1
        e_funct += 1 
    while m_funct and (m_funct < (1 << (52 + position_move))):
        m_funct <<= 1
        e_funct -= 1
    return m_funct, e_funct

def normalize_fmul2(m, e ):
    while m >= (1 << (53)):
        m >>= 1
        e += 1
    while m and m < (1 << (52)):
        m <<= 1
        e -= 1
    return m, e

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
    #               Subnormal                 #
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
    #subnormal case ( bias of exp == 0 is 1022 )
    if ea == 0 and ma != 0 :
        ea = ea - 1022
    else : 
        ea = ea -1023
    
    if eb == 0 and mb != 0 :
        eb = eb -1022
    else : 
        eb = eb - 1023
    
    ##########################################
    #               Normal                   #
    ##########################################
    result_m = ma * mb
    if sa == sb :
        result_s = 0
    else :
        result_s = 1
        
    mul_e = ea + eb 
    mul_e = mul_e + 1 # folllow hardware's rounder
    result_m, result_e = normalize_fmul1(result_m, mul_e , position_move=53)
    result_m = round_to_nearest_even_with_sticky(result_m , lsb_position=53)
    # after first time rounding , the floating point locate between bit[52:51]
    if result_m != 0 :
        result_m_final , result_e_final = normalize_fmul1(result_m , result_e , position_move = 0 )
    else :
        result_m_final = 0
        result_e_final = -5000
    # denormal (infinite num 、 zero num)
    exp_less = 0
    if result_e_final < -1022 :
        exp_less = -1022 - result_e_final
        result_e_final = -1023
        result_m_final >>= (exp_less)
    
    result_e_final = result_e_final + 1023
    
    if result_e_final == 2047 or result_e_final > 2047 :
        result_m_final = 0
        result_e_final = 2047
    
    return result_s , result_e_final , result_m_final
    # Zero case or inf case               
    # if result_e_final >= 2047 :
    #     return result_s , 2047 , 0
    # elif result_e_final < 0 :
    #     return 0 , 0 , 0
    # elif result_e_final == 0 and result_m_final == 0 :
    #     return 0 , 0 , 0
    # elif result_e_final == 0 and result_m_final != 0 :
    #     return result_s , result_e_final , (result_m_final >> 1 ) 
    # else :
    #     return result_s, result_e_final, result_m_final


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
    # while subnormal case , bias must be  1022 , so we shift 1 bits of mantissa to modify
    if ea_funct == 0 :
        ma_funct <<= 1
    if eb_funct == 0 :
        mb_funct <<= 1
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
    # modify subnormal case while exp == 0 , bias must become 1022 , so we shift mantissa 1 bit
    elif result_e_final == 0 and result_m_final != 0 :
        return result_s , result_e_final , (result_m_final >> 1)
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

#########################################################################################################
#                               Generate pattern and  write into .txt                                   #
#########################################################################################################

pattern_num = 200
with open("a_in.dat", "w") as ain, open("b_in.dat", "w") as bii , open("g_in.dat", "w") as gin, open("golden_a.dat", "w") as aout , open("golden_b.dat", "w") as bout ,open("a_float.dat", "w") as ai_fp, open("b_float.dat", "w") as bi_fp, open("golden_float.dat", "w") as gi_fp , open("golden_a_float.dat", "w") as aout_fp , open("golden_b_float.dat", "w") as bout_fp:

    for i in range(pattern_num):
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

        ###############################
        #   Generate complex num g    #
        ###############################
        g0_sign = generate_random_sign()
        g1_sign = generate_random_sign()

        g0_exp =  generate_random_exp()
        g1_exp = generate_random_exp()
        
        g0_frac = generate_random_mantissa()
        g1_frac = generate_random_mantissa()

        g0_val = assemble_float(g0_sign, g0_exp, g0_frac) # a0 = real part of com_A 
        g1_val = assemble_float(g1_sign, g1_exp, g1_frac) # b0 = img  part of com_A

        g0_bits = float_to_bits(g0_val)  # bit form of real part g(twiddle factor)
        g1_bits = float_to_bits(g1_val)  # bit form of img  part g(twiddle factor) 
        
        
        g_re   = int(g0_bits, 2) << 64  
        g_im   = int(g1_bits, 2)
        
        COM_G_bits  = g_re | g_im  

        ###################################################
        #      write hex type of IEEE754 for testbench    #
        ###################################################
        ain.write(f"{COM_A_bits:032X}\n")
        bii.write(f"{COM_B_bits:032X}\n")
        gin.write(f"{COM_G_bits:032X}\n")
        ##############################################
        #       wirte visible type for debugging     #
        ##############################################
        ai_fp.write(f"{a0_val:.16e}   +  j * {b0_val:.16e}\n")
        bi_fp.write(f"{a1_val:.16e}   +  j * {b1_val:.16e}\n")
        gi_fp.write(f"{g0_val:.16e}   +  j * {g1_val:.16e}\n")
        
        sa_re , ea_re , ma_re = extract_components(int(a0_bits, 2))
        sa_im , ea_im , ma_im = extract_components(int(b0_bits, 2))
        sb_re , eb_re , mb_re = extract_components(int(a1_bits, 2))
        sb_im , eb_im , mb_im = extract_components(int(b1_bits, 2))
        
        sg_re , eg_re , mg_re = extract_components(int(g0_bits, 2))
        sg_im , eg_im , mg_im = extract_components(int(g1_bits, 2))
        
        #do the mul of b*g    
        s_bg_re , e_bg_re , m_bg_re , s_bg_im ,e_bg_im , m_bg_im = fp64_cmul (mb_re , eb_re , sb_re , mb_im , eb_im , sb_im , mg_re , eg_re , sg_re  , mg_im , eg_im , sg_im )

        if(s_bg_re == 1) :
            s_bg_re_neg = 0
        else:
            s_bg_re_neg = 1
            
        if(s_bg_im == 1) :
            s_bg_im_neg = 0
        else:
            s_bg_im_neg = 1
                        
        s_num_a_re , e_num_a_re , m_num_a_re = fp64_add(ma_re, m_bg_re, ea_re, e_bg_re , sa_re , s_bg_re)      # re part of a+b*g
        s_num_a_im , e_num_a_im , m_num_a_im = fp64_add(ma_im, m_bg_im, ea_im, e_bg_im , sa_im , s_bg_im )     # im part of a+b*g
        
        s_num_b_re , e_num_b_re , m_num_b_re = fp64_add(ma_re, m_bg_re, ea_re, e_bg_re , sa_re , s_bg_re_neg)      # re part of a-b*g
        s_num_b_im , e_num_b_im , m_num_b_im = fp64_add(ma_im, m_bg_im, ea_im, e_bg_im , sa_im , s_bg_im_neg )     # im part of a-b*g
        
        
        a_re_result_bits = encode_IEEE754 (s_num_a_re , e_num_a_re , m_num_a_re )
        a_im_result_bits = encode_IEEE754 (s_num_a_im , e_num_a_im , m_num_a_im )
        
        b_re_result_bits = encode_IEEE754 (s_num_b_re , e_num_b_re , m_num_b_re )
        b_im_result_bits = encode_IEEE754 (s_num_b_im , e_num_b_im , m_num_b_im )
        
        
        a_result_re   = (a_re_result_bits) << 64 
        a_result_im   = (a_im_result_bits)

        b_result_re   = (b_re_result_bits) << 64 
        b_result_im   = (b_im_result_bits)

        a_result_re_val = bits_to_float(a_re_result_bits)
        a_result_im_val = bits_to_float(a_im_result_bits)
      
        b_result_re_val = bits_to_float(b_re_result_bits)
        b_result_im_val = bits_to_float(b_im_result_bits)  
    
        ###################################################################
        #       Write floating point format of result a  for debugging    #
        ###################################################################   
        if e_num_a_re == 2047 and m_num_a_re != 0 :
            if(e_num_a_im == 2047 and m_num_a_im != 0):    
                aout_fp.write(f"NaN  +  j *  NaN \n")
            else :
                aout_fp.write(f"NaN  +  j * {a_result_im_val:.16e} \n")
        elif e_num_a_im == 2047 and m_num_a_im != 0 :   
            aout_fp.write(f"{a_result_re_val:.16e}  +  j * NaN \n")
        else :       
            aout_fp.write(f"{a_result_re_val:.16e}  +  j * {a_result_im_val:.16e} \n")
            
        ##################################################################
        #       Write floating point format of result b  for debugging   #
        ##################################################################    
        if e_num_b_re == 2047 and m_num_b_re != 0 :
            if(e_num_b_im == 2047 and m_num_b_im != 0):    
                bout_fp.write(f"NaN  +  j *  NaN \n")
            else :
                bout_fp.write(f"NaN  +  j * {b_result_im_val:.16e} \n")
        elif e_num_b_im == 2047 and m_num_b_im != 0 :   
            bout_fp.write(f"{b_result_re_val:.16e}  +  j * NaN \n")
        else :       
            bout_fp.write(f"{b_result_re_val:.16e}  +  j * {b_result_im_val:.16e} \n")
        #################################################################
        #       Write IEEE754  format of result a 、 b for testbench    #
        #################################################################          
        COM_A_result_bits  = a_result_re | a_result_im
        COM_B_result_bits  = b_result_re | b_result_im
        
        aout.write(f"{COM_A_result_bits:032X}\n")
        bout.write(f"{COM_B_result_bits:032X}\n")

print (f"{pattern_num} of FFT pattern generated !")