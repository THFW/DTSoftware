
#include "interrupt.h"
#include "task.h"

void TimerHandler()
{
    static uint i = 0;
    
    i = (i + 1) % 5;
    
    if( i == 0 )
    {
        Schedule();
    }
    
    SendEOI(MASTER_EOI_PORT);
}

void SysCallHandler(ushort ax)   // __cdecl__
{  
    if( ax == 0 )
    {
        KillTask();
    }
}
