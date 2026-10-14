#include "ggml.h"
#include "ggml-cpu.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

static size_t checked=0;
static void compute(ggml_cgraph * g, int threads, bool reference) {
    auto plan=ggml_graph_plan(g,threads,nullptr);
    plan.use_ref=reference;
    std::vector<unsigned char> work(plan.work_size+64);
    plan.work_data=(uint8_t *)(((uintptr_t)work.data()+63)&~(uintptr_t)63);
    if (ggml_graph_compute(g,&plan)!=GGML_STATUS_SUCCESS) std::abort();
}
static void check(ggml_context * ctx, ggml_tensor * out) {
    auto * graph=ggml_new_graph(ctx);
    ggml_build_forward_expand(graph,out);
    const size_t n=ggml_nelements(out);
    std::vector<float> result(n+32,12345.f);
    out->data=result.data()+16;
    compute(graph,1,true);
    const auto expected=result;
    for (int threads : {1,3,60,120,180,240}) {
        std::fill(result.begin(),result.end(),12345.f);
        compute(graph,threads,false);
        if (std::memcmp(result.data(),expected.data(),result.size()*sizeof(float))) {
            std::fprintf(stderr,"FAIL %s ne=%lld,%lld,%lld,%lld workers=%d\n",ggml_op_name(out->op),
                (long long)out->ne[0],(long long)out->ne[1],(long long)out->ne[2],(long long)out->ne[3],threads);
            std::exit(1);
        }
        checked+=n;
    }
}
int main() {
    ggml_cpu_init();
    for (int width : {1,15,16,17,257,2048,10752}) for (int rows : {1,3,17,61}) for (int mode=0;mode<3;++mode) {
        ggml_init_params ip={4*1024*1024,nullptr,true};
        auto * ctx=ggml_init(ip);
        auto * x=ggml_new_tensor_2d(ctx,GGML_TYPE_F32,width*(mode==0?1:2),rows);
        auto * gate=ggml_new_tensor_2d(ctx,GGML_TYPE_F32,width,rows);
        // Row padding verifies the fast path honors source strides.
        x->nb[1]+=64;gate->nb[1]+=64;
        std::vector<float> a(ggml_nbytes(x)/4+16),b(ggml_nbytes(gate)/4+16);
        for (size_t i=0;i<a.size();++i)a[i]=std::sin(i*.017f)*12.f;
        for (size_t i=0;i<b.size();++i)b[i]=std::cos(i*.023f)*4.f;
        x->data=a.data();gate->data=b.data();
        auto * out=mode==0?ggml_swiglu_split(ctx,x,gate):mode==1?ggml_swiglu(ctx,x):ggml_swiglu_swapped(ctx,x);
        check(ctx,out);ggml_free(ctx);
    }
    for (int tokens : {1,3,17}) for (int heads : {1,8,32}) for (int kind : {0,1,2}) for (int sinks : {0,1}) {
        ggml_init_params ip={4*1024*1024,nullptr,true};
        auto * ctx=ggml_init(ip);
        auto * x=ggml_new_tensor_4d(ctx,GGML_TYPE_F32,257,tokens,heads,2);
        auto * mask=ggml_new_tensor_4d(ctx,kind==1?GGML_TYPE_F16:GGML_TYPE_F32,257,tokens,1,2);
        auto * sink=ggml_new_tensor_1d(ctx,GGML_TYPE_F32,heads);
        std::vector<float> a(ggml_nelements(x)),b(ggml_nelements(mask)),c(heads);
        std::vector<ggml_fp16_t> h(b.size());
        for(size_t i=0;i<a.size();++i)a[i]=std::sin(i*.017f)*7.f;
        for(size_t i=0;i<b.size();++i){b[i]=i%257>64?-INFINITY:std::cos(i*.031f);h[i]=ggml_fp32_to_fp16(b[i]);}
        for(int i=0;i<heads;++i)c[i]=i*.01f;
        x->data=a.data();mask->data=kind==1?(void *)h.data():(void *)b.data();sink->data=c.data();
        auto * out=ggml_soft_max_ext(ctx,x,kind?mask:nullptr,.125f,kind==2?2.f:0.f);
        if(sinks)ggml_soft_max_add_sinks(out,sink);
        check(ctx,out);ggml_free(ctx);
    }
    std::printf("PASS %zu bitwise SwiGLU/softmax outputs and canaries\n",checked);
}
