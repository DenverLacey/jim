package jim

import "core:strconv"
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
    _prev: [2]byte,
    _cur_indent: int,
    _array_depth: int,
    pp: int,
    out: io.Writer,
}

serialize_object_begin :: proc(s: ^Serializer) {
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

serialize_object_member :: proc(s: ^Serializer, key: string) {
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

@(private)
jprintf :: proc(s: ^Serializer, format: string, args: ..any) {
    bytes: [256]byte
    sb := strings.builder_from_bytes(bytes[:])
    r := fmt.sbprintf(&sb, format, ..args)
    if len(r) == 0 {
        return
    }

    if len(r) == 1 {
        s._prev[0] = s._prev[1]
        s._prev[1] = r[0]
    } else {
        s._prev[0] = r[len(r) - 2]
        s._prev[1] = r[len(r) - 1]
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
    if s._array_depth <= 0 {
        return
    }

    if needs_comma(s._prev) {
        jprintf(s, ",")
    }

    if s.pp != 0 {
        jprintf(s, "\n%*v", s._cur_indent * s.pp, "")
    }
}

Deserializer :: struct {
    _peeked: bool,
    _peeked_char: rune,
    input: io.Reader,
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

deserialize_object_member :: proc(d: ^Deserializer) -> (key: string, ok: bool) {
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

