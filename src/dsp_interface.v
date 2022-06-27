

struct Dsp_csr {
	mut:
		value u16
		dspintstat u16
		dspintmsk u16
		dspint u16
		arintmsk u16
		arint u16
		aidintmask u16
		aidint u16
		halt u16
		piint u16
		res u16
}

fn (mut c Dsp_csr) set_value(value u16) {
	if value & 1 != 0 {
		println("Dsp should reset")
	}
	c.value = value & ~u16(1)
}

struct Dsp {
	mut:
		csr Dsp_csr
		ar_size u16
		ar_dma_mmaddr u32
		ar_dma_araddr u32
		ar_dma_cnt u32
		dsp_mailbox_hi u16
		dsp_mailbox_lo u16
		cpu_mailbox_hi u16
		cpu_mailbox_lo u16
}

fn (mut d Dsp) init() {
	d.cpu_mailbox_hi = 0x8000
	d.csr.set_value(0x500A)
}

fn (mut d Dsp) load16(address u32) u16 {
	match address {
		0xCC005004 { 
			value := d.cpu_mailbox_hi
			d.cpu_mailbox_hi ^= 0x8000
			return value }
		0xCC005006 { return d.cpu_mailbox_lo }
		0xCC00500A { 
			value := d.csr.value
			d.csr.value ^= 0x8000
			return value }
		0xCC005012 { return d.ar_size }
		else { panic("Unhandled dsp load16 address ${address:08x}") }
	}
}

fn (mut d Dsp) store32(address u32, value u32) {
	match address {
		0xCC005020 { d.ar_dma_mmaddr = value }
		0xCC005024 { d.ar_dma_araddr = value }
		0xCC005028 { d.ar_dma_cnt = value }
		else { panic("Unhandled dsp store32 address ${address:08x}") }
	}
}

fn (mut d Dsp) store16(address u32, value u16) {
	match address {
		0xCC005000 { d.dsp_mailbox_hi = value }
		0xCC00500A { d.csr.set_value(value) }
		0xCC005012 { d.ar_size = value }
		else { panic("Unhandled dsp store16 address ${address:08x}") }
	}
}