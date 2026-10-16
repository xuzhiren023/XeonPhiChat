#include "ggml.h"
#include "ggml-cpu.h"
#include <vector>
#include <cmath>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <cstdint>

extern "C" void knc_f16_products_pair(size_t,const ggml_fp16_t*,const ggml_fp16_t*,const ggml_fp16_t*,float*,float*);
static void check(bool ok,const char *why) { if(!ok) {std::fprintf(stderr,"FAIL %s\n",why); std::exit(1);} }
static void *aligned(std::vector<unsigned char>&v,int offset=0) {return (void*)((((uintptr_t)v.data()+63)&~(uintptr_t)63)+offset);}
static size_t outputs=0,cases=0,bitwise_mismatches=0;
static size_t type_mismatches[2]={0,0};
static void graph_case(ggml_type wt,ggml_type xt,int k,int rows,int cols,int heads,int threads,int offset) {
    ggml_init_params ip={2*1024*1024,nullptr,true};auto*ctx=ggml_init(ip);check(ctx,"context");
    auto*w=ggml_new_tensor_3d(ctx,wt,k,rows,heads>1?2:1);
    auto*x=ggml_new_tensor_3d(ctx,xt,k,cols,heads);
    auto*y=ggml_mul_mat(ctx,w,x);auto*g=ggml_new_graph(ctx);ggml_build_forward_expand(g,y);
    std::vector<unsigned char> wa(ggml_nbytes(w)+128),xa(ggml_nbytes(x)+128),ya(ggml_nbytes(y)+192);
    w->data=aligned(wa,offset);x->data=aligned(xa);y->data=(float*)aligned(ya)+16;
    for(int64_t i=0;i<ggml_nelements(w);++i) {float v=std::sin(i*.071f)*3.1f;
        if(wt==GGML_TYPE_F16)((ggml_fp16_t*)w->data)[i]=ggml_fp32_to_fp16(v);else((float*)w->data)[i]=v;}
    for(int64_t i=0;i<ggml_nelements(x);++i) {float v=std::cos(i*.031f)*1.3f;
        if(xt==GGML_TYPE_F16)((ggml_fp16_t*)x->data)[i]=ggml_fp32_to_fp16(v);else((float*)x->data)[i]=v;}
    auto plan=ggml_graph_plan(g,threads,nullptr);std::vector<unsigned char> work(plan.work_size+64);plan.work_data=(uint8_t*)aligned(work);
    for(int mode=0;mode<2;++mode) {
        setenv("GGML_KNC_F16_CONV",mode?"1":"0",1);setenv("GGML_KNC_F32_ATTN",mode?"1":"0",1);
        std::memset(ya.data(),0xa5,ya.size());
        check(ggml_graph_compute(g,&plan)==GGML_STATUS_SUCCESS,"compute");
        static std::vector<float> expected;
        auto*p=(float*)y->data;
        if(!mode)expected.assign(p,p+ggml_nelements(y));
        else {
            for(size_t i=0;i<expected.size();++i) {
                check(std::isfinite(p[i]) && std::abs(p[i]-expected[i])<=0.0001f+0.00001f*std::abs(expected[i]),"dense numerical mismatch");
                const bool different=std::memcmp(p+i,&expected[i],4)!=0;
                bitwise_mismatches+=different; type_mismatches[wt==GGML_TYPE_F16]+=different; ++outputs;
#ifdef __k1om__
                if(wt==GGML_TYPE_F32)check(std::memcmp(p+i,&expected[i],4)==0,"native F32 accumulation changed");
#endif
            }
            auto*b=(unsigned char*)y->data;
            for(int i=1;i<=64;++i)check(b[-i]==0xa5,"leading canary");
            for(int i=0;i<64;++i)check(b[ggml_nbytes(y)+i]==0xa5,"trailing canary");
        }
    }
    ++cases;ggml_free(ctx);
}
int main() {
    ggml_cpu_init();
    setenv("GGML_KNC_DENSE_TRACE","1",1);
    alignas(64) ggml_fp16_t a[256],b[256],y[256];alignas(64) float p[256],q[256];size_t products=0;
    for(int base=0;base<65536;base+=256) {
        for(int i=0;i<256;++i) {
            a[i]=base+i;if((a[i]&0x7c00)==0x7c00)a[i]&=0xfbff;
            b[i]=a[i]^0x8000;y[i]=i*197+17;if((y[i]&0x7c00)==0x7c00)y[i]&=0xfbff;
        }
        knc_f16_products_pair(256,a,b,y,p,q);
        for(int i=0;i<256;++i) {
            float ep=ggml_fp16_to_fp32(a[i])*ggml_fp16_to_fp32(y[i]),eq=ggml_fp16_to_fp32(b[i])*ggml_fp16_to_fp32(y[i]);
            check(std::memcmp(&ep,&p[i],4)==0 && std::memcmp(&eq,&q[i],4)==0,"half conversion/product"); products+=2;
        }
    }
    for(int k : {16,32,64,96,256,512,2704}) for(int rows : {1,2,15,17,96,169}) {
        for(int threads : {1,3,8}) {
            graph_case(GGML_TYPE_F32,GGML_TYPE_F32,k,rows,9,1,threads,0);
            graph_case(GGML_TYPE_F16,GGML_TYPE_F32,k,rows,9,1,threads,0);
            graph_case(GGML_TYPE_F16,GGML_TYPE_F16,k,rows,9,1,threads,0);
        }
    }
    for(int k : {64,96,512}) for(int offset : {0,4}) {
        graph_case(GGML_TYPE_F32,GGML_TYPE_F32,k,17,3,4,8,offset);
        graph_case(GGML_TYPE_F16,GGML_TYPE_F32,k,17,3,4,8,offset);
    }
    for(int k : {13824,27648}) graph_case(GGML_TYPE_F16,GGML_TYPE_F16,k,3,3,1,3,0);
    std::printf("PASS %zu graph cases, %zu outputs, %zu half products; %zu output bit-pattern differences within numerical tolerance\n",cases,outputs,products,bitwise_mismatches);
    std::printf("BITWISE_DIFFERENCES f32=%zu f16=%zu\n",type_mismatches[0],type_mismatches[1]);
}
