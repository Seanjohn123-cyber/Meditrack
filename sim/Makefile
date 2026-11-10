# MediTrack Simulation Makefile
IVERILOG = iverilog -g2012
VVP = vvp
BUILD_DIR = build

.PHONY: all clean unit_tests tb_reminder_controller tb_acknowledgement_unit tb_missed_dose_detector

all: unit_tests

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

tb_acknowledgement_unit: $(BUILD_DIR)
	$(IVERILOG) -o $(BUILD_DIR)/tb_acknowledgement_unit.vvp ../rtl/reminder/acknowledgement_unit.v ../tb/unit/tb_acknowledgement_unit.v
	$(VVP) $(BUILD_DIR)/tb_acknowledgement_unit.vvp

tb_missed_dose_detector: $(BUILD_DIR)
	$(IVERILOG) -o $(BUILD_DIR)/tb_missed_dose_detector.vvp ../rtl/reminder/missed_dose_detector.v ../tb/unit/tb_missed_dose_detector.v
	$(VVP) $(BUILD_DIR)/tb_missed_dose_detector.vvp

tb_reminder_controller: $(BUILD_DIR)
	$(IVERILOG) -o $(BUILD_DIR)/tb_reminder_controller.vvp ../rtl/reminder/reminder_controller.v ../tb/unit/tb_reminder_controller.v
	$(VVP) $(BUILD_DIR)/tb_reminder_controller.vvp

unit_tests: tb_acknowledgement_unit tb_missed_dose_detector tb_reminder_controller

clean:
	rm -rf $(BUILD_DIR) *.vcd *.vvp
