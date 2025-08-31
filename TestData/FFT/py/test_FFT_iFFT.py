# include input random and create output

import struct
import random
from fft import fft          # 你的 FFT 實作
from fft import ifft  # 你的 IFFT 實作

# ===== 工具函式 =====
def float_to_hex(f):
    return struct.pack(">d", f).hex().upper()

def complex_to_hex128(c):
    """將複數轉換為兩個 IEEE 754 64-bit HEX 字串（實部 + 虛部）"""
    real_hex = float_to_hex(c.real)
    imag_hex = float_to_hex(c.imag)
    return real_hex + imag_hex  # 共 128 bits (16 hex bytes)

# ===== 設定 =====
N = 512  # 複數筆數
INPUT_DEC_FILE = "fft_input_complex_dec.txt"
INPUT_HEX_FILE = "FFT_in.hex"
INPUT_DEC_FILE_IFFT = "ifft_input_complex_dec.txt"
INPUT_HEX_FILE_IFFT = "iFFT_in.hex"
OUTPUT_DEC_FILE = "fft_output_complex_dec.txt"
OUTPUT_HEX_FILE = "FFT_out.hex"
OUTPUT_DEC_FILE_IFFT = "ifft_output_complex_dec.txt"
OUTPUT_HEX_FILE_IFFT = "iFFT_out.hex"

# ===== 產生隨機複數輸入 =====
data = [complex(random.uniform(-10, 10), 0.0) for _ in range(N)]

# ===== 輸出原始輸入（十進位與128-bit HEX）=====
with open(INPUT_DEC_FILE, "w") as f_dec, open(INPUT_HEX_FILE, "w") as f_hex:
    for c in data:
        f_dec.write(f"{c.real:.17e}, {c.imag:.17e}\n")
        f_hex.write(complex_to_hex128(c) + "\n")
        
# ===== 輸出原始輸入（十進位與128-bit HEX）=====
with open(INPUT_DEC_FILE_IFFT, "w") as f_dec, open(INPUT_HEX_FILE_IFFT, "w") as f_hex:
    for c in data:
        f_dec.write(f"{c.real:.17e}, {c.imag:.17e}\n")
        f_hex.write(complex_to_hex128(c) + "\n")

# ===== 執行 FFT =====
data_fft = fft(data)
# ===== 執行 iFFT =====
data_ifft = ifft(data)

# ===== 輸出 FFT 結果（十進位與128-bit HEX）=====
with open(OUTPUT_DEC_FILE, "w") as f_dec, open(OUTPUT_HEX_FILE, "w") as f_hex:
    for c in data_fft:
        f_dec.write(f"{c.real:.17e}, {c.imag:.17e}\n")
        f_hex.write(complex_to_hex128(c) + "\n")

# ===== 輸出 iFFT 結果（十進位與128-bit HEX）=====
with open(OUTPUT_DEC_FILE_IFFT, "w") as f_dec, open(OUTPUT_HEX_FILE_IFFT, "w") as f_hex:
    for c in data_ifft:
        f_dec.write(f"{c.real:.17e}, {c.imag:.17e}\n")
        f_hex.write(complex_to_hex128(c) + "\n")

