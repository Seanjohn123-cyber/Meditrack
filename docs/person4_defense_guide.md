# Person 4 Technical Defense & Presentation Guide (Day 7)

**Presenter:** Person 4 (Group Lead & Reminder Subsystem Lead)  
**Project:** MediTrack - Processor-Free Smart Medication Reminder SoC  
**Focus:** Reminder Lifecycle, Acknowledgement Debouncing, Timeout Detection, and Priority Arbitration

---

## 1. How to Explain Your Subsystem to Examiners

> *"I am Person 4 and the Group Lead for MediTrack. My direct hardware ownership encompasses the heart of the user experience: the active reminder lifecycle, button synchronization and debouncing, timeout detection, and the critical acknowledgement-versus-timeout arbitration logic."*

### Key Architecture Points:
1. **Processor-Free Determinism:**  
   Unlike microcontroller solutions that suffer from software interrupt latency, MediTrack's reminder lifecycle is implemented in dedicated Verilog digital logic, guaranteeing instant response and zero software freeze risk.
2. **2-Stage Synchronizer & Counter Debouncer:**  
   Mechanical buttons are inherently noisy and asynchronous to the clock. The `acknowledgement_unit` uses a 2-stage flip-flop synchronizer to eliminate metastability, followed by an integrator counter (`DEBOUNCE_CYCLES`) and a rising-edge detector. Even if a patient presses and holds the button continuously, exactly **one** single-cycle `ack_pulse` is generated.
3. **Dedicated Missed Dose Detector:**  
   The `missed_dose_detector` runs synchronously while `reminder_active` is asserted up to `TIMEOUT_CYCLES`. It emits strictly one single-cycle pulse and automatically resets when the reminder terminates or upon back-to-back reminders.
4. **Master Reminder FSM (`reminder_controller`):**  
   Implements a clean 2-state synchronous machine (`STATE_IDLE`, `STATE_ACTIVE`). It handshakes with Person 3's queue via `event_accept`, drives peripheral alerts via `reminder_active`, and acts as the **sole authority** emitting `reminder_start_pulse`, `ack_event_pulse`, and `missed_event_pulse`.

---

## 2. The End-to-End Event Flow (The "Canonical Path")

When asked to explain how an event flows from start to finish through the entire SoC:
1. **Time Generation (Person 2):** `timer_unit` ticks down system clock cycles and emits a 1-cycle `minute_tick`.
2. **Schedule Comparison (Person 2):** `schedule_matcher` compares current time with all 15 active slots in `schedule_memory` (Person 1) and emits `due_vector[14:0]`.
3. **Queue Ingestion (Person 3):** `event_queue` captures due slots, buffers simultaneous reminders, and asserts `event_valid` with the head slot `event_slot[3:0]`.
4. **Reminder Start (Person 4 - You):** While idle, `reminder_controller` samples `event_valid`, pulses `event_accept` for 1 cycle to pop the queue, pulses `reminder_start_pulse`, and asserts `reminder_active`.
5. **Peripherals & Alerts (Person 5):** `alert_controller` activates buzzer and LED blinking; `display_controller` displays `active_slot`.
6. **User Interaction (Person 4 - You):**
   - **Path A (User Ack):** User presses button -> debounced -> `ack_pulse` arrives -> `reminder_controller` emits `ack_event_pulse` -> alerts stop -> `dose_tracker` increments `ack_count` -> `caregiver_interface` stages packet.
   - **Path B (Timeout):** User does not press button -> `missed_dose_detector` reaches `TIMEOUT_CYCLES` -> emits `timeout_pulse` -> `reminder_controller` emits `missed_event_pulse` -> alerts stop -> `dose_tracker` increments `missed_count` -> `caregiver_interface` stages missed event telemetry.

---

## 3. The Golden Priority Rule: Acknowledgement vs Timeout

### The Problem:
What happens if the user presses the acknowledgement button at the exact microsecond (exact clock cycle) that the hardware timeout counter expires?
- If mismanaged, the system could record both an acknowledgment AND a missed event, causing conflicting records and alarming caregivers unnecessarily.

### MediTrack's Architectural Solution:
In `reminder_controller.v`:
```verilog
if (ack_pulse) begin
    ack_event_pulse    <= 1'b1;
    ack_event_slot     <= active_slot;
    missed_event_pulse <= 1'b0; // Suppressed!
    reminder_active    <= 1'b0;
    state              <= STATE_IDLE;
end else if (timeout_pulse) begin
    missed_event_pulse <= 1'b1;
    ...
```
**Acknowledgement unconditionally beats timeout.** If both pulses arrive on the same clock cycle, `ack_event_pulse` is generated and `missed_event_pulse` is suppressed. This was verified in Test 5 of `tb_reminder_controller.v` and can be shown in `pictures/tb_reminder_controller_waveform.png`.

---

## 4. Likely Examination Questions & Model Answers

**Q1: Why did you separate `missed_dose_detector` from `reminder_controller` instead of putting the counter inside the controller?**  
*Answer:* In accordance with the Single Responsibility Principle and our modular verification strategy. The timeout detector is an independent hardware timer that can be parameterized or replaced with an external watchdog or real-time clock counter without touching the FSM logic or priority arbitration rules.

**Q2: What happens if a user holds the physical button down indefinitely?**  
*Answer:* The `acknowledgement_unit` uses edge-detection on the debounced signal (`debounced_state && !debounced_state_d1`). It produces exactly one pulse on the rising edge. Holding the button yields zero additional pulses and will not accidentally acknowledge future reminders.

**Q3: Can a reminder be lost if a new schedule matches while a reminder is already active?**  
*Answer:* No. While `reminder_active == 1`, `reminder_controller` deasserts `event_accept`, so the queue does not pop. All incoming due events are safely preserved in Person 3's `event_queue` and processed sequentially as soon as the current reminder finishes.

**Q4: How did you verify the design?**  
*Answer:* We designed a comprehensive testbench suite with 4 testbenches (`tb_acknowledgement_unit`, `tb_missed_dose_detector`, `tb_reminder_controller`, and `tb_reminder_subsystem`) simulated using Icarus Verilog (`iverilog`) and GTKWave. All unit and integrated tests achieved 100% pass rates. Waveform screenshots were captured directly in `pictures/`.
