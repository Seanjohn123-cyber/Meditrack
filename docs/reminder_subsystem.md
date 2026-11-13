# Person 4 Module Documentation: Reminder Subsystem

**Owner:** Person 4 (Lead - Reminder Lifecycle & Acknowledgement)  
**Modules Covered:**  
- `rtl/reminder/acknowledgement_unit.v`
- `rtl/reminder/missed_dose_detector.v`
- `rtl/reminder/reminder_controller.v`
- `rtl/reminder/reminder_subsystem.v`

---

## 1. Subsystem Architecture Overview

The Reminder Subsystem manages the active reminder lifecycle, arbitrates user acknowledgement versus hardware timeout, and produces single-cycle event notification pulses for tracking and remote caregiver communication.

```
                     +---------------------------------------+
                     |          reminder_subsystem           |
                     |                                       |
btn_ack_raw -------->| +---------------------+               |
                     | |acknowledgement_unit |               |
                     | +----------+----------+               |
                     |            | ack_pulse                |
                     |            v                          |
event_valid -------->| +---------------------+               |----> reminder_active
event_slot[3:0] ---->| | reminder_controller |<-(timeout)----+----> active_slot[3:0]
event_accept <-------| +----------+----------+        |      |----> reminder_start_pulse/slot
                     |            |                   |      |----> ack_event_pulse/slot
                     |            +----(rem_active)---+      |----> missed_event_pulse/slot
                     |            |                   v      |
                     |            |     +------------------+ |
                     |            +---->|  missed_detector | |
                     | (rem_start)      +------------------+ |
                     +---------------------------------------+
```

---

## 2. Port Lists & Signal Descriptions

### 2.1 `acknowledgement_unit.v`
| Port | Direction | Width | Reset Value | Description |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Input | 1 | - | System clock (rising edge) |
| `rst_n` | Input | 1 | - | Asynchronous active-low reset |
| `btn_ack_raw` | Input | 1 | - | Asynchronous, noisy raw button switch input |
| `ack_pulse` | Output | 1 | `0` | Debounced 1-cycle active-high pulse |

**Parameters:**
- `DEBOUNCE_CYCLES` (Integer, default `4` for simulation; e.g. `500_000` for 10ms at 50MHz FPGA): Number of consecutive clock cycles the synchronized button level must remain stable before transitioning the internal debounced state.

**Reset Behavior:**
- Resets synchronizer flip-flops (`sync_ff1`, `sync_ff2`) to `0`.
- Clears `debounce_counter` to `0`.
- Deasserts `debounced_state`, `debounced_state_d1`, and `ack_pulse` to `0`.

---

### 2.2 `missed_dose_detector.v`
| Port | Direction | Width | Reset Value | Description |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | Input | 1 | - | System clock |
| `rst_n` | Input | 1 | - | Asynchronous active-low reset |
| `reminder_active` | Input | 1 | - | Status level from `reminder_controller` |
| `reminder_start_pulse`| Input | 1 | - | Strobe pulse indicating new reminder start |
| `timeout_pulse` | Output | 1 | `0` | Exactly one 1-cycle active-high timeout pulse |

**Parameters:**
- `TIMEOUT_CYCLES` (Integer, default `50` for simulation; scaled to real-world minutes/hours in hardware): Number of active clock cycles before timeout occurs.

**Reset Behavior:**
- Clears `timer_count` to `0`.
- Clears `timeout_fired` and `timeout_pulse` to `0`.
- Automatically clears when `reminder_active == 0` or on `reminder_start_pulse == 1`.

---

### 2.3 `reminder_controller.v`
| Port | Direction | Width | Reset Value | Description |
| :--- | :---: | :---: | :---: | :--- |
| `clk`, `rst_n` | Input | 1 | - | Clock and asynchronous active-low reset |
| `event_valid` | Input | 1 | - | Queue head valid (from Person 3) |
| `event_slot[3:0]` | Input | 4 | - | Queue head slot index (0 to 14) |
| `event_accept` | Output | 1 | `0` | 1-cycle handshake pop pulse to queue |
| `ack_pulse` | Input | 1 | - | 1-cycle button pulse from ack unit |
| `timeout_pulse` | Input | 1 | - | 1-cycle timeout pulse from detector |
| `reminder_active` | Output | 1 | `0` | Continuous level high while active |
| `active_slot[3:0]` | Output | 4 | `0` | Active slot ID (stable while active) |
| `reminder_start_pulse` | Output | 1 | `0` | 1-cycle pulse upon reminder start |
| `reminder_start_slot[3:0]` | Output | 4 | `0` | Slot ID associated with start pulse |
| `ack_event_pulse` | Output | 1 | `0` | 1-cycle pulse on successful ack |
| `ack_event_slot[3:0]` | Output | 4 | `0` | Slot ID associated with ack pulse |
| `missed_event_pulse` | Output | 1 | `0` | 1-cycle pulse on timeout |
| `missed_event_slot[3:0]` | Output | 4 | `0` | Slot ID associated with missed pulse |

**Reset Behavior:**
- FSM state forces to `STATE_IDLE` (`1'b0`).
- All output pulses (`event_accept`, `reminder_start_pulse`, `ack_event_pulse`, `missed_event_pulse`) deassert to `0`.
- `reminder_active` deasserts to `0`.
- Slot registers reset to `0`.

---

## 3. Strict Operating Rules & Priority Contract

1. **Pulse Length Rule:** Every notification strobe (`reminder_start_pulse`, `ack_event_pulse`, `missed_event_pulse`, `event_accept`, `ack_pulse`, `timeout_pulse`) is strictly **one system clock cycle in duration**.
2. **Single Reminder Authority:** At most one reminder can be active in the system at any given moment. While `reminder_active == 1`, incoming queue events are locked out (`event_accept` remains low).
3. **Golden Priority Rule (Same-Edge Ack vs Timeout):**
   ```verilog
   if (ack_pulse) begin
       ack_event_pulse    <= 1'b1;
       ack_event_slot     <= active_slot;
       missed_event_pulse <= 1'b0; // Missed event strictly suppressed!
       reminder_active    <= 1'b0;
       state              <= STATE_IDLE;
   end else if (timeout_pulse) begin
       missed_event_pulse <= 1'b1;
       missed_event_slot  <= active_slot;
       ack_event_pulse    <= 1'b0;
       reminder_active    <= 1'b0;
       state              <= STATE_IDLE;
   end
   ```
   If both `ack_pulse` and `timeout_pulse` arrive on the identical clock cycle, **acknowledgement wins unconditionally**. A missed dose event is never emitted.
4. **Spurious Input Isolation:** An `ack_pulse` or stale `timeout_pulse` arriving during `STATE_IDLE` is safely ignored and produces zero side effects.
