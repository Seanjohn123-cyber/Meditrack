# MediTrack System Overview

MediTrack is a processor-free medication reminder System-on-Chip (SoC) prototype designed for reliable, human-centred healthcare support.

## Core Tenets
1. **Processor-Free & Offline-First:** Core reminder scheduling and user interaction require no CPU, operating system, or active internet connection.
2. **Single Responsibility Architecture:** Each functional block has one owner. No module duplicates state or recreates events from other blocks.
3. **Deterministic Event Communication:** Notifications are single-cycle active-high pulses. Queues never silently drop events. Caregiver backpressure never blocks local reminder operation.
4. **Safety & Realism:** The system is an engineering prototype for reminders and access management. It does not calculate dosages or claim clinical validation of medication ingestion.
