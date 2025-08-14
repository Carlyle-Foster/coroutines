package coroutines

import "core:sys/linux"

foreign import assembly "coroutine.asm"
@(link_prefix="coroutine_", default_calling_convention="odin")
foreign assembly {
    /*
    Starts a coroutine to run the proc `f` with `arg` as it's argument.
    It starts running immediately

    Inputs:
    - f: The proc to run
    - arg: An opaque pointer passed to `f`
    */
    go          :: proc(f: proc"odin"(rawptr), arg: rawptr) ---

    /*
    Hands over control to another active coroutine, if any are ready
    */
    yield       :: proc() ---

    /*
    waits until the fille descriptor `fd` receives an event of type `event`

    Inputs:
    - fd: the file descriptor to wait on
    - event: the type of event to wait for (usually .Readable or .Writeable)
    */
    wait_until  :: proc(fd: linux.Fd, event: Event_Kind) ---
}

/*
Waits for all other coroutines to finish, panics on deadlock
*/
wait_for_others :: proc() {
    @(static) waiting_coroutines := 0

    waiting_coroutines += 1
    defer waiting_coroutines -= 1
    assert(waiting_coroutines < len(active), "everyone's waiting")

    for len(active) > 1 {
        yield()
    }
}

/*
Signals another coroutine, causing it to become active

Inputs:
- id: the ID of the coroutine to signal
*/
signal_other :: proc(id: int) {
    assert(len(contexts) > 0)
    append(&active, id)
    contexts[id].active_id = Active_Index(id)
}

/*
Returns the ID of the currently running coroutine

Returns:
- The ID of the currently running coroutine
*/
id :: proc() -> int {
    return active[current] if len(active) > 0 else 0
}
