#include "task.h"
#include "interrupt.h"
#include "screen.h"

void KMain()
{
    void (*AppModInit)() = (void*)BaseOfApp;
    
    PrintString("D.T.OS\n");
    
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
    
    AppModInit();
    
    TaskModInit();
    
    IntModInit();
    
    ConfigPageTable();
    
    LaunchTask();
    
}
