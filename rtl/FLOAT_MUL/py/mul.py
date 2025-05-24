# Author: Jesse
import struct

def float_to_uint64(x):
    return struct.unpack('>Q', struct.pack('>d', x))[0]

def read_input_file(filename):
    with open(filename, 'r') as f:
        return [float(line.strip()) for line in f]

def write_golden_file(filename, list1, list2, results):
    with open(filename, 'w') as f:
        for a, b, r in zip(list1, list2, results):
            a_hex = float_to_uint64(a)
            b_hex = float_to_uint64(b)
            r_hex = float_to_uint64(r)
            f.write(f"{a_hex:016X} {b_hex:016X} {r_hex:016X}\n")

def main():
    num1 = read_input_file('num1.dat')
    num2 = read_input_file('num2.dat')
    assert len(num1) == len(num2), "num1.dat and num2.dat length mismatch"

    results = [a * b for a, b in zip(num1, num2)]
    write_golden_file('golden.dat', num1, num2, results)
    print("✅ 已產生 golden.dat，包含 num1/num2/result 的 IEEE754 bit 表示")

if __name__ == "__main__":
    main()
