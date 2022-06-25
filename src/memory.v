import os

[heap]
struct Memory {
	mut:
		mem1 []u8
		mem2 []u8
		exi0csr u32
		exi1csr u32
		exi2csr u32
		exi0cr u32
		exi1cr u32
		exi2cr u32
		exi0data u32
		exi1data u32
		exi2data u32
		intsr u32
		intmr u32
		logger &Logger
}


fn (mut m Memory) init(logger &Logger) {
	m.logger = logger
	m.logger.log("Initializing memory", "Memory")
	m.mem1 = []u8{len: 0x01800000, init: 0}
	m.mem2 = []u8{len: 0x04000000, init: 0}
	m.exi0csr = 0
	m.exi1csr = 0
	m.exi2csr = 0
	m.exi0data = 0
	m.exi1data = 0
	m.exi2data = 0
	m.intsr = 0
	m.intmr = 0
}

fn (mut m Memory) dump_memory() {
	os.write_file_array("ramdump.bin", m.mem1) or { panic(err) }
	m.logger.log("Ram dumped", "Memory")
}


fn (mut m Memory) load_dol(dol_path string) u32 {
	m.logger.log("Loading ${dol_path}\n", "Memory")
	mut dol_data := os.read_bytes(dol_path) or { panic(err) }
	mut text_offsets := []u32{len: 7, init: 0}
	mut data_offsets := []u32{len: 11, init: 0}
	mut text_addr := []u32{len: 7, init: 0}
	mut data_addr := []u32{len: 11, init: 0}
	mut text_size := []u32{len: 7, init: 0}
	mut data_size := []u32{len: 11, init: 0}
	mut bss_addr := u32(0)
	mut bss_size := u32(0)
	mut entry_point := u32(0)
	for i in 0..7 {
		for j in 0..4{
			text_offsets[i] |= dol_data[0 + i*4 + j] << ((3 - j)*8)
			text_addr[i] |= dol_data[72 + i*4 + j] << ((3 - j)*8)
			text_size[i] |= dol_data[144 + i*4 + j] << ((3 - j)*8)
		}
	}
	for i in 0..11 {
		for j in 0..4{
			data_offsets[i] |= dol_data[28 + i*4 + j] << ((3 - j)*8)
			data_addr[i] |= dol_data[100 + i*4 + j] << ((3 - j)*8)
			data_size[i] |= dol_data[172 + i*4 + j] << ((3 - j)*8)
		}
	}
	for j in 0..4 {
		bss_addr |= dol_data[216 + j] << ((3 - j)*8)
		bss_size |= dol_data[220 + j] << ((3 - j)*8)
		entry_point |= dol_data[224 + j] << ((3 - j)*8)
	}
	m.logger.log("Text offset: ${text_offsets}", "Memory")
	m.logger.log("Text addr:   ${text_addr}", "Memory")
	m.logger.log("Text size:   ${text_size}\n", "Memory")
	m.logger.log("Data offset: ${data_offsets}", "Memory")
	m.logger.log("Data addr:   ${data_addr}", "Memory")
	m.logger.log("Data size:   ${data_size}\n", "Memory")
	m.logger.log("BSS addr:    0x${bss_addr:x}", "Memory")
	m.logger.log("BSS size:    0x${bss_size:x}", "Memory")
	m.logger.log("Entry point: 0x${entry_point:x}\n", "Memory")

	for i in 0..7 {
		offset := text_offsets[i]
		size := text_size[i]
		write_addr := text_addr[i] - 0x80000000 // The code will be copied into RAM
		if offset != 0 {
			m.logger.log("Copying text to 0x${write_addr:08x} in RAM (size: ${size})", "Memory")
			for j in 0..size {
				m.mem1[write_addr + j] = dol_data[offset + j]
			}
		}
	}

	for i in 0..7 {
		offset := data_offsets[i]
		size := data_size[i]
		write_addr := data_addr[i] - 0x80000000 // The code will be copied into RAM
		if offset != 0 {
			m.logger.log("Copying data to 0x${write_addr:08x} in RAM (size: ${size})", "Memory")
			for j in 0..size {
				m.mem1[write_addr + j] = dol_data[offset + j]
			}
		}
	}

	return entry_point
} 

fn (mut m Memory) load32(address u32) u32 {
	match true {
		((0x00000000 <= address) && (address < 0x01800000)) ||
		((0x80000000 <= address) && (address < 0x81800000)) {
			offset := (address << 1) >> 1
			mut value := u32(0)
			value |= u32(m.mem1[offset + 0]) << 24
            value |= u32(m.mem1[offset + 1]) << 16
            value |= u32(m.mem1[offset + 2]) << 8
            value |= u32(m.mem1[offset + 3]) << 0
			return value
		} 
		((0xD0000000 <= address) && (address < 0xD4000000)) {
			offset := address - 0xD0000000
			mut value := u32(0)
			value |= u32(m.mem2[offset + 0]) << 24
            value |= u32(m.mem2[offset + 1]) << 16
            value |= u32(m.mem2[offset + 2]) << 8
            value |= u32(m.mem2[offset + 3]) << 0
			return value
		}
		address == 0xcc00302c { return 2 << 28 } // bits 28-31: console type
		address == 0xCC003000 { return m.intsr }
		address == 0xCC003004 { return m.intmr }
		address == 0xCC006800 { return m.exi0csr }
		address == 0xCC006814 { return m.exi1csr }
		address == 0xCC006828 { return m.exi2csr }
		address == 0xCC00680c { return m.exi0cr }
		address == 0xCC006820 { return m.exi1cr }
		address == 0xCC006834 { return m.exi2cr }
		else { m.logger.log("Unhandled load32 ${address:08x}", "Critical")  return 0}
	}
}

fn (mut m Memory) load16(address u32) u16 {
	match true {
		((0x00000000 <= address) && (address < 0x01800000)) ||
		((0x80000000 <= address) && (address < 0x81800000)) {
			offset := (address << 1) >> 1
			mut value := u16(0)
			value |= u16(m.mem2[offset + 0]) << 8
            value |= u16(m.mem2[offset + 1]) << 0
			return value
		} 
		else { m.logger.log("Unhandled load16 ${address:08x}", "Critical")  return 0}
	}
}

fn (mut m Memory) load8(address u32) u8 {
	match true {
		((0x00000000 <= address) && (address < 0x01800000)) ||
		((0x80000000 <= address) && (address < 0x81800000)) {
			offset := (address << 1) >> 1
			return m.mem1[offset + 0] << 0
		} 
		else { m.logger.log("Unhandled load8 ${address:08x}", "Critical")  return 0}
	}
}

fn (mut m Memory) store32(address u32, value u32) {
	match true {
		((0x00000000 <= address) && (address < 0x01800000)) ||
		((0x80000000 <= address) && (address < 0x81800000)) {
			offset := (address << 1) >> 1
			m.mem1[offset + 0] = u8((value & 0xFF000000) >> 24)
            m.mem1[offset + 1] = u8((value & 0xFF0000) >> 16)
            m.mem1[offset + 2] = u8((value & 0xFF00) >> 8)
            m.mem1[offset + 3] = u8((value & 0xFF) >> 0)
		} 
		address == 0xcc003000 { m.intsr = value } // Interrupt cause
		address == 0xcc003004 { m.intmr = value } // Interrupt mask
		address == 0xCC006800 { m.exi0csr = value }
		address == 0xcc006814 { m.exi1csr = value }
		address == 0xcc006828 { m.exi2csr = value }
		address == 0xcc006810 { m.exi0data = value }
		address == 0xcc006824 { m.exi1data = value }
		address == 0xcc006838 { m.exi2data = value }
		address == 0xCC00680c { m.exi0cr = value }
		address == 0xCC006820 { m.exi1cr = value }
		address == 0xCC006834 { m.exi2cr = value }
		else { m.logger.log("Unhandled store32 addr ${address:08x} value ${value:08x}", "Critical") }
	}
}

fn (mut m Memory) store16(address u32, value u16) {
	match true {
		((0x00000000 <= address) && (address < 0x01800000)) ||
		((0x80000000 <= address) && (address < 0x81800000)) {
			offset := (address << 1) >> 1
            m.mem1[offset + 0] = u8((value & 0xFF00) >> 8)
            m.mem1[offset + 1] = u8((value & 0xFF) >> 0)
		} 
		else { m.logger.log("Unhandled store16 addr ${address:08x} value ${value:04x}", "Critical") }
	}
}

fn (mut m Memory) store8(address u32, value u8) {
	match true {
		((0x00000000 <= address) && (address < 0x01800000)) ||
		((0x80000000 <= address) && (address < 0x81800000)) {
			offset := (address << 1) >> 1
            m.mem1[offset] = value
		} 
		else { m.logger.log("Unhandled store8 addr ${address:08x} value ${value:02x}", "Critical") }
	}
}