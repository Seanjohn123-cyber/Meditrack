# MediTrack System Requirements Specification

**Document Coordinator:** Person 1 (Collected across all five team tracks)  
**Project:** MediTrack — Processor-Free Medication Reminder SoC  
**Scope:** System-level, functional, interface, verification, and boundary requirements

---

## 1. System-Wide & Architectural Requirements (SYS)

| Req ID | Priority | Owner | Requirement Statement |
| :--- | :--- | :--- | :--- |
| SYS-01 | Mandatory | All | The SoC shall operate offline-first with zero CPU, software, or network dependency for local life-safety reminders. |
| SYS-02 | Mandatory | All | Every architectural state and event responsibility shall have a single module owner; no module shall recreate another module's events or keep a competing copy of its state. |
| SYS-03 | Mandatory | All | All event notifications (minute_tick, due_vector bits, ack_pulse, timeout_pulse, reminder_start_pulse, ack_event_pulse, missed_event_pulse) shall be single-cycle synchronous pulses. |
| SYS-04 | Mandatory | All | Asynchronous active-low reset (rst_n) shall deterministically initialize all state machines, queues, counters, and schedule enables to safe idle states. |
| SYS-05 | Mandatory | All | Prototype logic shall not perform clinical dose calculation, alter prescribed schedules autonomously, or infer medication ingestion from button presses or compartment unlocks. |

---

## 2. Configuration & Schedule Storage Requirements (CFG — Person 1)

| Req ID | Priority | Module | Requirement Statement |
| :--- | :--- | :--- | :--- |
| CFG-01 | Mandatory | config_interface | The module shall accept write requests containing slot index (0-11), medication ID (0-3), hour (0-23), minute (0-59), and an enable bit. |
| CFG-02 | Mandatory | config_interface | The module shall validate all incoming fields in a single cycle; out-of-range requests shall assert cfg_error for one cycle and produce no write strobe. |
| CFG-03 | Mandatory | config_interface | Valid write requests shall assert a single-cycle mem_wr_en strobe and present sanitized record fields to schedule_memory. |
| CFG-04 | Mandatory | schedule_memory | The module shall store 12 schedule records matching the 12-bit width of due_vector[11:0], with all slots disabled after reset. |
| CFG-05 | Mandatory | schedule_memory | Slot records shall update atomically on a single clock edge so schedule_matcher never observes partially updated data. |
| CFG-06 | Mandatory | schedule_memory | All 12 slot records shall be exposed continuously in parallel (both packed and split buses) to schedule_matcher and peripheral lookup logic. |

---

## 3. Timing & Schedule Matching Requirements (TIM — Person 2)

| Req ID | Priority | Module | Requirement Statement |
| :--- | :--- | :--- | :--- |
| TIM-01 | Mandatory | timer_unit | The module shall maintain real-time cur_hour (0-23) and cur_minute (0-59) counters and emit a one-cycle minute_tick pulse at each minute rollover. |
| TIM-02 | Mandatory | timer_unit | Clock prescalers shall be parameterized to support fast simulation time-bases as well as hardware clock frequencies. |
| TIM-03 | Mandatory | schedule_matcher | The module shall compare current time against all 12 enabled schedule records and emit a one-cycle pulse on due_vector[11:0] for each matching slot. |
| TIM-04 | Mandatory | schedule_matcher | Multiple slots scheduled for the same minute shall assert their respective due_vector[11:0] bits simultaneously on the same cycle. |
| TIM-05 | Mandatory | schedule_matcher | Once a slot triggers on a matching minute, the matcher shall not re-trigger that slot while the clock remains on the same minute, re-arming only for the next occurrence. |

---

## 4. Event Queue & Dose Accounting Requirements (EVT — Person 3)

| Req ID | Priority | Module | Requirement Statement |
| :--- | :--- | :--- | :--- |
| EVT-01 | Mandatory | event_queue | The module shall capture all asserted bits of due_vector[11:0], including simultaneous multi-slot matches, without losing events. |
| EVT-02 | Mandatory | event_queue | The module shall present the next pending slot via event_valid and event_slot[3:0], holding the head slot stable until event_valid && event_accept is asserted. |
| EVT-03 | Mandatory | event_queue | Simultaneous enqueue and dequeue on the same clock edge shall preserve both operations; overflow shall never silently overwrite pending events. |
| EVT-04 | Mandatory | dose_tracker | The module shall increment start, acknowledged, and missed dose counters strictly once per reminder_start_pulse, ack_event_pulse, and missed_event_pulse. |
| EVT-05 | Mandatory | dose_tracker | Counters shall never increment from persistent status levels such as reminder_active. |

---

## 5. Reminder Lifecycle, Acknowledgement & Timeout Requirements (REM — Person 4)

| Req ID | Priority | Module | Requirement Statement |
| :--- | :--- | :--- | :--- |
| REM-01 | Mandatory | acknowledgement_unit | The module shall synchronize and debounce physical button inputs and emit a single-cycle ack_pulse per valid press without deciding reminder applicability. |
| REM-02 | Mandatory | missed_dose_detector | The module shall count elapsed time while reminder_active is high, reset its counter when a reminder ends or starts, and emit one timeout_pulse per expired reminder. |
| REM-03 | Mandatory | reminder_controller | When idle and event_valid is high, the controller shall assert event_accept, transition to active, and emit reminder_start_pulse with reminder_start_slot[3:0] exactly once. |
| REM-04 | Mandatory | reminder_controller | When active, the controller shall be the sole authority to accept ack_pulse (emitting ack_event_pulse) or consume timeout_pulse (emitting missed_event_pulse) and end the reminder. |
| REM-05 | Mandatory | reminder_controller | If ack_pulse and timeout_pulse occur on the same clock edge while a reminder is active, acknowledgement shall win and emit ack_event_pulse, not missed_event_pulse. |

---

## 6. Peripherals & Access Control Requirements (PER — Person 5)

| Req ID | Priority | Module | Requirement Statement |
| :--- | :--- | :--- | :--- |
| PER-01 | Mandatory | compartment_controller | The module shall validate compartment access requests against active reminder status and unlock at most one medication compartment at a time. |
| PER-02 | Mandatory | compartment_controller | Compartment unlocking shall not generate an acknowledgement pulse or alter reminder lifecycle state. |
| PER-03 | Mandatory | display_controller | The module shall drive user-facing slot, medication ID, and time indicators directly from active_slot, reminder_active, and timer outputs. |
| PER-04 | Mandatory | alert_controller | The module shall drive visual (LED) and audible (buzzer) alarm outputs from reminder_active and system status without owning timeout or acknowledgement decisions. |

---

## 7. Caregiver Communication Requirements (COM — Person 1)

| Req ID | Priority | Module | Requirement Statement |
| :--- | :--- | :--- | :--- |
| COM-01 | Mandatory | caregiver_interface | The module shall capture already-created start, ack, and missed event pulses alongside slot index and current timestamp into an internal synchronous FIFO. |
| COM-02 | Mandatory | caregiver_interface | The module shall transmit event records externally using comm_valid, comm_ready, and payload[16:0], holding comm_valid and payload stable until comm_valid && comm_ready. |
| COM-03 | Mandatory | caregiver_interface | Caregiver backpressure (comm_ready held low indefinitely) shall never stall local timers, schedule matching, event queuing, reminder state transitions, or peripheral alerts. |
| COM-04 | Mandatory | caregiver_interface | If an event arrives while the telemetry FIFO is full, the module shall drop the new arrival, assert overflow indicators, and preserve all queued and in-flight records uncorrupted. |
| COM-05 | Mandatory | caregiver_interface | The module shall never create reminder events or modify system dose counters. |

---

## 8. Verification & Integration Acceptance Requirements (VER)

| Req ID | Priority | Owner | Requirement Statement |
| :--- | :--- | :--- | :--- |
| VER-01 | Mandatory | All | Every RTL module shall have a dedicated self-checking unit testbench verifying normal operation, boundary conditions, invalid inputs, and reset recovery. |
| VER-02 | Mandatory | Person 1 | Configuration and telemetry testbenches shall demonstrate out-of-range rejection on every field, atomic read-during-write updates, and multi-cycle comm_ready backpressure. |
| VER-03 | Mandatory | Persons 2-4 | System integration tests shall verify simultaneous schedule matches, same-edge ACK-over-timeout priority, and uninterrupted local reminders during caregiver link stalls. |
| VER-04 | Mandatory | Person 5 | All RTL modules shall be written in clean, synthesizable Verilog-2001 compatible with Yosys synthesis and OpenROAD physical implementation flows. |
