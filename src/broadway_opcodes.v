
fn (mut b Broadway) bx() {
	if b.opcode.aa {
		b.nia = exts26(b.opcode.li << 2)
	} else {
		b.nia = b.pc + exts26(b.opcode.li << 2)
	}
	if b.opcode.lk {
		b.spr[8] = b.pc + 4
	}
}

fn (mut b Broadway) rlwinmx() {
	n := b.opcode.sh
	r := rotl(b.gpr[b.opcode.s], n)
	m := mask(b.opcode.mb, b.opcode.me)
	b.gpr[b.opcode.a] = r & m
	if b.opcode.rc {
		b.logger.log("rlwinmx should set cr0", "Warning")
	}
}

fn (mut b Broadway) ori() {
	b.gpr[b.opcode.a] = b.gpr[b.opcode.s] | b.opcode.uimm
}

fn (mut b Broadway) oris() {
	b.gpr[b.opcode.a] = b.gpr[b.opcode.s] | (b.opcode.uimm << 16)
}

fn (mut b Broadway) addis() {
	b.gpr[b.opcode.d] = b.opcode.simm << 16
	if b.opcode.a != 0 {
		b.gpr[b.opcode.d] += b.gpr[b.opcode.a]
	}
}

fn (mut b Broadway) mfmsr() {
	b.gpr[b.opcode.d] = b.msr
}

fn (mut b Broadway) mfspr() {
	n := ((b.opcode.spr & 0b11111) << 5) | ((b.opcode.spr >> 5) & 0b11111)
	b.gpr[b.opcode.d] = b.spr[n]
}

fn (mut b Broadway) mtspr() {
	n := ((b.opcode.spr & 0b11111) << 5) | ((b.opcode.spr >> 5) & 0b11111)
	b.spr[n] = b.gpr[b.opcode.s]
}

fn (mut b Broadway) decode_and_execute() {
	match b.opcode.primary_opcode {
		0b010010 { b.bx() }
		0b010101 { b.rlwinmx() }
		0b011000 { b.ori() }
		0b011001 { b.oris() }
		0b001111 { b.addis() }
		0b011111 {
			match b.opcode.extended_opcode {
				0b0001010011 { b.mfmsr() }
				0b0101010011 { b.mfspr() }
				0b0111010011 { b.mtspr() }
				else {
					b.logger.log("Unhandled 0b011111 extended opcode 0b${b.opcode.extended_opcode:010b}", "Critical")
					b.running = false
				}
			}
		} else {
			b.logger.log("Unhandled primary opcode 0b${b.opcode.primary_opcode:06b}", "Critical")
			b.running = false
		}
	}
}