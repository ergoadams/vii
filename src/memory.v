import os

@[heap]
struct Memory {
	mut:
		mem1 []u8
		mem2 []u8
		logger Logger
}

fn (mut m Memory) init(logger Logger) {
	m.logger = logger
	m.logger.log("Initializing memory", "Memory")
	m.mem1 = []u8{len: 0x01800000, init: 0}
	m.mem2 = []u8{len: 0x04000000, init: 0}
}

fn (mut m Memory) load_dol(dol_path string) u32 {
	m.logger.log("Loading ${dol_path}", "Memory")
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
	m.logger.log("Text size:   ${text_size}", "Memory")
	m.logger.log("Data offset: ${data_offsets}", "Memory")
	m.logger.log("Data addr:   ${data_addr}", "Memory")
	m.logger.log("Data size:   ${data_size}", "Memory")
	m.logger.log("BSS addr:    0x${bss_addr:x}", "Memory")
	m.logger.log("BSS size:    0x${bss_size:x}", "Memory")
	m.logger.log("Entry point: 0x${entry_point:x}", "Memory")
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
	for i in 0..11 {
		offset := data_offsets[i]
		size := data_size[i]
		write_addr := data_addr[i] - 0x80000000 // The code will be copied into RAM
		if offset != 0 {
			m.logger.log("Copying data to 0x${write_addr:08x} in RAM (size: ${size})", "Memory")
			for j in 0..size {
				m.mem1[write_addr + j] = dol_data[offset + j] // TODO: kinda hacky?
			}
		}
	}
	return entry_point
} 

fn (mut m Memory) load32(address u32) u32 {
	mut value := u32(0)
	match true {
		((0x80000000 <= address) && (address <= 0x817FFFFF)) {
			offset := address - 0x80000000
			value |= u32(m.mem1[offset + 0]) << 24
			value |= u32(m.mem1[offset + 1]) << 16
			value |= u32(m.mem1[offset + 2]) << 8
			value |= u32(m.mem1[offset + 3]) << 0
		} else { m.logger.log("Unhandled load32 address 0x${address:08x}", "Warning")}
	}
	return value
}
