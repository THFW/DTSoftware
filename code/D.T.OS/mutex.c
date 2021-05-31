
#include "mutex.h"
#include "memory.h"
#include "task.h"

extern volatile Task* gCTaskAddr;

static List gMList = {0};

void MutexModInit()
{
    List_Init(&gMList);
}

void MutexCallHandler(uint cmd, uint param1, uint param2)
{
    if( cmd == 0 )
    {
        uint* pRet = (uint*)param1;
        
        *pRet = (uint)SysCreateMutex();
    }
    else if( cmd == 1 )
    {
        SysEnterCritical((Mutex*)param1, (uint*)param2);
    }
    else if( cmd == 2 )
    {
        SysExitCritical((Mutex*)param1);
    }
    else 
    {
        SysDestroyMutex((Mutex*)param1, (uint*)param2);
    }
}

Mutex* SysCreateMutex()
{
    Mutex* ret = Malloc(sizeof(Mutex));
    
    if( ret )
    {
        ret->lock = 0;  
        
        List_Add(&gMList, (ListNode*)ret);
    }
    
    return ret;
}

static uint IsMutexValid(Mutex* mutex)
{
    uint ret = 0;
    ListNode* pos = NULL;
    
    List_ForEach(&gMList, pos)
    {
        if( IsEqual(pos, mutex) )
        {
            ret = 1;
            break;
        }
    }
    
    return ret;
}

void SysDestroyMutex(Mutex* mutex, uint* result)
{
    if( mutex )
    {
        ListNode* pos = NULL;
        
        *result = 0;
    
        List_ForEach(&gMList, pos)
        {
            if( IsEqual(pos, mutex) )
            {
                if( IsEqual(mutex->lock, 0) )
                {
                    List_DelNode(pos);
                    
                    Free(pos);
                    
                    *result = 1;
                }
                
                break;
            }
        }
    }
}

void SysEnterCritical(Mutex* mutex, uint* wait)
{
    if( mutex && IsMutexValid(mutex) )
    { 
        if( mutex->lock )
        {
            if( IsEqual(mutex->lock, gCTaskAddr) )
            {
                *wait = 0;
            }
            else
            {         
                *wait = 1;
                
                MtxSchedule(WAIT);
            }
        }
        else
        {
            mutex->lock = (uint)gCTaskAddr;
            
            *wait = 0;
        }
    }
}


void SysExitCritical(Mutex* mutex)
{
    if( mutex && IsMutexValid(mutex) )
    {
        if( IsEqual(mutex->lock, gCTaskAddr) )
        {
            mutex->lock = 0;
            
            MtxSchedule(NOTIFY);
        }
        else
        {   
            KillTask();
        }
    }
}


