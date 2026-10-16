// Bounded real-GGML operator screen. Times are not model token throughput.
#include "ggml.h"
#include "ggml-cpu.h"
#include <vector>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstring>
#include <cstdint>
#include "affinity-check.h"
static void check(bool ok,const char*why){if(!ok){fprintf(stderr,"FAIL %s\n",why);exit(1);}}
static int integer(const char*s,int max){char*e;long v=strtol(s,&e,10);check(*s&&!*e&&v>0&&v<=max,"argument");return v;}
static void *aligned(std::vector<unsigned char>&v){return(void*)(((uintptr_t)v.data()+63)&~(uintptr_t)63);}
int main(int argc,char**argv){
    check(argc==8,"usage: bench-dense f16|f32 k rows cols threads repeats output.f32");
    bool half=strcmp(argv[1],"f16")==0;check(half||strcmp(argv[1],"f32")==0,"type");
    int k=integer(argv[2],32768),rows=integer(argv[3],4096),cols=integer(argv[4],4096),threads=integer(argv[5],240),repeats=integer(argv[6],7);
    check((size_t)k*rows<=32*1024*1024&&(size_t)k*cols<=32*1024*1024&&(size_t)rows*cols<=8*1024*1024,"small test bounds");
    ggml_cpu_init();ggml_init_params ip={2*1024*1024,nullptr,true};auto*ctx=ggml_init(ip);check(ctx,"context");
    auto*w=ggml_new_tensor_2d(ctx,half?GGML_TYPE_F16:GGML_TYPE_F32,k,rows);
    auto*x=ggml_new_tensor_2d(ctx,half?GGML_TYPE_F16:GGML_TYPE_F32,k,cols);
    auto*y=ggml_mul_mat(ctx,w,x);auto*g=ggml_new_graph(ctx);ggml_build_forward_expand(g,y);
    std::vector<unsigned char> wa(ggml_nbytes(w)+64),xa(ggml_nbytes(x)+64),ya(ggml_nbytes(y)+64);
    w->data=aligned(wa);x->data=aligned(xa);y->data=aligned(ya);
    for(auto*t:{w,x})for(int64_t i=0;i<ggml_nelements(t);++i){float v=((i*197+13)%8191-4095)/8192.f;if(half)((ggml_fp16_t*)t->data)[i]=ggml_fp32_to_fp16(v);else((float*)t->data)[i]=v;}
    auto tp=ggml_threadpool_params_default(threads);auto*pool=ggml_threadpool_new(&tp);check(pool,"threadpool");
    auto plan=ggml_graph_plan(g,threads,pool);std::vector<unsigned char>scratch(plan.work_size+64);plan.work_data=(uint8_t*)aligned(scratch);
    check(verify_benchmark_affinity(threads),"benchmark affinity");
    for(int r=-1;r<repeats;++r){auto start=ggml_time_us();check(ggml_graph_compute(g,&plan)==GGML_STATUS_SUCCESS,"compute");auto us=ggml_time_us()-start;
        if(r>=0)printf("DENSE type=%s k=%d rows=%d cols=%d threads=%d repeat=%d us=%lld\n",argv[1],k,rows,cols,threads,r,(long long)us);}
    auto*out=(float*)y->data;for(int64_t i=0;i<ggml_nelements(y);++i)check(std::isfinite(out[i]),"nonfinite");
    FILE*f=fopen(argv[7],"wb");check(f,"output");check(fwrite(out,1,ggml_nbytes(y),f)==ggml_nbytes(y),"write");check(!fclose(f),"close");
    ggml_threadpool_free(pool);ggml_free(ctx);
}
