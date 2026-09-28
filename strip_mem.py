with open('build/soc_top_logic_only.v', 'r') as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    # Detect the start of a memory instantiation
    if 'imem' in line and 'u_core.u_imem' in line:
        skip = True
        continue
    if 'dmem' in line and 'u_core.u_dmem' in line:
        skip = True
        continue
        
    # If we are inside an instantiation, skip until we see the closing ");"
    if skip:
        if ');' in line:
            skip = False
        continue
        
    # Skip defparams for the memories
    if 'defparam' in line and ('u_imem' in line or 'u_dmem' in line):
        continue
        
    out.append(line)

with open('build/soc_top_logic_only.v', 'w') as f:
    f.writelines(out)
print("Memory instantiations stripped successfully.")
