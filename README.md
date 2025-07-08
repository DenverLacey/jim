# Jim

An immediate mode JSON (de)serialization library that doesn't produce a tree. (Based on [Tsoding's C version of the same idea](https://github.com/tsoding/jim).)

Jim doesn't create a tree to work with JSON data, it instead directly generates JSON or directly parses values.

This reduces the memory footprint for serializing and deserializing and also gives you schema validation for free.

The downside of this approach is that you essentially make a (de)serializer for one specific schema at a time. This makes this library's
approach not suited for situations where you have no idea what the data layout of the incoming JSON is.

However, in situations where the layout is known (or can be deduced,) this library can be useful for parsing JSON in a low-memory-cost manner
and can provide data validation essentially for free.

# Usage

## Serialization

Say we wanted to print this JSON to stdout.

```json
{
  "msg": "Hello world!",
  "sender": "Alex Smith"
}
```

The code to do this using Jim would look like this.

```odin
import "jim"
print_json :: proc() {
    // `pp` sets indent size
    se := jim.Serializer{pp = 2}

    jim.object_begin(&se)
        jim.object_member(&se, "msg")
        jim.str(&se, "Hello world!")
        jim.object_member(&se, "sender")
        jim.str(&se, "Alex Smith")
    jim.object_end(&se)
}
```

`Serializer` uses an `io.Writer` to emit the JSON so it is possible to specify the output (stdout is the default.)

```odin
sb := strings.Builder{}
se := jim.Serializer{out=strings.to_writer(&sb)}

// build json output ...

output_json := strings.to_string(sb)
```

## Deserialization

Now let's see how you would parse json that follows that format.

```odin
import "core:fmt"
import "core:strings"
import "jim"
parse_json :: proc(json: string) -> (ok: bool) {
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}
    
    jim.object_begin(&de) or_return
        msg_member := jim.object_member(&de) or_return
        assert(msg_member == "msg")

        msg_value := jim.str(&de) or_return

        sender_member := jim.object_member(&de) or_return
        assert(sender_member == "sender")

        sender_value := jim.str(&de) or_return
    jim.object_end(&de) or_return

    fmt.printfln("msg = %w, sender = %w", msg_value, sender_value)
}
```

The cool thing is that parsing happens gradually and doesn't need to build a tree of a bunch of heap allocated objects because everything happens immediately.

NOTE: At the moment strings are cloned and thus require freeing. You can set `context.allocator` to change this behaviour.

