; this file uses a NASM/intel dialect

bits 64

section .note.GNU-stack

section .text

extern __finish_current

extern __yield
extern __sleep_read
extern __sleep_write

global coroutine_yield
global coroutine_sleep_read
global coroutine_sleep_write

global coroutine_setup_context
global coroutine_restore_context

%macro save_registers 0
    push rdi
    push rsi
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
%endmacro

coroutine_setup_context:
    mov r8,  rsp
    mov rsp, rdi

    push qword 0    ; for alignment
    push rcx        ; implicit context pointer, popped by finish_current
    lea rax, [rel finish_current]
    push rax

    push rsi        ; f
    mov rdi, rdx    ; args (for f)
    mov rsi, rcx    ; implicit context pointer (for f)

    save_registers

    mov rax, rsp
    mov rsp, r8
    ret

finish_current:
    pop rdi ; implicit context pointer

    jmp [rel __finish_current wrt ..got]

coroutine_restore_context:
    mov rsp, rdi

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    pop rsi
    pop rdi

    ret

coroutine_yield:
    save_registers
    mov rsi, rdi
    mov rdi, rsp
    jmp [rel __yield wrt ..got]

coroutine_sleep_read:
    save_registers
    mov rdx, rsi
    mov rsi, rsp
    jmp [rel __sleep_read wrt ..got]

coroutine_sleep_write:
    save_registers
    mov rdx, rsi
    mov rsi, rsp
    jmp [rel __sleep_write wrt ..got]
