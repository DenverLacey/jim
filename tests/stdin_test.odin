package jim_tests

import "core:fmt"
import "core:io"
import "core:os"
import jim ".."

Object :: struct {
    sender: string,
    msg: string,
}

parse_object_json :: proc(de: ^jim.Deserializer) -> (res: Object, ok: bool) {
    jim.object_begin(de) or_return
    for !jim.is_object_end(de) {
        key := jim.object_member(de) or_return
        defer delete(key)

        switch key {
        case "msg":
            res.msg = jim.str(de) or_return
        case "sender":
            res.sender = jim.str(de) or_return
        case:
            fmt.printfln("Error: Invalid key in input json: %w", key)
            return res, false
        }
    }
    jim.object_end(de) or_return

    return res, true
}

main :: proc() {
    stdin, ok_stdin := io.to_reader(os.stream_from_handle(os.stdin))
    if !ok_stdin {
        return
    }

    de := jim.Deserializer{input = stdin}
    obj, obj_ok := parse_object_json(&de)
    if !obj_ok {
        return
    }

    fmt.printfln("%#v", obj)
}

