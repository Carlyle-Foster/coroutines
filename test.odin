package coroutines

import "core:testing"
import "core:log"
import "core:math/rand"

g_invariants := []proc() -> bool {
    proc() -> bool {
        return current < len(active) || len(active) == 0
    },
    proc() -> bool {
        result := true
        for context_id in dead {
            result &&= context_id < len(contexts)
        }
        return result
    },
    proc() -> bool {
        return len(active) <= len(contexts)
    },
    proc() -> bool {
        return len(dead) <= len(contexts)
    },
    proc() -> bool {
        return len(active)+len(dead) <= len(contexts)
    },
    proc() -> bool {
        return g_waiting_coroutines < len(active) || len(contexts) == 0
    },
}

assert_invariants :: proc(t: ^testing.T) {
    ok := true

    for invariant, i in g_invariants {
        if !invariant() {
            log.errorf("invariant %v violated (counting from 1)", i+1)
            ok = false
        }
    }

    if !ok {
        testing.fail_now(t)
    }
}

Instruction :: enum {
    Go,
    Yield,
    Wait_For_Others,
}

random_instruction :: proc() -> Instruction {
    Weights := [Instruction]f64 {
        .Go     = 0.43,
        .Yield  = 1.00,
        .Wait_For_Others = 0.39,
    }
    sum_of_weights := 0.
    for w in Weights {
        sum_of_weights += w
    }
    roll := rand.float64_range(0, sum_of_weights)
    for instr in Instruction {
        roll -= Weights[instr]

        if roll < 0 {
            return instr
        }
    }
    unreachable()
}

Virtual_Machine_Args :: struct {
    instructions: []Instruction,
    coroutine_depth: int,
    t: ^testing.T,
}

virtual_machine_coroutine :: proc(args: rawptr) {
    using args_ := (cast(^Virtual_Machine_Args)args)^

    virtual_machine(instructions, coroutine_depth, t)
}

virtual_machine :: proc(instructions: []Instruction, coroutine_depth: int, t: ^testing.T) {
    for instruction in instructions {
        // log.infof("[%v] runs %v", id(), instruction)

        switch instruction {
        case .Go:
            sub_instructions := make([]Instruction, rand.int_max(max(1, 54 - coroutine_depth*16)))
            for i in 0..<len(sub_instructions) {
                sub_instructions[i] = random_instruction()
            }
            args := Virtual_Machine_Args {
                instructions = sub_instructions,
                coroutine_depth = coroutine_depth + 1,
                t = t,
            }
            go(virtual_machine_coroutine, &args)
        case .Yield:
            yield()
        case .Wait_For_Others:
            wait_for_others()
        case:
            unreachable()
        }

        assert_invariants(t)
    }
    delete(instructions)
}

@(test)
the_test :: proc(t: ^testing.T) {
    random_generator_state := rand.create(t.seed)
    context.random_generator = rand.default_random_generator(&random_generator_state)

    instructions := make([]Instruction, 175 + rand.int_max(30))
    for i in 0..<len(instructions) {
        instructions[i] = random_instruction()
    }

    log.infof("running %v top-level instructions", len(instructions))

    virtual_machine(instructions, coroutine_depth=0, t=t)
    reset_runtime()
}
