; this file uses a NASM/intel dialect

bits 64

default rel

section .note.GNU-stack

section .text

extern __finish_current

extern __yield
extern __sleep_read
extern __sleep_write

global coroutine_yield
global coroutine_sleep_read
global coroutine_sleep_write

global coroutine_restore_context
global coroutine_finish_current

%macro save_registers 0
    push rdi
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push qword 0  ; for alignment
%endmacro

coroutine_yield:
    save_registers
    mov rdi, rsp
    jmp [__yield wrt ..got]

coroutine_sleep_read:
    save_registers
    mov rsi, rsp
    jmp [__sleep_read wrt ..got]

coroutine_sleep_write:
    save_registers
    mov rsi, rsp
    jmp [__sleep_write wrt ..got]

coroutine_restore_context:
    mov rsp, rdi
    pop r15     ; for alignment
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    pop rdi
    ret

coroutine_finish_current:
    push qword 0
    jmp [__finish_current wrt ..got]
