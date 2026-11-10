# MediTrack: Processor-Free Medication Reminder SoC

MediTrack is a digital System-on-Chip (SoC) designed in Verilog HDL for reliable, human-centred medication reminder and compartment access management. It is designed to operate offline-first with zero software or network dependency for core life-safety reminders, while offering an asynchronous telemetry channel for remote caregiver monitoring.

## Key Features
- **15 Configurable Schedule Slots:** Supporting 4 medication IDs with programmable hours and minutes (slots 0 to 14).
- **Hardware Schedule Matcher:** Compares real-time clock counter with enabled schedule records.
- **Simultaneous Event Queue:** Safely buffers and arbitrates concurrent dose events.
- **Reminder State Machine:** Orchestrates reminder lifecycle, user alerts, and strict priority arbitration.
- **Debounced Acknowledgement Unit:** Synchronizes and debounces physical button inputs.
- **Deterministic Timeout Detector:** Triggers missed reminder events after configurable idle intervals.
- **Peripheral Access Control:** Safe single-compartment unlock logic and visual/audible alarms.
- **Isolated Caregiver Interface:** Telemetry FIFO prevents external backpressure from impacting local timing.

## Team Architecture & Ownership
- **Person 1:** Configuration Interface, Schedule Memory, Caregiver Interface.
- **Person 2:** Timer Unit, Schedule Matcher, Simulation Automation.
- **Person 3:** Event Queue, Dose Tracker, System Testbench Coordination.
- **Person 4 (Team Lead):** Reminder Controller, Acknowledgement Unit, Missed Dose Detector, Master Verification Coordination.
- **Person 5:** Compartment Controller, Display Controller, Alert Controller, Synthesis & Physical Design Lead.

## Directory Structure
```
MediTrack/
├── docs/                # Architecture, interface contracts, verification plans
├── rtl/                 # Verilog RTL source files organized by subsystem
│   ├── top/             # Top-level SoC wrapper (medi_soc_top.v)
│   ├── configuration/   # Config bus & schedule memory
│   ├── timing/          # Timer & matcher
│   ├── events/          # FIFO queue & accounting tracker
│   ├── reminder/        # Reminder controller, debouncer, timeout detector
│   ├── peripherals/     # Compartment lock, display, and alert drivers
│   └── communication/   # Caregiver telemetry interface
├── tb/                  # Testbenches
│   ├── unit/            # Module-level unit testbenches
│   └── system/          # Top-level integration testbenches
├── sim/                 # Simulation makefiles and configuration
├── scripts/             # Automated test runners (Linux .sh & Windows .bat)
├── synthesis/           # Yosys synthesis scripts and reports
└── physical_design/     # Constraints and preliminary OpenROAD configs
```

## Running Simulations
Ensure [Icarus Verilog](http://iverilog.icarus.com/) and [GTKWave](http://gtkwave.sourceforge.net/) are installed.

### On Windows:
```cmd
scripts\run_tests.bat
```

### On Linux / macOS:
```bash
chmod +x scripts/*.sh
./scripts/run_tests.sh
```
