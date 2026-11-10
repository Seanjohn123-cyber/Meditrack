# MediTrack Module Interfaces and Day-1 Frozen Contracts

**Document Version:** 1.0 (Frozen on Day 1)  
**Status:** Approved by Team Lead (Person 4) & All Subsystem Owners  
**Target Architecture:** Processor-free Medication Reminder SoC Prototype (Verilog RTL)

---

## 1. Global System Conventions and Data Widths

| Parameter / Signal | Width / Format | Valid Range | Description |
| :--- | :--- | :--- | :--- |
| `clk` | 1 bit | Rising edge active | System clock |
| `rst_n` | 1 bit | Active-low | Asynchronous system reset |
| `slot_id` | 4 bits (`[3:0]`) | `0` to `11` | 12 medication reminder slots |
| `med_id` | 2 bits (`[1:0]`) | `0` to `3` | 4 distinct medications |
| `hour` | 5 bits (`[4:0]`) | `0` to `23` | Hours (24-hour time format) |
| `minute` | 6 bits (`[5:0]`) | `0` to `59` | Minutes |
| `due_vector` | 12 bits (`[11:0]`) | Bitmask | Bit `i` high indicates slot `i` is due |
| `event_code` | 2 bits (`[1:0]`) | `00`=Start, `01`=Ack, `10`=Missed | Standard event codes |
| `counter_width` | 8 bits (`[7:0]`) | `0` to `255` | Dose event counters (saturating at 255) |
| `caregiver_fifo_depth` | Parameter | Default: `8` records | Buffer for remote telemetry link |

### Pulse Semantics
- **All event and trigger notifications are strictly 1-cycle pulses** (`reminder_start_pulse`, `ack_pulse`, `ack_event_pulse`, `timeout_pulse`, `missed_event_pulse`, `minute_tick`, `due_vector`).
- **Status levels remain continuously asserted while valid** (`reminder_active`, `active_slot`, `comm_valid`, `event_valid`).
- **Priority Rule:** If `ack_pulse` and `timeout_pulse` are sampled on the **exact same clock cycle**, **acknowledgement wins**. An `ack_event_pulse` is generated; `missed_event_pulse` is suppressed.

---

## 2. Module Specifications & Port Contracts

### Person 1: Configuration & Caregiver Subsystem

#### 2.1 `config_interface.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `cfg_write_req`: 1 bit write strobe
  - `cfg_slot_idx[3:0]`: target slot index (0–11)
  - `cfg_med_id[1:0]`: medication ID (0–3)
  - `cfg_hour[4:0]`: scheduled hour (0–23)
  - `cfg_minute[5:0]`: scheduled minute (0–59)
  - `cfg_enable`: 1 bit schedule enable flag
- **Outputs:**
  - `cfg_error`: 1 bit flag (asserted 1 cycle if write fields are out of range)
  - `mem_we`: 1 bit write enable strobe to `schedule_memory`
  - `mem_slot[3:0]`: validated slot index
  - `mem_med_id[1:0]`: validated medication ID
  - `mem_hour[4:0]`: validated hour
  - `mem_minute[5:0]`: validated minute
  - `mem_enable`: validated enable

#### 2.2 `schedule_memory.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `mem_we`, `mem_slot[3:0]`, `mem_med_id[1:0]`, `mem_hour[4:0]`, `mem_minute[5:0]`, `mem_enable`
- **Outputs:**
  - `sched_enables[11:0]`: continuous 12-bit enable vector
  - `sched_hours[59:0]`: packed 12×5-bit scheduled hours
  - `sched_minutes[71:0]`: packed 12×6-bit scheduled minutes
  - `sched_med_ids[23:0]`: packed 12×2-bit medication IDs

#### 2.3 `caregiver_interface.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `event_code[1:0]`: 00=Start, 01=Ack, 10=Missed
  - `event_slot[3:0]`: slot index associated with event
  - `event_pulse`: 1 bit strobe pushing event to FIFO
  - `comm_ready`: 1 bit input from external gateway (high when gateway can accept data)
- **Outputs:**
  - `comm_valid`: 1 bit handshake output (held stable until `comm_valid && comm_ready`)
  - `comm_payload[7:0]`: packed event packet `{2'b00, event_code[1:0], event_slot[3:0]}` (held stable)
  - `fifo_overflow`: 1 bit flag if FIFO exceeds depth

---

### Person 2: Timing & Schedule Matching Subsystem

#### 2.4 `timer_unit.v`
- **Parameters:**
  - `CLKS_PER_SECOND`: integer (e.g. 10 for simulation, 50_000_000 for 50MHz FPGA)
  - `SECS_PER_MINUTE`: integer (e.g. 6 for fast simulation, 60 for real time)
- **Inputs:**
  - `clk`, `rst_n`
  - `time_load_en`: 1 bit strobe to load time
  - `load_hour[4:0]`, `load_minute[5:0]`
- **Outputs:**
  - `curr_hour[4:0]`: current hour (0–23)
  - `curr_minute[5:0]`: current minute (0–59)
  - `minute_tick`: 1-cycle pulse emitted on each minute boundary

#### 2.5 `schedule_matcher.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `minute_tick`: 1-cycle pulse from `timer_unit`
  - `curr_hour[4:0]`, `curr_minute[5:0]`
  - `sched_enables[11:0]`, `sched_hours[59:0]`, `sched_minutes[71:0]`
- **Outputs:**
  - `due_vector[11:0]`: 1-cycle pulse vector where bit `i` is high if slot `i` matches current time

---

### Person 3: Event Queue & Event Accounting Subsystem

#### 2.6 `event_queue.v`
- **Parameters:**
  - `QUEUE_DEPTH`: default 12
- **Inputs:**
  - `clk`, `rst_n`
  - `due_vector[11:0]`: 1-cycle pulse vector from `schedule_matcher`
  - `event_accept`: 1-cycle handshake strobe from `reminder_controller`
- **Outputs:**
  - `event_valid`: high while queue has at least one pending event
  - `event_slot[3:0]`: head slot of queue (stable while `event_valid` is high)
  - `queue_empty`, `queue_full`, `queue_overflow`

#### 2.7 `dose_tracker.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `reminder_start_pulse`: 1-cycle pulse from `reminder_controller`
  - `ack_event_pulse`: 1-cycle pulse from `reminder_controller`
  - `missed_event_pulse`: 1-cycle pulse from `reminder_controller`
- **Outputs:**
  - `start_count[7:0]`: 8-bit saturating counter for started reminders
  - `ack_count[7:0]`: 8-bit saturating counter for acknowledged reminders
  - `missed_count[7:0]`: 8-bit saturating counter for missed reminders

---

### Person 4: Reminder Lifecycle & Acknowledgement (Lead Subsystem)

#### 2.8 `acknowledgement_unit.v`
- **Parameters:**
  - `DEBOUNCE_CYCLES`: integer (default 4 for simulation, larger for FPGA)
- **Inputs:**
  - `clk`, `rst_n`
  - `btn_ack_raw`: raw button input
- **Outputs:**
  - `ack_pulse`: exactly one 1-cycle pulse per valid button press (holding button yields only 1 pulse)

#### 2.9 `missed_dose_detector.v`
- **Parameters:**
  - `TIMEOUT_CYCLES`: integer (e.g. 50 for simulation)
- **Inputs:**
  - `clk`, `rst_n`
  - `reminder_active`: status level from `reminder_controller`
- **Outputs:**
  - `timeout_pulse`: exactly one 1-cycle pulse emitted when active count reaches `TIMEOUT_CYCLES`

#### 2.10 `reminder_controller.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `event_valid`: from `event_queue`
  - `event_slot[3:0]`: from `event_queue`
  - `ack_pulse`: from `acknowledgement_unit`
  - `timeout_pulse`: from `missed_dose_detector`
- **Outputs:**
  - `event_accept`: 1-cycle pulse popped to `event_queue`
  - `reminder_active`: persistent level high during active reminder
  - `active_slot[3:0]`: slot being reminded (stable while `reminder_active` is high)
  - `reminder_start_pulse`: 1-cycle pulse when reminder starts
  - `reminder_start_slot[3:0]`: slot index at start
  - `ack_event_pulse`: 1-cycle pulse on valid acknowledgement
  - `ack_event_slot[3:0]`: slot index at ack
  - `missed_event_pulse`: 1-cycle pulse on timeout
  - `missed_event_slot[3:0]`: slot index at timeout

---

### Person 5: Peripherals & User-Facing Controllers

#### 2.11 `compartment_controller.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `open_req`: 1-cycle request pulse
  - `req_slot[3:0]`: requested slot compartment
  - `close_req`: 1-cycle close/relock pulse
- **Outputs:**
  - `compartment_unlock[11:0]`: 1-hot unlock signals (at most one compartment unlocked at a time)
  - `access_granted`: 1-cycle status pulse
  - `access_denied`: 1-cycle status pulse (if slot invalid or another door already open)

#### 2.12 `display_controller.v`
- **Inputs:**
  - `clk`, `rst_n`
  - `reminder_active`: from `reminder_controller`
  - `active_slot[3:0]`: from `reminder_controller`
  - `curr_hour[4:0]`, `curr_minute[5:0]`: from `timer_unit`
- **Outputs:**
  - `disp_active`: status indicator
  - `disp_slot[3:0]`: displayed slot
  - `disp_status_code[1:0]`: 00=Idle, 01=Reminder Active

#### 2.13 `alert_controller.v`
- **Parameters:**
  - `BLINK_PERIOD`: integer for simulation
- **Inputs:**
  - `clk`, `rst_n`
  - `reminder_active`: from `reminder_controller`
- **Outputs:**
  - `buzzer_out`: alert buzzer signal
  - `led_out`: alert LED blink signal
