
// Wii emulator written in V -> Vii

import os

fn main() {
	mut logger := Logger{}
	logging_enabled := false
	tracing_enabled := false
	logger.init(logging_enabled, tracing_enabled)

	mut dol_name := "dols/triangle.dol"
	if os.args.len == 2 {
		print("Using provided dol path ")
		println(os.args[1])
		dol_name = os.args[1] 
	} else if os.args.len > 2 {
		print("Too many OS args ")
		println(os.args)
	} 

	mut memory := Memory{logger: 0}
	memory.init(&logger)

	entry_point := memory.load_dol(dol_name)
	//memory.dump_memory()

	mut broadway := PPC{memory: 0, logger: 0}
	broadway.init(&memory, &logger)
	broadway.set_entry_point(entry_point)
	logger.log("Begin execution", "Broadway")

	for {
		if broadway.running == true {
			broadway.tick()
		} else {
			exit(0)
		}
	}
}