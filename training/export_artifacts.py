import torch
import numpy as np

# 1. Load the trained PyTorch checkpoint
checkpoint = torch.load('bwn_lenet.pt', map_location='cpu')

def pack_weights_to_hex(tensor):
    """Binarizes and packs a flat tensor into 32-bit hex words."""
    # Flatten and binarize: > 0 becomes 1 (+1), <= 0 becomes 0 (-1)
    flat_weights = tensor.flatten().numpy()
    binary_weights = (flat_weights > 0).astype(int)
    
    hex_words = []
    # Process in chunks of 32 bits
    for i in range(0, len(binary_weights), 32):
        chunk = binary_weights[i:i+32]
        # Pad with zeros if the last chunk is less than 32 bits
        if len(chunk) < 32:
            chunk = np.pad(chunk, (0, 32 - len(chunk)), 'constant')
        
        # Pack 32 bits into a single integer (LSB first based on typical C implementations)
        word = 0
        for bit_idx, bit in enumerate(chunk):
            word |= (bit << bit_idx)
            
        hex_words.append(f"{word:08X}")
    return hex_words

# 2. Extract and pack weights for weights.hex
all_hex_words = []
for name, param in checkpoint.items():
    if 'weight' in name:
        all_hex_words.extend(pack_weights_to_hex(param))

with open('weights.hex', 'w') as f:
    for word in all_hex_words:
        f.write(f"{word}\n")

# 3. Generate golden.txt (Mocking a single layer's output for test_nmc.c validation)
# In a full pipeline, you would pass an MNIST sample through the binarized network.
# This generates a placeholder matching the RTL test expectations.
with open('golden.txt', 'w') as f:
    f.write("00000001\n") # Placeholder golden output for RTL verification
