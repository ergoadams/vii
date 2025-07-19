

struct Opcode {
	mut:
		opcode u32
		primary_opcode u32
		extended_opcode u32
		li u32
		spr u32
		d u32
		s u32
		a u32
		sh u32
		mb u32
		me u32
		uimm u32
		simm u32
		aa bool
		lk bool
		rc bool
}

fn (mut o Opcode) set_opcode(opcode u32) {
	o.opcode = opcode
	o.primary_opcode = (opcode >> 26) & 0b111111
	o.extended_opcode = (opcode >> 1) & 0b1111111111
	o.aa = (opcode & 0b10) != 0 
	o.lk = (opcode & 0b01) != 0
	o.rc = (opcode & 0b01) != 0
	o.li = (opcode >> 2) & 0xFFFFFF
	o.spr = (opcode >> 11) & 0b1111111111
	o.d = (opcode >> 21) & 0b11111
	o.s = (opcode >> 21) & 0b11111
	o.a = (opcode >> 16) & 0b11111
	o.sh = (opcode >> 11) & 0b11111
	o.mb = (opcode >> 6) & 0b11111
	o.me = (opcode >> 1) & 0b11111
	o.uimm = opcode & 0xFFFF
	o.simm = opcode & 0xFFFF
}

struct Broadway {
	mut:
		gpr []u32
		fpr []u32
		sr []u32
		spr []u32
		msr u32
		pc u32
		nia u32
		opcode Opcode
		running bool
		logger Logger
		memory Memory
}

fn (mut b Broadway) init(logger Logger, memory Memory) {
	b.logger = logger
	b.logger.log("Broadway init", "Broadway")
	b.memory = memory
	b.opcode = Opcode{}
	b.gpr = []u32{len: 32, init: 0}
	b.fpr = []u32{len: 32, init: 0}
	b.sr = []u32{len: 16, init: 0}
	b.spr = []u32{len: 1024, init: 0}
	b.msr = 0
	b.pc = 0
	b.nia = 0
}

fn (mut b Broadway) set_entry_point(entrypoint u32) {
	b.pc = entrypoint
	b.nia = entrypoint
	b.running = true
}

fn (mut b Broadway) tick() {
	b.pc = b.nia
	b.nia += 4
	b.opcode.set_opcode(b.memory.load32(b.pc))
	b.decode_and_execute()
}