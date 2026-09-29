libs/ holds generated timing artifacts only.
soc_top_preRoute.sdf: OpenSTA pre-route SDF (cell delays, ZERO wire delay) from
build/soc_top_synth.v + scripts/soc_top.sdc. Labelled pre-route per plan 9.2;
final SDF comes from C post-route.
Liberty: NOT committed (12.7 MB PDK file) - use env.sh -> PDK_LIB, version pinned
in tool_versions.txt.
