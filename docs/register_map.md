# MediTrack Register Map and Record Format Specification

**Subsystem Owner:** Person 1 (Configuration and Caregiver Communication)  
**Target Branch:** feature/person1-config-comm  
**Status:** Day-1 Frozen Specification (TBD-D1 Resolved)

---

## 1. Overview

MediTrack operates as a processor-free digital System-on-Chip (SoC) with deterministic hardware state machines and synchronous register storage. This document specifies:
1. The upstream configuration write bus fields, widths, reset values, and validation rules handled by config_interface.
2. The 12-slot schedule register file layout and atomic update rules inside schedule_memory.
3. The continuous parallel bus exposure formats connecting schedule_memory to schedule_matcher and peripheral controllers.
4. The 17-bit caregiver telemetry payload and FIFO status outputs driven by caregiver_interface.

---

## 2. Configuration Write Bus Specification

The configuration interface accepts synchronous write requests on the rising edge of clk when cfg_wr_en is asserted.

| Field Name | Width | Valid Range | Reset Value | Access Rule |
| :--- | :--- | :--- | :--- | :--- |
| cfg_wr_en | 1 bit | 0 to 1 | 0 | Write strobe |
| cfg_slot_idx | 4 bits | 0 to 11 | 0 | Target slot |
| cfg_med_id | 4 bits | 0 to 3 | 0 | Medication ID |
| cfg_hour | 5 bits | 0 to 23 | 0 | 24-hour clock |
| cfg_minute | 6 bits | 0 to 59 | 0 | Minute field |
| cfg_enable | 1 bit | 0 to 1 | 0 | Slot enable |
| cfg_error | 1 bit | 0 to 1 | 0 | Error output |

* **cfg_wr_en:** Active-high single-cycle write request strobe.
* **cfg_slot_idx:** Selects one of the 12 hardware schedule slots. Values 12 through 15 are rejected.
* **cfg_med_id:** Accepts a 4-bit medication identifier input, validates that the value is between 0 and 3, and stores the lower 2 bits in schedule memory. Values 4 through 15 are rejected.
* **cfg_hour:** Scheduled hour in 24-hour format (0 to 23). Values 24 through 31 are rejected.
* **cfg_minute:** Scheduled minute (0 to 59). Values 60 through 63 are rejected.
* **cfg_enable:** Sets the slot active (1) or inactive (0).
* **cfg_error:** Asserted for one clock cycle when cfg_wr_en is high and any input field violates its valid range.

---

## 3. Schedule Slot Record Format (14-Bit Atomic Entry)

Each of the 12 slots in schedule_memory is stored as an atomic 14-bit register updated on a single rising edge of clk.

| Bit Slice | Field Name | Width | Reset Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| [13] | enable | 1 bit | 0 | Slot enabled |
| [12:11] | med_id | 2 bits | 0 | Medication ID |
| [10:6] | hour | 5 bits | 0 | Hour (0-23) |
| [5:0] | minute | 6 bits | 0 | Minute (0-59) |

* **Atomic Update Guarantee:** All 14 bits of a slot register update simultaneously on the rising edge of clk when mem_wr_en is high. Downstream combinational readers (schedule_matcher and peripheral controllers) never observe half-old, half-new field combinations.
* **Post-Reset State:** Asynchronous active-low reset (rst_n = 0) clears all 14 bits of all 12 slots to zero, ensuring every slot is disabled upon reset.

---

## 4. Schedule Memory Slot Map

The register array contains 12 addressable schedule slots indexed by slot_idx (0 to 11), corresponding 1-to-1 with due_vector[11:0].

| Slot Index |Packed Bus Slice | Due Vector Bit | Reset State | Default Status |
| :--- | :--- | :--- | :--- | :--- |
| Slot 0 | [13:0] | due_vector[0] | 0x0000 | Disabled |
| Slot 1 | [27:14] | due_vector[1] | 0x0000 | Disabled |
| Slot 2 | [41:28] | due_vector[2] | 0x0000 | Disabled |
| Slot 3 | [55:42] | due_vector[3] | 0x0000 | Disabled |
| Slot 4 | [69:56] | due_vector[4] | 0x0000 | Disabled |
| Slot 5 | [83:70] | due_vector[5] | 0x0000 | Disabled |
| Slot 6 | [97:84] | due_vector[6] | 0x0000 | Disabled |
| Slot 7 | [111:98] | due_vector[7] | 0x0000 | Disabled |
| Slot 8 | [125:112] | due_vector[8] | 0x0000 | Disabled |
| Slot 9 | [139:126] | due_vector[9] | 0x0000 | Disabled |
| Slot 10 | [153:140] | due_vector[10] | 0x0000 | Disabled |
| Slot 11 | [167:154] | due_vector[11] | 0x0000 | Disabled |

* **Reserved Indices:** Slot indices 12, 13, 14, and 15 are unimplemented reserved indices. Write attempts to indices 12 through 15 are blocked by config_interface and guarded by schedule_memory; combinational indexed reads to indices 12 through 15 return all zeros.

---

## 5. Continuous Parallel Exposure Buses

To support Verilog-2001 port compatibility across all subsystems, schedule_memory exposes all 12 slots continuously in both packed and split formats, plus an indexed combinational read port.

| Output Port | Total Width | Per-Slot Slice Formula | Target Consumer |
| :--- | :--- | :--- | :--- |
| schedule_flat | 168 bits | [slot*14 +: 14] | schedule_matcher |
| slot_en | 12 bits | [slot] | schedule_matcher |
| slot_med_id_flat | 24 bits | [slot*2 +: 2] | peripherals |
| slot_hour_flat | 60 bits | [slot*5 +: 5] | schedule_matcher |
| slot_min_flat | 72 bits | [slot*6 +: 6] | schedule_matcher |

* **Indexed Read Port:** Setting rd_slot_idx[3:0] (e.g., driven by active_slot[3:0] from reminder_controller) combinationally outputs rd_enable, rd_med_id[1:0], rd_hour[4:0], rd_minute[5:0], and rd_record[13:0] with zero clock latency.

---

## 6. Caregiver Telemetry Payload and FIFO Diagnostics

The caregiver interface buffers canonical event pulses in an 8-entry First-Word Fall-Through (FWFT) synchronous FIFO and transmits each event as a 17-bit payload using a valid/ready handshake.

### 6.1 Telemetry Payload Bit Layout (payload[16:0])

| Bit Slice | Field Name | Width | Reset Value | Encoding |
| :--- | :--- | :--- | :--- | :--- |
| [16:15] | event_type | 2 bits | 0 | 1=START, 2=ACK, 3=MISSED |
| [14:11] | event_slot | 4 bits | 0 | Slot index (0-11) |
| [10:6] | cur_hour | 5 bits | 0 | Event hour (0-23) |
| [5:0] | cur_minute | 6 bits | 0 | Event minute (0-59) |

* **Event Type Encoding:**
  * 00: Reserved / Empty FIFO output
  * 01: Reminder Start Event (captured from reminder_start_pulse)
  * 10: Accepted Acknowledgement Event (captured from ack_event_pulse)
  * 11: Missed Reminder Event (captured from missed_event_pulse)
* **Priority Rule:** If ack_event_pulse and missed_event_pulse ever assert on the same clock edge, ACK (10) takes strict priority over MISSED (11).

### 6.2 Caregiver Link and FIFO Status Signals

| Signal Name | Width | Direction | Reset Value | Behaviour |
| :--- | :--- | :--- | :--- | :--- |
| comm_valid | 1 bit | Output | 0 | High when FIFO non-empty |
| comm_ready | 1 bit | Input | N/A | Receiver accept strobe |
| fifo_empty | 1 bit | Output | 1 | High when count is 0 |
| fifo_full | 1 bit | Output | 0 | High when count is 8 |
| fifo_count | 4 bits | Output | 0 | Current occupancy (0-8) |
| fifo_overflow_pulse | 1 bit | Output | 0 | 1-cycle pulse on drop |
| fifo_overflow | 1 bit | Output | 0 | Sticky overflow flag |
| overflow_count | 8 bits | Output | 0 | Saturating drop counter |

---

## 7. Write Rules, Handshake Rules, and Safety Invariants

1. **All-or-Nothing Write Validation:** A configuration write request must satisfy all four boundary conditions simultaneously (cfg_slot_idx <= 11, cfg_med_id <= 3, cfg_hour <= 23, cfg_minute <= 59). If any single field is out of range, mem_wr_en remains 0, cfg_error pulses high for one clock cycle, and schedule_memory remains completely unchanged.
2. **Valid/Ready Payload Stability:** Once caregiver_interface asserts comm_valid = 1, both comm_valid and payload[16:0] remain stable and unchanged across clock cycles until a rising clk edge where comm_valid && comm_ready evaluates to 1.
3. **Non-Blocking Overflow Policy:** When fifo_full = 1 and a new canonical event pulse arrives while comm_ready = 0, caregiver_interface drops the incoming telemetry record, asserts fifo_overflow_pulse for one cycle, latches fifo_overflow = 1, and increments overflow_count (saturating at 255). Existing records inside the FIFO and the record currently in flight on payload[16:0] are never overwritten or corrupted.
