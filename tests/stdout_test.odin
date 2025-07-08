package jim_tests

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

    se := jim.Serializer{pp=2}
    jim.object_begin(&se)
        jim.object_member(&se, "msg")
        jim.str(&se, "hello world")
        jim.object_member(&se, "time")
        jim.str(&se, time.to_string_hms(ts, strbuf[:]))
    jim.object_end(&se)
    fmt.println()

    json.parse()
}

