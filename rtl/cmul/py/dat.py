# Author: Jesse (text float format version for complex input)
import random

def generate_large_floats(n, low_exp=-10, high_exp=10):
    floats = []
    for _ in range(n):
        base = random.uniform(1.0, 10.0)
        exp = random.randint(low_exp, high_exp)
        sign = random.choice([-1, 1])
        val = sign * base * (10 ** exp)
        floats.append(val)
    return floats

def write_complex_float_file(filename, real_list, imag_list):
    assert len(real_list) == len(imag_list)
    with open(filename, 'w') as f:
        for r, i in zip(real_list, imag_list):
            f.write(f"{r:.16e} {i:.16e}\n")  # 兩個浮點數空格分隔

# 產生 200 筆 complex number（每個包含 2 個浮點數）
N = 1000
Xr_list = generate_large_floats(N)
Xi_list = generate_large_floats(N)
Yr_list = generate_large_floats(N)
Yi_list = generate_large_floats(N)

# 寫入 num1.dat（Xr Xi）與 num2.dat（Yr Yi）
write_complex_float_file("num1.dat", Xr_list, Xi_list)
write_complex_float_file("num2.dat", Yr_list, Yi_list)

print("✅ 已寫入 %d 筆num1.dat 和 num2.dat，格式為每行 2 個浮點數（Xr Xi / Yr Yi）"% N)
