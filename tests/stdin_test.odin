package jim_tests

import "core:fmt"
import "core:io"
import "core:os"
import jim ".."

Object :: struct {
    from: string,
    msg: string,
}

parse_object_json :: proc(de: ^jim.Deserializer) -> (res: Object, ok: bool) {
    jim.object_begin(de) or_return
    for !jim.is_object_end(de) {
        key := jim.key(de) or_return
        defer delete(key)

        switch key {
        case "msg":
            res.msg = jim.str(de) or_return
        case "from":
            res.from = jim.str(de) or_return
        case:
            fmt.printfln("Error: Invalid key in input json: %w", key)
            return res, false
        }
    }
    jim.object_end(de) or_return

    return res, true
}

when !ODIN_TEST {
    main :: proc() {
        de := jim.Deserializer{}
        obj, ok := parse_object_json(&de)
        if !ok {
            return
        }

        fmt.printfln("%#v", obj)
    }
}

