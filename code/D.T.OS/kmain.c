#include "kernel.h"
#include "screen.h"
#include "global.h"

void (* const InitInterrupt)() = NULL;
void (* const EnableTimer)() = NULL;
void (* const SendEOI)(uint port) = NULL;

volatile Task* gCTaskAddr = NULL;
Task p = {0};
Task t = {0};
TSS gTSS = {0};

void InitTask(Task* pt, void(*entry)())
{
    pt->rv.cs = LDT_CODE32_SELECTOR;
    pt->rv.gs = LDT_VIDEO_SELECTOR;
    pt->rv.ds = LDT_DATA32_SELECTOR;
    pt->rv.es = LDT_DATA32_SELECTOR;
    pt->rv.fs = LDT_DATA32_SELECTOR;
    pt->rv.ss = LDT_DATA32_SELECTOR;
    
    pt->rv.esp = (uint)pt->stack + sizeof(pt->stack);
    pt->rv.eip = (uint)entry;
    pt->rv.eflags = 0x3202;
    
    gTSS.ss0 = GDT_DATA32_FLAT_SELECTOR;
    gTSS.esp0 = (uint)&pt->rv + sizeof(pt->rv);
    gTSS.iomb = sizeof(TSS);
    
    SetDescValue(pt->ldt + LDT_VIDEO_INDEX,  0xB8000, 0x07FFF, DA_DRWA + DA_32 + DA_DPL3);
    SetDescValue(pt->ldt + LDT_CODE32_INDEX, 0x00,    0xFFFFF, DA_C + DA_32 + DA_DPL3);
    SetDescValue(pt->ldt + LDT_DATA32_INDEX, 0x00,    0xFFFFF, DA_DRW + DA_32 + DA_DPL3);
    
    pt->ldtSelector = GDT_TASK_LDT_SELECTOR;
    pt->tssSelector = GDT_TASK_TSS_SELECTOR;
    
    SetDescValue(&gGdtInfo.entry[GDT_TASK_LDT_INDEX], (uint)&pt->ldt, sizeof(pt->ldt)-1, DA_LDT + DA_DPL0);
    SetDescValue(&gGdtInfo.entry[GDT_TASK_TSS_INDEX], (uint)&gTSS, sizeof(gTSS)-1, DA_386TSS + DA_DPL0);
}

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

void TaskB()
{
    int i = 0;
    
    SetPrintPos(0, 13);
    
    PrintString("Task B: ");
    
    while(1)
    {
        SetPrintPos(8, 13);
        PrintChar('0' + i);
        i = (i + 1) % 10;
        Delay(1);
    }
}

void ChangeTask()
{
    gCTaskAddr = (gCTaskAddr == &p) ? &t : &p;
    
    gTSS.ss0 = GDT_DATA32_FLAT_SELECTOR;
    gTSS.esp0 = (uint)&gCTaskAddr->rv.gs + sizeof(RegValue);
    
    SetDescValue(&gGdtInfo.entry[GDT_TASK_LDT_INDEX], (uint)&gCTaskAddr->ldt, sizeof(gCTaskAddr->ldt)-1, DA_LDT + DA_DPL0);
    
    LoadTask(gCTaskAddr);
}

void TimerHandlerEntry();

void TimerHandler()
{
    static uint i = 0;
    
    i = (i + 1) % 5;
    
    if( i == 0 )
    {
        ChangeTask();
    }
    
    SendEOI(MASTER_EOI_PORT);
}

void KMain()
{
    int n = PrintString("D.T.OS\n");
    uint temp = 0;
    
    PrintString("GDT Entry: ");
    PrintIntHex((uint)gGdtInfo.entry);
    PrintChar('\n');
    
    PrintString("GDT Size: ");
    PrintIntDec((uint)gGdtInfo.size);
    PrintChar('\n');
    
    PrintString("IDT Entry: ");
    PrintIntHex((uint)gIdtInfo.entry);
    PrintChar('\n');
    
    PrintString("IDT Size: ");
    PrintIntDec((uint)gIdtInfo.size);
    PrintChar('\n');
    
    InitTask(&t, TaskB);
    InitTask(&p, TaskA);
    
    
    SetIntHandler(gIdtInfo.entry + 0x20, (uint)TimerHandlerEntry);
    
    InitInterrupt();
    
    EnableTimer();
    
    gCTaskAddr = &p;
    
    RunTask(gCTaskAddr);
}
