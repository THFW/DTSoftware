
#ifndef MUTEX_H
#define MUTEX_H

#include "type.h"
#include "list.h"

typedef struct 
{
    ListNode head;
    uint lock;
} Mutex;

void MutexModInit();
void MutexCallHandler(uint cmd, uint param1, uint param2);

Mutex* SysCreateMutex();
void SysDestroyMutex(Mutex* mutex, uint* result);
void SysEnterCritical(Mutex* mutex, uint* wait);
void SysExitCritical(Mutex* mutex);

#endif
