

## 1. Near-Memory Compute (NMC) Accelerator & ML Training

### 1.1 Binary-Weight LeNet Training (`training/`)

- Developed and trained the binary-weight LeNet architecture (`bwn\_lenet.py`) matching plan §2.1: conv1 (1→8, 3×3) → threshold → 2×2 pool → conv2 (8→16, 3×3) → threshold → pool → FC10.

- Implemented binarization via sign() with a straight-through estimator for training.

- Executed full training runs on MNIST via `train.py`, achieving **92.38% test accuracy** and including the 5-epoch trained checkpoint (`bwn\_lenet.pt`) in the repository.

### 1.2 ML Artifact Export Pipeline (D4 Deliverable)

- Implemented and verified `export\_artifacts.py` to extract trained model weights and golden reference outputs directly from PyTorch checkpoints.

- Generated and successfully pushed the required ML artifacts (`weights.hex` and `golden.txt`) to the GitHub repository for hardware-software co-verification.

## 2. RTL Synthesis & Waveform Simulation Integration

### 2.1 RTL Synthesis Setup & Execution

- Authored and verified synthesis scripts (`scripts/synth\_counter.ys`, `scripts/synth\_cpu.ys`) using Yosys to translate core Verilog blocks into gate-level netlists.

- Integrated automated execution flows to validate module hierarchies and ensure clean netlist generation for synthesis targets.

### 2.2 Simulation & Waveform Verification

- Configured and executed testbenches (`tb\_pipeline.v`) using Icarus Verilog (`iverilog`) to simulate instruction execution and data movement.

- Captured and formatted multi-signal waveforms (`.vcd` / GTKWave views) to verify signal transitions, pipeline execution, and data paths during instruction processing.

## 3. Status Matrix (Member C)

| **Item** | **Status** |
| :-: | :-: |
| Binary-Weight LeNet Model & Training (`bwn\_lenet.py`, `train.py`) | ✅ done (92.38% accuracy) |
| Trained Checkpoint (`bwn\_lenet.pt`) | ✅ done |
| ML Artifact Export Script (`export\_artifacts.py`) & Pushed Artifacts (`weights.hex`, `golden.txt`) | ✅ done |
| RTL Synthesis Scripts (`synth\_counter.ys`, `synth\_cpu.ys`) | ✅ done |
| Waveform Simulation & Testbench Verification (`iverilog`, `gtkwave`) | ✅ done |
| NMC C Golden Model & Driver Draft (`nmc\_golden.c/.h`) | ✅ done |

## 4. Open Items & Team Alignment

1. **Collaboration with B** — Review and finalize ownership of the NMC golden model and driver integration.

2. **Co-Verification** — Run end-to-end hardware-accelerated test cases using the exported `weights.hex` and `golden.txt` against the simulated core.

