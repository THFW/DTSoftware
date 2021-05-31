%include "inc.asm"

org 0x9000

jmp ENTRY_SEGMENT

[section .gdt]
; GDT definition
;                                 段基址，       段界限，       段属性
GDT_ENTRY       :     Descriptor    0,            0,           0
CODE32_DESC     :     Descriptor    0,    Code32SegLen - 1,   DA_C + DA_32 + DA_DPL2
VIDEO_DESC      :     Descriptor 0xB8000,     0x07FFF,         DA_DRWA + DA_32 + DA_DPL2
DATA32_DESC_0   :     Descriptor    0,    Data32SegLen0 - 1,   DA_DR + DA_32 + DA_DPL0
DATA32_DESC_2   :     Descriptor    0,    Data32SegLen2 - 1,   DA_DR + DA_32 + DA_DPL2
STACK32_DESC_0  :     Descriptor    0,     TopOfStack320,      DA_DRW + DA_32 + DA_DPL0
STACK32_DESC_2  :     Descriptor    0,     TopOfStack322,      DA_DRW + DA_32 + DA_DPL2
TSS_DESC        :     Descriptor    0,       TSSLen - 1,       DA_386TSS + DA_DPL0
FUNCTION_DESC   :     Descriptor    0,   FunctionSegLen - 1,   DA_C + DA_32 + DA_DPL0
; Call Gate
;                                           选择子,            偏移,          参数个数,         属性
FUNC_PRINTSTRING_DESC    :    Gate      FunctionSelector,   PrintString,       0,         DA_386CGate + DA_DPL3
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0
          
          
; GDT Selector
Code32Selector     equ (0x0001 << 3) + SA_TIG + SA_RPL2
VideoSelector      equ (0x0002 << 3) + SA_TIG + SA_RPL2
Data32Selector0    equ (0x0003 << 3) + SA_TIG + SA_RPL0
Data32Selector2    equ (0x0004 << 3) + SA_TIG + SA_RPL2
Stack32Selector0   equ (0x0005 << 3) + SA_TIG + SA_RPL0
Stack32Selector2   equ (0x0006 << 3) + SA_TIG + SA_RPL2
TSSSelector        equ (0x0007 << 3) + SA_TIG + SA_RPL0
FunctionSelector   equ (0x0008 << 3) + SA_TIG + SA_RPL0
; Gate Selector
FuncPrintStringSelector    equ   (0x0009 << 3) + SA_TIG + SA_RPL3
; end of [section .gdt]

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
    
    mov esi, DATA32_SEGMENT_0
    mov edi, DATA32_DESC_0
    
    call InitDescItem
    
    mov esi, DATA32_SEGMENT_2
    mov edi, DATA32_DESC_2
    
    call InitDescItem
    
    mov esi, STACK32_SEGMENT_0
    mov edi, STACK32_DESC_0
    
    call InitDescItem
    
    mov esi, STACK32_SEGMENT_2
    mov edi, STACK32_DESC_2
    
    call InitDescItem
    
    mov esi, FUNCTION_SEGMENT
    mov edi, FUNCTION_DESC
    
    call InitDescItem
    
    mov esi, TSS_SEGMENT
    mov edi, TSS_DESC
    
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
    
    ; 5. load TSS
    mov ax, TSSSelector
    ltr ax
    
    ; 6. jump to 32 bits code
    push Stack32Selector2
    push TopOfStack322
    push Code32Selector    
    push 0                 
    retf
    


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

[section .dat0]
[bits 32]
DATA32_SEGMENT_0:
    DPL0               db  "DPL = 0", 0
    DPL0_OFFSET        equ DPL0 - $$

Data32SegLen0 equ $ - DATA32_SEGMENT_0

[section .dat2]
[bits 32]
DATA32_SEGMENT_2:
    DPL2               db  "DPL = 2", 0
    DPL2_OFFSET        equ DPL2 - $$

Data32SegLen2 equ $ - DATA32_SEGMENT_2

[section .tss]
[bits 32]
TSS_SEGMENT:
        dd    0
        dd    TopOfStack320           ; 0
        dd    Stack32Selector0        ;
        dd    0                       ; 1
        dd    0                       ;
        dd    0                       ; 2
        dd    0                       ;
        times 4 * 18 dd 0
        dw    0
        dw    $ - TSS_SEGMENT + 2
        db    0xFF
        
TSSLen    equ    $ - TSS_SEGMENT
   
[section .s32]
[bits 32]
CODE32_SEGMENT:
    mov ax, VideoSelector
    mov gs, ax
    
    mov ax, Data32Selector2
    mov ds, ax
    
    mov ebp, DPL2_OFFSET
    mov bx, 0x0C
    mov dh, 12
    mov dl, 33
    
    call FuncPrintStringSelector : 0

    jmp $

Code32SegLen    equ    $ - CODE32_SEGMENT


[section .func]
[bits 32]
FUNCTION_SEGMENT:

; ds:ebp    --> string address
; bx        --> attribute
; dx        --> dh : row, dl : col
PrintStringFunc:
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
    
    mov ax, Data32Selector0
    mov ds, ax
    mov gs, ax
    
    retf
    
PrintString    equ   PrintStringFunc - $$

FunctionSegLen    equ   $ - FUNCTION_SEGMENT

[section .gs0]
[bits 32]
STACK32_SEGMENT_0:
    times 1024 db 0
    
Stack32SegLen0 equ $ - STACK32_SEGMENT_0
TopOfStack320  equ Stack32SegLen0 - 1

[section .gs2]
[bits 32]
STACK32_SEGMENT_2:
    times 1024 db 0
    
Stack32SegLen2 equ $ - STACK32_SEGMENT_2
TopOfStack322  equ Stack32SegLen2 - 1