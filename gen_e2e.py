def r(f7, rs2, rs1, f3, rd, op): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def i(imm, rs1, f3, rd, op): return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def s(imm, rs2, rs1, f3, op): return (((imm>>5)&0x7F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|op
def b(imm, rs2, rs1, f3, op):
    imm12 = (imm >> 12) & 1; imm11 = (imm >> 11) & 1
    imm10_5 = (imm >> 5) & 0x3F; imm4_1 = (imm >> 1) & 0xF
    return (imm12<<31)|(imm10_5<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(imm4_1<<8)|(imm11<<7)|op

ins = []
# 1. x1 = 0xFFFFFFFF (All-ones pattern for synthetic weights/acts)
ins.append(i(-1, 0, 0, 1, 0x13))

# 2. Stage 128 words of weights in DMEM at 0x000
for k in range(128): ins.append(s(k*4, 1, 0, 2, 0x23))

# 3. Stage 4 words of activations in DMEM at 0x200 (512)
for k in range(4): ins.append(s(512 + k*4, 1, 0, 2, 0x23))

# 4. Setup registers for accelerator
ins.append(i(512, 0, 0, 2, 0x13))   # x2 = 512 (act base)
ins.append(i(4, 0, 0, 3, 0x13))     # x3 = 4 (act word count)
ins.append(i(0, 0, 0, 4, 0x13))     # x4 = 0 (weight base)
ins.append(i(128, 0, 0, 5, 0x13))   # x5 = 128 (weight row count)

# 5. Accelerator Sequence
ins.append(r(0, 5, 4, 0, 0, 0x0B))  # nmc.ldw x0, x4, x5
ins.append(r(0, 3, 2, 1, 0, 0x0B))  # nmc.lda x0, x2, x3
ins.append(r(0, 0, 0, 2, 0, 0x0B))  # nmc.run

# 6. Poll Status CSR (0x7C0) for 'done' (bit 1)
poll_addr = len(ins)
ins.append(i(0x7C0, 0, 2, 6, 0x73)) # csrr x6, 0x7C0
ins.append(i(0x2, 6, 0, 7, 0x13))   # andi x7, x6, 2
ins.append(b(-8, 7, 0, 0, 0x63))    # beq x7, x0, poll_addr

# 7. Readback result into x8
ins.append(r(0, 0, 0, 3, 8, 0x0B))  # nmc.rd x8

# 8. ebreak (halt)
ins.append(i(0, 0, 0, 0, 0x73))

# Pad to 256 words
while len(ins) < 256: ins.append(0x00000013)

with open('tb/program_e2e.hex', 'w') as f:
    for w in ins: f.write(f"{w:08X}\n")

# Generate golden reference (128 rows of 1s -> pc=128, dot=128, acc=128)
with open('tb/golden_e2e.txt', 'w') as f:
    f.write("00000080\n") # 128 in hex

print("Generated tb/program_e2e.hex and tb/golden_e2e.txt")
