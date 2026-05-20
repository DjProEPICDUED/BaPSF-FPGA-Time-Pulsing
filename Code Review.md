Search complete: Find HDL files

Searched codebase for "HDL project timing CDC FSM issues review", no results

Searched for files matching `**/*.sv`, 4 matches

Searched for files matching `**/*.xdc`, 1 match

Searched for regex `clock|clock.*domain|reset|CDC|timing|setup|hold|fsm|state.*machine`, 32 results

Searched for regex `always_ff|always_comb|sync.*reset|async.*reset|dff|ff.*d`, 23 results

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/main_tb.sv#1-1), lines 1 to 260

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/top.sv)

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/dual_timePulser.sv)

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/mmcm_shifter.sv)

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/Arty-A7-Pulse.xdc)

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/top.sv)

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/dual_timePulser.sv)

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/mmcm_shifter.sv)

Read [](file:///c%3A/Users/Jeanm/Desktop/Courses/BaPsF/BaPSF-FPGA-Time-Pulsing/Arty-A7-Pulse.xdc)

**Findings**
- Critical — Independent trigger synchronizers can start the base and shifted sequences on different cycles in dual_timePulser.sv. Problem: `trig_sync_base_*` and `trig_sync_shift_*` sample `trigger` independently, so one domain can see the event while the other misses it. Why: this can create a `set_pulses` without a corresponding `reset_pulses` (or vice‑versa), leaving outputs stuck high or never asserting. When: any short or asynchronous trigger, or phase alignment that captures the edge in only one domain. Fix: generate a single event in one domain and transfer it as a toggle or handshake into the other domain so both domains act on the same event. Snippet:
```systemverilog
// Base domain: sync and edge-detect trigger, then toggle
(* ASYNC_REG = "TRUE" *) logic [1:0] trig_sync_base;
logic trig_pulse_base, trig_toggle_base;

always_ff @(posedge clk_base or negedge n_rst) begin
  if (!n_rst) begin
    trig_sync_base  <= 2'b00;
    trig_toggle_base <= 1'b0;
  end else begin
    trig_sync_base  <= {trig_sync_base[0], trigger};
    trig_pulse_base <= trig_sync_base[1] & ~trig_sync_base[0];
    if (trig_pulse_base) trig_toggle_base <= ~trig_toggle_base;
  end
end

// Shifted domain: detect toggle to create a single pulse
(* ASYNC_REG = "TRUE" *) logic [1:0] trig_sync_shift;
logic trig_pulse_shift;

always_ff @(posedge clk_shifted or negedge n_rst) begin
  if (!n_rst) trig_sync_shift <= 2'b00;
  else trig_sync_shift <= {trig_sync_shift[0], trig_toggle_base};
end

assign trig_pulse_shift = trig_sync_shift[1] ^ trig_sync_shift[0];
```

- Critical — The asynchronous SR latch combines two clock domains in dual_timePulser.sv. Problem: `always_latch` uses `set_pulses` and `reset_pulses` from different clocks to control `final_pulses`. Why: near‑simultaneous set/reset transitions can create metastability and glitching that is not modeled in simulation, and the output is combinationally driven by two clocks. When: any time `clk_shifted` moves relative to `clk_base` (dynamic phase shift), or when set/reset edges are close. Fix: drive output pulses from a single clock domain and use a dedicated delay element (ODELAY/OSERDES) or a single‑clock pattern generator; do not combine two unrelated clocks in an async latch. Snippet (single‑clock output register with IOB placement):
```systemverilog
logic [NUM_CHANNELS-1:0] pulse_reg;

always_ff @(posedge clk_base or negedge n_rst) begin
  if (!n_rst) pulse_reg <= '0;
  else begin
    // set/clear pulse_reg in one domain
  end
end

(* IOB = "TRUE" *) logic [NUM_CHANNELS-1:0] output_pulse;
assign output_pulse = pulse_reg;
```

- Critical — Reset deassertion is asynchronous to all three clock domains in top.sv, dual_timePulser.sv, and mmcm_shifter.sv. Problem: `n_rst` is a raw inverted button and is used as an async reset for sequential logic in multiple clocks. Why: async deassert can leave flops in metastable or partial‑reset states, causing stuck FSMs or spurious pulses. When: any reset release that happens near a clock edge. Fix: use async‑assert / sync‑deassert reset synchronizers per clock domain. Snippet:
```systemverilog
module reset_sync (
  input  logic clk,
  input  logic rst_async,   // active-high
  output logic rst_sync_n    // active-low
);
  (* ASYNC_REG = "TRUE" *) logic [1:0] rst_ff;
  always_ff @(posedge clk or posedge rst_async) begin
    if (rst_async) rst_ff <= 2'b00;
    else rst_ff <= {rst_ff[0], 1'b1};
  end
  assign rst_sync_n = rst_ff[1];
endmodule
```

- High — External buttons and trigger are used without synchronization or debounce in top.sv and mmcm_shifter.sv. Problem: `trigger`, `ext_btn_signal`, `btn_add_half_ns`, `btn_sub_half_ns` are asynchronous inputs feeding logic and edge detectors directly. Why: metastability and bounce can create multiple unintended MMCM shifts or phantom triggers. When: any button press or external trigger edge not aligned to the clock. Fix: synchronize each async input to a single clock domain and debounce buttons before edge detect. Snippet:
```systemverilog
(* ASYNC_REG = "TRUE" *) logic [1:0] btn_add_sync;
always_ff @(posedge clk_100mhz or negedge n_rst) begin
  if (!n_rst) btn_add_sync <= 2'b00;
  else btn_add_sync <= {btn_add_sync[0], btn_add_half_ns};
end
logic btn_add_rise = btn_add_sync[1] & ~btn_add_sync[0];
```

- High — `locked` gates the trigger in combinational logic in top.sv. Problem: `locked` is not synchronized to the 200 MHz domains but is ANDed with `trigger` before synchronization. Why: asynchronous gating can create runt pulses or metastable trigger inputs to both domains. When: MMCM lock toggles or during phase shift. Fix: synchronize `locked` into the domain that generates the trigger event and only use it inside synchronous logic.

- High — Missing timing constraints for the clocks in Arty-A7-Pulse.xdc. Problem: there is no `create_clock` on `clk_100mhz` nor generated clock constraints for the MMCM outputs. Why: timing analysis may be incomplete or incorrect, masking real setup/hold violations. When: any build; the tools can silently ignore critical paths or over‑optimize. Fix: add explicit clock constraints (or ensure the Clock Wizard XDC is included). Snippet:
```tcl
create_clock -name clk_100mhz -period 10.000 [get_ports clk_100mhz]
create_generated_clock -name clk_base_200mhz \
  -source [get_ports clk_100mhz] [get_pins clk_multiplier/clk_out1]
create_generated_clock -name clk_shifted_200mhz \
  -source [get_ports clk_100mhz] [get_pins clk_multiplier/clk_out2]
```

- High — Dynamic phase shifts occur while pulses are generated in mmcm_shifter.sv and dual_timePulser.sv. Problem: shifting the MMCM while outputs are active changes the relative phase mid‑pulse. Why: pulse width becomes non‑deterministic and may violate hardware timing assumptions. When: any shift request while a pulse sequence is running. Fix: inhibit pulse generation during MMCM shifting, or only allow shifts when the system is idle and outputs are low.

- High — The MMCM phase shift is unbounded across button presses in mmcm_shifter.sv. Problem: repeated shifts can wrap the phase, potentially making the shifted clock lead or lag by large amounts. Why: the reset edge can move earlier than the set edge, collapsing or inverting pulses. When: repeated button presses beyond the intended range. Fix: track phase position and clamp to safe bounds; refuse further shifts at limits.

- Medium — `final_pulses` has no reset path in dual_timePulser.sv. Problem: latch outputs power up X or retain last state across reset. Why: asynchronous resets only clear `set_pulses`/`reset_pulses`, not the latch itself. When: power‑up or after reset while outputs are latched high. Fix: explicitly clear `final_pulses` on reset (or move to a registered implementation). Snippet:
```systemverilog
always_latch begin
  if (!n_rst) final_pulses <= '0;
  else begin
    for (int i = 0; i < NUM_CHANNELS; i++) begin
      if (reset_pulses[i]) final_pulses[i] <= 1'b0;
      else if (set_pulses[i]) final_pulses[i] <= 1'b1;
    end
  end
end
```

- Medium — Level‑sensitive trigger re‑fires sequences if the trigger stays high in dual_timePulser.sv and dual_timePulser.sv. Problem: as soon as `base_active` clears, a still‑high trigger restarts the sequence immediately. Why: this can generate back‑to‑back pulses from a single long button press. When: external trigger or button is held. Fix: edge‑detect the trigger in a single domain and use a one‑shot.

- Medium — FSM lacks illegal‑state recovery and a `psdone` timeout in mmcm_shifter.sv. Problem: if `state` is corrupted or `psdone` never arrives, the FSM can hang. Why: no default branch or timeout mechanism to return to `IDLE`. When: reset deassert issues, MMCM handshake failure, or metastability on `psdone`. Fix: add a default recovery and a timeout counter.

- Medium — Output pulses are not registered or placed in IOBs in top.sv and dual_timePulser.sv. Problem: outputs are driven by internal LUT/latch logic with uncontrolled routing skew. Why: inter‑channel timing skew can be large and unpredictable at 200 MHz. When: any build with different placement or PVT. Fix: register outputs with `(* IOB = "TRUE" *)` and control all timing in a single clock domain.

- Low — Counters use `int` (signed 32‑bit) in dual_timePulser.sv and mmcm_shifter.sv. Problem: wide signed arithmetic can increase resource use and introduces signed/unsigned comparison hazards. Why: synthesis may infer more logic than necessary, and comparisons to unsigned parameters can be ambiguous. When: large parameter values or aggressive optimization. Fix: use sized unsigned logic, e.g. `logic [$clog2(DELAY_CYCLES):0]`.

**Modules most likely to fail timing closure**
- `dual_timePulser` due to the asynchronous latch and CDC paths in dual_timePulser.sv.
- The top‑level due to missing timing constraints in Arty-A7-Pulse.xdc.

**Signals that should be synchronized or registered**
- `trigger`, `ext_btn_signal`, `btn_add_half_ns`, `btn_sub_half_ns`, and `locked` in top.sv.
- `trig_sync_*` synchronizers should have `(* ASYNC_REG = "TRUE" *)` attributes in dual_timePulser.sv.
- `output_pulse` should be registered/IOB‑placed in top.sv.

**Open questions / assumptions**
- Is `trigger` intended to be a short pulse or a level? If it is a level, do you want single‑shot behavior or repeated sequences while it remains high?
- What is the safe phase‑shift range you want to allow before you’d rather clamp (to avoid reset leading set)?
- Can you accept moving to a single‑clock output architecture (using ODELAY/OSERDES) to eliminate the async latch?

No code changes were made. If you want, I can propose a concrete re‑architecture for the pulse generator that removes the cross‑clock latch while preserving sub‑cycle timing.