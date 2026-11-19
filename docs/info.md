# TinyMPPT

A digital perturb-and-observe (P&O) maximum-power-point-tracking (MPPT)
controller for reconfigurable RF energy harvesters, implemented as a
pure-digital Tiny Tapeout project.

An RF rectifier is only efficient at one operating point: its optimal load
and its input impedance change with the available input power. TinyMPPT
continuously adjusts a 4-bit configuration word (rectifier stage count /
load trim) so that the harvester stays at its maximum power point while
the ambient RF level varies.

# How it works

Power is sensed without an ADC: the off-chip harvester delivers fixed
charge packets to the storage element and emits one pulse per packet on
`ui[0]`, so the pulse rate is proportional to the harvested power.

Every measurement window (16384 clock cycles, about 1.64 ms at the nominal
10 MHz clock) the controller:

1. counts the pulses received during the window (the "power" sample);
2. compares this sample with the previous window's sample;
3. if the power increased, steps the 4-bit configuration `uo[3:0]` one more
   step in the same direction; if it decreased, reverses direction and steps;
4. pulses the window strobe `uo[4]` for one clock cycle.

This is the classic perturb-and-observe hill-climbing algorithm: the
configuration walks up the power curve and, once at the peak, dithers by
one step around it (normal P&O behaviour).

In manual mode (`ui[1]` = 1) the tracking loop is bypassed and the
configuration is forced to the value present on `uio[3:0]`. This mode is
intended for characterising a harvester: sweeping all 16 configurations
while recording the pulse rate yields the full power-versus-configuration
curve.

Debug outputs: `uo[5]` shows the current search direction (1 = up, 0 =
down); `uo[6]` echoes the manual-mode select.

# How to test

## Bench test with the devkit

1. Seat the chip breakout on the demo board and connect it to a PC.
2. With the Tiny Tapeout Commander, select the TinyMPPT project and set
   the clock to 10 MHz.
3. Manual mode: drive `ui[1]` high and place a value on `uio[3:0]` (RP2040
   GPIOs or switches on your interface); check that `uo[3:0]` equals it.
4. Auto mode: drive `ui[1]` low and feed a 10-100 kHz pulse train into
   `ui[0]` (function generator or RP2040 GPIO); monitor `uo[3:0]` and the
   strobe `uo[4]` with a logic analyser: the configuration steps once per
   window (about 1.64 ms).

## Closed-loop (hardware-in-the-loop) test

To observe tracking without an RF front-end, emulate the harvester with
the RP2040 or any microcontroller:

1. read the configuration `uo[3:0]`;
2. evaluate a harvester model: pulse rate = f(configuration), with a
   single peak at a chosen configuration (e.g. 12);
3. emit pulses on `ui[0]` at that rate.

The controller walks from its reset value (8) towards the model's peak
and then dithers between the peak and its neighbours. The same two checks
(manual override and peak tracking) also run automatically in simulation,
including gate-level: see `test/test.py` (cocotb), executed in CI.
