
#include "app.h"
#include "utility.h"

#define MAX_APP_NUM    16

static AppInfo gAppToRun[MAX_APP_NUM] = {0};
static uint gAppNum = 0;

void TaskA();
void TaskB();
void TaskC();
void TaskD();

static void RegApp(const char* name, void(*tmain)(), byte pri)
{
    if( gAppNum < MAX_APP_NUM )
    {
        AppInfo* app = AddrOff(gAppToRun, gAppNum);
        
        app->name = name;
        app->tmain = tmain;
        app->priority = pri;
        
        gAppNum++;
    }
}

void AppModInit()
{
    RegApp("Task A", TaskA, 255);
    RegApp("Task B", TaskB, 230);
    RegApp("Task C", TaskC, 230);
    RegApp("Task D", TaskD, 255);
}

AppInfo* GetAppToRun(uint index)
{
    AppInfo* ret = NULL;
    
    if( index < MAX_APP_NUM )
    {
        ret = AddrOff(gAppToRun, index);
    }
    
    return ret;
}

uint GetAppNum()
{
    return gAppNum;
}


void TaskA()
{
    int i = 0;
    
    SetPrintPos(0, 12);
    
    PrintString(__FUNCTION__);
    
    while( i < 5 )
    {
        SetPrintPos(8, 12);
        PrintChar('A' + i);
        i = (i + 1) % 26;
        Delay(1);
    }
    
    SetPrintPos(8, 12);
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