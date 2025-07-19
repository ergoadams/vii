import term
import arrays
import os

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
@[heap]
struct Logger {
mut:
	log_types       map[string][]int
	logs            []string
	logging_enabled bool
}

/* Colors for logger
(252,233,241)		|
(233,252,244)		|
(254,236,232)		| Broadway
(232,250,254)		| Memory
(236,232,254)		| Args
*/

fn (mut l Logger) init(logging_enabled bool) {
	println('Initializing logger')
	l.logging_enabled = logging_enabled
	l.log_types['Warning'] = [255, 255, 0]
	l.log_types['Critical'] = [255, 0, 0]

	l.log_types['Broadway'] = [254, 236, 232]
	l.log_types['Memory'] = [232, 250, 254]
	l.log_types['Args'] = [236, 232, 254]
}

fn (mut l Logger) log(message string, log_type string) {
	if l.logging_enabled || log_type == 'Critical' {
		if log_type in l.log_types {
			cur_color := l.log_types[log_type]
			l.logs << term.rgb(cur_color[0], cur_color[1], cur_color[2], '${log_type:10}: ${message}')
			println(l.logs[l.logs.len - 1])
		}
	}
}
