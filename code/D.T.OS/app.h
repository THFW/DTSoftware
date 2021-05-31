
#ifndef APP_H
#define APP_H

#include "type.h"

typedef struct 
{
    const char* name;
    void (*tmain)();
} AppInfo;

void AppModInit();
AppInfo* GetAppToRun(uint index);
uint GetAppNum();

#endif
