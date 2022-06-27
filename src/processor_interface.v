

struct Processor {
	mut:
		interrupt_cause u32
		interrupt_mask u32
}

fn (mut p Processor) load32(address u32) u32 {
	match address {
		0xCC003000 { return p.interrupt_cause }
		0xCC00302C { return 0xffffffff } // bits 28-31 console type?
		else { panic("Unhandled processor load32 ${address:08x}") }
	}
}

fn (mut p Processor) store32(address u32, value u32) {
	match address {
		0xCC003000 { p.interrupt_cause = value & u32(0xFFFEFFFF) } // Interrupt cause, bit 16 is reset switch state
		0xCC003004 { p.interrupt_mask = value } // Interrupt mask
		else { panic("Unhandled processor store32 ${address:08x}") }
	}
}