
#ifndef GLOBAL_H
#define GLOBAL_H

#include "kernel.h"
#include "const.h"

extern GdtInfo gGdtInfo;
extern IdtInfo gIdtInfo;
extern void (* const RunTask)(volatile Task* pt);
extern void (* const LoadTask)(volatile Task* pt);

#endif
