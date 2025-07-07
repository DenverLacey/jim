package tests

import "core:testing"
import "core:strings"
import jim ".."

@(test)
serialize_empty_object :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object_begin(&ser)
    jim.object_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "{}")
}

@(test)
serialize_empty_object_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.object_begin(&ser)
    jim.object_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "{\n}")
}

@(test)
serialize_object :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object_begin(&ser)
        jim.object_member(&ser, "x")
        jim.null(&ser)
        jim.object_member(&ser, "y")
        jim.boolean(&ser, true)
        jim.object_member(&ser, "z")
        jim.number(&ser, 3.14)
        jim.object_member(&ser, "w")
        jim.str(&ser, "hello")
    jim.object_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `{"x":null,"y":true,"z":3.14,"w":"hello"}`)
}

@(test)
serialize_object_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.object_begin(&ser)
        jim.object_member(&ser, "x")
        jim.null(&ser)
        jim.object_member(&ser, "y")
        jim.boolean(&ser, true)
        jim.object_member(&ser, "z")
        jim.number(&ser, 3.14)
        jim.object_member(&ser, "w")
        jim.str(&ser, "hello")
    jim.object_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "{\n    \"x\": null,\n    \"y\": true,\n    \"z\": 3.14,\n    \"w\": \"hello\"\n}")
}

@(test)
serialize_empty_array :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb)}

    jim.array_begin(&ser)
    jim.array_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "[]")
}

@(test)
serialize_empty_array_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.array_begin(&ser)
    jim.array_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "[\n]")
}

@(test)
serialize_array :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb)}

    jim.array_begin(&ser)
        jim.null(&ser)
        jim.boolean(&ser, false)
        jim.number(&ser, 1.5)
        jim.str(&ser, "goodbye")
    jim.array_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `[null,false,1.5,"goodbye"]`)
}

@(test)
serialize_array_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.array_begin(&ser)
        jim.null(&ser)
        jim.boolean(&ser, false)
        jim.number(&ser, 1.5)
        jim.str(&ser, "goodbye")
    jim.array_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "[\n    null,\n    false,\n    1.5,\n    \"goodbye\"\n]")
}

@(test)
serialize_nested :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object_begin(&ser)
        jim.object_member(&ser, "array")
        jim.array_begin(&ser)
            jim.number(&ser, 1)
            jim.number(&ser, 2)
            jim.number(&ser, 3)
        jim.array_end(&ser)
        jim.object_member(&ser, "obj")
        jim.object_begin(&ser)
            jim.object_member(&ser, "name")
            jim.str(&ser, "John Smith")
            jim.object_member(&ser, "age")
            jim.number(&ser, 32)
        jim.object_end(&ser)
    jim.object_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `{"array":[1,2,3],"obj":{"name":"John Smith","age":32}}`)
}

@(test)
serialize_nested_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    ser := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.object_begin(&ser)
        jim.object_member(&ser, "array")
        jim.array_begin(&ser)
            jim.number(&ser, 1)
            jim.number(&ser, 2)
            jim.number(&ser, 3)
        jim.array_end(&ser)
        jim.object_member(&ser, "obj")
        jim.object_begin(&ser)
            jim.object_member(&ser, "name")
            jim.str(&ser, "John Smith")
            jim.object_member(&ser, "age")
            jim.number(&ser, 32)
        jim.object_end(&ser)
    jim.object_end(&ser)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `{
    "array": [
        1,
        2,
        3
    ],
    "obj": {
        "name": "John Smith",
        "age": 32
    }
}`)
}

@(test)
deserialize_empty_object :: proc(t: ^testing.T) {
    json := "{}"
    de := jim.Deserializer{strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failled to find beginning of empty object")

    ok = jim.object_end(&de)
    testing.expect(t, ok, "Failled to find ending of empty object")
}

@(test)
deserialize_empty_object_pp :: proc(t: ^testing.T) {
    json := "{\n}"
    de := jim.Deserializer{strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failled to find beginning of empty object")

    ok = jim.object_end(&de)
    testing.expect(t, ok, "Failled to find ending of empty object")
}

@(test)
deserialize_object :: proc(t: ^testing.T) {
    json := `{"msg": "hello"}`
    de := jim.Deserializer{strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failed to find beginning of object")

    key: string
    key, ok = jim.object_member(&de)
    testing.expect(t, ok, "Failed to find key of object")
    testing.expect_value(t, key, "msg")
    delete(key)

    value: string
    value, ok = jim.str(&de)
    testing.expect(t, ok, "Failed to find value for 'msg'")
    testing.expect_value(t, value, "hello")
    delete(value)

    ok = jim.object_end(&de)
    testing.expect(t, ok, "Failed to find ending of object")
}

