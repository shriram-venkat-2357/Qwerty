import torch, torch.nn as nn, torch.nn.functional as F, numpy as np, os
from torchvision import datasets, transforms

class BinSign(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x): return torch.sign(x)
    @staticmethod
    def backward(ctx, g): return g

class BinConv(nn.Conv2d):
    def forward(self, x):
        return F.conv2d(x, BinSign.apply(self.weight), self.bias, self.stride, self.padding)

class Net(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = BinConv(1, 8, 3, padding=1)
        self.conv2 = BinConv(8, 16, 3, padding=1)
        self.fc = nn.Linear(16*7*7, 10)
    def forward(self, x):
        x = F.max_pool2d((self.conv1(x) >= 0).float(), 2)
        x = F.max_pool2d((self.conv2(x) >= 0).float(), 2)
        return self.fc(x.flatten(1))

torch.manual_seed(42); np.random.seed(42)
tf = transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.1307,), (0.3081,))])
print("Downloading MNIST (if needed)...", flush=True)
tr = datasets.MNIST('data', train=True, transform=tf, download=True)
te = datasets.MNIST('data', train=False, transform=tf, download=True)
trl = torch.utils.data.DataLoader(tr, batch_size=128, shuffle=True)
tel = torch.utils.data.DataLoader(te, batch_size=1000)

m = Net(); opt = torch.optim.Adam(m.parameters(), lr=1e-3); ce = nn.CrossEntropyLoss()

print("Starting training...", flush=True)
for ep in range(10):
    for x, y in trl:
        opt.zero_grad(); l = ce(m(x), y); l.backward(); opt.step()
    m.eval(); c = sum((m(x).argmax(1) == y).sum().item() for x, y in tel)
    m.train(); print(f"epoch {ep+1} acc {c/len(te)*100:.2f}%", flush=True)

os.makedirs('training/export', exist_ok=True)
w1 = (BinSign.apply(m.conv1.weight).detach() > 0).int().cpu().numpy().flatten()
w2 = (BinSign.apply(m.conv2.weight).detach() > 0).int().cpu().numpy().flatten()
bits = np.concatenate([w1, w2])
pad_len = (32 - len(bits) % 32) % 32
bits = np.concatenate([bits, np.zeros(pad_len, dtype=int)])

with open('training/export/weights.hex', 'w') as f:
    for word in bits.reshape(-1, 32):
        val = sum(int(b) << i for i, b in enumerate(word))
        f.write(f"{val:08x}\n")

m.eval(); x0 = te[0][0].unsqueeze(0)
with torch.no_grad(): pred = m(x0).argmax(1).item()
open('training/export/golden.txt', 'w').write(f"{pred:08x}\n")
open('training/export/thresholds.txt', 'w').write('\n'.join(['0']*32) + '\n')
print(f"EXPORTED {len(bits)//32} words; golden = {pred}", flush=True)
