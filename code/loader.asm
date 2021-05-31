%include "inc.asm"

org 0x9000

jmp ENTRY_SEGMENT

[section .gdt]
; GDT definition
;                                 段基址，       段界限，       段属性
GDT_ENTRY       :     Descriptor    0,            0,           0
CODE32_DESC     :     Descriptor    0,    Code32SegLen - 1,    DA_C + DA_32
VIDEO_DESC      :     Descriptor 0xB8000,     0x07FFF,         DA_DRWA + DA_32
DATA32_DESC     :     Descriptor    0,    Data32SegLen - 1,    DA_DR + DA_32
STACK32_DESC    :     Descriptor    0,     TopOfStack32,       DA_DRW + DA_32
CODE16_DESC     :     Descriptor    0,        0xFFFF,          DA_C 
UPDATE_DESC     :     Descriptor    0,        0xFFFF,          DA_DRW
TASK_A_LDT_DESC :     Descriptor    0,     TaskALdtLen - 1,    DA_LDT
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0
          
          
; GDT Selector

Code32Selector    equ (0x0001 << 3) + SA_TIG + SA_RPL0
VideoSelector     equ (0x0002 << 3) + SA_TIG + SA_RPL0
Data32Selector    equ (0x0003 << 3) + SA_TIG + SA_RPL0
Stack32Selector   equ (0x0004 << 3) + SA_TIG + SA_RPL0
Code16Selector    equ (0x0005 << 3) + SA_TIG + SA_RPL0
UpdateSelector    equ (0x0006 << 3) + SA_TIG + SA_RPL0
TaskALdtSelector  equ (0x0007 << 3) + SA_TIG + SA_RPL0
; end of [section .gdt]

TopOfStack16    equ 0x7c00

[section .dat]
[bits 32]
DATA32_SEGMENT:
    DTOS               db  "D.T.OS!", 0
    DTOS_OFFSET        equ DTOS - $$
    HELLO_WORLD        db  "Hello World!", 0
    HELLO_WORLD_OFFSET equ HELLO_WORLD - $$

Data32SegLen equ $ - DATA32_SEGMENT

[section .s16]
[bits 16]
ENTRY_SEGMENT:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, TopOfStack16
    
    mov [BACK_TO_REAL_MODE + 3], ax
    
    ; initialize GDT for 32 bits code segment
    mov esi, CODE32_SEGMENT
    mov edi, CODE32_DESC
    
    call InitDescItem
    
    mov esi, DATA32_SEGMENT
    mov edi, DATA32_DESC
    
    call InitDescItem
    
    mov esi, STACK32_SEGMENT
    mov edi, STACK32_DESC
    
    call InitDescItem
    
    mov esi, CODE16_SEGMENT
    mov edi, CODE16_DESC
    
    call InitDescItem
    
    mov esi, TASK_A_LDT_ENTRY
    mov edi, TASK_A_LDT_DESC
    
    call InitDescItem
    
    mov esi, TASK_A_CODE32_SEGMENT
    mov edi, TASK_A_CODE32_DESC
    
    call InitDescItem
    
    mov esi, TASK_A_DATA32_SEGMENT
    mov edi, TASK_A_DATA32_DESC
    
    call InitDescItem
    
    mov esi, TASK_A_STACK32_SEGMENT
    mov edi, TASK_A_STACK32_DESC
    
    call InitDescItem
    
    ; initialize GDT pointer struct
    mov eax, 0
    mov ax, ds
    shl eax, 4
    add eax, GDT_ENTRY
    mov dword [GdtPtr + 2], eax

    ; 1. load GDT
    lgdt [GdtPtr]
    
    ; 2. close interrupt
    cli 
    
    ; 3. open A20
    in al, 0x92
    or al, 00000010b
    out 0x92, al
    
    ; 4. enter protect mode
    mov eax, cr0
    or eax, 0x01
    mov cr0, eax
    
    ; 5. jump to 32 bits code
    jmp dword Code32Selector : 0

BACK_ENTRY_SEGMENT:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, TopOfStack16
    
    in al, 0x92
    and al, 11111101b
    out 0x92, al
    
    sti
    
    mov bp, HELLO_WORLD
    mov cx, 12
    mov dx, 0
    mov ax, 0x1301
    mov bx, 0x0007
    int 0x10
    
    jmp $

; esi    --> code segment label
; edi    --> descriptor label
InitDescItem:
    push eax

    mov eax, 0
    mov ax, cs
    shl eax, 4
    add eax, esi
    mov word [edi + 2], ax
    shr eax, 16
    mov byte [edi + 4], al
    mov byte [edi + 7], ah
    
    pop eax
    
    ret
    

[section .s16]
[bits 16]
CODE16_SEGMENT:
    mov ax, UpdateSelector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    mov eax, cr0
    and al, 11111110b
    mov cr0, eax

BACK_TO_REAL_MODE:    
    jmp 0 : BACK_ENTRY_SEGMENT
    
Code16SegLen    equ    $ - CODE16_SEGMENT

    
[section .s32]
[bits 32]
CODE32_SEGMENT:
    mov ax, VideoSelector
    mov gs, ax
    
    mov ax, Stack32Selector
    mov ss, ax
    
    mov eax, TopOfStack32
    mov esp, eax
    
    mov ax, Data32Selector
    mov ds, ax
    
    mov ebp, DTOS_OFFSET
    mov bx, 0x0C
    mov dh, 12
    mov dl, 33
    
    call PrintString
    
    mov ebp, HELLO_WORLD_OFFSET
    mov bx, 0x0C
    mov dh, 13
    mov dl, 31
    
    call PrintString
    
    mov ax, TaskALdtSelector
    
    lldt ax
    
    jmp TaskACode32Selector : 0
    
    ; jmp Code16Selector : 0

; ds:ebp    --> string address
; bx        --> attribute
; dx        --> dh : row, dl : col
PrintString:
    push ebp
    push eax
    push edi
    push cx
    push dx
    
print:
    mov cl, [ds:ebp]
    cmp cl, 0
    je end
    mov eax, 80
    mul dh
    add al, dl
    shl eax, 1
    mov edi, eax
    mov ah, bl
    mov al, cl
    mov [gs:edi], ax
    inc ebp
    inc dl
    jmp print

end:
    pop dx
    pop cx
    pop edi
    pop eax
    pop ebp
    
    ret
    
Code32SegLen    equ    $ - CODE32_SEGMENT

[section .gs]
[bits 32]
STACK32_SEGMENT:
    times 1024 * 4 db 0
    
Stack32SegLen equ $ - STACK32_SEGMENT
TopOfStack32  equ Stack32SegLen - 1


; ==========================================
;
;            Task A Code Segment 
;
; ==========================================

[section .task-a-ldt]
; Task A LDT definition
;                                             段基址,                段界限,                段属性
TASK_A_LDT_ENTRY:
TASK_A_CODE32_DESC    :    Descriptor          0,           TaskACode32SegLen - 1,        DA_C + DA_32
TASK_A_DATA32_DESC    :    Descriptor          0,           TaskAData32SegLen - 1,        DA_DR + DA_32
TASK_A_STACK32_DESC   :    Descriptor          0,           TaskAStack32SegLen - 1,       DA_DRW + DA_32

TaskALdtLen  equ   $ - TASK_A_LDT_ENTRY

; Task A LDT Selector
TaskACode32Selector  equ   (0x0000 << 3) + SA_TIL + SA_RPL0
TaskAData32Selector  equ   (0x0001 << 3) + SA_TIL + SA_RPL0
TaskAStack32Selector equ   (0x0002 << 3) + SA_TIL + SA_RPL0

[section .task-a-dat]
[bits 32]
TASK_A_DATA32_SEGMENT:
    TASK_A_STRING        db   "This is Task A!", 0
    TASK_A_STRING_OFFSET equ  TASK_A_STRING - $$
    
TaskAData32SegLen  equ  $ - TASK_A_DATA32_SEGMENT

[section .task-a-gs]
[bits 32]
TASK_A_STACK32_SEGMENT:
    times 1024 db 0
    
TaskAStack32SegLen  equ  $ - TASK_A_STACK32_SEGMENT
TaskATopOfStack32   equ  TaskAStack32SegLen - 1

[section .task-a-s32]
[bits 32]
TASK_A_CODE32_SEGMENT:
    mov ax, VideoSelector
    mov gs, ax
    
    mov ax, TaskAStack32Selector
    mov ss, ax
    
    mov eax, TaskATopOfStack32
    mov esp, eax
    
    mov ax, TaskAData32Selector
    mov ds, ax
    
    mov ebp, TASK_A_STRING_OFFSET
    mov bx, 0x0C
    mov dh, 14
    mov dl, 29
    
    call TaskAPrintString
    
    jmp Code16Selector : 0
    

; ds:ebp    --> string address
; bx        --> attribute
; dx        --> dh : row, dl : col
TaskAPrintString:
    push ebp
    push eax
    push edi
    push cx
    push dx
    
task_print:
    mov cl, [ds:ebp]
    cmp cl, 0
    je task_end
    mov eax, 80
    mul dh
    add al, dl
    shl eax, 1
    mov edi, eax
    mov ah, bl
    mov al, cl
    mov [gs:edi], ax
    inc ebp
    inc dl
    jmp task_print

task_end:
    pop dx
    pop cx
    pop edi
    pop eax
    pop ebp
    
    ret
    
TaskACode32SegLen   equ  $ - TASK_A_CODE32_SEGMENT
