#include "utility.h"
#include "task.h"

#define MAX_RUNNING_TASK    16


void (* const RunTask)(volatile Task* pt) = NULL;
void (* const LoadTask)(volatile Task* pt) = NULL;

volatile Task* gCTaskAddr = NULL;
static TaskNode gTaskBuff[MAX_RUNNING_TASK] = {0};
static Queue gRunningTask = {0};
static TSS gTSS = {0};

void TaskA()
{
    int i = 0;
    
    SetPrintPos(0, 12);
    
    PrintString(__FUNCTION__);
    
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
    
    PrintString(__FUNCTION__);
    
    while(1)
    {
        SetPrintPos(8, 13);
        PrintChar('0' + i);
        i = (i + 1) % 10;
        Delay(1);
    }
}

void TaskC()
{
    int i = 0;
    
    SetPrintPos(0, 14);
    
    PrintString(__FUNCTION__);
    
    while(1)
    {
        SetPrintPos(8, 14);
        PrintChar('a' + i);
        i = (i + 1) % 26;
        Delay(1);
    }
}

void TaskD()
{
    int i = 0;
    
    SetPrintPos(0, 15);
    
    PrintString(__FUNCTION__);
    
    while(1)
    {
        SetPrintPos(8, 15);
        PrintChar('!' + i);
        i = (i + 1) % 10;
        Delay(1);
    }
}


static void InitTask(Task* pt, void(*entry)())
{
    PrintIntHex(pt);
    PrintString("    ");
    PrintIntHex((uint)pt + 48);
    PrintChar('\n');
    
    pt->rv.cs = LDT_CODE32_SELECTOR;
    pt->rv.gs = LDT_VIDEO_SELECTOR;
    pt->rv.ds = LDT_DATA32_SELECTOR;
    pt->rv.es = LDT_DATA32_SELECTOR;
    pt->rv.fs = LDT_DATA32_SELECTOR;
    pt->rv.ss = LDT_DATA32_SELECTOR;
    
    pt->rv.esp = (uint)pt->stack + sizeof(pt->stack);
    pt->rv.eip = (uint)entry;
    pt->rv.eflags = 0x3202;
    
    SetDescValue(AddrOff(pt->ldt, LDT_VIDEO_INDEX),  0xB8000, 0x07FFF, DA_DRWA + DA_32 + DA_DPL3);
    SetDescValue(AddrOff(pt->ldt, LDT_CODE32_INDEX), 0x00,    0xFFFFF, DA_C + DA_32 + DA_DPL3);
    SetDescValue(AddrOff(pt->ldt, LDT_DATA32_INDEX), 0x00,    0xFFFFF, DA_DRW + DA_32 + DA_DPL3);
    
    pt->ldtSelector = GDT_TASK_LDT_SELECTOR;
    pt->tssSelector = GDT_TASK_TSS_SELECTOR;
}

static void PrepareForRun(volatile Task* pt)
{
    gTSS.ss0 = GDT_DATA32_FLAT_SELECTOR;
    gTSS.esp0 = (uint)&pt->rv + sizeof(pt->rv);
    gTSS.iomb = sizeof(TSS);
    
    SetDescValue(AddrOff(gGdtInfo.entry, GDT_TASK_LDT_INDEX), (uint)&pt->ldt, sizeof(pt->ldt)-1, DA_LDT + DA_DPL0);
}

void TaskModInit()
{
    SetDescValue(AddrOff(gGdtInfo.entry, GDT_TASK_TSS_INDEX), (uint)&gTSS, sizeof(gTSS)-1, DA_386TSS + DA_DPL0);
    
    InitTask(&((TaskNode*)AddrOff(gTaskBuff, 0))->task, TaskA);
    InitTask(&((TaskNode*)AddrOff(gTaskBuff, 1))->task, TaskB);
    InitTask(&((TaskNode*)AddrOff(gTaskBuff, 2))->task, TaskC);
    InitTask(&((TaskNode*)AddrOff(gTaskBuff, 3))->task, TaskD);
    
    Queue_Init(&gRunningTask);
    
    Queue_Add(&gRunningTask, (QueueNode*)AddrOff(gTaskBuff, 0));
    Queue_Add(&gRunningTask, (QueueNode*)AddrOff(gTaskBuff, 1));
    Queue_Add(&gRunningTask, (QueueNode*)AddrOff(gTaskBuff, 2));
    Queue_Add(&gRunningTask, (QueueNode*)AddrOff(gTaskBuff, 3));
}

void LaunchTask()
{
    gCTaskAddr = &((TaskNode*)Queue_Front(&gRunningTask))->task;
    
    PrepareForRun(gCTaskAddr);
    
    RunTask(gCTaskAddr);
}

void Schedule()
{
    Queue_Rotate(&gRunningTask);
    
    gCTaskAddr = &((TaskNode*)Queue_Front(&gRunningTask))->task;
    
    PrepareForRun(gCTaskAddr);
    
    LoadTask(gCTaskAddr);
}



