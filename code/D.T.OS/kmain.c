#include "kernel.h"
#include "screen.h"
#include "global.h"

Task p = {0};

void Delay(int n)
{
    while( n > 0 )
    {
        int i = 0;
        int j = 0;
        
        for(i=0; i<1000; i++)
        {
            for(j=0; j<1000; j++)
            {
                asm volatile ("nop\n");
            }
        }
        
        n--;
    }
}

void TaskA()
{
    int i = 0;
    
    SetPrintPos(0, 12);
    
    PrintString("Task A: ");
    
    while(1)
    {
        SetPrintPos(8, 12);
        PrintChar('A' + i);
        i = (i + 1) % 26;
        Delay(1);
    }
}

void KMain()
{
    int n = PrintString("D.T.OS\n");
    uint base = 0;
    uint limit = 0;
    ushort attr = 0;
    int i = 0;
    
    PrintString("GDT Entry: ");
    PrintIntHex((uint)gGdtInfo.entry);
    PrintChar('\n');
    
    for(i=0; i<gGdtInfo.size; i++)
    {
        GetDescValue(gGdtInfo.entry + i, &base, &limit, &attr);
    
        PrintIntHex(base);
        PrintString("    ");
    
        PrintIntHex(limit);
        PrintString("    ");
    
        PrintIntHex(attr);
        PrintChar('\n');
    }
    
    PrintString("RunTask: ");
    PrintIntHex((uint)RunTask);
    PrintChar('\n');
    
    p.rv.cs = LDT_CODE32_SELECTOR;
    p.rv.gs = LDT_VIDEO_SELECTOR;
    p.rv.ds = LDT_DATA32_SELECTOR;
    p.rv.es = LDT_DATA32_SELECTOR;
    p.rv.fs = LDT_DATA32_SELECTOR;
    p.rv.ss = LDT_DATA32_SELECTOR;
    
    p.rv.esp = (uint)p.stack + sizeof(p.stack);
    p.rv.eip = (uint)TaskA;
    p.rv.eflags = 0x3002;
    
    p.tss.ss0 = GDT_DATA32_FLAT_SELECTOR;
    p.tss.esp0 = 0;
    p.tss.iomb = sizeof(p.tss);
    
    SetDescValue(p.ldt + LDT_VIDEO_INDEX,  0xB8000, 0x07FFF, DA_DRWA + DA_32 + DA_DPL3);
    SetDescValue(p.ldt + LDT_CODE32_INDEX, 0x00,    0xFFFFF, DA_C + DA_32 + DA_DPL3);
    SetDescValue(p.ldt + LDT_DATA32_INDEX, 0x00,    0xFFFFF, DA_DRW + DA_32 + DA_DPL3);
    
    p.ldtSelector = GDT_TASK_LDT_SELECTOR;
    p.tssSelector = GDT_TASK_TSS_SELECTOR;
    
    SetDescValue(&gGdtInfo.entry[GDT_TASK_LDT_INDEX], (uint)&p.ldt, sizeof(p.ldt)-1, DA_LDT + DA_DPL0);
    SetDescValue(&gGdtInfo.entry[GDT_TASK_TSS_INDEX], (uint)&p.tss, sizeof(p.tss)-1, DA_386TSS + DA_DPL0);
    
    PrintString("Stack Bottom: ");
    PrintIntHex((uint)p.stack);
    PrintString("    Stack Top: ");
    PrintIntHex((uint)p.stack + sizeof(p.stack));
    
    RunTask(&p);
}
