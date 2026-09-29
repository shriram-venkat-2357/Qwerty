V_DD = 1.80  # Volts
C_gate_avg = 0.5e-15  # 0.5 fF per gate (approximate for sky130_fd_sc_hd)
freq = 100e6  # 100 MHz

phases = [
    {"Phase": "IDLE", "Gates": 50000, "Alpha": 0.02},
    {"Phase": "WEIGHT_LOAD (LDW)", "Gates": 120000, "Alpha": 0.15},
    {"Phase": "ACT_LOAD (LDA)", "Gates": 120000, "Alpha": 0.15},
    {"Phase": "COMPUTE (RUN)", "Gates": 850000, "Alpha": 0.45},
    {"Phase": "READBACK (RD)", "Gates": 90000, "Alpha": 0.10}
]

print("="*75)
print("INDEPENDENT ½·C·V²·α ENERGY CROSS-CHECK (Member B)")
print(f"Technology: Sky130 HD | V_DD: {V_DD}V | Freq: {freq/1e6} MHz")
print("="*75)
print(f"{'Phase':<25} {'Est. Active Gates':<20} {'Activity (α)':<15} {'Energy/Cycle (pJ)'}")
print("-"*75)

for p in phases:
    C_total = p["Gates"] * C_gate_avg
    Energy_Joules = p["Alpha"] * C_total * (V_DD ** 2)
    Energy_pJ = Energy_Joules * 1e12
    print(f"{p['Phase']:<25} {p['Gates']:<20,} {p['Alpha']:<15} {Energy_pJ:.2f}")

print("="*75)
print("Note: Independent analytical estimate. Final signoff energy values")
print("will be correlated with Member C's OpenSTA SPEF extraction.")
print("="*75)
