package jim

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

object_begin :: proc{serialize_object_begin, deserialize_object_begin}
object_end   :: proc{serialize_object_end, deserialize_object_end}
array_begin  :: proc{serialize_array_begin, deserialize_array_begin}
array_end    :: proc{serialize_array_end, deserialize_array_end}
key          :: proc{serialize_key, deserialize_key}
boolean      :: proc{serialize_boolean, deserialize_boolean}
number       :: proc{serialize_number, deserialize_number}
str          :: proc{serialize_str, serialize_enum_str, deserialize_str, deserialize_enum_str}

when !ODIN_NO_RTTI {
    object :: proc{serialize_object, deserialize_object}
}

Serializer :: struct {
    out: io.Writer,
    pp: u16,
    _cur_indent: u16,
    _array_depth: u16,
    _prev: byte,
}

serialize_object_begin :: proc(s: ^Serializer) {
    format_for_array_if_needed(s)
    jprintf(s, "{{")
    if s.pp != 0 {
        s._cur_indent += 1
    }
}

serialize_object_end :: proc(s: ^Serializer) {
    if s.pp != 0 {
        assert(s._cur_indent > 0)
        s._cur_indent -= 1
        jprintf(s, "\n%*v", s._cur_indent * s.pp, "")
    }
    jprintf(s, "}}")
}

serialize_array_begin :: proc(s: ^Serializer) {
    format_for_array_if_needed(s)
    jprintf(s, "[")
    if s.pp != 0 {
        s._cur_indent += 1
    }
    s._array_depth += 1
}

serialize_array_end :: proc(s: ^Serializer) {
    if s.pp != 0 {
        assert(s._cur_indent > 0)
        s._cur_indent -= 1
        jprintf(s, "\n%*v", s._cur_indent * s.pp, "")
    }
    jprintf(s, "]")
    s._array_depth -= 1
}

serialize_key :: proc(s: ^Serializer, key: string) {
    if needs_comma(s._prev) {
        jprintf(s, ",")
    }

    if s.pp != 0 {
        jprintf(s, "\n%*v\"%v\": ", s._cur_indent * s.pp, "", key)
    } else {
        jprintf(s, "\"%v\":", key)
    }
}

null :: proc(s: ^Serializer) {
    format_for_array_if_needed(s)
    jprintf(s, "null")
}

serialize_boolean :: proc(s: ^Serializer, value: bool) {
    format_for_array_if_needed(s)
    jprintf(s, "%t", value)
}

serialize_number :: proc(s: ^Serializer, value: f64) {
    format_for_array_if_needed(s)
    jprintf(s, "%v", value)
}

serialize_str :: proc(s: ^Serializer, value: string) {
    format_for_array_if_needed(s)
    jprintf(s, "%w", value)
}

serialize_enum_str :: proc(s: ^Serializer, value: $E)
    where intrinsics.type_is_enum(E)
{
    format_for_array_if_needed(s)
    e_info := reflect.type_info_base(type_info_of(E)).variant.(Type_Info_Enum)
    name := reflect.enum_name_from_value(value)
    str(s, name)
}

when !ODIN_NO_RTTI {
    serialize_object :: proc(s: ^Serializer, value: $T, caller := #caller_location) {
        format_for_array_if_needed(s)
        ti := reflect.type_info_base(type_info_of(T))
        if !type_is_serializable(ti) || !reflect.is_struct(ti) {
            panic("Tried to serialize an object that cannot be serialized.", caller)
        }
        serialize_any(s, value)
    }

    @(private)
    serialize_any :: proc(s: ^Serializer, value: any) {
        bti := reflect.type_info_base(type_info_of(value.id))
        #partial switch ti in bti.variant {
        case runtime.Type_Info_Boolean:
            field_value := value.(bool)
            boolean(s, field_value)
        case runtime.Type_Info_Rune:
            field_value := value.(rune)
            buf: [4]byte
            sb := strings.builder_from_bytes(buf[:])
            strings.write_rune(&sb, field_value)
            str(s, strings.to_string(sb))
        case runtime.Type_Info_Integer:
            unimplemented()
        case runtime.Type_Info_Float:
            field_value := value.(f64)
            number(s, field_value)
        case runtime.Type_Info_String:
            field_value := value.(string)
            str(s, field_value)
        case runtime.Type_Info_Array, runtime.Type_Info_Dynamic_Array, runtime.Type_Info_Slice:
            array_begin(s)
            it := 0
            for elem in reflect.iterate_array(value, &it) {
                serialize_any(s, elem)
            }
            array_end(s)
        case runtime.Type_Info_Struct:
            object_begin(s)
            for i in 0..<ti.field_count {
                field := reflect.struct_field_at(bti.id, int(i))
                key(s, field.name)
                serialize_any(s, reflect.struct_field_value(value, field))
            }
            object_end(s)
        case runtime.Type_Info_Enum:
            name, ok := reflect.enum_name_from_value_any(value)
            assert(ok)
            str(s, name)
        case:
            unreachable()
        }
    }
}

@(private)
jprintf :: proc(s: ^Serializer, format: string, args: ..any) {
    if s.out == {} {
        ok: bool
        s.out, ok = io.to_writer(os.stream_from_handle(os.stdout))
        assert(ok)
    }

    bytes: [256]byte
    sb := strings.builder_from_bytes(bytes[:])
    r := fmt.sbprintf(&sb, format, ..args)
    if len(r) == 0 {
        return
    }

    s._prev = r[len(r) - 1]
    io.write_string(s.out, r)
}

@(private)
needs_comma :: proc(prev: byte) -> bool {
    return prev != '{' && prev != '[' && prev != ',' && prev != '\n' && prev != ' ' && prev != ':' && prev != 0
}

@(private)
needs_newline :: proc(s: ^Serializer) -> bool {
    if s.pp == 0 {
        return false
    }
    p := s._prev
    return (p == '{' || p == '[' || p == ',') && (p != '\n' && p != ' ' && p != ':' && p != 0)
}

@(private)
format_for_array_if_needed :: proc(s: ^Serializer) {
    if s._array_depth <= 0 {
        return
    }

    if needs_comma(s._prev) {
        jprintf(s, ",")
    }

    if needs_newline(s) {
        jprintf(s, "\n%*v", s._cur_indent * s.pp, "")
    }
}

@(private)
type_is_serializable :: proc(T: ^runtime.Type_Info) -> bool {
    bti := reflect.type_info_base(T)
    #partial switch ti in bti.variant {
    case runtime.Type_Info_Boolean:
    case runtime.Type_Info_Rune:
    case runtime.Type_Info_Integer:
    case runtime.Type_Info_Float:
    case runtime.Type_Info_String:
    case runtime.Type_Info_Array:
        return type_is_serializable(ti.elem)
    case runtime.Type_Info_Dynamic_Array:
        return type_is_serializable(ti.elem)
    case runtime.Type_Info_Slice:
        return type_is_serializable(ti.elem)
    case runtime.Type_Info_Struct:
        for i in 0..<ti.field_count {
            field_type := reflect.type_info_base(ti.types[i])
            ok := type_is_serializable(field_type)
            if !ok {
                return false
            }
        }
    case runtime.Type_Info_Enum:
    case:
        fmt.eprintfln("Error: Cannot serialize a value with of type `%v`", T)
        return false
    }
    return true
}

Deserializer :: struct {
    input: io.Reader,
    _peeked_char: rune,
    _peeked: bool,
}

deserialize_object_begin :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d, .OCURLY)
    return ok
}

deserialize_object_end :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d, .CCURLY)
    return ok
}

deserialize_array_begin :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d, .OBRACKET)
    return ok
}

deserialize_array_end :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d, .CBRACKET)
    return ok
}

is_object_end :: proc(d: ^Deserializer) -> bool {
    c := skip_whitespace(d) or_return
    d._peeked_char = c
    d._peeked = true
    return c == '}'
}

is_array_end :: proc(d: ^Deserializer) -> bool {
    c := skip_whitespace(d) or_return
    d._peeked_char = c
    d._peeked = true
    return c == ']'
}

deserialize_key :: proc(d: ^Deserializer) -> (key: string, ok: bool) {
    key = deserialize_str(d) or_return
    expect(d, .COLON) or_return
    return key, true
}

deserialize_boolean :: proc(d: ^Deserializer) -> (value: bool, ok: bool) {
    tok := next_token(d) or_return
    eat_char(d, ',') or_return

    #partial switch tok.kind {
    case .TRUE:
        return true, true
    case .FALSE:
        return false, true
    case:
        return false, false
    }
}

deserialize_number :: proc(d: ^Deserializer) -> (value: f64, ok: bool) {
    tok := expect(d, .NUMBER) or_return
    eat_char(d, ',') or_return

    value = strconv.atof(string(tok.text[:tok.len]))
    return value, true
}

deserialize_str :: proc(d: ^Deserializer) -> (value: string, ok: bool) {
    tok := expect(d, .STRING) or_return
    eat_char(d, ',') or_return
    res, err := strings.clone(string(tok.text[:tok.len]))
    if err != nil {
        return "", false
    }
    return res, true
}

deserialize_enum_str :: proc(d: ^Deserializer, $E: typeid) -> (value: E, ok: bool)
    where intrinsics.type_is_enum(E)
{
    name := str(d) or_return
    defer delete(name)
    return reflect.enum_from_name(E, name)
}

when !ODIN_NO_RTTI {
    deserialize_object :: proc(d: ^Deserializer, $T: typeid, allow_partial_init := false, caller := #caller_location) -> (value: T, ok: bool) {
        ti := reflect.type_info_base(type_info_of(T))
        if !type_is_serializable(ti) || !reflect.is_struct(ti) {
            panic("Tried to deserialize an object that cannot be deserialized.", caller)
        }
        ok = deserialize_value(d, ti, auto_cast &value, allow_partial_init)
        return
    }

    @(private)
    deserialize_value :: proc(d: ^Deserializer, info: ^runtime.Type_Info, value_ptr: uintptr, allow_partial_init: bool) -> (ok: bool) {
        bti := reflect.type_info_base(info)
        #partial switch ti in bti.variant {
        case runtime.Type_Info_Boolean:
            field_value := boolean(d) or_return
            field_ptr := cast(^bool)value_ptr
            field_ptr^ = field_value
        case runtime.Type_Info_Rune:
            field_value := str(d) or_return
            defer delete(field_value)
            if utf8.rune_count(field_value) != 1 {
                fmt.eprintfln("Error: Cannot convert string %w to a rune as it has more than one character.", field_value)
                return false
            }
            field_ptr := cast(^rune)value_ptr
            field_ptr^ = utf8.rune_at(field_value, 0)
        case runtime.Type_Info_Integer:
            unimplemented()
        case runtime.Type_Info_Float:
            field_value := number(d) or_return
            field_ptr := cast(^f64)value_ptr // TODO: Check size
            field_ptr^ = field_value
        case runtime.Type_Info_String:
            field_value := str(d) or_return
            field_ptr := cast(^string)value_ptr
            field_ptr^ = field_value
        case runtime.Type_Info_Array:
            unimplemented()
        case runtime.Type_Info_Slice:
            unimplemented()
        case runtime.Type_Info_Dynamic_Array:
            unimplemented()
        case runtime.Type_Info_Struct:
            set_fields: [dynamic]string
            defer {
                for field in set_fields {
                    delete(field)
                }
                delete(set_fields)
            }

            object_begin(d) or_return
            for !is_object_end(d) {
                k := key(d) or_return
                if _, found := slice.linear_search(set_fields[:], k); found {
                    fmt.eprintfln("Error: Duplicate key found: %v", k)
                    delete(k)
                    return false
                }

                append(&set_fields, k)

                field := reflect.struct_field_by_name(info.id, k)
                if field == {} {
                    fmt.eprintfln("Error: %v does not have a member called %v", info.id, k)
                    return false
                }

                ok = deserialize_value(d, field.type, value_ptr + field.offset, allow_partial_init)
                if !ok {
                    return
                }
            }
            object_end(d) or_return

            if !allow_partial_init && len(set_fields) != int(ti.field_count) {
                fmt.eprintfln("Error: Not all fields given a value.") // TODO: Improve error message
                return false
            }
        case runtime.Type_Info_Enum:
            field_value := str(d) or_return
            defer delete(field_value)

            idx, found := slice.linear_search(ti.names, field_value)
            if !found {
                fmt.eprintfln("Error: '%v' is not a valid value an %v", field_value, info.id)
                return false
            }

            enum_value := ti.values[idx]
            field_ptr := cast(^runtime.Type_Info_Enum_Value)value_ptr
            field_ptr^ = enum_value
        case:
            unreachable()
        }
        return true
    }
}

TokenKind :: enum {
    NONE,
    OCURLY,
    CCURLY,
    OBRACKET,
    CBRACKET,
    COMMA,
    COLON,
    NULL,
    TRUE,
    FALSE,
    NUMBER,
    STRING,
}

Token :: struct {
    kind: TokenKind,
    len: int,
    text: [256]byte,
}

@(private)
peek_char :: proc(d: ^Deserializer) -> (c: rune, ok: bool) {
    if d._peeked {
        return d._peeked_char, true
    }

    if d.input == {} {
        ok: bool
        d.input, ok = io.to_reader(os.stream_from_handle(os.stdin))
        assert(ok)
    }

    r, _, err := io.read_rune(d.input)
    if err != nil {
        return 0, false
    }

    d._peeked_char = r
    d._peeked = true
    return r, true
}

@(private)
next_char :: proc(d: ^Deserializer) -> (c: rune, ok: bool) {
    c = peek_char(d) or_return
    d._peeked = false
    return c, true
}

@(private)
skip_whitespace :: proc(d: ^Deserializer) -> (c: rune, ok: bool) {
    for {
        c = next_char(d) or_return
        if !unicode.is_white_space(c) {
            return c, true
        }
    }
}

@(private)
eat_char :: proc(d: ^Deserializer, ch: rune) -> (ok: bool) {
    c := skip_whitespace(d) or_return
    if c == ch {
        return true
    }
    d._peeked_char = c
    d._peeked = true
    return true
}

@(private)
next_token :: proc(d: ^Deserializer) -> (token: Token, ok: bool) {
    c, scs := skip_whitespace(d)
    if !scs {
        return {}, false
    }

    switch c {
    case '{':
        token = {kind = .OCURLY}
    case '}':
        token = {kind = .CCURLY}
    case '[':
        token = {kind = .OBRACKET}
    case ']':
        token = {kind = .CBRACKET}
    case ',':
        token = {kind = .COMMA}
    case ':':
        token = {kind = .COLON}
    case '"':
        sb := strings.builder_from_bytes(token.text[:])
        for { 
            c := next_char(d) or_return
            if c == '"' {
                break
            }
            // TODO: escaping
            strings.write_rune(&sb, c)
        }
        s := strings.to_string(sb)
        token.kind = .STRING
        token.len = len(s)
        for i in 0..<token.len {
            token.text[i] = s[i]
        }
    case:
        sb := strings.builder_from_bytes(token.text[:])

        _, err := strings.write_rune(&sb, c)
        if err != nil {
            return token, false
        }

        if unicode.is_letter(c) {
            for {
                c := peek_char(d) or_return
                if !unicode.is_letter(c) {
                    break
                }

                _, err = strings.write_rune(&sb, c)
                if err != nil {
                    return token, false
                }

                next_char(d)
            }

            token.len = strings.builder_len(sb)
            switch string(token.text[:token.len]) {
            case "null":
                token.kind = .NULL
            case "true":
                token.kind = .TRUE
            case "false":
                token.kind = .FALSE
            case:
                return token, false
            }
        } else if unicode.is_digit(c) {
            dot := false
            for {
                c := peek_char(d) or_return

                if c == '.' && !dot {
                    dot = true
                } else if !unicode.is_digit(c) {
                    break
                }

                _, err = strings.write_rune(&sb, c)
                if err != nil {
                    return token, false
                }

                next_char(d)
            }

            token.kind = .NUMBER
            token.len = strings.builder_len(sb)
        } else {
            unimplemented()
        }
    }

    return token, true
}

@(private)
expect :: proc(d: ^Deserializer, kind: TokenKind) -> (token: Token, ok: bool) {
    token = next_token(d) or_return
    return token, token.kind == kind
}

