# Person 5 -- Peripheral interfaces
(Paste into the peripheral sections of docs/module_interfaces.md. Values below are the TBD-D1 proposals; edit to match what the team freezes on Day 1.)

Common: `clk`, `rst_n` (active-low, asynchronous). Notifications are one-cycle pulses. These modules consume only `reminder_active` and `active_slot` (Person 4) and the compartment request; they never touch `ack_pulse`, `timeout_pulse`, any event pulse, the queue or the counters.

## compartment_controller
| Port | Dir | Width | Meaning |
|---|---|---|---|
| clk, rst_n | in | 1 | clock, async active-low reset |
| req_valid | in | 1 | compartment request (sampled on clk edge) |
| req_slot | in | 4 | requested slot, valid 0..NUM_SLOTS-1 |
| relock_req | in | 1 | optional early relock |
| unlock | out | NUM_SLOTS | zero or one-hot unlock lines |
| unlock_active | out | 1 | a compartment is open |
| invalid_pulse | out | 1 | one cycle: slot out of range |
| reject_pulse | out | 1 | one cycle: request while one is open |

Parameters: `NUM_SLOTS` (12), `UNLOCK_CYCLES` (16, >= 1).
Lock policy: all locked after reset; at most one unlocked; a second request while open is rejected and the open slot is unchanged; auto-relock after UNLOCK_CYCLES or on relock_req. Unlocking is access only: not an acknowledgement, no proof of ingestion.
Reset: all compartments locked, pulses cleared.

## display_controller
| Port | Dir | Width | Meaning |
|---|---|---|---|
| reminder_active | in | 1 | from Person 4 |
| active_slot | in | 4 | from Person 4; meaningful while active |
| display_active | out | 1 | 1 = reminder active, 0 = idle |
| display_slot | out | 4 | active_slot while active, 4'hF while idle |
| display_seg | out | 7 | {a,b,c,d,e,f,g} active-high hex digit; blank when idle |

Combinational, no state. Idle display: display_active=0, display_slot=F, segments blank. Reset: reminder_active is 0 during reset, so idle. Only active/idle exist; acknowledged/missed are not visible to this module.

## alert_controller
| Port | Dir | Width | Meaning |
|---|---|---|---|
| clk, rst_n | in | 1 | used only when BLINK_EN=1 |
| reminder_active | in | 1 | from Person 4 |
| buzzer, led | out | 1 | on while reminder_active is high |

Parameters: `BLINK_EN` (0 = steady, no state), `BLINK_HALF_PERIOD` (8). Blink pattern starts high when a reminder starts and clears on reset or when reminder_active drops.
