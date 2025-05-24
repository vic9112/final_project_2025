# Author: Jesse (generate golden.dat with full complex input/output hex)
import struct

def float_to_uint64(x):
    return struct.unpack('>Q', struct.pack('>d', x))[0]

def read_complex_file(filename):
    data = []
    with open(filename, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) != 2:
                continue
            real, imag = map(float, parts)
            data.append((real, imag))
    return data

def write_golden_file(filename, num1_list, num2_list, Zr_list, Zi_list):
    with open(filename, 'w') as f:
        for (Xr, Xi), (Yr, Yi), Zr, Zi in zip(num1_list, num2_list, Zr_list, Zi_list):
            f.write(
                f"{float_to_uint64(Xr):016X} "
                f"{float_to_uint64(Xi):016X} "
                f"{float_to_uint64(Yr):016X} "
                f"{float_to_uint64(Yi):016X} "
                f"{float_to_uint64(Zr):016X} "
                f"{float_to_uint64(Zi):016X}\n"
            )

def main():
    num1 = read_complex_file('num1.dat')  # Xr Xi
    num2 = read_complex_file('num2.dat')  # Yr Yi
    assert len(num1) == len(num2), "num1.dat and num2.dat length mismatch"

    Zr_list = []
    Zi_list = []
    for (Xr, Xi), (Yr, Yi) in zip(num1, num2):
        Zr = Xr * Yr - Xi * Yi
        Zi = Xr * Yi + Yr * Xi
        Zr_list.append(Zr)
        Zi_list.append(Zi)

    write_golden_file('golden.dat', num1, num2, Zr_list, Zi_list)
    print("✅ 已產生 golden.dat，排序為 Xr Xi Yr Yi Zr Zi（每個為 IEEE 754 64-bit）")

if __name__ == "__main__":
    main()
