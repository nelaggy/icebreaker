# Verification Plan for `stopwatch.v`

## DUT Overview

- **Clock**: 12 MHz (parameter `CLKDIV_MAX` cycles per BCD tick, default 1,200,000 = 100ms)
- **Parameter**: `CLKDIV_MAX` — set to 119 in testbench via `defparam` (period = 120 cycles = `CLK_PER_TICK`)
- **Inputs**: `CLK`, `BTN_N` (active-low reset), `BTN3` (start), `BTN1` (stop), `BTN2` (lap)
- **Outputs**: `LED1`–`LED5` (combinational), `P1A*` (7-segment display)
- **Internal State**: `display_value` (8-bit BCD 0–99), `running` flag, `lap_value`, `lap_timeout` (5-bit)
- **Submodules**: `bcd8_increment` (BCD +1), `seven_seg_ctrl` (display mux), `seven_seg_hex` (digit decode)

### Button Semantics (always block source order, last assignment wins)

| Mode | BTN_N | BTN3 | BTN1 | BTN2 | Effect |
|------|-------|------|------|------|--------|
| Reset | 0 | X | X | X | `display=0`, `clkdiv=0`, `running=0` (lap_timeout untouched) |
| Start | 1 | 1 | 0 | 0 | `running=1` |
| Stop  | 1 | X | 1 | X | `running=0` |
| Lap   | 1 | X | X | 1 | `lap_value=display`, `lap_timeout=20` |

### BCD Value Encoding (decimal literal used in testbench checks)

| Decimal | BCD (hex) | Testbench literal |
|---------|-----------|-------------------|
| 0–9     | `8'h0`–`8'h9` | 0–9 |
| 10      | `8'h10`  | 16 |
| 99      | `8'h99`  | 153 |

---

## Test Cases

### T1 — Reset Initialization

| Step | Action | Expected |
|------|--------|----------|
| T1a | `reset()`, check `display_value` | 0 |
| T1b | Check `running` | 0 |
| T1c | `wait_ticks(2)`, check `display_value` still | 0 |
| T1d | `BTN_N=0`, check `LED4` | 1 |
| T1e | Check `LED5` | 1 |

### T2 — LED Combinational Logic

| Step | Button State | Expected |
|------|-------------|----------|
| T2a | All released | `LED4=0`, `LED5=0` |
| T2c,d | `BTN_N=0` | `LED4=1`, `LED5=1` |
| T2e | `BTN1=1` | `LED1=0`, `LED5=1` |
| T2g | `BTN2=1` | `LED5=1` |
| T2h | `BTN3=1` | `LED5=1` |
| T2i | `BTN1=1, BTN2=1` | `LED1=1` |
| T2j | `BTN1=1, BTN3=1` | `LED2=1` |
| T2k | `BTN2=1, BTN3=1` | `LED3=1` |
| T2l–o | All three | `LED1=LED2=LED3=LED5=1` |

### T3 — Start Counting

| Step | Action | Expected |
|------|--------|----------|
| T3a | `press(BTN3)` | `running=1` |
| T3b | `wait_ticks(1)` | `display_value=1` |
| T3c | `wait_ticks(4)` more | `display_value=5` |

### T4 — Stop Counting

| Step | Action | Expected |
|------|--------|----------|
| T4a | `press(BTN1)` | `running=0` |
| T4b | `wait_ticks(5)` | `display_value` still 5 |

### T5 — Resume After Stop

| Step | Action | Expected |
|------|--------|----------|
| T5a | `press(BTN3)` | `running=1` |
| T5b | `wait_ticks(2)` | `display_value=7` (continues from 5) |

### T6 — BCD Low-Nibble Rollover (9 → 10)

| Step | Action | Expected |
|------|--------|----------|
| T6a | Reset, start, `wait_ticks(9)` | `display_value=9` |
| T6b | `wait_ticks(1)` | `display_value=16` (`8'h10`, BCD 10) |

Verifies `bcd8_increment` correctly handles `din[3:0] == 9` → low nibble wraps to 0, high nibble increments.

### T7 — BCD Full Rollover (99 → 00)

| Step | Action | Expected |
|------|--------|----------|
| T7a | From 10, `wait_ticks(89)` | `display_value=153` (`8'h99`) |
| T7b | `wait_ticks(1)` | `display_value=0` |

Verifies the `din[7:0] == 8'h99` case wraps entirely to 0.

### T8 — Lap Capture

| Step | Action | Expected |
|------|--------|----------|
| T8a | Start, `wait_ticks(5)` | `display_value=5` |
| T8b | `press(BTN2)` | `lap_value=5` |
| T8c | | `lap_timeout=20` |
| T8d | `wait_ticks(20)` | `lap_timeout=0` (lap expired) |

### T9 — Lap While Stopped

| Step | Action | Expected |
|------|--------|----------|
| T9a | Start, wait 3, stop | `display_value=3`, `running=0` |
| T9b | `press(BTN2)` | `lap_value=3` |
| T9c | | `lap_timeout=20` |
| T9d | `wait_ticks(21)` | `lap_timeout=0` |

### T10 — Lap Refresh (BTN2 During Active Lap)

| Step | Action | Expected |
|------|--------|----------|
| T10a | Start, wait 3, press lap | `lap_value=3` |
| T10b | `wait_ticks(5)`, counter still running | `display_value=8` |
| T10c | `press(BTN2)` again | `lap_value=8` (updated) |
| T10d | | `lap_timeout=20` (reset) |

### T11 — Reset While Running

| Step | Action | Expected |
|------|--------|----------|
| T11a | Start, `wait_ticks(5)` | `display_value=5`, `running=1` |
| T11b | Assert `BTN_N` one cycle | `display_value=0` |
| T11c | | `running=0` |
| T11d | `wait_ticks(3)` | `display_value` still 0 |

### T12 — Button Priority

| Step | Simultaneous Buttons | Expected |
|------|---------------------|----------|
| T12a | `BTN_N=0, BTN3=1` | `display=0`, `running=1` (BTN3 last wins) |
| T12c | `BTN1=1, BTN3=1` | `running=0` (BTN1/stop overrides BTN3/start) |
| T12d-e | `BTN_N=0, BTN1=1, BTN3=1` | `display=0`, `running=0` |

Source-order priority: later `if` blocks' non-blocking assignments overwrite earlier ones within the same `always` block.

### T13 — Lap + Start Same Cycle

| Step | Action | Expected |
|------|--------|----------|
| T13a | `BTN2=1, BTN3=1` same cycle | `running=1` |
| T13b | | `lap_value=0` (captures current display) |
| T13c | | `lap_timeout=20` |

### T14 — Reset Does Not Clear `lap_timeout`

| Step | Action | Expected |
|------|--------|----------|
| T14a | Start, wait 5, press lap, wait 5 | snapshot `lap_timeout` |
| T14b | Assert `BTN_N` | `display_value=0` |
| T14c | | `lap_timeout` still equals snapshot (not 0) |
| T14d | `wait_ticks(1)` | `lap_timeout` decremented by 1 |

This verifies the design behaviour (as distinct from the solution, which does clear `lap_timeout` on reset). Since `clkdiv` is reset but `lap_timeout` is not, the lap timer continues counting down from where it left off after reset.

---

## Testbench Architecture

### Tasks
- **`reset()`** — asserts `BTN_N=0` for one cycle, zeros all other buttons
- **`press(button)`** — asserts a button for one cycle
- **`wait_ticks(n)`** — waits `n * 1_200_000` posedge edges (`n` BCD ticks)
- **`check(name, got, exp)`** — displays PASS/FAIL, increments `errors` counter

### Hierarchical Access
Internal signals are probed via dot-path: `dut.display_value`, `dut.running`, `dut.lap_value`, `dut.lap_timeout`.

### Helper Register
`reg [7:0] snapshot` — captures `lap_timeout` before reset in T14 for before/after comparison.

### BCD Value Convention
All check values use decimal literals matching the raw 8-bit register value (`8'h10` = 16, `8'h99` = 153).

---

## Simulation Notes

- Clock: `#41.667` half-period, `1ns/1ns` timescale → ~12 MHz functional
- **`defparam dut.CLKDIV_MAX = 119`** — period = CLKDIV_MAX+1 = 120 = CLK_PER_TICK; exact 1:1 tick matching
- **`localparam CLK_PER_TICK = 120`** — wait_ticks(n) waits n×120 posedge events = exactly n BCD ticks
- `sync;` (`@(negedge CLK)`) called before every check of synchronous state (display_value, running, lap_*, etc.) to settle NBAs
- `#0;` delta delay used before LED (combinational) checks to allow continuous assigns to re-evaluate
- Button tasks (`start`, `stop`, `lap`, `reset`) hold button values through `@(negedge CLK)` to avoid race conditions with DUT always block
- `seven_seg_ctrl` internal divider (10-bit, max 1023) is not parameterized — unaffected
