# MediTrack Implementation Plan & Git Workflow

## 1. Five-Person Division of Ownership
- **Person 1:** Configuration & Caregiver Communication (`feature/person1-config-comm`)
- **Person 2:** Timing & Schedule Matching (`feature/person2-timing`)
- **Person 3:** Event Queue & Event Accounting (`feature/person3-events`)
- **Person 4 (Lead):** Reminder Lifecycle & Acknowledgement (`feature/person4-reminder` & `main` guardian)
- **Person 5:** Peripherals & Synthesis Lead (`feature/person5-peripherals`)

## 2. Seven-Day Schedule
- **Day 1:** Interface contracts frozen, repository initialized, base docs established.
- **Day 2:** RTL implementations committed by all members on feature branches.
- **Day 3:** Unit testbenches completed and passing.
- **Day 4:** Integration into `rtl/top/medi_soc_top.v` and smoke test verification.
- **Day 5:** Full system verification and edge case validation.
- **Day 6:** Yosys synthesis, preliminary OpenROAD physical design, documentation review.
- **Day 7:** Demonstration, waveform reviews, final presentation.
