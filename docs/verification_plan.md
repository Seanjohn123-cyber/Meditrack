# MediTrack Master Verification Plan

**Coordinator:** Person 4 (Group Lead & Reminder Lifecycle Owner)  
**Target:** Icarus Verilog (`iverilog`) & GTKWave Simulation Suite  
**Scope:** 13 Unit Testbenches + System-Level Integration Testbench

---

## 1. Verification Strategy and Tooling

- **Simulator:** Icarus Verilog (`iverilog -g2012`)
- **Waveform Viewer:** GTKWave (`.vcd` output)
- **Passing Criteria:** Zero assertion failures, clear console messages with `[PASS]`, and visual inspection of waveform transitions.
- **Continuous Gatekeeping Rule:** No module PR is merged into `main` without its unit testbench passing 100% of defined test cases.

---

## 2. Unit Testbench Matrix & Coverage Goals

| Subsystem Owner | Testbench File | Target Module | Mandatory Test Cases |
| :--- | :--- | :--- | :--- |
| **Person 1** | `tb/unit/tb_config_interface.v` | `config_interface` | Valid write, out-of-range hours (>23), out-of-range minutes (>59), invalid slot indices, reset clears state, back-to-back configuration writes. |
| **Person 1** | `tb/unit/tb_schedule_memory.v` | `schedule_memory` | Write then readback, overwrite existing slot, write during read stability, reset clears all 12 enable bits. |
| **Person 1** | `tb/unit/tb_caregiver_interface.v` | `caregiver_interface` | `comm_ready` low with payload held stable, `comm_ready` toggling, FIFO full & overflow detection, burst of 3 records, reset mid-transfer. |
| **Person 2** | `tb/unit/tb_timer_unit.v` | `timer_unit` | Tick spacing, 59->00 minute rollover, 23:59->00:00 midnight rollover, time load preset, asynchronous reset. |
| **Person 2** | `tb/unit/tb_schedule_matcher.v` | `schedule_matcher` | Single match, simultaneous matches (2 and all 12 slots), disabled slot suppression, same-minute no-retrigger lock, midnight slot matching, next-day re-arm. |
| **Person 3** | `tb/unit/tb_event_queue.v` | `event_queue` | Empty queue status, single enqueue, simultaneous enqueue from due vector, fill to capacity (12 entries), overflow flag, simultaneous enqueue and dequeue in same cycle, head slot stability while awaiting accept. |
| **Person 3** | `tb/unit/tb_dose_tracker.v` | `dose_tracker` | Each pulse type alone (`start`, `ack`, `missed`), long idle periods with zero counter drift, same-cycle pulses of different types, 8-bit saturation at 255, asynchronous reset. |
| **Person 4** | `tb/unit/tb_acknowledgement_unit.v` | `acknowledgement_unit` | Input contact bounce rejection, long continuous button hold (yields exactly one 1-cycle pulse), repeated quick presses, asynchronous reset. |
| **Person 4** | `tb/unit/tb_missed_dose_detector.v` | `missed_dose_detector` | Timeout fires once exactly at `TIMEOUT_CYCLES`, early reminder termination resets counter, immediate back-to-back reminder resets, reset clears counter. |
| **Person 4** | `tb/unit/tb_reminder_controller.v` | `reminder_controller` | Normal acknowledgement path, timeout path emitting missed event, **same-edge ack and timeout collision (ACK must win)**, ack while idle ignored, new event arriving during active reminder blocked, back-to-back reminders, reset safe state. |
| **Person 5** | `tb/unit/tb_compartment_controller.v` | `compartment_controller` | Valid open request, out-of-range slot rejection, second open request rejected while door open, relock sequence, reset clears all unlock lines. |
| **Person 5** | `tb/unit/tb_display_controller.v` | `display_controller` | Idle display format, active slot display during reminder, status transitions, reset state. |
| **Person 5** | `tb/unit/tb_alert_controller.v` | `alert_controller` | Alert active when `reminder_active` is high, alert silent when low, rapid start/stop toggling, reset state. |

---

## 3. System Integration Scenarios (`tb/system/tb_medi_soc_top.v`)

1. **Scenario 1: Canonical Flow (End-to-End Successful Reminder)**
   - Configure slot 0 for 08:30.
   - Advance clock to 08:30.
   - Verify `due_vector[0]` pulses -> queued -> reminder becomes active -> LED/buzzer alert -> user acknowledges -> alert stops -> `ack_count` increments -> caregiver packet queued.
2. **Scenario 2: Missed Dose Flow (Unacknowledged Timeout)**
   - Configure slot 1 for 09:00.
   - Advance clock to 09:00.
   - Let timer expire without pressing button -> `missed_dose_detector` pulses `timeout_pulse` -> reminder controller emits `missed_event_pulse` -> alert stops -> `missed_count` increments -> caregiver packet queued with Missed code.
3. **Scenario 3: Simultaneous Due Events Preservation**
   - Configure slots 2 and 3 for the same minute (12:00).
   - Advance clock to 12:00 -> verify both slots captured into `event_queue` without drops -> Slot 2 processed first -> on completion, Slot 3 immediately transitions to active.
4. **Scenario 4: Priority Arbitration (Ack vs Timeout on Same Clock Edge)**
   - Force button press at exact cycle when timeout counter reaches threshold.
   - Verify `ack_event_pulse` is generated, `missed_event_pulse` is NEVER generated, and `ack_count` increments.
5. **Scenario 5: Caregiver Backpressure Isolation**
   - Deassert `comm_ready` (slow or disconnected caregiver link).
   - Trigger multiple reminders; verify timer, reminder state machine, user alerts, and button inputs operate with zero stalls or delays.
