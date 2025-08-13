// Lexer is a classical example of usecase for coroutines.
// This is a *very* simple and basic lexer that
// can lex single digit integers, + and -.
// The example would be better if we could return values
// when we yield (kind of like a generator). But it is what it is.

package lexer

import "core:fmt"
import "core:os/os2"

import coroutine "../../../coroutines"

tk_op :: distinct rune
tk_int :: distinct int

TokenValue :: union {
    tk_op,
    tk_int,
}

token_value: TokenValue

lex :: proc(input_void: rawptr) {
    input := (cast(^string)input_void)^

    for rn in input {
        switch rn {
        case '0'..='9':
            token_value = tk_int(rn - '0')
        case '*', '+', '-' :
            token_value = tk_op(rn)
        case:
            return
        }
        // For every token we consume, we yield control back to the caller (a parser, I guess).
        coroutine.yield()

        token_value = nil // clear the already read value
    }
}

main :: proc() {
    if (len(os2.args) != 2) {
        fmt.printfln("Usage: %v <input-text>", os2.args[0])
        os2.exit(1)
    }

    coroutine.go(lex, &os2.args[1])

    // Consume those tokens
    loop: for coroutine.alive() > 1 {
        // Yield control to the lexer.
        // It will lex and yield control back to here.
        coroutine.yield()
        switch v in token_value {
        case tk_int:
            fmt.printfln("TK_INT : %v", v)
        case tk_op:
            fmt.printfln("TK_OP  : %v", v)
        case nil:
            fmt.printfln("Done!")
            break loop
        }
    }
}
