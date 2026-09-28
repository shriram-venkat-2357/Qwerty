# 0006 — SRAM macro read-latency adaptations (freeze-rule logged)
Owner: A. Target: Wk8. Status: proposed (C, Wk7).

(a) imem gains a clk port + soc_top wiring (sim behaviour unchanged: combinational read).
(b) Fetch-stage registration for the macro's +1-cycle read (registered fetch or 1-cycle stall).
(c) cim_sequencer samples b_rdata one cycle later (sites: cim_sequencer.v:90, :100).

Until landed: macro netlist is physically signoff-clean but functionally pending latency closure; all functional/energy/accuracy numbers remain from the inferred-memory simulation netlist; B re-runs gate sim against the macro netlist after (a)-(c) land.
