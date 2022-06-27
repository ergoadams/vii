

struct Cr {
	mut:
		value u32
		tlen u32
		rw u32
		transfer_mode_dma bool
		tstart bool
}

fn (mut e External) set_cr_value(value u32, channel u32) {
	e.channels[channel].cr.value = value
	e.channels[channel].cr.tlen = ((value >> 4) & 3) + 1
	e.channels[channel].cr.rw = (value >> 2) & 3
	e.channels[channel].cr.transfer_mode_dma = (value & 2) != 0
	e.channels[channel].cr.tstart = (value & 1) != 0
	if e.channels[channel].cr.tstart {
		if e.channels[channel].cr.transfer_mode_dma == true {
			//println("Unhandled external dma transfer start")
		} else {
			/*println("Unhandled external immediate transfer start")
			println("RW ${e.channels[channel].cr.rw}, TLEN ${e.channels[channel].cr.tlen}")
			println("CS ${e.channels[channel].csr.cs}, CHANNEL ${channel}")
			println("FREQ ${e.channels[channel].csr.clk}, ADDR ${e.channels[channel].mar:08x}" )
			println("DATA ${e.channels[channel].data:08x}")*/
		}
	}
}

struct Ext_csr {
	mut:
		value u32
		romdis bool
		extins bool
		extinsint bool
		extinsintmask bool
		cs u32
		clk u32
		tcint bool
		tcintmask bool
		extint bool
		exintmask bool
}

fn (mut e Ext_csr) set_value(value u32) {
	e.value = value
	e.romdis = (value >> 13) != 0
	if (value >> 12) != 0 {
		e.extins = false
	}
	e.extinsint = (value >> 11) != 0
	e.extinsintmask = (value >> 10) != 0
	e.cs = (value >> 7) & 0x7
	e.clk = (value >> 4) & 0x7
	if (value >> 3) != 0 {
		e.tcint = false
	}
	e.tcintmask = (value >> 2) != 0
	if (value >> 1) != 0 {
		e.extint = false
	}
	e.exintmask = (value >> 0) != 0
}

fn (mut e Ext_csr) get_value() u32 {
	e.value &= ~u32(0x3FFF)
	if e.romdis == true {
		e.value |= 1 << 13
	}
	if e.extins == true {
		e.value |= 1 << 12
	}
	if e.extinsint == true {
		e.value |= 1 << 11
	}
	if e.extinsintmask == true {
		e.value |= 1 << 10
	}
	e.value |= e.cs << 7
	e.value |= e.clk << 4
	if e.tcint == true {
		e.value |= 1 << 3
	}
	if e.tcintmask == true {
		e.value |= 1 << 2
	}
	if e.extint == true {
		e.value |= 1 << 1
	}
	if e.exintmask == true {
		e.value |= 1 << 0
	}
	return e.value
}

struct Channel {
	mut:
		value u32
		csr Ext_csr
		cr Cr
		data u32
		length u32
		mar u32
}

struct External {
	mut:
		channels []Channel
}

fn (mut e External) init() {
	e.channels = []Channel{len: 3}
}

fn (mut e External) load32(address u32) u32 {
	return 0
	/*match address & 0xCC00683F {
		0xCC006800 { return e.channels[0].csr.get_value() }
		0xCC006814 { return e.channels[1].csr.get_value() }
		0xCC006828 { return e.channels[2].csr.get_value() }
		0xCC00680C { return e.channels[0].cr.value }
		0xCC006820 { return e.channels[1].cr.value }
		0xCC006834 { return e.channels[2].cr.value }
		0xCC006810 { return e.channels[0].data }
		0xCC006824 { return e.channels[1].data }
		0xCC006838 { return e.channels[2].data }
		0xCC006808 { return e.channels[0].length }
		0xCC00681C { return e.channels[1].length }
		0xCC006830 { return e.channels[2].length }
		else { panic("Unhandled external load32 ${address & 0xCC00683F:08x}") }
	}*/
}

fn (mut e External) store32(address u32, value u32) {
	match address & 0xCC00683F {

		0xCC006800 { e.channels[0].csr.set_value(value) }
		0xCC006814 { e.channels[1].csr.set_value(value) }
		0xCC006828 { e.channels[2].csr.set_value(value) }
		0xCC00680C { e.set_cr_value(value, 0) }
		0xCC006820 { e.set_cr_value(value, 1) }
		0xCC006834 { e.set_cr_value(value, 2) }
		0xCC006810 { e.channels[0].data = value }
		0xCC006824 { e.channels[1].data = value }
		0xCC006838 { e.channels[2].data = value }
		0xCC006804 { e.channels[0].mar = value }
		0xCC006818 { e.channels[1].mar = value }
		0xCC00682C { e.channels[2].mar = value }
		0xCC006808 { e.channels[0].length = value }
		0xCC00681C { e.channels[1].length = value }
		0xCC006830 { e.channels[2].length = value }
		else { panic("Unhandled external store32 ${address & 0xCC00683F:08x}") }
	}
	
}