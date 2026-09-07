"""
train.py
--------
Trains the Binary-Weight LeNet (bwn_lenet.py) on MNIST.

Usage:
    python3 train.py --epochs 5

Produces:
    bwn_lenet.pt   -- trained PyTorch model checkpoint

Run export_golden.py afterward to produce weights.hex and golden.txt
from this checkpoint (deliverable D4).
"""

import argparse
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader

from bwn_lenet import BWNLenet


def get_dataloaders(batch_size=128, data_dir="./data"):
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,)),
    ])
    train_set = datasets.MNIST(data_dir, train=True, download=True, transform=transform)
    test_set = datasets.MNIST(data_dir, train=False, download=True, transform=transform)
    train_loader = DataLoader(train_set, batch_size=batch_size, shuffle=True)
    test_loader = DataLoader(test_set, batch_size=256, shuffle=False)
    return train_loader, test_loader


def evaluate(model, loader, device):
    model.eval()
    correct, total = 0, 0
    with torch.no_grad():
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            pred = model(x).argmax(dim=1)
            correct += (pred == y).sum().item()
            total += y.size(0)
    return correct / total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--batch-size", type=int, default=128)
    parser.add_argument("--out", type=str, default="bwn_lenet.pt")
    args = parser.parse_args()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    train_loader, test_loader = get_dataloaders(args.batch_size)

    model = BWNLenet().to(device)
    optimizer = optim.Adam(model.parameters(), lr=args.lr)
    criterion = nn.CrossEntropyLoss()

    for epoch in range(1, args.epochs + 1):
        model.train()
        running_loss = 0.0
        for batch_idx, (x, y) in enumerate(train_loader):
            x, y = x.to(device), y.to(device)
            optimizer.zero_grad()
            out = model(x)
            loss = criterion(out, y)
            loss.backward()
            optimizer.step()

            # Clip real-valued binary-conv weights to [-1, 1] after each
            # step -- standard BNN practice (keeps the latent weight that
            # gets binarized in a sane range for the STE gradient).
            with torch.no_grad():
                for m in model.modules():
                    if hasattr(m, "weight") and m.__class__.__name__ == "BinaryConv2d":
                        m.weight.clamp_(-1, 1)

            running_loss += loss.item()
            if batch_idx % 100 == 0:
                print(f"Epoch {epoch} [{batch_idx * len(x)}/{len(train_loader.dataset)}] "
                      f"loss={loss.item():.4f}")

        acc = evaluate(model, test_loader, device)
        print(f"=== Epoch {epoch} done. Avg loss={running_loss/len(train_loader):.4f}  "
              f"Test accuracy={acc*100:.2f}% ===")

    torch.save(model.state_dict(), args.out)
    print(f"Saved trained model to {args.out}")


if __name__ == "__main__":
    main()
