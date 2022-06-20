import thecodrr.crayon
import arrays

// Sign extensions, copied from dolphin

fn exts26(value u32) u32 {
	if (value & 0x2000000) != 0 {
		return u32(int(value | 0xFC000000))
	} else {
		return u32(int(value))
	}
}

fn exts16(value u32) u32 {
	return u32(int(i16(value)))
}

fn rotl(value u32, n u32) u32 {
	if n == 0 {
		return value
	}
	return (value << (n % 32)) | (value >> (32 - (n % 32)))
}

fn mask(mb u32, me u32) u32 {
	begin_pos := u32(0xFFFFFFFF) >> mb
	end_pos := u32(0x7FFFFFFF) >> me
	mask := begin_pos ^ end_pos
	if me < mb {
		return ~mask
	} else {
		return mask
	}
}

// Logger

[heap]
struct Logger {
	mut:
		log_types map[string]string
		logs []string
		logging_enabled bool
}

/* Colors for logger
(242,191,215) Little Girl Pink		|
(246,215,232) Piggy Pink			|
(246,237,238) Isabelline			|
(220,208,234) Languid Lavender		| Memory
(242,232,206) Champagne				| Args
(241,220,197) Almond				| Broadway
*/

fn (mut l Logger) init(logging_enabled bool) {
	println("Initializing logger")
	l.log_types['Warning'] = "yellow"
	l.log_types['Critical'] = "bold.red"

	l.log_types['Broadway'] = "rgb(241,220,197)"
	l.log_types['Memory'] = "rgb(242,232,206)"
	l.log_types['Args'] = "rgb(220,208,234)"
	l.logging_enabled = logging_enabled
}

fn (mut l Logger) log(message string, log_type string) {
	if l.logging_enabled || log_type == "Critical" {
		if log_type in l.log_types {
			crayon_string := '{${l.log_types[log_type]} ${log_type:10}: ${message}\n}' 
			l.logs << crayon.color(crayon_string)
		}
	}
}

fn (mut l Logger) out() {
	// Hack for my emulator to get the opcode and address to be before instruction info
	if l.logs.len > 0 {
		arrays.rotate_right(mut l.logs, 1)
		for log in l.logs {
			print(log)
		}
		l.logs = []string{len: 0}
	}
}