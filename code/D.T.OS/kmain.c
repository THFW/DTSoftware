#include "kernel.h"
#include "screen.h"
#include "global.h"

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
}
