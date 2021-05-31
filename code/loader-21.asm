%include "inc.asm"

org 0x9000

jmp ENTRY_SEGMENT

[section .gdt]
; GDT definition
;                                      段基址，       段界限，             段属性
GDT_ENTRY            :     Descriptor    0,            0,                0
CODE32_DESC          :     Descriptor    0,    Code32SegLen - 1,         DA_C + DA_32 + DA_DPL3
VIDEO_DESC           :     Descriptor 0xB8000,     0x07FFF,              DA_DRWA + DA_32 + DA_DPL3
DATA32_KERNEL_DESC   :     Descriptor    0,    Data32KernelSegLen - 1,   DA_DRW + DA_32 + DA_DPL0  
DATA32_USER_DESC     :     Descriptor    0,    Data32UserSegLen - 1,     DA_DRW + DA_32 + DA_DPL3  
STACK32_KERNEL_DESC  :     Descriptor    0,     TopOfKernelStack32,      DA_DRW + DA_32 + DA_DPL0
STACK32_USER_DESC    :     Descriptor    0,     TopOfUserStack32,        DA_DRW + DA_32 + DA_DPL3
TSS_DESC             :     Descriptor    0,       TSSLen - 1,            DA_386TSS + DA_DPL0
FUNCTION_DESC        :     Descriptor    0,   FunctionSegLen - 1,        DA_C + DA_32 + DA_DPL0
; Call Gate
;                                                  选择子,                 偏移,          参数个数,      属性
FUNC_GETKERNELDATA_DESC :    Gate             FunctionSelector,       GetKernelData,       0,         DA_386CGate + DA_DPL3
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0
          
          
; GDT Selector
Code32Selector         equ (0x0001 << 3) + SA_TIG + SA_RPL3
VideoSelector          equ (0x0002 << 3) + SA_TIG + SA_RPL3
KernelData32Selector   equ (0x0003 << 3) + SA_TIG + SA_RPL0
UserData32Selector     equ (0x0004 << 3) + SA_TIG + SA_RPL3
KernelStack32Selector  equ (0x0005 << 3) + SA_TIG + SA_RPL0
UserStack32Selector    equ (0x0006 << 3) + SA_TIG + SA_RPL3
TSSSelector            equ (0x0007 << 3) + SA_TIG + SA_RPL0
FunctionSelector       equ (0x0008 << 3) + SA_TIG + SA_RPL0
; Gate Selector
GetKernelDataSelector  equ (0x0009 << 3) + SA_TIG + SA_RPL3
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
    
    mov esi, DATA32_KERNEL_SEGMENT
    mov edi, DATA32_KERNEL_DESC
    
    call InitDescItem
    
    mov esi, DATA32_USER_SEGMENT
    mov edi, DATA32_USER_DESC
    
    call InitDescItem
    
    mov esi, STACK32_KERNEL_SEGMENT
    mov edi, STACK32_KERNEL_DESC
    
    call InitDescItem
    
    mov esi, STACK32_USER_SEGMENT
    mov edi, STACK32_USER_DESC
    
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
    ;jmp word Code32Selector : 0
    push UserStack32Selector
    push TopOfUserStack32
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

[section .kdat]
[bits 32]
DATA32_KERNEL_SEGMENT:
    KDAT               db  "Kernel Data", 0
    KDAT_LEN           equ $ - KDAT
    KDAT_OFFSET        equ KDAT - $$

Data32KernelSegLen equ $ - DATA32_KERNEL_SEGMENT

[section .udat]
[bits 32]
DATA32_USER_SEGMENT:
    UDAT               times 16 db 0
    UDAT_LEN           equ $ - UDAT
    UDAT_OFFSET        equ UDAT - $$

Data32UserSegLen equ $ - DATA32_USER_SEGMENT

[section .tss]
[bits 32]
TSS_SEGMENT:
        dd    0
        dd    TopOfKernelStack32      ; 0
        dd    KernelStack32Selector   ;
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
    
    mov ax, UserData32Selector
    mov es, ax
    
    mov di, UDAT_OFFSET
    
    call GetKernelDataSelector : 0
    
    mov ax, UserData32Selector   ; eip ==> 0x17
    mov ds, ax
    
    mov ebp, UDAT_OFFSET
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


[section .func]
[bits 32]
FUNCTION_SEGMENT:

; es:di --> data buffer 
GetKernelDataFunc:  
    mov cx, [esp + 4]
    and cx, 0x0003
    mov ax, es
    and ax, 0xFFFC
    or  ax, cx
    mov es, ax

    mov ax, KernelData32Selector
    mov ds, ax
    
    mov si, KDAT_OFFSET
    
    mov cx, KDAT_LEN
    
    call KMemCpy
    
    retf

; ds:si --> source
; es:di --> destination
; cx    --> length
KMemCpy:
    mov ax, es
    
    call CheckRPL
    
    cmp si, di
    ja btoe
    add si, cx
    add di, cx
    dec si
    dec di
    jmp etob
btoe:
    cmp cx, 0
    jz done
    mov al, [ds:si]
    mov byte [es:di], al
    inc si
    inc di
    dec cx
    jmp btoe
etob: 
    cmp cx, 0
    jz done
    mov al, [ds:si]
    mov byte [es:di], al
    dec si
    dec di
    dec cx
    jmp etob
done:   
    ret   

; ax --> selector value
CheckRPL:
    and ax, 0x0003
    cmp ax, SA_RPL0
    jz valid
    
    mov ax, 0
    mov fs, ax
    mov byte [fs:0], 0
    
valid:
    ret    
GetKernelData    equ   GetKernelDataFunc - $$
FunctionSegLen    equ   $ - FUNCTION_SEGMENT

[section .kgs]
[bits 32]
STACK32_KERNEL_SEGMENT:
    times 256 db 0
    
Stack32KernelSegLen equ $ - STACK32_KERNEL_SEGMENT
TopOfKernelStack32  equ Stack32KernelSegLen - 1

[section .ugs]
[bits 32]
STACK32_USER_SEGMENT:
    times 256 db 0
    
Stack32UserSegLen equ $ - STACK32_USER_SEGMENT
TopOfUserStack32  equ Stack32UserSegLen - 1