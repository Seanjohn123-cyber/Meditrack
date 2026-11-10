# MediTrack System Architecture and Microarchitecture Specification

**Author/Owner:** Person 4 (Reminder Subsystem Lead & Overall Group Lead)  
**Contributors:** Persons 1, 2, 3, 5  
**Document Version:** 1.0  

---

## 1. High-Level SoC Overview

MediTrack is an offline-first, processor-free digital System-on-Chip (SoC) designed in Verilog HDL. It guarantees deterministic, real-time medication reminders and event reporting without dependence on microcontrollers, software operating systems, or internet connectivity.

```
       +-----------------------+           +----------------------+
       |   config_interface    |           |      timer_unit      |
       +-----------+-----------+           +----------+-----------+
                   |                                  | (curr_time, minute_tick)
                   v                                  v
       +-----------+-----------+           +----------+-----------+
       |    schedule_memory    +---------->|   schedule_matcher   |
       +-----------------------+           +----------+-----------+
                                                      | (due_vector[11:0])
                                                      v
                                           +----------+-----------+
                                           |     event_queue      |
                                           +-----+----------+-----+
                                                 |          ^
                      (event_valid, event_slot)  |          | (event_accept)
                                                 v          |
+----------------------+                   +-----+----------+-----+
| acknowledgement_unit +---(ack_pulse)---->|                      |
+----------------------+                   | reminder_controller  |
                                           |                      |
+----------------------+                   |   (Master State      |
| missed_dose_detector |<-(rem_active)---->|      Machine)        |
+----------------------+  (timeout_pulse)  +---+----+---------+---+
                                               |    |         |
                  (reminder_active, active_slot|    |         | (start/ack/missed pulses)
                                               v    |         v
                      +------------------------+    |   +-----+--------+
                      | User-Facing Peripherals|    |   | dose_tracker |
                      | (alert/disp/compartmt) |    |   +--------------+
                      +------------------------+    |
                                                    v
                                         +----------+-----------+
                                         | caregiver_interface  |
                                         +----------------------+
```

---

## 2. Person 4 Subsystem: Reminder Lifecycle & Acknowledgement

### 2.1 Microarchitecture of Person 4 Subsystem
The Reminder subsystem comprises three tightly coupled units:
1. `acknowledgement_unit`: Filters noise and button bounce, detects rising edges, and emits a clean single-cycle `ack_pulse`.
2. `missed_dose_detector`: Synchronous timer measuring reminder duration against a programmable parameter `TIMEOUT_CYCLES`. Emits a single-cycle `timeout_pulse`.
3. `reminder_controller`: 2-state Moore/Mealy hybrid FSM orchestrating event popping, active alerts, priority arbitration, and event pulse dispatching.

### 2.2 FSM State Definitions (`reminder_controller`)

```
               rst_n = 0
                   |
                   v
             +------------+
             |   S_IDLE   | <---------------------------+
             +-----+------+                             |
                   | event_valid == 1                   |
                   | / event_accept = 1                 |
                   |   reminder_start_pulse = 1         |
                   |   active_slot <= event_slot        |
                   v                                    |
             +------------+                             |
             | S_ACTIVE   |                             |
             +-----+------+                             |
                   |                                    |
                   +-- ack_pulse (with or without       |
                   |              timeout_pulse)        |
                   |   / ack_event_pulse = 1            |
                   |                                    |
                   +-- timeout_pulse && !ack_pulse -----+
                       / missed_event_pulse = 1
```

- **`S_IDLE` (`1'b0`):**
  - `reminder_active` is `0`.
  - Continuously monitors `event_valid` from `event_queue`.
  - When `event_valid` is asserted:
    - Samples `event_slot[3:0]`.
    - Asserts `event_accept` for exactly 1 clock cycle to pop the queue.
    - Emits `reminder_start_pulse` (with `reminder_start_slot = event_slot`) for 1 clock cycle.
    - Transitions to `S_ACTIVE` on the next clock edge.
  - Any `ack_pulse` or `timeout_pulse` received while in `S_IDLE` is safely discarded without side effects.

- **`S_ACTIVE` (`1'b1`):**
  - `reminder_active` is held continuously at `1`.
  - `active_slot[3:0]` is held stable throughout the reminder duration.
  - While in `S_ACTIVE`, `event_accept` is strictly held low; incoming queue events remain queued.
  - Evaluates inputs on each clock edge:
    1. **Case A (User Acknowledges):** If `ack_pulse` is high (regardless of `timeout_pulse`):
       - Emits `ack_event_pulse` for 1 clock cycle with `ack_event_slot = active_slot`.
       - Transitions back to `S_IDLE`.
    2. **Case B (Timeout Expiration):** If `timeout_pulse` is high and `ack_pulse` is low:
       - Emits `missed_event_pulse` for 1 clock cycle with `missed_event_slot = active_slot`.
       - Transitions back to `S_IDLE`.

### 2.3 Critical Golden Rule: Same-Edge Collision Resolution
In digital hardware, user button input and hardware timeout counters may coincide on the exact same clock edge.
- **Specification:** When `ack_pulse == 1` and `timeout_pulse == 1` simultaneously during `S_ACTIVE`:
  - **Acknowledgement wins strictly.**
  - `ack_event_pulse` is driven high for 1 clock cycle.
  - `missed_event_pulse` is forced to `0`.
  - System returns to `S_IDLE`.

### 2.4 Button Synchronization and Debouncing (`acknowledgement_unit`)
- External mechanical switches exhibit contact bouncing.
- Implements a 2-stage synchronizer (`sync_ff1`, `sync_ff2`) to prevent metastability.
- Implements an integrator/counter-based debouncer (`DEBOUNCE_CYCLES`).
- Edge detector generates a 1-cycle pulse only on the 0->1 transition of the debounced level.
- Continuous holding of the button produces exactly **one** pulse upon initial press; no repeat pulses occur while held.

### 2.5 Timeout Detector (`missed_dose_detector`)
- Synchronous counter increments on each clock cycle where `reminder_active == 1`.
- When counter reaches `TIMEOUT_CYCLES - 1`, `timeout_pulse` is pulsed for exactly 1 clock cycle.
- Counter holds at terminal count or resets to 0 when `reminder_active == 0`.
- If a reminder is acknowledged prior to timeout, `reminder_active` deasserts, resetting the counter immediately.
- Handles back-to-back reminders seamlessly: counter resets to 0 upon entering a new reminder.
