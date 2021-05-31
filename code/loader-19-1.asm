%include "inc.asm"

org 0x9000

jmp ENTRY_SEGMENT

[section .gdt]
; GDT definition
;                                 段基址，       段界限，       段属性
GDT_ENTRY       :     Descriptor    0,            0,           0
CODE32_DESC     :     Descriptor    0,    Code32SegLen - 1,    DA_C + DA_32 + DA_DPL0
VIDEO_DESC      :     Descriptor 0xB8000,     0x07FFF,         DA_DRWA + DA_32 + DA_DPL3
DATA32_DESC     :     Descriptor    0,    Data32SegLen - 1,    DA_DR + DA_32 + DA_DPL2
STACK32_DESC    :     Descriptor    0,     TopOfStack32,       DA_DRW + DA_32 + DA_DPL0
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0
          
          
; GDT Selector

Code32Selector     equ (0x0001 << 3) + SA_TIG + SA_RPL0
VideoSelector      equ (0x0002 << 3) + SA_TIG + SA_RPL3
Data32Selector     equ (0x0003 << 3) + SA_TIG + SA_RPL1
Stack32Selector    equ (0x0004 << 3) + SA_TIG + SA_RPL0

; end of [section .gdt]


; CPL = 2， RPL = 1， DPL = 3， 访问是否合法？   ===> yes
; CPL = 0， RPL = 3， DPL = 2， 访问是否合法？   ===> no
; CPL = 0， RPL = 1， DPL = 2， 访问是否合法？   ===> yes



TopOfStack16    equ 0x7c00

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
    ; push Stack32Selector   ; 目标栈段选择子
    ; push TopOfStack32      ; 栈顶指针位置
    ; push Code32Selector    ; 目标代码段选择子
    ; push 0                 ; 目标代码段偏移
    ; retf
    jmp word Code32Selector : 0


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

[section .dat]
[bits 32]
DATA32_SEGMENT:
    DTOS               db  "D.T.OS!", 0
    DTOS_OFFSET        equ DTOS - $$

Data32SegLen equ $ - DATA32_SEGMENT

   
[section .s32]
[bits 32]
CODE32_SEGMENT:
    mov ax, VideoSelector
    mov gs, ax
    
    mov ax, Data32Selector
    mov ds, ax
    
    mov ax, Stack32Selector
    mov ss, ax
    
    mov eax, TopOfStack32
    mov esp, eax
    
    mov ebp, DTOS_OFFSET
    mov bx, 0x0C
    mov dh, 12
    mov dl, 33
    
    call PrintString
    
    jmp $
    
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
