import math

fn (mut p PPC) op_blank() {

}

fn (p PPC) get_sprs(reg u32) u32 {
	match reg {
		1 { return p.xer.get_value() }
		else { return p.sprs[reg] }
	}
}

fn (mut p PPC) set_sprs(reg u32, value u32) {
	match reg {
		1 { p.xer.set_value(value) }
		else { p.sprs[reg] = value }
	}
}

fn (mut p PPC) set_conditions(result u32, reg u32) {
	p.cr &= ~(0b1111 << ((7 - reg)*4))

	res := int(result)
	if res < 0 {
		p.cr |= (1 << (31 - (4*reg)))
	} else if res > 0 {
		p.cr |= (1 << (30 - (4*reg)))
	} else {
		p.cr |= (1 << (29 - (4*reg)))
	}
	p.cr |= (p.get_sprs(xer_r) >> 31) << (28 - (4*reg))
}

fn (mut p PPC) set_conditions_cmp(a u32, b u32, reg u32, signed bool) {
	p.cr &= ~(0b1111 << ((7 - reg)*4))
	if signed == true {
		if int(a) < int(b) {
			p.cr |= (1 << (31 - (4*reg)))
		} else if int(a) > int(b) {
			p.cr |= (1 << (30 - (4*reg)))
		} else {
			p.cr |= (1 << (29 - (4*reg)))
		}
		p.cr |= (p.get_sprs(xer_r) >> 31) << (28 - (4*reg))
	} else {
		if a < b {
			p.cr |= (1 << (31 - (4*reg)))
		} else if a > b {
			p.cr |= (1 << (30 - (4*reg)))
		} else {
			p.cr |= (1 << (29 - (4*reg)))
		}
		p.cr |= (p.get_sprs(xer_r) >> 31) << (28 - (4*reg))
	}
}


fn (mut p PPC) dequantized(mem u32, lt u32, ls u32) f32 {
	return f32(mem) * math.powf(2, -1*p.scaling_factor[ls])
}

fn (mut p PPC) exception(exception_type Exception) {
	match exception_type {
		.syscall {
			p.set_sprs(srr0_r, p.pc)
			p.set_sprs(srr1_r, p.msr.value & 0x87C0FFFF)

            p.msr.set_value(p.msr.value & ~u32(1))
            if (p.msr.value & (1 << 16)) != 0 {
                p.msr.set_value(p.msr.value | 1)
			}

            p.msr.set_value(p.msr.value & ~u32(0x04EF36))
            p.pc = 0x00000C00
		}
		// else { p.logger.log("Unhandled exception type ${exception_type}", "Critical") }
	}
}

fn (mut p PPC) op_ps_mr() {
	d := p.opcode.b6_10
	b := p.opcode.b16_20
	rc := p.opcode.b31
	p.fprs[d].ps0 = p.fprs[b].ps0
	p.fprs[d].ps1 = p.fprs[b].ps1
	if rc == true {
		p.logger.log("ps_mr should set conditions", "Critical")
	}
}

fn (mut p PPC) op_mulli() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	simm := p.opcode.b16_31
    result := u64(i64(int(p.gprs[a])) * i64(int(simm)))
	p.gprs[d] = u32(result & 0xffffffff)
}

fn (mut p PPC) op_subfic() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	simm := p.opcode.b16_31
	result := u64(~p.gprs[a]) + u64(exts16(simm)) + 1
    p.gprs[d] = u32(result & 0xffffffff)
	p.xer.ca = p.gprs[d] < result
}

fn (mut p PPC) op_cmpli() {
	crfd := p.opcode.b6_10 >> 2
	a := p.gprs[p.opcode.b11_15]
	uimm := p.opcode.b16_31
	p.set_conditions_cmp(a, uimm, crfd, false)
}

fn (mut p PPC) op_cmpi() {
	crfd := p.opcode.b6_10 >> 2
	a := p.gprs[p.opcode.b11_15]
	simm := exts16(p.opcode.b16_31)
	p.logger.log("Comparing ${a:08x}(reg ${p.opcode.b11_15}) to ${simm:08x}", "Args")
	p.set_conditions_cmp(a, simm, crfd, true)
}

fn (mut p PPC) op_addic() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	simm := p.opcode.b16_31
	result := u64(p.gprs[a]) + u64(exts16(simm))
	p.gprs[d] = p.gprs[a] + exts16(simm)
	p.xer.ca = p.gprs[d] < result
}

fn (mut p PPC) op_addicr() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	simm := p.opcode.b16_31
	result := u64(p.gprs[a]) + u64(exts16(simm))
	p.gprs[d] = p.gprs[a] + exts16(simm)
	p.set_conditions(p.gprs[d], 0)
	p.xer.ca = p.gprs[d] < result
}

fn (mut p PPC) op_addi() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	simm := p.opcode.b16_31
	mut value := exts16(simm)
	if a != 0 {
		value += p.gprs[a]
	}
	p.logger.log("${simm:08x} " + if a != 0 {"+ ${p.gprs[a]:08x}(reg ${a})"} else {""} + " = ${value:08x}(stored to reg ${d})", "Args")
	p.gprs[d] = value
}

fn (mut p PPC) op_addis() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	simm := p.opcode.b16_31
	mut value := simm << 16
	if a != 0 {
		value += p.gprs[a]
	}
	p.logger.log("${simm << 16:08x} " + if a != 0 {"${p.gprs[a]:08x}(reg ${a})"} else {""} + " = ${value:08x}(stored to reg ${d})", "Args")
	p.gprs[d] = value
}

fn (mut p PPC) op_bx() {
	lk := p.opcode.b31
	aa := p.opcode.b30
	li := p.opcode.b6_29
	cur_pc := p.pc
	if lk == true {
		p.set_sprs(lr_r, cur_pc)
		p.logger.log("Writing pc ${cur_pc:08x} to LR", "Args")
	}
	p.pc = exts26(li)
	if aa == false {
		p.pc += cur_pc - 4
	}
	p.logger.log("New pc ${p.pc:08x}", "Args")
}

fn (mut p PPC) op_ori() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	uimm := p.opcode.b16_31
	p.logger.log("${p.gprs[s]:08x}(reg ${s}) | ${uimm:08x} = ${p.gprs[s] | uimm:08x}(stored to reg ${a})", "Args")
	p.gprs[a] = p.gprs[s] | uimm
}

fn (mut p PPC) op_oris() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	uimm := p.opcode.b16_31
	p.logger.log("${p.gprs[s]:08x}(reg ${s}) | ${(uimm << 16):08x} = ${p.gprs[s] | (uimm << 16):08x}(stored to reg ${a})", "Args")
	p.gprs[a] = p.gprs[s] | (uimm << 16)
}

fn (mut p PPC) op_xori() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	uimm := p.opcode.b16_31
	p.gprs[a] = p.gprs[s] ^ uimm
}

fn (mut p PPC) op_bcx() {
	bo := p.opcode.b6_10
	bi := p.opcode.b11_15
	bd := p.opcode.b16_29
	lk := p.opcode.b31
	aa := p.opcode.b30

	if (bo & 0b00100) == 0 {
        p.set_sprs(ctr_r, p.get_sprs(ctr_r) - 1)
	}
	ctr_ok := ((bo & 0b00100) != 0) || ((p.get_sprs(ctr_r) != 0) != ((bo & 0b00010) != 0))
    current_cr := (p.cr & (1 << (31 - bi))) != 0
    cond_ok := ((bo & 0b10000) != 0) || (current_cr == ((bo & 0b01000) != 0))
	p.logger.log("ctr_ok ${ctr_ok}, current_cr ${current_cr}, cond_ok ${cond_ok}", "Args")
    if (ctr_ok == true) && (cond_ok == true){
		cur_pc := p.pc
		p.pc = exts16(bd << 2)
        if aa == false {
			p.pc += cur_pc - 4
		}
        if lk == true {
            p.set_sprs(lr_r, cur_pc)
			p.logger.log("Linking to ${cur_pc:08x}", "Args")
		}

		p.logger.log("Setting pc to ${p.pc:08x}", "Args")
	}
}

fn (mut p PPC) op_sc() {
	p.exception(Exception.syscall)
}

fn (mut p PPC) op_bclrx() {
	bo := p.opcode.b6_10
	bi := p.opcode.b11_15
	lk := p.opcode.b31

    if (bo & 0b00100) == 0{
        p.set_sprs(ctr_r, p.get_sprs(ctr_r) - 1)
	}

    ctr_ok := ((bo & 0b00100) != 0) || ((p.get_sprs(ctr_r) != 0) != ((bo & 0b00010) != 0))
    current_cr := (p.cr & (1 << (31 - bi))) != 0
    cond_ok := ((bo & 0b10000) != 0) || (current_cr == ((bo & 0b01000) != 0))
	p.logger.log("ctr_ok ${ctr_ok}, current_cr ${current_cr}, cond_ok ${cond_ok}", "Args")
    if (ctr_ok == true) && (cond_ok == true) {
		cur_pc := p.pc
		p.pc = (p.get_sprs(lr_r) >> 2) << 2
		p.logger.log("Setting pc to ${p.pc:08x}", "Args")
        if lk == true {
			p.logger.log("Linking to ${cur_pc:08x}", "Args")
            p.set_sprs(lr_r, cur_pc)
		}
	}
}

fn (mut p PPC) op_rfi() {
	mask := u32(0x87C0FFFF)
	p.msr.set_value(((p.msr.value & ~mask) | (p.get_sprs(srr1_r) & mask)) & 0xFFFBFFFF)
	p.pc = (p.get_sprs(srr0_r) >> 2) << 2
	p.logger.log("New pc ${p.pc:08x}", "Args")
}

fn (mut p PPC) op_isync() {
    // Nothing for us right now
}

fn (mut p PPC) op_bcctrx() {
	bo := p.opcode.b6_10
	bi := p.opcode.b11_15
	lk := p.opcode.b31
	current_cr := (p.cr & (1 << (31 - bi))) != 0
    cond_ok := ((bo & 0b10000) != 0) || (current_cr == ((bo & 0b01000) != 0))
	if cond_ok == true {
		if lk == true {
			p.set_sprs(lr_r, p.pc)
		}
		p.pc = p.get_sprs(ctr_r) << 2
	}
}

fn (mut p PPC) op_srawx() {
    s := p.opcode.b6_10
    a := p.opcode.b11_15
    sh := p.opcode.b16_20
	rc := p.opcode.b31
	r := rotl(p.gprs[s], 32 - sh)
	m := mask(sh, 31)
	mut s2 := p.gprs[s] >> 31
	for i in 1..32 {
		s2 |= ((s2 & 1) << i)
	}
	p.gprs[a] = (r & m) | (s2 & ~m)
	p.xer.ca = s2 & (r & ~m) != 0
	if rc == true {
		p.set_conditions(p.gprs[a], 0)
	}
}

fn (mut p PPC) op_srawix() {
    s := p.opcode.b6_10
    a := p.opcode.b11_15
    b := p.opcode.b16_20
	rc := p.opcode.b31
	n := p.gprs[b] & 0b11111
	r := rotl(p.gprs[s], 32 - n)
	m := mask(n, 31)
	mut s2 := p.gprs[s] >> 31
	for i in 1..32 {
		s2 |= ((s2 & 1) << i)
	}
	p.gprs[a] = (r & m) | (s2 & ~m)
	p.xer.ca = ((s2 & 1) != 0) && ((r & ~m) != 0)
	if rc == true {
		p.set_conditions(p.gprs[a], 0)
	}
}

fn (mut p PPC) op_rlwimix() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	sh := p.opcode.b16_20
	mb := p.opcode.b21_25
	me := p.opcode.b26_30
	rc := p.opcode.b31
    r := rotl(p.gprs[s], sh)
	m := mask(mb, me)
	p.gprs[a] = (r & m) | (p.gprs[a] & ~m)
	if rc == true {
		p.set_conditions(p.gprs[a], 0)
	}
}

fn (mut p PPC) op_rlwinmx() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	sh := p.opcode.b16_20
	mb := p.opcode.b21_25
	me := p.opcode.b26_30
	rc := p.opcode.b31
    r := rotl(p.gprs[s], sh)
	m := mask(mb, me)
	p.logger.log("rotl ${p.gprs[s]:08x} by ${sh} = ${r:08x}", "Args")
	p.logger.log("mask ${mb} to ${me} = ${m:08x}", "Args")
	p.gprs[a] = r & m
	p.logger.log("${r:08x} & ${m:08x} = ${p.gprs[a]:08x}(reg ${a})", "Args")
	if rc == true {
		p.set_conditions(r & m, 0)
		p.logger.log("Setting conditions", "Args")
	}
}

fn (mut p PPC) op_andi() {
	s := p.opcode.b6_10
	a :=p.opcode.b11_15
	uimm := p.opcode.b16_31
	p.gprs[a] = p.gprs[s] & uimm
	p.logger.log("${p.gprs[s]:08x} & ${uimm:08x} = ${p.gprs[a]:08x}(reg ${a})", "Args")
	p.set_conditions(p.gprs[a], 0)
	p.logger.log("Setting conditions", "Args")
}

fn (mut p PPC) op_cmp() {
	a := p.gprs[p.opcode.b11_15]
	b := p.gprs[p.opcode.b16_20]
	crfd := p.opcode.b6_10 >> 2
	p.set_conditions(u32(int(a) - int(b)), crfd)
}

fn (mut p PPC) op_subfcx() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	b := p.opcode.b6_10
	oe := ((p.opcode.b21_25 >> 4) & 1) != 0
	rc := p.opcode.b31
	result := u64(~p.gprs[a]) + u64(p.gprs[b]) + 1
	p.gprs[d] = ~p.gprs[a] + p.gprs[b] + 1
	p.xer.ca = p.gprs[d] < result
	if oe == true {
		p.xer.ov = (result >> 32) != ((result + 1) >> 32)
		if p.xer.ov == true {
			p.xer.so = true
		}
	}
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
}

fn (mut p PPC) op_addcx() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	b := p.opcode.b6_10
	oe := ((p.opcode.b21_25 >> 4) & 1) != 0
	rc := p.opcode.b31
	result := u64(p.gprs[a]) + u64(p.gprs[b])
	p.gprs[d] = p.gprs[a] + p.gprs[b]
	p.xer.ca = p.gprs[d] < result
	if oe == true {
		if oe == true {
		p.xer.ov = (result >> 32) != ((result + 1) >> 32)
		if p.xer.ov == true {
			p.xer.so = true
		}
	}
	}
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
}

fn (mut p PPC) op_mulhwux() {
	d := p.opcode.b6_10
	p.gprs[d] = p.cr
}

fn (mut p PPC) op_mfcr() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	rc := p.opcode.b31
	result := u64(p.gprs[a]) * u64(p.gprs[b])
	p.gprs[d] = u32(result >> 32)
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
}

fn (mut p PPC) op_lwzx() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	mut addr := p.gprs[b]
	if a != 0 {
		addr += p.gprs[a]
	}
	p.gprs[d] = p.memory.load32(addr)
	p.logger.log("Loading ${p.gprs[d]:08x}(stored to reg ${d}) from address ${addr:08x}", "Args")
}

fn (mut p PPC) op_slwx() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	rc := p.opcode.b31
	n := p.gprs[b] & 0b11111
	p.gprs[a] = p.gprs[s] << n
	if rc == true {
		p.set_conditions(p.gprs[a], 0)
	}
}

fn (mut p PPC) op_cntlzwx() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	rc := p.opcode.b31
	mut count := u32(0)
	for n in 0..32 {
		if (p.gprs[s] & (1 << (31 - n))) == 1 {
			break
		}
		count += 1
	}
	p.gprs[a] = count
	if rc == true {
		p.set_conditions(count, 0)
	}
}

fn (mut p PPC) op_andx() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	rc := p.opcode.b31
	p.gprs[a] = p.gprs[s] & p.gprs[b]
	p.logger.log("${p.gprs[s]:08x}(reg ${s}) & ${p.gprs[b]:08x}(reg ${b}) = ${p.gprs[a]:08x}(reg ${a})", "Args")
	if rc == true {
		p.set_conditions(p.gprs[a], 0)	
		p.logger.log("Setting conditions", "Args")
	}
}

fn (mut p PPC) op_cmpl() {
	a := p.gprs[p.opcode.b11_15]
	b := p.gprs[p.opcode.b16_20]
	crfd := p.opcode.b6_10 >> 2
	p.set_conditions_cmp(a, b, crfd, false) // ??? TODO: is thhis right
}

fn (mut p PPC) op_subfx() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	oe := ((p.opcode.b21_25) >> 4) != 0
	rc := p.opcode.b31
	result := u64(~p.gprs[a]) + u64(p.gprs[b]) + 1
	p.gprs[d] = ~p.gprs[a] + p.gprs[b] + 1
	if oe == true {
		p.xer.ov = (result >> 32) != ((result + 1) >> 32)
		if p.xer.ov == true {
			p.xer.so = true
		}
	}
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
}

fn (mut p PPC) op_andcx() {
	s := p.opcode.b6_10
	a :=p.opcode.b11_15
	b := p.opcode.b16_20
	rc := p.opcode.b31
	p.gprs[a] = p.gprs[s] & ~p.gprs[b]
	p.logger.log("${p.gprs[s]:08x}(reg ${s}) & ~${p.gprs[b]:08x}(reg ${b}) = ${p.gprs[a]:08x}(reg ${a})", "Args")
	if rc == true {
		p.set_conditions(p.gprs[a], 0)
		p.logger.log("Setting conditions", "Args")
	}
}

fn (mut p PPC) op_mfmsr() {
	d := p.opcode.b6_10
    p.gprs[d] = p.msr.value
	p.logger.log("Setting reg ${d} to msr(${p.msr.value:08x})", "Args")
}

fn (mut p PPC) op_dcbf() {
	// Not needed right now
}

fn (mut p PPC) op_negx() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	oe := ((p.opcode.b21_25 >> 4) & 1) != 0
	rc := p.opcode.b31
	result := u64(~p.gprs[a]) + 1
	p.gprs[d] = u32(result & 0xffffffff)
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
	if oe == true {
		p.xer.ov = (result >> 32) != ((result + 1) >> 32)
		if p.xer.ov == true {
			p.xer.so = true
		}
	}
}

fn (mut p PPC) op_norx() {
	s := p.opcode.b6_10
	a := p.opcode.b6_10
	b := p.opcode.b6_10
	rc := p.opcode.b31

	p.gprs[a] = ~(p.gprs[s] | p.gprs[b])
	p.logger.log("~(${p.gprs[s]:08x}(reg ${s}) | ${p.gprs[b]:08x}(reg ${b})) = ${p.gprs[a]:08x}(reg ${a})", "Args")
	if rc == true {
		p.set_conditions(p.gprs[a], 0)
	}
}

fn (mut p PPC) op_subfex() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	b := p.opcode.b6_10
	oe := (p.opcode.b21_25 >> 4) != 0
	rc := p.opcode.b31
	mut result := u64(0)
	if p.xer.ca == true {
		result = u64(~p.gprs[a]) + u64(p.gprs[b]) + 1
		p.gprs[d] = ~p.gprs[a] + p.gprs[b] + 1
	} else {
		result = u64(~p.gprs[a]) + u64(p.gprs[b])
		p.gprs[d] = ~p.gprs[a] + p.gprs[b]
	}
	p.xer.ca = p.gprs[d] < result
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
	if oe == true {
		p.xer.ov = (result >> 32) != ((result + 1) >> 32)
		if p.xer.ov == true {
			p.xer.so = true
		}
	}
}

fn (mut p PPC) op_addex() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	b := p.opcode.b6_10
	oe := (p.opcode.b21_25 >> 4) != 0
	rc := p.opcode.b31
	mut result := u64(0)
	if p.xer.ca == true {
		result = u64(p.gprs[a]) + u64(p.gprs[b]) + 1
		p.gprs[d] = p.gprs[a] + p.gprs[b] + 1
	} else {
		result = u64(p.gprs[a]) + u64(p.gprs[b])
		p.gprs[d] = p.gprs[a] + p.gprs[b]
	}
	p.xer.ca = p.gprs[d] < result
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
	if oe == true {
		p.xer.ov = (result >> 32) != ((result + 1) >> 32)
		if p.xer.ov == true {
			p.xer.so = true
		}
	}
}

fn (mut p PPC) op_mtcrf() {
	s := p.opcode.b6_10
	crm := p.opcode.b11_20 >> 1
	mut mask := u32(0)
	for i in 0..8 {
		if (crm & (1 << i)) != 0 {
			mask |= 0b1111 << (4*i)
		}
	}
	p.cr = (p.gprs[s] & mask) | (p.cr & ~mask)
    
}

fn (mut p PPC) op_mtmsr() {
	d := p.opcode.b6_10
    p.msr.set_value(p.gprs[d])
	p.logger.log("Setting msr to ${p.msr.value:08x}(reg ${d})", "Args")
}

fn (mut p PPC) op_stwx() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	mut addr := p.gprs[b]
	if a != 0 {
		addr += p.gprs[a]
	}
	p.memory.store32(addr, p.gprs[s])
	p.logger.log("Storing ${p.gprs[s]:08x}(reg ${s}) to address ${addr:08x}", "Args")
}

fn (mut p PPC) op_addzex() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	oe := ((p.opcode.b21_25 >> 4) & 1) != 0
	rc := p.opcode.b31
	mut result := u64(0)
	if p.xer.ca == true {
		result = u64(p.gprs[a]) + 1
		p.gprs[d] = p.gprs[a] + 1
	} else {
		result = p.gprs[a]
		p.gprs[d] = p.gprs[a]
	}
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
	if oe == true  {
		p.xer.ov = (result >> 32) != ((result + 1) >> 32)
		if p.xer.ov == true {
			p.xer.so = true
		}
	}
}

fn (mut p PPC) op_mtsr() {
	s := p.opcode.b6_10
	sr := p.opcode.b11_15 & 0xf
    p.sr[sr] = p.gprs[s]
	p.logger.log("Setting sr${sr} to ${p.sr[sr]:08x}(reg ${s})", "Args")
}

fn (mut p PPC) op_mullwx() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	b := p.opcode.b6_10
	oe := ((p.opcode.b21_25 >> 4) & 1) != 0
	rc := p.opcode.b31
    result := i64(int(p.gprs[a])) * i64(int(p.gprs[b]))
	p.gprs[d] = u32(result & 0xffffffff)
	if rc == true {
		p.set_conditions(u32(result & 0xffffffff), 0)
	}
	if oe == true {
		if oe == true {
			p.xer.ov = (u64(result) >> 32) != ((u64(result) + 1) >> 32)
			if p.xer.ov == true {
				p.xer.so = true
			}
		}
	}
}

fn (mut p PPC) op_addx() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	rc := p.opcode.b31
	oe := (p.opcode.b21_25 >> 4) != 0
	p.gprs[d] = p.gprs[a] + p.gprs[b]
	p.logger.log("${p.gprs[a]}(reg ${a}) + ${p.gprs[b]}(reg ${b}) = ${p.gprs[d]}(stored to reg ${d})", "Args")
	if oe == true {
		p.logger.log("addx should set xer fields", "Critical")
	}
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
		p.logger.log("Setting conditions", "Args")
	}
}

fn (mut p PPC) op_lhzx() {
	d := p.opcode.b6_10
	a := p.opcode.b6_10
	b := p.opcode.b6_10
	mut addr := p.gprs[b]
	if a != 0 {
		addr += p.gprs[a]
	}
	p.gprs[d] = u32(p.memory.load16(addr))
}

fn (mut p PPC) op_mfspr() {
	d := p.opcode.b6_10
	spr := p.opcode.b11_20
    index := ((spr & 0x1F) << 5) + ((spr >> 5) & 0x1F)
    p.gprs[d] = p.get_sprs(index)
	p.logger.log("Setting reg ${d} to sprs[${index}](${p.get_sprs(index):08x})", "Args")
}

fn (mut p PPC) op_mftb() {
	d := p.opcode.b6_10
	tbr := p.opcode.b11_20
    index := ((tbr & 0x1F) << 5) + ((tbr >> 5) & 0x1F)
	if (p.instruction_count / 12) < p.tbl {
		p.tbu += 1
	}
	p.tbl = p.instruction_count / 12
    if index == 268 {
		p.gprs[d] = p.tbl
	} else if index == 269 {
		p.gprs[d] = p.tbu
	} else {
		p.logger.log("Invalid mftb field ${index}", "Critical")
	}
}

fn (mut p PPC) op_orx() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	rc := p.opcode.b31
	p.gprs[a] = p.gprs[s] | p.gprs[b]
	p.logger.log("${p.gprs[s]:08x}(reg ${s}) | ${p.gprs[b]:08x}(reg ${b}) = ${p.gprs[a]:08x}(stored to reg ${a})", "Args")
	if rc == true {
		p.set_conditions(p.gprs[s] | p.gprs[b], 0)
		p.logger.log("Setting conditions", "Args")
	}
}

fn (mut p PPC) op_divwux() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	oe := ((p.opcode.b21_25 >> 4) & 1) != 0
	rc := p.opcode.b31
	p.gprs[d] = p.gprs[a] / p.gprs[b]
	if rc == true {
		p.set_conditions(p.gprs[d], 0)
	}
	if oe == true {
		println("divwux should set xer")
	}
}

fn (mut p PPC) op_mtspr() {
	s := p.opcode.b6_10
	spr := p.opcode.b11_20
    index := ((spr & 0x1F) << 5) | ((spr >> 5) & 0x1F)
    p.set_sprs(index, p.gprs[s])
	p.logger.log("Setting sprs[${index}] to reg ${s}(${p.get_sprs(index):08x})", "Args")
}

fn (mut p PPC) op_dcbi() {
	// Nothing for us right now
}


fn (mut p PPC) op_srwx() {
    s := p.opcode.b6_10
	a := p.opcode.b11_15
	b := p.opcode.b16_20
	rc := p.opcode.b31
	n := p.gprs[b] & 0b11111
	p.gprs[a] = p.gprs[s] >> n
	if rc == true {
		p.set_conditions(p.gprs[a], 0)
	}
}

fn (mut p PPC) op_sync() {
    // Nothing for us right now
}

fn (mut p PPC) op_icbi() {
    // Nothing for us right now
}

fn (mut p PPC) op_lwz() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.gprs[d] = p.memory.load32(addr)
	p.logger.log("Setting reg${d} to ${p.gprs[d]:08x} (loaded from ${addr:08x})", "Args")
}

fn (mut p PPC) op_lwzu() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := p.gprs[a] + exts16(d2)
	p.gprs[d] = p.memory.load32(addr)
	p.logger.log("Setting reg${d} to ${p.gprs[d]:08x} (loaded from ${addr:08x})", "Args")
	p.gprs[a] = addr
	p.logger.log("Writing addr(${addr:08x}) back to reg${a}", "Args")
}

fn (mut p PPC) op_lbz() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.gprs[d] = p.memory.load8(addr)
	p.logger.log("Setting reg${d} to ${p.gprs[d]:02x} (loaded from ${addr:08x})", "Args")
}

fn (mut p PPC) op_stw() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	d := p.opcode.b16_31
	mut addr := exts16(d)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.memory.store32(addr, p.gprs[s])
	p.logger.log("Writing ${p.gprs[s]:08x}(reg ${s}) to address ${addr:08x}", "Args")

}

fn (mut p PPC) op_stwu() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	d := p.opcode.b16_31
	addr := p.gprs[a] + exts16(d)
	p.logger.log("Storing ${p.gprs[s]:08x}(reg ${s}) to ${addr:08x}", "Args")
	p.memory.store32(addr, p.gprs[s])
	p.gprs[a] = addr
	p.logger.log("Writing address ${addr:08x} back to reg ${a}", "Args")
}

fn (mut p PPC) op_stb() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	d := p.opcode.b16_31
	mut addr := exts16(d)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.logger.log("Storing ${p.gprs[s]:02x}(reg ${s}) to ${addr:08x}", "Args")
	p.memory.store8(addr, u8(p.gprs[s] & 0xff))
}

fn (mut p PPC) op_lhz() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.gprs[d] = u32(p.memory.load16(addr))
	p.logger.log("loading ${p.gprs[d]:04x}(reg ${d}) from address ${addr:08x}", "Args")
}

fn (mut p PPC) op_lha() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.gprs[d] = exts16(u32(p.memory.load16(addr)))
}

fn (mut p PPC) op_sth() {
	s := p.opcode.b6_10
	a := p.opcode.b11_15
	d := p.opcode.b16_31
	mut addr := exts16(d)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.logger.log("Storing ${p.gprs[s]:04x}(reg ${s}) to ${addr:08x}", "Args")
	p.memory.store16(addr, u16(p.gprs[s] & 0xffff))
}

fn (mut p PPC) op_lmw() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	for r in d..32 {
		p.gprs[r] = p.memory.load32(addr)
		p.logger.log("Loading ${p.gprs[r]:08x} to reg${r} (loaded from address ${addr:08x})", "Args")
		addr += 4
	}
}

fn (mut p PPC) op_stmw() {
	mut s := p.opcode.b6_10
	a := p.opcode.b11_15
	d := p.opcode.b16_31
	mut addr := exts16(d)
	if a != 0 {
		addr += p.gprs[a]
	}
	for r in s..32 {
		p.memory.store32(addr, p.gprs[r])
		p.logger.log("Storing ${p.gprs[r]:08x}(reg ${r}) to ${addr:08x}", "Args")
		addr += 4
	}
}

fn (mut p PPC) op_lfs() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.fprs[d].ps0 = f32(p.memory.load32(addr) & 0xffff)
	p.fprs[d].ps1 = f32(p.memory.load32(addr) >> 16) // TODO: recheck
}

fn (mut p PPC) op_lfd() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	d2 := p.opcode.b16_31
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	p.fprs[d].ps0 = f32(p.memory.load32(addr))
	p.fprs[d].ps1 = f32(p.memory.load32(addr + 4))
}

fn (mut p PPC) op_psq_l() {
	d := p.opcode.b6_10
	a := p.opcode.b11_15
	w := p.opcode.b16_20 >> 4
	i := (p.opcode.b16_20 >> 1) & 7
	d2 := p.opcode.b16_31 & 0xfff
	mut addr := exts16(d2)
	if a != 0 {
		addr += p.gprs[a]
	}
	lt := (p.get_sprs(912 + i) >> 16) & 7
	ls := p.get_sprs(912 + i) >> 24
	mut c := 4
	if (lt == 4) || (lt == 6) {
		c = 1
	}
	if (lt == 5) || (lt == 7) {
		c = 2
	}

	if w == 0 {
		match c {
			4 {
				ps0 := p.memory.load32(addr)
				ps1 := p.memory.load32(addr + 4)
				p.fprs[d].ps0 = p.dequantized(ps0, lt, ls)
				p.fprs[d].ps1 = p.dequantized(ps1, lt, ls)
			}
			else { p.logger.log("Unhandled psq_l w == 0, c == ${c}", "Warning")}
		}
	} else {
		match c {
			4 {
				ps0 := p.memory.load32(addr)
				p.fprs[d].ps0 = p.dequantized(ps0, lt, ls)
				p.fprs[d].ps1 = f32(1.0)
			}
			else { p.logger.log("Unhandled psq_l w == 0, c == ${c}", "Warning")}
		}
	}
}

fn (mut p PPC) op_mtfsb1x() {
	crbd := p.opcode.b6_10
	rc := p.opcode.b31
	p.fpscr |= 1 << (31 - crbd)
	if rc == true {
		p.logger.log("mtfsb1x should set conditions", "Critical")
	}
}

fn (mut p PPC) op_fmrx() {
	d := p.opcode.b6_10
	b := p.opcode.b16_20
	rc := p.opcode.b31
	p.fprs[d].ps0 = p.fprs[b].ps0
	p.fprs[d].ps1 = p.fprs[b].ps1
	if rc == true {
		p.logger.log("fmrx should set conditions", "Critical")
	}
}

fn (mut p PPC) op_mtfsfx() {
	fm := (p.opcode.value >> 17) & 0xff
	b := p.opcode.b16_20
	rc := p.opcode.b31
	temp := u32(p.fprs[b].ps0)
	for i in 0..7 {
		if (fm & (1 << i)) != 0 {
			p.fpscr |= temp & (0b1111 << (4*i))
		}
	}
	if rc == true {
		p.logger.log("mtfsfx should set conditions", "Critical")
	}
}