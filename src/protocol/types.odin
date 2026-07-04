package protocol

import "core:encoding/endian"
import "core:encoding/varint"
import "core:mem"
import "core:net"

Protocol_Send_Error :: net.TCP_Send_Error
Protocol_Recv_Error :: net.TCP_Recv_Error

POSITION_X_BITS :: 26
POSITION_Y_BITS :: 12
POSITION_Z_BITS :: 26
POSITION_X_SHIFT :: POSITION_Y_BITS + POSITION_Z_BITS
POSITION_Y_SHIFT :: POSITION_Z_BITS
POSITION_X_MAX :: (1 << (POSITION_X_BITS - 1)) - 1
POSITION_X_MIN :: -(1 << (POSITION_X_BITS - 1))
POSITION_Y_MAX :: (1 << (POSITION_Y_BITS - 1)) - 1
POSITION_Y_MIN :: -(1 << (POSITION_Y_BITS - 1))
POSITION_Z_MAX :: (1 << (POSITION_Z_BITS - 1)) - 1
POSITION_Z_MIN :: -(1 << (POSITION_Z_BITS - 1))

METADATA_END_MARKER :: 0x7F

@(private)
@(require_results)
to_u32 :: #force_inline proc(v: i32) -> u32 {
	w := v
	return (^u32)(&w)^
}

Buffer_Reader :: struct {
	data: []u8,
	pos:  int,
}

Buffer_Writer :: struct {
	buf:       [dynamic]u8,
	allocator: mem.Allocator,
}

buffer_reader_init :: proc(r: ^Buffer_Reader, data: []u8) {
	r.data = data
	r.pos = 0
}

buffer_writer_init :: proc(w: ^Buffer_Writer, allocator: mem.Allocator, initial_cap := 64) {
	w.buf = make([dynamic]u8, 0, initial_cap, allocator)
	w.allocator = allocator
}

buffer_writer_destroy :: proc(w: ^Buffer_Writer) {
	delete(w.buf)
}

buffer_writer_bytes :: proc(w: ^Buffer_Writer) -> []u8 {
	return w.buf[:]
}

@(private)
_buffer_reader_eof :: proc(r: ^Buffer_Reader) -> bool {
	return r.pos >= len(r.data)
}

br_read_byte :: proc(r: ^Buffer_Reader) -> (u8, Protocol_Recv_Error) {
	if _buffer_reader_eof(r) {
		return 0, .Connection_Closed
	}
	b := r.data[r.pos]
	r.pos += 1
	return b, nil
}

br_read_bytes :: proc(r: ^Buffer_Reader, dst: []u8) -> (int, Protocol_Recv_Error) {
	if _buffer_reader_eof(r) {
		return 0, .Connection_Closed
	}
	n := min(len(dst), len(r.data) - r.pos)
	copy(dst, r.data[r.pos:r.pos + n])
	r.pos += n
	return n, nil
}

br_read_int :: proc(r: ^Buffer_Reader, $T: typeid) -> (T, Protocol_Recv_Error) {
	size := size_of(T)
	if r.pos + size > len(r.data) {
		return 0, .Connection_Closed
	}
	slice := r.data[r.pos:r.pos + size]
	r.pos += size

	when T == u16 || T == i16 {
		return T(endian.unchecked_get_u16be(slice)), nil
	} else when T == u32 || T == i32 {
		return T(endian.unchecked_get_u32be(slice)), nil
	} else when T == u64 || T == i64 {
		return T(endian.unchecked_get_u64be(slice)), nil
	} else when T == f32 {
		return transmute(f32)endian.unchecked_get_u32be(slice), nil
	} else when T == f64 {
		return transmute(f64)endian.unchecked_get_u64be(slice), nil
	} else {
		#panic("br_read_int: unsupported type")
	}
}

bw_write_byte :: proc(w: ^Buffer_Writer, b: u8) -> Protocol_Send_Error {
	append(&w.buf, b)
	return nil
}

bw_write_bytes :: proc(w: ^Buffer_Writer, src: []u8) -> Protocol_Send_Error {
	append(&w.buf, ..src)
	return nil
}

bw_write_int :: proc(w: ^Buffer_Writer, $T: typeid, value: T) -> Protocol_Send_Error {
	size := size_of(T)
	assert(size <= 16)
	buf: [16]u8
	slice := buf[:size]

	when T == u8 || T == i8 {
		slice[0] = u8(value)
	} else when T == u16 || T == i16 {
		endian.unchecked_put_u16be(slice, u16(value))
	} else when T == u32 || T == i32 {
		endian.unchecked_put_u32be(slice, u32(value))
	} else when T == u64 || T == i64 {
		endian.unchecked_put_u64be(slice, u64(value))
	} else when T == f32 {
		endian.unchecked_put_u32be(slice, transmute(u32)value)
	} else when T == f64 {
		endian.unchecked_put_u64be(slice, transmute(u64)value)
	} else {
		#panic("bw_write_int: unsupported type")
	}
	append(&w.buf, ..slice)
	return nil
}

bw_write_varint :: proc(w: ^Buffer_Writer, value: i64) -> Protocol_Send_Error {
	val32 := i32(value)
	buf: [10]u8

	n, err := varint.encode_uleb128(buf[:], u128(to_u32(val32)))
	if err != nil {
		return .Unknown
	}

	assert(n <= 5)
	append(&w.buf, ..buf[:n])
	return nil
}

bw_write_string :: proc(w: ^Buffer_Writer, s: string) -> Protocol_Send_Error {
	if err := bw_write_varint(w, i64(len(s))); err != nil {
		return err
	}
	return bw_write_bytes(w, transmute([]u8)s)
}

bw_write_position :: proc(w: ^Buffer_Writer, x, y, z: i32) -> Protocol_Send_Error {
	val :=
		(u64(u32(x)) & ((1 << POSITION_X_BITS) - 1)) << POSITION_X_SHIFT |
		(u64(u32(y)) & ((1 << POSITION_Y_BITS) - 1)) << POSITION_Y_SHIFT |
		(u64(u32(z)) & ((1 << POSITION_Z_BITS) - 1))
	if err := bw_write_int(w, u64, val); err != nil {
		return err
	}
	return nil
}

bw_write_uuid :: proc(w: ^Buffer_Writer, uuid: [16]u8) -> Protocol_Send_Error {
	tmp := uuid
	return bw_write_bytes(w, tmp[:])
}

// --- Read helpers ---

read_varint :: proc(r: ^Buffer_Reader) -> (i32, Protocol_Recv_Error) {
	val, size, err := varint.decode_uleb128_buffer(r.data[r.pos:])
	if err != nil {
		return 0, .Connection_Closed
	}
	if size > 5 {
		return 0, .Invalid_Argument
	}
	r.pos += size
	return i32(val), nil
}

read_ushort :: proc(r: ^Buffer_Reader) -> (u16, Protocol_Recv_Error) {
	return br_read_int(r, u16)
}

read_short :: proc(r: ^Buffer_Reader) -> (i16, Protocol_Recv_Error) {
	return br_read_int(r, i16)
}

read_int :: proc(r: ^Buffer_Reader) -> (i32, Protocol_Recv_Error) {
	return br_read_int(r, i32)
}

read_long :: proc(r: ^Buffer_Reader) -> (i64, Protocol_Recv_Error) {
	return br_read_int(r, i64)
}

read_float :: proc(r: ^Buffer_Reader) -> (f32, Protocol_Recv_Error) {
	v, err := br_read_int(r, u32)
	if err != nil {
		return 0, err
	}
	return transmute(f32)v, nil
}

read_double :: proc(r: ^Buffer_Reader) -> (f64, Protocol_Recv_Error) {
	v, err := br_read_int(r, u64)
	if err != nil {
		return 0, err
	}
	return transmute(f64)v, nil
}

read_ubyte :: proc(r: ^Buffer_Reader) -> (u8, Protocol_Recv_Error) {
	return br_read_byte(r)
}

read_byte :: proc(r: ^Buffer_Reader) -> (i8, Protocol_Recv_Error) {
	b, err := br_read_byte(r)
	return i8(b), err
}

read_boolean :: proc(r: ^Buffer_Reader) -> (bool, Protocol_Recv_Error) {
	b, err := br_read_byte(r)
	return b != 0, err
}

read_string :: proc(r: ^Buffer_Reader) -> (string, Protocol_Recv_Error) {
	length, err := read_varint(r)
	if err != nil {
		return "", err
	}
	if length < 0 || i64(length) > i64(len(r.data) - r.pos) {
		return "", .Connection_Closed
	}
	n := int(length)
	s := string(r.data[r.pos:r.pos + n])
	r.pos += n
	return s, nil
}

@(private)
read_chat :: proc(r: ^Buffer_Reader) -> (string, Protocol_Recv_Error) {
	return read_string(r)
}

read_uuid :: proc(r: ^Buffer_Reader) -> ([16]u8, Protocol_Recv_Error) {
	uuid: [16]u8
	_, err := br_read_bytes(r, uuid[:])
	return uuid, err
}

read_position :: proc(r: ^Buffer_Reader) -> (Position, Protocol_Recv_Error) {
	val, err := br_read_int(r, u64)

	if err != nil {
		return {}, err
	}

	x_raw := i32(val >> POSITION_X_SHIFT)
	y_raw := i32((val >> POSITION_Y_SHIFT) & ((1 << POSITION_Y_BITS) - 1))
	z_raw := i32(val & ((1 << POSITION_Z_BITS) - 1))

	x := x_raw
	if x >= 1 << (POSITION_X_BITS - 1) {
		x -= 1 << POSITION_X_BITS
	}

	y := y_raw
	if y >= 1 << (POSITION_Y_BITS - 1) {
		y -= 1 << POSITION_Y_BITS
	}

	z := z_raw
	if z >= 1 << (POSITION_Z_BITS - 1) {
		z -= 1 << POSITION_Z_BITS
	}

	return Position{x = x, y = y, z = z}, nil
}

Position :: struct {
	x: i32,
	y: i32,
	z: i32,
}

Item_Slot :: struct {
	item_id: i16,
	count:   u8,
	damage:  i16,
	nbt:     Nbt_Tag,
}

write_item_slot :: proc(w: ^Buffer_Writer, slot: Item_Slot) -> Protocol_Send_Error {
	if err := bw_write_int(w, i16, slot.item_id); err != nil {
		return err
	}
	if slot.item_id == -1 {
		return nil
	}
	if err := bw_write_byte(w, slot.count); err != nil {
		return err
	}
	if err := bw_write_int(w, i16, slot.damage); err != nil {
		return err
	}
	return write_nbt(w, slot.nbt)
}

read_item_slot :: proc(
	r: ^Buffer_Reader,
	allocator: mem.Allocator,
) -> (
	Item_Slot,
	Protocol_Recv_Error,
) {
	id, e0 := br_read_int(r, i16)
	if e0 != nil {return {}, e0}
	if id == -1 {
		return Item_Slot{item_id = -1}, nil
	}
	count, e1 := br_read_byte(r)
	if e1 != nil {return {}, e1}
	damage, e2 := br_read_int(r, i16)
	if e2 != nil {return {}, e2}
	nbt, e3 := read_nbt(r, allocator)
	if e3 != nil {return {}, e3}
	return Item_Slot{item_id = id, count = count, damage = damage, nbt = nbt}, nil
}

Metadata_Entry :: struct {
	index: u8,
	type:  u8,
	value: union {
		i8,
		i16,
		i32,
		f32,
		string,
		Item_Slot,
		[3]i32,
		[3]f32,
	},
}

read_metadata_entries :: proc(
	r: ^Buffer_Reader,
	allocator: mem.Allocator,
) -> (
	[]Metadata_Entry,
	Protocol_Recv_Error,
) {
	entries := make([dynamic]Metadata_Entry, allocator)
	defer delete(entries)

	for {
		header, err := br_read_byte(r)
		if err != nil {return {}, err}
		if header == METADATA_END_MARKER {break}

		typ := header >> 5
		idx := header & 0x1F
		entry := Metadata_Entry {
			index = idx,
			type  = typ,
		}

		switch typ {
		case 0:
			v, e := read_byte(r)
			if e != nil {return {}, e}
			entry.value = v
		case 1:
			v, e := read_short(r)
			if e != nil {return {}, e}
			entry.value = v
		case 2:
			v, e := read_int(r)
			if e != nil {return {}, e}
			entry.value = v
		case 3:
			v, e := read_float(r)
			if e != nil {return {}, e}
			entry.value = v
		case 4:
			v, e := read_string(r)
			if e != nil {return {}, e}
			entry.value = v
		case 5:
			v, e := read_item_slot(r, allocator)
			if e != nil {return {}, e}
			entry.value = v
		case 6:
			x, e0 := read_int(r)
			if e0 != nil {return {}, e0}
			y, e1 := read_int(r)
			if e1 != nil {return {}, e1}
			z, e2 := read_int(r)
			if e2 != nil {return {}, e2}
			entry.value = [3]i32{x, y, z}
		case 7:
			x, e0 := read_float(r)
			if e0 != nil {return {}, e0}
			y, e1 := read_float(r)
			if e1 != nil {return {}, e1}
			z, e2 := read_float(r)
			if e2 != nil {return {}, e2}
			entry.value = [3]f32{x, y, z}
		case:
			return {}, .Invalid_Argument
		}
		append(&entries, entry)
	}

	out := make([]Metadata_Entry, len(entries), allocator)
	copy(out, entries[:])
	return out, nil
}

write_metadata_entries :: proc(
	w: ^Buffer_Writer,
	entries: []Metadata_Entry,
) -> Protocol_Send_Error {
	for e in entries {
		header := (e.type << 5) | (e.index & 0x1F)
		if err := bw_write_byte(w, header); err != nil {
			return err
		}
		#partial switch v in e.value {
		case i8:
			if err := bw_write_byte(w, u8(v)); err != nil {return err}
		case i16:
			if err := bw_write_int(w, i16, v); err != nil {return err}
		case i32:
			if err := bw_write_int(w, i32, v); err != nil {return err}
		case f32:
			if err := bw_write_int(w, f32, v); err != nil {return err}
		case string:
			if err := bw_write_string(w, v); err != nil {return err}
		case Item_Slot:
			if err := write_item_slot(w, v); err != nil {return err}
		case [3]i32:
			if err := bw_write_int(w, i32, v[0]); err != nil {return err}
			if err := bw_write_int(w, i32, v[1]); err != nil {return err}
			if err := bw_write_int(w, i32, v[2]); err != nil {return err}
		case [3]f32:
			if err := bw_write_int(w, f32, v[0]); err != nil {return err}
			if err := bw_write_int(w, f32, v[1]); err != nil {return err}
			if err := bw_write_int(w, f32, v[2]); err != nil {return err}
		}
	}
	return bw_write_byte(w, METADATA_END_MARKER)
}

json_escape :: proc(s: string, allocator: mem.Allocator) -> string {
	out: [dynamic]u8
	out = make([dynamic]u8, 0, len(s) + 4, allocator)
	hex_digits := "0123456789ABCDEF"
	for i := 0; i < len(s); i += 1 {
		c := s[i]
		switch c {
		case '"':
			append(&out, '\\', '"')
		case '\\':
			append(&out, '\\', '\\')
		case '\b':
			append(&out, '\\', 'b')
		case '\f':
			append(&out, '\\', 'f')
		case '\n':
			append(&out, '\\', 'n')
		case '\r':
			append(&out, '\\', 'r')
		case '\t':
			append(&out, '\\', 't')

			default: if c < 0x20 {
				append(&out, '\\', 'u', '0', '0')
				append(&out, hex_digits[c >> 4])
				append(&out, hex_digits[c & 0xF])
			} else {
				append(&out, c)
			}
		}
	}
	return string(out[:])
}
