# MediTrack System Requirements

## Functional Requirements
- **FR-01:** Support storage for up to 4 medication types (2-bit ID).
- **FR-02:** Support 15 configurable schedule slots (4-bit slot index 0–14).
- **FR-03:** Support time setting and minute boundary detection.
- **FR-04:** Reject invalid configuration (hour > 23, minute > 59, slot >= 15).
- **FR-05:** Match schedule times on minute ticks and assert due pulses via a 15-bit vector (`due_vector[14:0]`).
- **FR-06:** Enqueue multiple simultaneous due events without loss.
- **FR-07:** Sequential presentation of queued events to reminder controller.
- **FR-08:** Audible and visual alert signaling during active reminders.
- **FR-09:** Debounced button acknowledgement terminating active reminder.
- **FR-10:** Timeout detection generating missed reminder events.
- **FR-11:** Strict priority rule: acknowledgement beats timeout on identical clock cycles.
- **FR-12:** Event accounting counting start, ack, and missed occurrences.
- **FR-13:** Controlled compartment access: at most one door unlocked at a time.
- **FR-14:** Caregiver event telemetry via valid/ready handshake.
- **FR-15:** Complete isolation: telemetry link stalls cannot stall local reminder operations.
- **FR-16:** Predictable safe reset state across all registers.
