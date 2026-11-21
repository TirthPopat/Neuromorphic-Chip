# Neuromorphic Chip: 8-Core RRAM Spiking Neural Network Accelerator

An 8-core spiking neural network accelerator taken from RTL to GDSII on the open SkyWater 130 nm PDK, with an analog leaky integrate-and-fire (LIF) neuron prototype built in Cadence Virtuoso.

Course project for BECE303L (VLSI System Design), VIT Vellore.

## Highlights

- **256 LIF neurons** (8 cores x 32) and **16,384 RRAM synapses** (8 x 64 x 32, 8-bit weights)
- On-chip **STDP learning** and an 8-port round-robin network-on-chip with 9-bit AER packets
- Replacing SRAM with RRAM crossbar macros cut reported area by **81%** (2.05 mm2 to 0.38 mm2)
- Forward pass went from about 530 to **96 cycles** (5.5x faster) with single-cycle vector-matrix multiply
- Scaled from 4 to 8 cores; 72,781 synthesized cells at a 66.7 MHz target
- A 16-core version passes RTL simulation; physical design ran out of memory (>14 GB)

## Design flow

| Stage | Tool |
|---|---|
| Synthesis | Yosys |
| Place and route | OpenROAD |
| Layout viewing / GDS | KLayout |
| Analog prototype | Cadence Virtuoso (45 nm) |
| PDK | SkyWater Sky130HD |

## Repository contents

| Item | Description |
|---|---|
| `multicore_tile.v` | Top-level 8-core tile |
| `lif_neuron_array.v`, `lif_neuron_core.v` | LIF neuron array and core |
| `membrane_accumulator.v`, `membrane_mem.v` | Membrane potential logic and storage |
| `network_interface.v` | Spike-to-packet network interface |
| `lif_neuron_array.sdc` | Timing constraints |
| `n1_neurochip_6_finish.rpt` | Final flow report |
| `n1_neurochip*_reports/` | Synthesis and place-and-route reports |
| `RRAM Reports/`, `sram/` | RRAM and SRAM macro work |
| `24BVD1055_24BVD1031_Neuromorphic.pdf` | Full project report |

The final layout (`n1_neurochip_6_final.gds`, about 200 MB) is too large for GitHub. Download it here: **ADD LINK**

## Results summary

| Metric | Value |
|---|---|
| Technology | SkyWater 130 nm (Sky130HD) |
| Target clock | 66.7 MHz (15 ns period) |
| Worst slack | -0.02 ns (near miss at 15 ns) |
| Total wire length | 7.76 m |
| Layout violations | 37 DRC + 4 antenna |
| Power (post-route estimate) | 872 mW (RRAM power not modeled) |

## Authors

- Tirth Bhavinkumar Popat (24BVD1055)
- Atharva Mahaveer Chougule (24BVD1031)

Guide: Dr. Velmathi G
