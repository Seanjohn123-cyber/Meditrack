# MediTrack Register Map & Memory Layout

## 1. Schedule Memory Layout (Slots 0 to 11)
Each slot register consists of 14 bits:
- `[13]`: Slot Enable (`1` = active schedule, `0` = disabled)
- `[12:11]`: Medication ID (`0` to `3`)
- `[10:6]`: Scheduled Hour (`0` to `23`, 5 bits)
- `[5:0]`: Scheduled Minute (`0` to `59`, 6 bits)

## 2. Event Codes (Telemetry & Tracker)
- `2'b00`: Reminder Start
- `2'b01`: Acknowledged
- `2'b10`: Missed (Timeout)
- `2'b11`: Reserved
