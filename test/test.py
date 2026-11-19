import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

_CLOCK_STARTED = False

async def start_clk(dut):
    global _CLOCK_STARTED
    if not _CLOCK_STARTED:
        _CLOCK_STARTED = True
        cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())

def read_cfg(dut):
    try:
        return int(dut.uo_out.value) & 0xF
    except Exception:
        return 8

async def fake_harvester(dut):
    """Emulated rectifier+storage: pulse rate peaks at config 12."""
    while True:
        d = abs(read_cfg(dut) - 12)
        half = 1 + d
        dut.ui_in.value = 1
        await Timer(half, units="us")
        dut.ui_in.value = 0
        await Timer(half, units="us")

@cocotb.test()
async def manual_mode_forces_config(dut):
    await start_clk(dut)
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 4)
    dut.uio_in.value = 5
    dut.ui_in.value = 2          # manual mode on
    await ClockCycles(dut.clk, 8)
    assert read_cfg(dut) == 5, f"manual mode failed, cfg={read_cfg(dut)}"

@cocotb.test()
async def tracks_the_peak(dut):
    await start_clk(dut)
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    dut.rst_n.value = 1
    cocotb.start_soon(fake_harvester(dut))
    await Timer(20, units="ms")
    cfg = read_cfg(dut)
    dut._log.info(f"final config = {cfg}")
    assert 11 <= cfg <= 13, f"did not lock to peak, cfg={cfg}"
