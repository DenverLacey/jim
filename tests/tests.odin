#+feature dynamic-literals
package jim_tests

import "core:testing"
import "core:strings"
import jim ".."

@(test)
serialize_empty_object :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object_begin(&se)
    jim.object_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "{}")
}

@(test)
serialize_empty_object_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.object_begin(&se)
    jim.object_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "{\n}")
}

@(test)
serialize_object :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object_begin(&se)
        jim.key(&se, "x")
        jim.null(&se)
        jim.key(&se, "y")
        jim.boolean(&se, true)
        jim.key(&se, "z")
        jim.number(&se, 3.14)
        jim.key(&se, "w")
        jim.str(&se, "hello")
    jim.object_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `{"x":null,"y":true,"z":3.14,"w":"hello"}`)
}

@(test)
serialize_object_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.object_begin(&se)
        jim.key(&se, "x")
        jim.null(&se)
        jim.key(&se, "y")
        jim.boolean(&se, true)
        jim.key(&se, "z")
        jim.number(&se, 3.14)
        jim.key(&se, "w")
        jim.str(&se, "hello")
    jim.object_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "{\n    \"x\": null,\n    \"y\": true,\n    \"z\": 3.14,\n    \"w\": \"hello\"\n}")
}

@(test)
serialize_empty_array :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.array_begin(&se)
    jim.array_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "[]")
}

@(test)
serialize_empty_array_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.array_begin(&se)
    jim.array_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "[\n]")
}

@(test)
serialize_array :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.array_begin(&se)
        jim.null(&se)
        jim.boolean(&se, false)
        jim.number(&se, 1.5)
        jim.str(&se, "goodbye")
    jim.array_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `[null,false,1.5,"goodbye"]`)
}

@(test)
serialize_array_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.array_begin(&se)
        jim.null(&se)
        jim.boolean(&se, false)
        jim.number(&se, 1.5)
        jim.str(&se, "goodbye")
    jim.array_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, "[\n    null,\n    false,\n    1.5,\n    \"goodbye\"\n]")
}

@(test)
serialize_nested :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object_begin(&se)
        jim.key(&se, "array")
        jim.array_begin(&se)
            jim.number(&se, 1)
            jim.number(&se, 2)
            jim.number(&se, 3)
        jim.array_end(&se)
        jim.key(&se, "obj")
        jim.object_begin(&se)
            jim.key(&se, "name")
            jim.str(&se, "John Smith")
            jim.key(&se, "age")
            jim.number(&se, 32)
        jim.object_end(&se)
    jim.object_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `{"array":[1,2,3],"obj":{"name":"John Smith","age":32}}`)
}

@(test)
serialize_nested_pp :: proc(t: ^testing.T) {
    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb), pp=4}

    jim.object_begin(&se)
        jim.key(&se, "array")
        jim.array_begin(&se)
            jim.number(&se, 1)
            jim.number(&se, 2)
            jim.number(&se, 3)
            jim.object_begin(&se)
                jim.key(&se, "A")
                jim.number(&se, 65)
                jim.key(&se, "B")
                jim.number(&se, 66)
                jim.key(&se, "C")
                jim.number(&se, 67)
            jim.object_end(&se)
        jim.array_end(&se)
        jim.key(&se, "obj")
        jim.object_begin(&se)
            jim.key(&se, "name")
            jim.str(&se, "John Smith")
            jim.key(&se, "age")
            jim.number(&se, 32)
        jim.object_end(&se)
    jim.object_end(&se)

    json := strings.to_string(sb)
    testing.expect_value(t, json, `{
    "array": [
        1,
        2,
        3,
        {
            "A": 65,
            "B": 66,
            "C": 67
        }
    ],
    "obj": {
        "name": "John Smith",
        "age": 32
    }
}`)
}

@(test)
serialize_object_auto_primitive :: proc(t: ^testing.T) {
    Foo :: struct {
        char: rune,
        number: f64,
        boolean: bool,
        str: string,
    }

    foo := Foo{'K', 5, true, "I'm a foo"}

    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object(&se, foo)
    json := strings.to_string(sb)

    testing.expect_value(t, json, `{"char":"K","number":5,"boolean":true,"str":"I'm a foo"}`)
}

@(test)
serialize_object_auto_nested :: proc(t: ^testing.T) {
    Foo :: struct {
        name: string,
        objs: []Bar,
    }

    Bar :: struct {
        name: string,
    }

    foo := Foo{"foo", {{"bar"}, {"baz"}, {"buz"}}}

    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object(&se, foo)
    json := strings.to_string(sb)

    testing.expect_value(t, json, `{"name":"foo","objs":[{"name":"bar"},{"name":"baz"},{"name":"buz"}]}`)
}

@(test)
serialize_object_auto_enum :: proc(t: ^testing.T) {
    Fruit :: enum {
        Apple,
        Banana,
        Cherry,
    }

    Foo :: struct {
        fruit: Fruit,
        qty: f64,
    }

    foo := Foo{.Banana, 23}

    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object(&se, foo)
    json := strings.to_string(sb)

    testing.expect_value(t, json, `{"fruit":"Banana","qty":23}`)
}

@(test)
serialize_object_auto_array :: proc(t: ^testing.T) {
    Fruit :: enum { Apple, Banana, Cherry }
    Foo :: struct {
        fixed: [3]rune,
        slice: []f64,
        dyn: [dynamic]Fruit,
    }

    foo := Foo{{'A', 'B', 'C'}, {1, 2, 3}, {.Apple, .Banana, .Cherry}}
    defer delete(foo.dyn)

    sb := strings.Builder{}
    defer strings.builder_destroy(&sb)

    se := jim.Serializer{out=strings.to_writer(&sb)}

    jim.object(&se, foo)
    json := strings.to_string(sb)

    testing.expect_value(t, json, `{"fixed":["A","B","C"],"slice":[1,2,3],"dyn":["Apple","Banana","Cherry"]}`)
}

@(test)
deserialize_empty_object :: proc(t: ^testing.T) {
    json := "{}"
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failled to find beginning of empty object")

    ok = jim.object_end(&de)
    testing.expect(t, ok, "Failled to find ending of empty object")
}

@(test)
deserialize_empty_object_pp :: proc(t: ^testing.T) {
    json := "{\n}"
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failled to find beginning of empty object")

    ok = jim.object_end(&de)
    testing.expect(t, ok, "Failled to find ending of empty object")
}

@(test)
deserialize_object :: proc(t: ^testing.T) {
    json := `{"msg": "hello", "loggedIn": true, "gold": 23}`
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failed to find beginning of object")

    {
        key: string
        key, ok = jim.key(&de)
        testing.expect(t, ok, "Failed to find key of object")
        testing.expect_value(t, key, "msg")
        delete(key)

        value: string
        value, ok = jim.str(&de)
        testing.expect(t, ok, "Failed to find value for 'msg'")
        testing.expect_value(t, value, "hello")
        delete(value)
    }

    {
        key: string
        key, ok = jim.key(&de)
        testing.expect(t, ok, "Failed to find key of object")
        testing.expect_value(t, key, "loggedIn")
        delete(key)

        value: bool
        value, ok = jim.boolean(&de)
        testing.expect(t, ok, "Failed to find value for 'msg'")
        testing.expect_value(t, value, true)
    }

    {
        key: string
        key, ok = jim.key(&de)
        testing.expect(t, ok, "Failed to find key of object")
        testing.expect_value(t, key, "gold")
        delete(key)

        value: f64
        value, ok = jim.number(&de)
        testing.expect(t, ok, "Failed to find value for 'msg'")
        testing.expect_value(t, value, 23)
    }

    ok = jim.object_end(&de)
    testing.expect(t, ok, "Failed to find ending of object")
}

@(test)
deserialize_object_pp :: proc(t: ^testing.T) {
    json := "{\n  \"msg\": \"hello\",\n  \"loggedIn\": true,\n  \"gold\": 23\n}"
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failed to find beginning of object")

    {
        key: string
        key, ok = jim.key(&de)
        testing.expect(t, ok, "Failed to find key of object")
        testing.expect_value(t, key, "msg")
        delete(key)

        value: string
        value, ok = jim.str(&de)
        testing.expect(t, ok, "Failed to find value for 'msg'")
        testing.expect_value(t, value, "hello")
        delete(value)
    }

    {
        key: string
        key, ok = jim.key(&de)
        testing.expect(t, ok, "Failed to find key of object")
        testing.expect_value(t, key, "loggedIn")
        delete(key)

        value: bool
        value, ok = jim.boolean(&de)
        testing.expect(t, ok, "Failed to find value for 'msg'")
        testing.expect_value(t, value, true)
    }

    {
        key: string
        key, ok = jim.key(&de)
        testing.expect(t, ok, "Failed to find key of object")
        testing.expect_value(t, key, "gold")
        delete(key)

        value: f64
        value, ok = jim.number(&de)
        testing.expect(t, ok, "Failed to find value for 'msg'")
        testing.expect_value(t, value, 23)
    }

    ok = jim.object_end(&de)
    testing.expect(t, ok, "Failed to find ending of object")
}

@(test)
deserialize_object_auto_primitive :: proc(t: ^testing.T) {
    Fruit :: enum {
        Apple,
        Banana,
        Cherry,
    }

    Foo :: struct {
        b: bool,
        r: rune,
        n: f64,
        s: string,
        f: Fruit,
    }

    json := `{"b":true,"r":"K","n":7,"s":"hi","f":"Banana"}`
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    foo, ok := jim.object(&de, Foo)
    defer delete(foo.s)

    testing.expect(t, ok, "Failed to deserialize object")
    testing.expect_value(t, foo, Foo{b=true, r='K', n=7, s="hi", f=.Banana})
}

@(test)
deserialize_object_auto_nested :: proc(t: ^testing.T) {
    Fruit :: enum {
        Apple,
        Banana,
        Cherry,
    }

    Drink :: enum {
        Water,
        Rum,
        Vodka,
    }

    Bar :: struct {
        d: Drink,
        q: f64,
    }

    Foo :: struct {
        b: bool,
        r: rune,
        n: f64,
        s: string,
        f: Fruit,
        bar: Bar,
    }

    json := `{"b":true,"r":"K","n":7,"s":"hi","f":"Banana","bar":{"d":"Vodka","q":69}}`
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    foo, ok := jim.object(&de, Foo)
    defer delete(foo.s)

    testing.expect(t, ok, "Failed to deserialize object")
    testing.expect_value(t, foo, Foo{b=true, r='K', n=7, s="hi", f=.Banana, bar={d=.Vodka, q=69}})
}

@(test)
deserialize_array :: proc(t: ^testing.T) {
    json := `[true, false, 7, 1.5, "abc"]`
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    ok := jim.array_begin(&de)
    testing.expect(t, ok, "Failed to find beginning of array")

    {
        value: bool
        value, ok = jim.boolean(&de)
        testing.expect(t, ok, "Failed to parse boolean value")
        testing.expect_value(t, value, true)
    }

    {
        value: bool
        value, ok = jim.boolean(&de)
        testing.expect(t, ok, "Failed to parse boolean value")
        testing.expect_value(t, value, false)
    }

    {
        value: f64
        value, ok = jim.number(&de)
        testing.expect(t, ok, "Failed to parse number value")
        testing.expect_value(t, value, 7)
    }

    {
        value: f64
        value, ok = jim.number(&de)
        testing.expect(t, ok, "Failed to parse number value")
        testing.expect_value(t, value, 1.5)
    }

    {
        value: string
        value, ok = jim.str(&de)
        testing.expect(t, ok, "Failed to parse string value")
        testing.expect_value(t, value, "abc")
        delete(value)
    }

    ok = jim.array_end(&de)
    testing.expect(t, ok, "Failed to find ending of array")
}

@(test)
deserialize_array_pp :: proc(t: ^testing.T) {
    json := "[\n  true,\n  false,\n  7,\n  1.5,\n  \"abc\"\n]"
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    ok := jim.array_begin(&de)
    testing.expect(t, ok, "Failed to find beginning of array")

    {
        value: bool
        value, ok = jim.boolean(&de)
        testing.expect(t, ok, "Failed to parse boolean value")
        testing.expect_value(t, value, true)
    }

    {
        value: bool
        value, ok = jim.boolean(&de)
        testing.expect(t, ok, "Failed to parse boolean value")
        testing.expect_value(t, value, false)
    }

    {
        value: f64
        value, ok = jim.number(&de)
        testing.expect(t, ok, "Failed to parse number value")
        testing.expect_value(t, value, 7)
    }

    {
        value: f64
        value, ok = jim.number(&de)
        testing.expect(t, ok, "Failed to parse number value")
        testing.expect_value(t, value, 1.5)
    }

    {
        value: string
        value, ok = jim.str(&de)
        testing.expect(t, ok, "Failed to parse string value")
        testing.expect_value(t, value, "abc")
        delete(value)
    }

    ok = jim.array_end(&de)
    testing.expect(t, ok, "Failed to find ending of array")
}

@(test)
deserialize_enum :: proc(t: ^testing.T) {
    json := `{"fruit":"Banana","qty":23}`
    de := jim.Deserializer{input = strings.to_reader(&strings.Reader{}, json)}

    ok := jim.object_begin(&de)
    testing.expect(t, ok, "Failed to find beginning of object")

    fruit_key, fruit_key_ok := jim.key(&de)
    testing.expect(t, fruit_key_ok, "Failed to find Fruit value")
    testing.expect_value(t, fruit_key, "fruit")
    delete(fruit_key)

    Fruit :: enum {Apple, Banana, Cherry}

    fruit_value, fruit_value_ok := jim.str(&de, Fruit)
    testing.expect(t, fruit_value_ok, "Failed to parse Fruit value")
    testing.expect_value(t, fruit_value, Fruit.Banana)

    qty_key, qty_key_ok := jim.key(&de)
    testing.expect(t, fruit_key_ok, "Failed to find qty value")
    testing.expect_value(t, qty_key, "qty")
    delete(qty_key)

    qty_value, qty_value_ok := jim.number(&de)
    testing.expect(t, qty_value_ok, "Failed to parse Fruit value")
    testing.expect_value(t, qty_value, 23)
}

