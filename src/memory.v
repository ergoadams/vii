import os

[heap]
struct Memory {
	mut:
		mem1 []u8
		mem2 []u8
		logger &Logger
		processor Processor
		external External
		dsp Dsp
}


fn (mut m Memory) init(logger &Logger) {
	m.logger = logger
	m.processor = Processor{}
	m.external = External{}
	m.external.init()
	m.dsp = Dsp{}
	m.dsp.init()
	m.logger.log("Initializing memory", "Memory")
	m.mem1 = []u8{len: 0x01800000, init: 0}
	m.mem2 = []u8{len: 0x04000000, init: 0}
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
		((0x90000000 <= address) && (address < 0x94000000)) ||
		((0xD0000000 <= address) && (address < 0xD4000000)) {
			offset := (address << 4) >> 4
			mut value := u32(0)
			value |= u32(m.mem2[offset + 0]) << 24
            value |= u32(m.mem2[offset + 1]) << 16
            value |= u32(m.mem2[offset + 2]) << 8
            value |= u32(m.mem2[offset + 3]) << 0
			return value
		}

		((0xcc003000 <= address) && (address < 0xcc003100)) { return m.processor.load32(address) }
		((0xcc006800 <= address) && (address < 0xcc006880)) { return m.external.load32(address) }
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
		((0xcc005000 <= address) && (address < 0xcc005200)) { return m.dsp.load16(address) }
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
		((0x90000000 <= address) && (address < 0x94000000)) ||
		((0xD0000000 <= address) && (address < 0xD4000000)) {
			offset := (address << 4) >> 4
			m.mem2[offset + 0] = u8((value & 0xFF000000) >> 24)
            m.mem2[offset + 1] = u8((value & 0xFF0000) >> 16)
            m.mem2[offset + 2] = u8((value & 0xFF00) >> 8)
            m.mem2[offset + 3] = u8((value & 0xFF) >> 0)
		} 
		((0xcc003000 <= address) && (address < 0xcc003100)) { m.processor.store32(address, value) }
		((0xcc006800 <= address) && (address < 0xcc006880)) { m.external.store32(address, value) }
		address == 0xcc006480 {
			if value != 0 {
				addr := (value << 1) >> 1
				println(m.mem1[addr..addr+0x1000].bytestr())
			}
		}
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
		((0xcc005000 <= address) && (address < 0xcc005200)) { m.dsp.store16(address, value) }
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