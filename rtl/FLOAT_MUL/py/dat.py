# Author: Jesse
import random

def generate_large_floats(n, low_exp=-100, high_exp=100):
    floats = []
    for _ in range(n):
        base = random.uniform(1.0, 10.0)
        exp = random.randint(low_exp, high_exp)
        sign = random.choice([-1, 1])
        val = sign * base * (10 ** exp)
        floats.append(val)
    return floats

def write_float_file(filename, data):
    with open(filename, 'w') as f:
        for num in data:
            f.write(f"{num:.17e}\n")  # 保留高精度，避免誤差

# 產生資料
N = 1000
num1_data = generate_large_floats(N, -100, 100)
num2_data = generate_large_floats(N, -100, 100)

# 寫入檔案
write_float_file("num1.dat", num1_data)
write_float_file("num2.dat", num2_data)

print("✅ 已寫入 num1.dat 和 num2.dat，含 %d 筆範圍大的 double 精度浮點數"% N)
