#pragma once
#include <omp.h>
#include <sched.h>
#include <set>
#include <sstream>
static bool verify_benchmark_affinity(int threads) {
    const char*value=getenv("GOMP_CPU_AFFINITY");if(!value)return false;
    std::istringstream input(value);std::set<int> allowed,seen;int id;
    while(input>>id)allowed.insert(id);
    std::vector<int> cpus(threads,-1);
    omp_set_dynamic(0);
#pragma omp parallel num_threads(threads)
    {
        cpu_set_t mask;CPU_ZERO(&mask);
        if(sched_getaffinity(0,sizeof(mask),&mask)==0&&CPU_COUNT(&mask)==1)
            for(int i=0;i<CPU_SETSIZE;++i)if(CPU_ISSET(i,&mask))cpus[omp_get_thread_num()]=i;
    }
    for(int cpu:cpus)if(!allowed.count(cpu)||!seen.insert(cpu).second)return false;
    printf("AFFINITY_VERIFIED threads=%d unique_cpus=%zu\n",threads,seen.size());
    return true;
}
