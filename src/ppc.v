
struct Opcode {
	mut:
		value u32
		opcd u32
		secondary u32
		b26_30 u32
		b21_25 u32
		b16_31 u32
		b16_29 u32
		b16_20 u32
		b11_20 u32
		b11_15 u32
		b6_29 u32
		b6_10 u32
		b31 bool
		b30 bool
}

const(
	xer_r = 1
	lr_r = 8
	ctr_r = 9
	srr0_r = 26
	srr1_r = 27
)

enum Exception {
	syscall
}

struct Xer {
	mut:
		so bool
		ov bool
		ca bool
		byte_count u32
}

fn (mut x Xer) set_value(value u32) {
	x.so = (value >> 31) != 0
	x.ov = (value >> 30) != 0
	x.ca = (value >> 29) != 0
	x.byte_count = value & 0x7f
}

fn (x Xer) get_value() u32 {
	mut value := u32(0)
	if x.so == true {
		value |= 1 << 31
	}
	if x.ov == true {
		value |= 1 << 30
	}
	if x.ca == true {
		value |= 1 << 29
	}
	value |= x.byte_count
	return value
}

struct Fpr {
	mut:
		ps0 f32
		ps1 f32
}

struct Msr {
	mut:
		value u32
		pow bool
		ile bool
		ee bool
		pr bool
		fp bool
		me bool
		fe0 bool
		se bool
		be bool
		fe1 bool
		ir bool
		dr bool
		pmm bool
		ri bool
		le bool
}

fn (mut m Msr) set_value(value u32) {
	m.value = value
	m.pow = ((value >> 18) & 1) != 0
	m.ile = ((value >> 16) & 1) != 0
	m.ee = ((value >> 15) & 1) != 0
	m.pr = ((value >> 14) & 1) != 0
	m.fp = ((value >> 13) & 1) != 0
	m.me = ((value >> 12) & 1) != 0
	m.fe0 = ((value >> 11) & 1) != 0
	m.se = ((value >> 10) & 1) != 0
	m.be = ((value >> 9) & 1) != 0
	m.fe1 = ((value >> 8) & 1) != 0
	m.ir = ((value >> 5) & 1) != 0
	m.dr = ((value >> 3) & 1) != 0
	m.pmm = ((value >> 2) & 1) != 0
	m.ri = ((value >> 1) & 1) != 0
	m.le = ((value >> 0) & 1) != 0
}

struct PPC {
	mut:
		instruction_count u32
		pc u32
		prev_pc u32
		opcode Opcode
		opcode_name string
		gprs []u32
		sprs []u32
		fprs []Fpr
		xer Xer
		cr u32
		fpscr u32
		sr []u32
		msr Msr
		memory &Memory
		logger &Logger
		running bool
		scaling_factor []f32
		tbl u32
		tbu u32
}

fn (mut o Opcode) set_value(value u32) {
	o.value = value
	o.opcd = value >> 26
	o.secondary = (value >> 1) & 0x3FF
	o.b16_31 = value & 0xffff
	o.b26_30 = (value >> 1) & 0x1f
	o.b21_25 = (value >> 6) & 0x1f
	o.b16_29 = (value >> 2) & 0x3fff
	o.b16_20 = (value >> 11) & 0x1f
	o.b11_20 = (value >> 11) & 0x3ff
	o.b11_15 = (value >> 16) & 0x1f
	o.b6_29 = ((value << 6) >> 8) << 2
	o.b6_10 = (value >> 21) & 0x1f
	o.b31 = (value & 1) != 0
	o.b30 = (value & 2) != 0

}

// Maybe using the function name init is not the best, cause it is typically
// an automatic function that runs on module imports. Atleast it works.
fn (mut p PPC) init(memory &Memory, logger &Logger) {
	p.logger = logger
	p.logger.log("Initializing Broadway", "Broadway")

	p.pc = 0
	p.cr = 0
	p.fpscr = 0
	p.msr.set_value(0b1010000000110000)
	p.opcode.set_value(0)
	p.gprs = []u32{len: 32}
	p.sprs = []u32{len: 0x3ff}
	p.sr = []u32{len: 16}
	p.fprs = []Fpr{len: 32}
	p.scaling_factor = []f32{len: 64}
	for i in 0..31 {
		p.scaling_factor[i] = f32(i)
		p.scaling_factor[i + 32] = f32(i - 32)
	}
	p.memory = memory
	p.running = true
}

fn (mut p PPC) set_entry_point(entry_point u32) {
	p.logger.log("Setting Broadway entry point to 0x${entry_point:x}", "Broadway")
	p.pc = entry_point
}

fn (mut p PPC) fetch_opcode(pc u32) u32 {
	return p.memory.load32(pc)
}

fn (mut p PPC) decode_and_execute() {
	// Bits 0-5 specify the primary opcode
	// Bit order is reversed, bit 0 is the MSB
	match p.opcode.opcd {
		0b000100 { 
			match p.opcode.secondary {
				0b0001001000 { p.op_ps_mr() p.opcode_name = "ps_mrx" }
				else { p.logger.log("${p.pc:08x}(${p.instruction_count}) Unhandled 0b000100 (4) secondary 0b${p.opcode.secondary:010b} (${p.opcode.secondary}) opcode ${p.opcode.value:08x}", "Critical") p.running = false }
			}
		}
		0b000111 { p.op_mulli() p.opcode_name = "mulli" }
		0b001000 { p.op_subfic() p.opcode_name = "subfic" }
		0b001010 { p.op_cmpli() p.opcode_name = "cmpli" }
		0b001011 { p.op_cmpi() p.opcode_name = "cmpi" }
		0b001100 { p.op_addic() p.opcode_name = "addic" }
		0b001101 { p.op_addicr() p.opcode_name = "addicr" }
		0b001110 { p.op_addi() p.opcode_name = "addi" }
		0b001111 { p.op_addis() p.opcode_name = "addis" }
		0b010010 { p.op_bx() p.opcode_name = "bx" }
		0b011000 { p.op_ori() p.opcode_name = "ori" }
		0b011001 { p.op_oris() p.opcode_name = "oris" }
		0b011010 { p.op_xori() p.opcode_name = "xori" }
		0b010000 { p.op_bcx() p.opcode_name = "bcx" }
		0b010001 { p.op_sc() p.opcode_name = "sc" }
		0b010011 {
			match p.opcode.secondary {
				0b0000010000 { p.op_bclrx() p.opcode_name = "bclrx" }	
				0b0000110010 { p.op_rfi() p.opcode_name = "rfi" }	
				0b0010010110 { p.op_isync() p.opcode_name = "isync" }	
				0b1000010000 { p.op_bcctrx() p.opcode_name = "bcctrx" }	
				else { p.logger.log("${p.pc:08x}(${p.instruction_count}) Unhandled 0b010011 (19) secondary 0b${p.opcode.secondary:010b} (${p.opcode.secondary}) opcode ${p.opcode.value:08x}", "Critical") p.running = false }
			}
		}
		0b010100 { p.op_rlwimix() p.opcode_name = "rlwimix"}
		0b010101 { p.op_rlwinmx() p.opcode_name = "rlwinmx"}
		0b011100 { p.op_andi() p.opcode_name = "andi"}
		0b011101 { p.op_andis() p.opcode_name = "andis"}
		0b011111 { 
			match p.opcode.secondary {
				0b0000000000 { p.op_cmp() p.opcode_name = "cmp" }
				0b0000001000 { p.op_subfcx() p.opcode_name = "subfcx" }
				0b0000001010 { p.op_addcx() p.opcode_name = "addcx" }
				0b0000001011 { p.op_mulhwux() p.opcode_name = "mulhwux" }
				0b0000010011 { p.op_mfcr() p.opcode_name = "mfcr" }
				0b0000010111 { p.op_lwzx() p.opcode_name = "lwzx" }
				0b0000011000 { p.op_slwx() p.opcode_name = "slwx" }
				0b0000011010 { p.op_cntlzwx() p.opcode_name = "cntlzwx" }
				0b0000011100 { p.op_andx() p.opcode_name = "andx" }
				0b0000100000 { p.op_cmpl() p.opcode_name = "cmpl" }
				0b0000101000 { p.op_subfx() p.opcode_name = "subfx" }
				0b0000111100 { p.op_andcx() p.opcode_name = "andcx" }
				0b0001010011 { p.op_mfmsr() p.opcode_name = "mfmsr" }	
				0b0001010110 { p.op_dcbf() p.opcode_name = "dcbf" }	
				0b0001101000 { p.op_negx() p.opcode_name = "negx" }	
				0b0001111100 { p.op_norx() p.opcode_name = "norx" }	
				0b0010001000 { p.op_subfex() p.opcode_name = "subfex" }	
				0b0010001010 { p.op_addex() p.opcode_name = "addex" }	
				0b0010010000 { p.op_mtcrf() p.opcode_name = "mtcrf" }	
				0b0010010010 { p.op_mtmsr() p.opcode_name = "mtmsr" }	
				0b0010010111 { p.op_stwx() p.opcode_name = "stwx" }	
				0b0011001010 { p.op_addzex() p.opcode_name = "addzex" }	
				0b0011010010 { p.op_mtsr() p.opcode_name = "mtsr" }	
				0b0011101011 { p.op_mullwx() p.opcode_name = "mullwx" }	
				0b0100001010 { p.op_addx() p.opcode_name = "addx" }
				0b0100010111 { p.op_lhzx() p.opcode_name = "lhzx" }
				0b0101010011 { p.op_mfspr() p.opcode_name = "mfspr" }	
				0b0101110011 { p.op_mftb() p.opcode_name = "mftb" }	
				0b0110111100 { p.op_orx() p.opcode_name = "orx" }	
				0b0111001011 { p.op_divwux() p.opcode_name = "divwux" }	
				0b0111010011 { p.op_mtspr() p.opcode_name = "mtspr" }	
				0b0111010110 { p.op_dcbi() p.opcode_name = "dcbi" }	
				0b1000011000 { p.op_srwx() p.opcode_name = "srwx" }	
				0b1001010110 { p.op_sync() p.opcode_name = "sync" }	
				0b1100011000 { p.op_srawx() p.opcode_name = "srawx" }	
				0b1100111000 { p.op_srawix() p.opcode_name = "srawix" }	
				0b1111010110 { p.op_icbi() p.opcode_name = "icbi" }	
				else { p.logger.log("${p.pc:08x}(${p.instruction_count})  Unhandled 0b011111 (31) secondary 0b${p.opcode.secondary:010b} (${p.opcode.secondary}) opcode ${p.opcode.value:08x}", "Critical") p.running = false }
			}
		}
		0b100000 { p.op_lwz() p.opcode_name = "lwz" }
		0b100001 { p.op_lwzu() p.opcode_name = "lwzu" }
		0b100010 { p.op_lbz() p.opcode_name = "lbz" }
		0b100100 { p.op_stw() p.opcode_name = "stw" }
		0b100101 { p.op_stwu() p.opcode_name = "stwu" }
		0b100110 { p.op_stb() p.opcode_name = "stb" }
		0b101000 { p.op_lhz() p.opcode_name = "lhz" }
		0b101010 { p.op_lha() p.opcode_name = "lha" }
		0b101100 { p.op_sth() p.opcode_name = "sth" }
		0b101110 { p.op_lmw() p.opcode_name = "lmw" }
		0b101111 { p.op_stmw() p.opcode_name = "stmw" }
		0b110000 { p.op_lfs() p.opcode_name = "lfs" }
		0b110010 { p.op_lfd() p.opcode_name = "lfd" }
		0b111000 { p.op_psq_l() p.opcode_name = "psq_l" }
		0b111111 {
			match p.opcode.secondary {
				0b0000100110 { p.op_mtfsb1x() p.opcode_name = "mtfsb1x" }
				0b0001001000 { p.op_fmrx() p.opcode_name = "fmrx" }
				0b1011000111 { p.op_mtfsfx() p.opcode_name = "mtfsfx" }
				else { p.logger.log("${p.pc:08x}(${p.instruction_count})  Unhandled 0b111111 (63) secondary 0b${p.opcode.secondary:010b} (${p.opcode.secondary}) opcode ${p.opcode.value:08x}", "Critical") p.running = false }
			}
			
		}
		else { p.logger.log("${p.pc:08x}(${p.instruction_count}) Unhandled opcd 0b${p.opcode.opcd:06b} (${p.opcode.opcd}) opcode ${p.opcode.value:08x} ", "Critical") p.running = false }
	}
}


fn (mut p PPC) tick() {
	p.prev_pc = p.pc
	p.opcode.set_value(p.fetch_opcode(p.pc))
	p.pc += 4
	p.decode_and_execute()
	p.instruction_count += 1
	/*if p.instruction_count >= 500000 {
		println("${p.pc:08x}")
	}*/
	if p.running == true {
		p.logger.log("${p.instruction_count} ${p.prev_pc:08X} ${p.opcode.value:08X} (${p.opcode.opcd}, ${p.opcode.secondary}) ${p.opcode_name} ${p.gprs}", "Broadway")
	}
	p.logger.out()
}