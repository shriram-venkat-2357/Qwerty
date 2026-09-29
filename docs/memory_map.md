# Memory Map

Status: Draft v0.1 for team freeze
Owner: Shriram Kumar V

## Proposed address map

| Start Address | End Address   | Region |
|---------------|---------------|--------|
| 0x0000_0000   | 0x0001_FFFF   | IMEM |
| 0x0002_0000   | 0x0003_FFFF   | DMEM |
| 0x1000_0000   | 0x1000_0003   | UART/putchar |
| 0x4000_0000   | 0x4000_0FFF   | Accelerator debug/MMIO optional |

## Notes

- IMEM and DMEM will use the Sky130 pre-hardened SRAM macro.
- Accelerator dispatch is primarily through custom-0 instructions, not MMIO.
- MMIO region is optional/debug and may be removed or changed.
- UART/putchar address must be confirmed with Member C.

## Addendum (Decision 0002, acked by C 2026-09-28): nmc.cfg
custom-0 (0x0B), funct3 = 3'b100, R-type: rs1 = column address, rs2 = signed threshold.
Non-blocking; completes in one cycle with done set. Thresholds reset to 0 at rst.
