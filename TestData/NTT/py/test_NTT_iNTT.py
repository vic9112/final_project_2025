import random
from ntt import ntt, intt
from ntt_constants import roots_dict_Zq, inv_mod_q
from common import q

# Parameters
n = 1024  # NTT size

# Generate random input data
input_poly = [random.randint(0, q-1) for _ in range(n)]

# Compute NTT and inverse NTT
ntt_out = ntt(input_poly)
intt_out = intt(ntt_out)

# Save polynomial data as hex, 8 per line, space-separated
def save_hex(filename, data, num_per_line=1):
    with open(filename, "w") as f:
        for x in data:
            f.write(f"{x:04x}\n")

save_hex("test_input.hex", input_poly)
save_hex("test_ntt.hex", ntt_out)
save_hex("test_intt.hex", intt_out)

# Extract and save all NTT/iNTT twiddle factors
ntt_twiddles = roots_dict_Zq[n]
intt_twiddles = [inv_mod_q[w] for w in ntt_twiddles]
save_hex("twiddle_ntt.hex", ntt_twiddles)
save_hex("twiddle_intt.hex", intt_twiddles)

# Extract and save first 512 twiddle factors for both NTT and iNTT
ntt_twiddles_512 = ntt_twiddles[:512]
intt_twiddles_512 = intt_twiddles[:512]
save_hex("twiddle_ntt_first512.hex", ntt_twiddles_512)
save_hex("twiddle_intt_first512.hex", intt_twiddles_512)

# Confirm correctness
if all((a - b) % q == 0 for a, b in zip(input_poly, intt_out)):
    print("NTT/iNTT test passed: iNTT(NTT(input)) == input")
else:
    print("NTT/iNTT test FAILED!")

print("Files generated:")
print("  test_input.hex               (input polynomial, hex)")
print("  test_ntt.hex                 (NTT output, hex)")
print("  test_intt.hex                (iNTT output, hex, should match input)")
print("  twiddle_ntt.hex              (NTT twiddles, hex)")
print("  twiddle_intt.hex             (iNTT twiddles, hex)")
print("  twiddle_ntt_first512.hex     (first 512 NTT twiddles, hex)")
print("  twiddle_intt_first512.hex    (first 512 iNTT twiddles, hex)")