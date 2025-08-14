package coroutines

Context :: struct {
    rsp: rawptr,
    stack_base: rawptr,
    active_id: Maybe(Active_Index),
}

Event_Kind :: enum {
    Readable,
    Writeable,
}

Active_Index :: distinct int