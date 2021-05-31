
#include "interrupt.h"

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
