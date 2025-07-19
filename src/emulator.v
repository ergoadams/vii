
// Wii emulator written in V -> Vii

import os

fn main() {
	mut logging_enabled := true
	mut logger := Logger{}
	logger.init(logging_enabled)
	mut dol_name := "dols/triangle.dol"
	if os.args.len == 2 {
		print("Using provided dol path ")
		println(os.args[1])
		dol_name = os.args[1] 
	} else if os.args.len > 2 {
		print("Too many OS args ")
		println(os.args)
	} 
	mut memory := Memory{}
	memory.init(logger)
	entry_point := memory.load_dol(dol_name)
	mut broadway := Broadway{}
	broadway.init(logger, memory)
	broadway.set_entry_point(entry_point)

	for {
		if broadway.running == true {
			broadway.tick()
		} else {
			exit(0)
		}
	}
}