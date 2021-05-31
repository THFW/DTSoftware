#include "utility.h"
#include "task.h"


void (* const RunTask)(volatile Task* pt) = NULL;
void (* const LoadTask)(volatile Task* pt) = NULL;

volatile Task* gCTaskAddr = NULL;
Task p = {0};
Task t = {0};
TSS gTSS = {0};

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


static void InitTask(Task* pt, void(*entry)())
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
    
    SetDescValue(AddrOff(pt->ldt, LDT_VIDEO_INDEX),  0xB8000, 0x07FFF, DA_DRWA + DA_32 + DA_DPL3);
    SetDescValue(AddrOff(pt->ldt, LDT_CODE32_INDEX), 0x00,    0xFFFFF, DA_C + DA_32 + DA_DPL3);
    SetDescValue(AddrOff(pt->ldt, LDT_DATA32_INDEX), 0x00,    0xFFFFF, DA_DRW + DA_32 + DA_DPL3);
    
    pt->ldtSelector = GDT_TASK_LDT_SELECTOR;
    pt->tssSelector = GDT_TASK_TSS_SELECTOR;
    
    SetDescValue(AddrOff(gGdtInfo.entry, GDT_TASK_LDT_INDEX), (uint)&pt->ldt, sizeof(pt->ldt)-1, DA_LDT + DA_DPL0);
    SetDescValue(AddrOff(gGdtInfo.entry, GDT_TASK_TSS_INDEX), (uint)&gTSS, sizeof(gTSS)-1, DA_386TSS + DA_DPL0);
}

void TaskModInit()
{
    InitTask(&t, TaskB);
    InitTask(&p, TaskA);
}

void LaunchTask()
{
    gCTaskAddr = &p;
    
    RunTask(gCTaskAddr);
}

void Schedule()
{
    gCTaskAddr = (gCTaskAddr == &p) ? &t : &p;
    
    gTSS.ss0 = GDT_DATA32_FLAT_SELECTOR;
    gTSS.esp0 = (uint)&gCTaskAddr->rv.gs + sizeof(RegValue);
    
    SetDescValue(AddrOff(gGdtInfo.entry, GDT_TASK_LDT_INDEX), (uint)&gCTaskAddr->ldt, sizeof(gCTaskAddr->ldt)-1, DA_LDT + DA_DPL0);
    
    LoadTask(gCTaskAddr);
}



