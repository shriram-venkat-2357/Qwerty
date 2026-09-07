"""
bwn_lenet.py
------------
Binary-Weight LeNet for MNIST, matching the architecture frozen in the
Two-Phase Project Plan (Section 2.1):

    conv1 (1->8, 3x3) -> threshold -> 2x2 pool
    -> conv2 (8->16, 3x3) -> threshold -> pool
    -> FC10

"Binary-weight" means: convolution weights are constrained to {-1, +1}
during the forward pass (this is what nmc_unit's XNOR + popcount datapath
computes in hardware). Activations after conv+threshold are the sign of
the pre-activation sum (also binary), matching the "threshold unit"
described in the plan. This keeps the software-side network numerically
consistent with the accelerator's actual binary-weight, binary-activation
datapath (a "BNN" — Binary Neural Network).

We use the standard Straight-Through Estimator (STE) trick to train
through the non-differentiable sign() function: forward pass uses
sign(), backward pass pretends it was identity (clamped to [-1,1]).
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class BinarizeSTE(torch.autograd.Function):
    """sign() on the forward pass, straight-through (clamped) on backward."""

    @staticmethod
    def forward(ctx, x):
        ctx.save_for_backward(x)
        # sign(): map to {-1, +1}. Treat exact 0 as +1 (matches the golden
        # model's `acc >= threshold` producing 1 at the boundary).
        return torch.where(x >= 0, torch.ones_like(x), -torch.ones_like(x))

    @staticmethod
    def backward(ctx, grad_output):
        (x,) = ctx.saved_tensors
        # Straight-through, clipped outside [-1, 1] (standard BNN trick)
        grad_input = grad_output.clone()
        grad_input[x.abs() > 1] = 0
        return grad_input


def binarize(x):
    return BinarizeSTE.apply(x)


class BinaryConv2d(nn.Conv2d):
    """Conv2d whose WEIGHTS are binarized {-1,+1} on the forward pass.
    Activations (input to this layer) are left as-is; the *output* is
    binarized separately by BinaryThreshold below, matching the plan's
    'conv -> threshold' pipeline stage-by-stage."""

    def forward(self, x):
        bw = binarize(self.weight)
        return F.conv2d(x, bw, self.bias, self.stride, self.padding)


class BinaryThreshold(nn.Module):
    """The 'threshold unit' from the plan: binarizes the conv output
    to {-1, +1}, i.e. the sign/threshold nonlinearity."""

    def forward(self, x):
        return binarize(x)


class BWNLenet(nn.Module):
    def __init__(self):
        super().__init__()
        # conv1: 1 -> 8 channels, 3x3, padding=1 to keep spatial size at 28x28
        self.conv1 = BinaryConv2d(1, 8, kernel_size=3, padding=1, bias=False)
        self.thresh1 = BinaryThreshold()
        self.pool1 = nn.MaxPool2d(2)  # 28x28 -> 14x14

        # conv2: 8 -> 16 channels, 3x3, padding=1 -> stays 14x14
        self.conv2 = BinaryConv2d(8, 16, kernel_size=3, padding=1, bias=False)
        self.thresh2 = BinaryThreshold()
        self.pool2 = nn.MaxPool2d(2)  # 14x14 -> 7x7

        # FC10: flatten (16*7*7) -> 10 class scores. Kept full-precision,
        # matching typical BNN practice of leaving the final classifier layer
        # in higher precision for accuracy (out of scope items in the plan
        # exclude anything beyond "binary weights with int8 activations" for
        # the accelerator itself; the final FC is a software-side readout).
        self.fc = nn.Linear(16 * 7 * 7, 10)

    def forward(self, x):
        x = self.pool1(self.thresh1(self.conv1(x)))
        x = self.pool2(self.thresh2(self.conv2(x)))
        x = x.flatten(1)
        return self.fc(x)
