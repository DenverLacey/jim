package jim

import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:unicode"

object_begin  :: proc{serialize_object_begin, deserialize_object_begin}
object_end    :: proc{serialize_object_end, deserialize_object_end}
array_begin   :: proc{serialize_array_begin, deserialize_array_begin}
array_end     :: proc{serialize_array_end, deserialize_array_end}
object_member :: proc{serialize_object_member, deserialize_object_member}
boolean       :: proc{serialize_boolean, deserialize_boolean}
number        :: proc{serialize_number, deserialize_number}
str           :: proc{serialize_str, deserialize_str}

Serializer :: struct {
    pp: int,
    cur_indent: int,
    array_depth: int,
    out: io.Writer,
    prev: [2]byte,
}

serialize_object_begin :: proc(s: ^Serializer) {
    jprintf(s, "{{")
    if s.pp != 0 {
        s.cur_indent += 1
    }
}

serialize_object_end :: proc(s: ^Serializer) {
    if s.pp != 0 {
        assert(s.cur_indent > 0)
        s.cur_indent -= 1
        jprintf(s, "\n%*v", s.cur_indent * s.pp, "")
    }
    jprintf(s, "}}")
}

serialize_array_begin :: proc(s: ^Serializer) {
    jprintf(s, "[")
    if s.pp != 0 {
        s.cur_indent += 1
    }
    s.array_depth += 1
}

serialize_array_end :: proc(s: ^Serializer) {
    if s.pp != 0 {
        assert(s.cur_indent > 0)
        s.cur_indent -= 1
        jprintf(s, "\n%*v", s.cur_indent * s.pp, "")
    }
    jprintf(s, "]")
    s.array_depth -= 1
}

serialize_object_member :: proc(s: ^Serializer, key: string) {
    if needs_comma(s.prev) {
        jprintf(s, ",")
    }

    if s.pp != 0 {
        jprintf(s, "\n%*v\"%v\": ", s.cur_indent * s.pp, "", key)
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

@(private)
jprintf :: proc(s: ^Serializer, format: string, args: ..any) {
    bytes: [256]byte
    sb := strings.builder_from_bytes(bytes[:])
    r := fmt.sbprintf(&sb, format, ..args)
    if len(r) == 0 {
        return
    }

    if len(r) == 1 {
        s.prev[0] = s.prev[1]
        s.prev[1] = r[0]
    } else {
        s.prev[0] = r[len(r) - 2]
        s.prev[1] = r[len(r) - 1]
    }

    if s.out == {} {
        ok: bool
        s.out, ok = io.to_writer(os.stream_from_handle(os.stdout))
        assert(ok)
    }

    io.write_string(s.out, r)
}

@(private)
needs_comma :: proc(buf: [2]byte) -> bool {
    b := buf
    return b[1] != '{' && b[1] != '[' && b[1] != 0 && string(b[:]) != "{\n" && string(b[:]) != "[\n"
}

@(private)
format_for_array_if_needed :: proc(s: ^Serializer) {
    if s.array_depth <= 0 {
        return
    }

    if needs_comma(s.prev) {
        jprintf(s, ",")
    }

    if s.pp != 0 {
        jprintf(s, "\n%*v", s.cur_indent * s.pp, "")
    }
}

Deserializer :: struct {
    bytes: io.Reader,
}

deserialize_object_begin :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d.bytes, .OCURLY)
    return ok
}

deserialize_object_end :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d.bytes, .CCURLY)
    return ok
}

deserialize_array_begin :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d.bytes, .OBRACKET)
    return ok
}

deserialize_array_end :: proc(d: ^Deserializer) -> bool {
    _, ok := expect(d.bytes, .CBRACKET)
    return ok
}

deserialize_object_member :: proc(d: ^Deserializer) -> (key: string, ok: bool) {
    key = deserialize_str(d) or_return
    expect(d.bytes, .COLON) or_return
    return key, true
}

deserialize_boolean :: proc(d: ^Deserializer) -> (value: bool, ok: bool) {
    unimplemented()
}

deserialize_number :: proc(d: ^Deserializer) -> (value: f64, ok: bool) {
    unimplemented()
}

deserialize_str :: proc(d: ^Deserializer) -> (value: string, ok: bool) {
    tok := expect(d.bytes, .STRING) or_return
    res, err := strings.clone(string(tok.text[:tok.len]))
    if err != nil {
        return "", false
    }
    return res, true
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
skip_whitespace :: proc(r: io.Reader) -> (c: rune, ok: bool) {
    for {
        c, _, err := io.read_rune(r);
        if err != nil {
            return 0, false
        }
        if !unicode.is_white_space(c) {
            return c, true
        }
    }
}

@(private)
next_token :: proc(r: io.Reader) -> (token: Token, ok: bool) {
    c, scs := skip_whitespace(r)
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
            c, _, err := io.read_rune(r);
            if err != nil {
                return {}, false
            }
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
        if unicode.is_letter(c) {
            unimplemented()
        } else if unicode.is_digit(c) {
            unimplemented()
        } else {
            unimplemented()
        }
    }

    return token, true
}

@(private)
expect :: proc(r: io.Reader, kind: TokenKind) -> (token: Token, ok: bool) {
    token = next_token(r) or_return
    return token, token.kind == kind
}

