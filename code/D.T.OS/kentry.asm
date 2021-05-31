%include "common.asm"

global _start

extern gGdtInfo
extern gIdtInfo
extern InitInterrupt
extern EnableTimer
extern SendEOI
extern RunTask
extern KMain
extern ClearScreen

[section .text]
[bits 32]
_start:
    mov ebp, 0
    
    call InitGlobal
    call ClearScreen
    call KMain
    
    jmp $
    
;
;    
InitGlobal:
    push ebp
    mov ebp, esp
    
    mov eax, dword [GdtEntry]
    mov [gGdtInfo], eax
    mov eax, dword [GdtSize]
    mov [gGdtInfo + 4], eax
    
    mov eax, dword [IdtEntry]
    mov [gIdtInfo], eax
    mov eax, dword [IdtSize]
    mov [gIdtInfo + 4], eax
    
    mov eax, dword [RunTaskEntry]
    mov dword [RunTask], eax
    
    mov eax, dword [InitInterruptEntry]
    mov [InitInterrupt], eax
    
    mov eax, dword [EnableTimerEntry]
    mov [EnableTimer], eax
    
    mov eax, dword [SendEOIEntry]
    mov [SendEOI], eax
    
    leave
    
    ret
