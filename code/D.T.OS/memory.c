
#include "memory.h"
#include "utility.h"
#include "list.h"

#include <stdio.h>
#include <time.h>
#include <stdlib.h>

#define FM_ALLOC_SIZE    32
#define FM_NODE_SIZE     sizeof(FMemNode)
#define VM_HEAD_SIZE     sizeof(VMemHead)

typedef byte(FMemUnit)[FM_ALLOC_SIZE];
typedef union _FMemNode  FMemNode;

union _FMemNode
{
    FMemNode* next;
    FMemUnit* ptr;
};

typedef struct
{
    FMemNode* node;
    FMemNode* nbase;
    FMemUnit* ubase;
    uint max;
} FMemList;


typedef struct
{
    ListNode head;
    uint used;
    uint free;
    byte* ptr;
} VMemHead;


static FMemList gFMemList = {0};
static List gVMemList = {0};

static void FMemInit(byte* mem, uint size)
{
    FMemNode* p = NULL;
    int i = 0;
    uint max = 0;
    
    max = size / (FM_NODE_SIZE + FM_ALLOC_SIZE);
    
    gFMemList.max = max;
    gFMemList.nbase = (FMemNode*)mem;
    gFMemList.ubase = (FMemUnit*)((uint)mem + max * FM_NODE_SIZE);
    gFMemList.node = (FMemNode*)mem;
    
    p = gFMemList.node;
    
    for(i=0; i<max-1; i++)
    {
        FMemNode* current = (FMemNode*)AddrOff(p, i);
        FMemNode* next = (FMemNode*)AddrOff(p, i+1);
        
        current->next = next;
    }
    
    ((FMemNode*)AddrOff(p, i))->next = NULL;
}

static void* FMemAlloc()
{
    void* ret = NULL;
    
    if( gFMemList.node )
    {
        FMemNode* alloc = gFMemList.node;
        int index = AddrIndex(alloc, gFMemList.nbase);
        
        ret = AddrOff(gFMemList.ubase, index);
        
        gFMemList.node = alloc->next;
        
        alloc->ptr = ret;
    }
    
    return ret;
}

static int FMemFree(void* ptr)
{
    int ret = 0;
    
    if( ptr )
    {
        uint index = AddrIndex((FMemUnit*)ptr, gFMemList.ubase);
        FMemNode* node = AddrOff(gFMemList.nbase, index);
        
        if( (index < gFMemList.max) && IsEqual(node->ptr, ptr) )
        {
            node->next = gFMemList.node;
            
            gFMemList.node = node;
            
            ret = 1;
        }
    }
    
    return ret;
}

static void VMemInit(byte* mem, uint size)
{
    List_Init((List*)&gVMemList);
    VMemHead* head = (VMemHead*)mem;
    
    head->used = 0;
    head->free = size - VM_HEAD_SIZE;
    head->ptr = AddrOff(head, 1);
    
    List_AddTail(&gVMemList, (ListNode*)head);
} 

static void* VMemAlloc(uint size)
{
    ListNode* pos = NULL;
    VMemHead* ret = NULL;
    uint alloc = size + VM_HEAD_SIZE;
    
    List_ForEach(&gVMemList, pos)
    {
        VMemHead* current = (VMemHead*)pos;
        
        if( current->free >= alloc )
        {
            byte* mem = (byte*)((uint)current->ptr + (current->used + current->free) - alloc);
            
            ret = (VMemHead*)mem;
            ret->used = size;
            ret->free = 0;
            ret->ptr = AddrOff(ret, 1);
            
            current->free -= alloc;
            
            List_AddAfter((ListNode*)current, (ListNode*)ret);
            
            break;
        }
    }
    
    return ret ? ret->ptr : NULL;
}

static int VMemFree(void* ptr)
{
    int ret = 0;
    
    if( ptr )
    {
        ListNode* pos = NULL;
        
        List_ForEach(&gVMemList, pos)
        {
            VMemHead* current = (VMemHead*)pos;
            
            if( IsEqual(current->ptr, ptr) )
            {
                VMemHead* prev = (VMemHead*)(current->head.prev);
                
                prev->free += current->used + current->free + VM_HEAD_SIZE;
                
                List_DelNode((ListNode*)current);
                
                ret = 1;
                
                break;
            }
        }
    }
    
    return ret;
}

void vmem_test()
{
    static byte vmem[0x10000] = {0};
    void* array[2000] = {0};
    ListNode* pos = NULL;
    int i = 0;
    
    srand((unsigned)time(NULL));
    
    VMemInit(vmem, sizeof(vmem));
    
    List_ForEach(&gVMemList, pos)
    {
        VMemHead* current = (VMemHead*)pos;
        
        printf("i = %d\n", i++);
        printf("used: %d\n", current->used);
        printf("free: %d\n", current->free);
        printf("\n");
    }
    
    printf("Alloc Test:\n");
    
    i = 0;
    
    for(i=0; i<100000; i++)
    {
        int ii = i % 2000;
        byte* p = VMemAlloc(1 + rand() % 400);
        
        if( array[ii] )
        {
            VMemFree(array[ii]);
            
            array[ii] = NULL; 
        }
        
        array[ii] = p;
        
        if( i % 3 == 0 )
        {
            int index = rand() % 2000;
            
            VMemFree(array[index]);
            
            array[index] = NULL;
        }
    }
    
    printf("\n");
    
    printf("Free Test:\n");
    
    for(i=0; i<2000; i++)
    {
        VMemFree(array[i]);
    }
    
    i = 0;
    
    List_ForEach(&gVMemList, pos)
    {
        VMemHead* current = (VMemHead*)pos;
        
        printf("i = %d\n", i++);
        printf("used: %d\n", current->used);
        printf("free: %d\n", current->free);
        printf("\n");
    }
}

void fmem_test()
{
    static byte fmem[0x10000] = {0};
    static void* array[2000] = {0};
    int i = 0;
    
    FMemNode* pos = NULL;
    
    FMemInit(fmem, sizeof(fmem));
    
    pos = gFMemList.node;
    
    while( pos )
    {
        i++;
        pos = pos->next;
    }
    
    printf("i = %d\n", i++);
    
    for(i=0; i<100000; i++)
    {
        int ii = i % 2000;
        byte* p = FMemAlloc();
        
        if( array[ii] )
        {
            FMemFree(array[ii]);
            
            array[ii] = NULL; 
        }
        
        array[ii] = p;
        
        if( i % 3 == 0 )
        {
            int index = rand() % 2000;
            
            FMemFree(array[index]);
            
            array[index] = NULL;
        }
    }
    
    for(i=0; i<2000; i++)
    {
        FMemFree(array[i]);
    }
    
    i = 0;
    
    pos = gFMemList.node;
    
    while( pos )
    {
        i++;
        pos = pos->next;
    }
    
    printf("i = %d\n", i++);
}


