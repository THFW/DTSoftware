%include "inc.asm"

org 0x9000

jmp ENTRY_SEGMENT

[section .gdt]
; GDT definition
;                                     段基址，           段界限，       段属性
GDT_ENTRY       :     Descriptor        0,                0,           0
CODE32_DESC     :     Descriptor        0,        Code32SegLen - 1,    DA_C + DA_32
VIDEO_DESC      :     Descriptor     0xB8000,         0x07FFF,         DA_DRWA + DA_32
DATA32_DESC     :     Descriptor        0,        Data32SegLen - 1,    DA_DRW + DA_32
STACK32_DESC    :     Descriptor        0,         TopOfStack32,       DA_DRW + DA_32
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0         
          
; GDT Selector

Code32Selector   equ (0x0001 << 3) + SA_TIG + SA_RPL0
VideoSelector    equ (0x0002 << 3) + SA_TIG + SA_RPL0
Data32Selector   equ (0x0003 << 3) + SA_TIG + SA_RPL0
Stack32Selector  equ (0x0004 << 3) + SA_TIG + SA_RPL0
; end of [section .gdt]

[section .idt]
align 32
[bits 32]
IDT_ENTRY:
; IDT definition
;                        Selector,           Offset,       DCount,    Attribute
%rep 32
              Gate    Code32Selector,    DefaultHandler,   0,         DA_386IGate
%endrep

Int0x20   :   Gate    Code32Selector,    TimerHandler,     0,         DA_386IGate

%rep 95
              Gate    Code32Selector,    DefaultHandler,   0,         DA_386IGate
%endrep

Int0x80   :   Gate    Code32Selector,    Int0x80Handler,   0,         DA_386IGate

%rep 127
              Gate    Code32Selector,    DefaultHandler,   0,         DA_386IGate
%endrep

IdtLen    equ    $ - IDT_ENTRY

IdtPtr:
          dw    IdtLen - 1
          dd    0

; end of [section .idt]

TopOfStack16    equ 0x7c00

[section .dat]
[bits 32]
DATA32_SEGMENT:
    DTOS               db  "D.T.OS!", 0
    DTOS_OFFSET        equ DTOS - $$
    INT_80H            db  "int 0x80", 0
    INT_80H_OFFSET     equ INT_80H - $$

Data32SegLen equ $ - DATA32_SEGMENT

[section .s16]
[bits 16]
ENTRY_SEGMENT:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, TopOfStack16
    
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
    
    ; initialize GDT pointer struct
    mov eax, 0
    mov ax, ds
    shl eax, 4
    add eax, GDT_ENTRY
    mov dword [GdtPtr + 2], eax
    
    ; initialize IDT pointer struct
    mov eax, 0
    mov ax, ds
    shl eax, 4
    add eax, IDT_ENTRY
    mov dword [IdtPtr + 2], eax

    ; 1. load GDT
    lgdt [GdtPtr]
    
    ; 2. close interrupt and load IDT
    cli 
    
    lidt [IdtPtr]
    
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
    
    call Init8259A
    
    mov ax, 0xFF
    mov dx, MASTER_IMR_PORT
    
    call WriteIMR
    
    mov ax, 0xFF
    mov dx, SLAVE_IMR_PORT
    
    call WriteIMR
    
    mov ebp, DTOS_OFFSET
    mov bx, 0x0C
    mov dh, 12
    mov dl, 33
    
    call PrintString
    
    
    mov ebp, INT_80H_OFFSET
    mov bx, 0x0C
    mov dh, 13
    mov dl, 32
    
    int 0x80
    
    sti
    
    call EnableTimer
    
    jmp $

;
;
EnableTimer:
    push ax
    push dx
    
    mov ah, 0x0C
    mov al, '0'
    mov [gs:((80 * 14 + 36) * 2)], ax
    
    mov dx, MASTER_IMR_PORT
    
    call ReadIMR
    
    and ax, 0xFE
    
    call WriteIMR
    
    pop dx
    pop ax
    
    ret

;
;
Delay:
    %rep 5
    nop
    %endrep
    ret
    
;
;
Init8259A:
    push ax
    
    ; master
    ; ICW1
    mov al, 00010001B
    out MASTER_ICW1_PORT, al
    
    call Delay
    
    ; ICW2
    mov al, 0x20
    out MASTER_ICW2_PORT, al
    
    call Delay
    
    ; ICW3
    mov al, 00000100B
    out MASTER_ICW3_PORT, al
    
    call Delay
    
    ; ICW4
    mov al, 00010001B
    out MASTER_ICW4_PORT, al
    
    call Delay
    
    ; slave
    ; ICW1
    mov al, 00010001B
    out SLAVE_ICW1_PORT, al
    
    call Delay
    
    ; ICW2
    mov al, 0x28
    out SLAVE_ICW2_PORT, al
    
    call Delay
    
    ; ICW3
    mov al, 00000010B
    out SLAVE_ICW3_PORT, al
    
    call Delay
    
    ; ICW4
    mov al, 00000001B
    out SLAVE_ICW4_PORT, al
    
    call Delay
    
    pop ax
    
    ret
    
; al --> IMR register value
; dx --> 8259A port
WriteIMR:
    out dx, al
    call Delay
    ret
    
; dx --> 8259A
; return:
;     ax --> IMR register value
ReadIMR:
    in ax, dx
    call Delay
    ret

;
; dx --> 8259A port
WriteEOI:
    push ax
    
    mov al, 0x20
    out dx, al
    
    call Delay
    
    pop ax
    
    ret
       
;
;
DefaultHandlerFunc:
    iret
    
DefaultHandler    equ    DefaultHandlerFunc - $$
    
;
;
Int0x80HandlerFunc:
    call PrintString
    iret
    
Int0x80Handler    equ    Int0x80HandlerFunc - $$

;
;
TimerHandlerFunc:
    push ax
    push dx
    
    mov ax, [gs:((80 * 14 + 36) * 2)]
    
    cmp al, '9'
    je throtate
    inc al
    jmp thshow

throtate:
    mov al, '0'
    
thshow:
    mov [gs:((80 * 14 + 36) * 2)], ax
    
    mov dx, MASTER_OCW2_PORT
    call WriteEOI
    
    pop dx
    pop ax
    
    iret
    
TimerHandler    equ    TimerHandlerFunc - $$

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