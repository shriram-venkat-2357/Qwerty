import os
import glob, os, sys

matches = [os.environ.get('PDK_LIB', os.path.expanduser('~/pdk/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib'))]

lib_path = matches[0] if matches else ""
print(f"Found library: {lib_path}")

if not lib_path:
    print("ERROR: Library not found")
    sys.exit(1)

cell_areas = {}
curr = None
with open(lib_path, 'r') as f:
    for line in f:
        line_s = line.strip()
        if line_s.startswith("cell ("):
            curr = line_s.split("(")[1].split(")")[0].strip()
        elif "area :" in line_s and curr:
            try:
                cell_areas[curr] = float(line_s.split(":")[1].rstrip(";").strip())
            except ValueError:
                pass

stat_file = "build/g2_stat.txt"
total_area = 0.0
with open(stat_file, 'r') as f:
    text = f.read()

for line in text.splitlines():
    p = line.strip().split()
    if len(p) == 2 and p[0] in cell_areas:
        try:
            total_area += cell_areas[p[0]] * int(p[1])
        except ValueError:
            pass

print(f"\n==========================================")
print(f"Total Chip Area: {total_area:.2f} um^2")
print(f"Budget Cap:      180973.73 um^2")
if total_area <= 180973.73:
    print("STATUS: PASSED (Under budget - Lock in 128x32)")
else:
    print("STATUS: FAILED (Exceeds budget - Trigger 128x16 fallback)")
print(f"==========================================\n")
