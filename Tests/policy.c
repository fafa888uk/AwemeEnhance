#include "../Sources/Core/AEPolicy.h"
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
int main(void) {
    assert(AEClampRate(.25)==.25 && AEClampRate(3)==3 && AEClampRate(NAN)==1 && AEClampRate(INFINITY)==1 && AEClampRate(0)==1 && AEClampRate(4)==1);
    assert(AEClampOpacity(.2)==.2 && AEClampOpacity(1)==1 && AEClampOpacity(NAN)==1 && AEClampOpacity(.1)==1);
    assert(AEFilterItem(true,true,false,false,true,false,false));
    assert(!AEFilterItem(false,true,true,true,true,true,true));
    assert(!AEFilterItem(true,false,false,false,true,true,true));
    assert(AEFilterItem(true,false,true,false,false,true,false));
    assert(AEFilterItem(true,false,false,true,false,false,true));
    double b[]={100,200,1000,NAN}; bool supported[]={true,true,false,true};
    assert(AEBestRendition(b,supported,4)==1);
    assert(AEBestRendition(NULL,NULL,0)==SIZE_MAX);
    supported[0]=false; supported[1]=false; assert(AEBestRendition(b,supported,4)==SIZE_MAX);
    assert(AEDue(true,true,true,1200,1200,false));
    assert(!AEDue(true,false,true,1200,1200,false));
    assert(!AEDue(true,true,false,1200,1200,false));
    assert(!AEDue(true,true,true,1200,1200,true));
    assert(!AEDue(true,true,true,1199,1200,false));
    assert(!AEDue(true,true,true,1440,1200,false));
    assert(!AEDue(true,true,true,1300,-1,false));
    puts("policy: all assertions passed"); return 0;
}
