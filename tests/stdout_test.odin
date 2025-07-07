package tests

import "core:fmt"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"
import jim ".."

strbuf: [256]u8

main :: proc() {
    tm := time.now()
    dt, _ := time.time_to_datetime(tm)
    tz, _ := timezone.region_load("local")
    dt = timezone.datetime_to_tz(dt, tz)
    ts, _ := time.datetime_to_time(dt)

    ser := jim.Serializer{pp=2}
    jim.object_begin(&ser)
        jim.object_member(&ser, "msg")
        jim.str(&ser, "hello world")
        jim.object_member(&ser, "time")
        jim.str(&ser, time.to_string_hms(ts, strbuf[:]))
    jim.object_end(&ser)
    fmt.println()
}

