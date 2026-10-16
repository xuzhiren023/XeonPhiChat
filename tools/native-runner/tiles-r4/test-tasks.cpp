// SPDX-License-Identifier: MIT. Exact scheduler equivalence, edges and canaries.
#include "ggml.h"
#include "ggml-cpu.h"
#include "ggml-quants.h"
#include "knc-mq.h"
#include <vector>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
extern "C" void ggml_knc_optimized_enable(int);
static void check(bool v,const char*s){if(!v){fprintf(stderr,"FAIL %s\n",s);exit(1);}}
static void* aligned(std::vector<uint8_t>&v){return (void*)(((uintptr_t)v.data()+63)&~(uintptr_t)63);}
int main(){
 ggml_cpu_init();ggml_knc_mq_init();ggml_knc_optimized_enable(1);ggml_knc_mq_optimized(1);
 setenv("GGML_KNC_WIDE16","1",1);setenv("GGML_KNC_TEXT_PAIR","1",1);
 size_t cases=0,values=0;
 for(auto type:{GGML_TYPE_Q3_K,GGML_TYPE_Q4_K,GGML_TYPE_Q5_K,GGML_TYPE_Q6_K})
 for(int k:{256,512})for(int rows:{16,32,33,256})for(int cols:{16,17,31,32,33,64})for(int nth:{1,3,8}) {
  ggml_init_params ip={2*1024*1024,nullptr,true};auto*ctx=ggml_init(ip);check(ctx,"context");
  auto*w=ggml_new_tensor_2d(ctx,type,k,rows);auto*x=ggml_new_tensor_2d(ctx,GGML_TYPE_F32,k,cols);
  auto*y=ggml_mul_mat(ctx,w,x);auto*g=ggml_new_graph(ctx);ggml_build_forward_expand(g,y);
  std::vector<uint8_t> wm(ggml_nbytes(w)+64),xm(ggml_nbytes(x)+64),ym(ggml_nbytes(y)+192);
  w->data=aligned(wm);x->data=aligned(xm);y->data=(float*)aligned(ym)+16;
  std::vector<float> row(k),expected(rows*cols);
  for(int r=0;r<rows;++r){for(int i=0;i<k;++i)row[i]=((i*197+r*89)%4093-2046)/1024.f;
   void*p=(char*)w->data+r*w->nb[1];
   switch(type){case GGML_TYPE_Q3_K:quantize_row_q3_K_ref(row.data(),(block_q3_K*)p,k);break;
    case GGML_TYPE_Q4_K:quantize_row_q4_K_ref(row.data(),(block_q4_K*)p,k);break;
    case GGML_TYPE_Q5_K:quantize_row_q5_K_ref(row.data(),(block_q5_K*)p,k);break;
    default:quantize_row_q6_K_ref(row.data(),(block_q6_K*)p,k);}
  }
  for(int i=0;i<k*cols;++i)((float*)x->data)[i]=((i*137+43)%8191-4095)/4096.f;
  auto plan=ggml_graph_plan(g,nth,nullptr);std::vector<uint8_t>work(plan.work_size+64);plan.work_data=(uint8_t*)aligned(work);
  for(int mode=0;mode<2;++mode){setenv("GGML_KNC_WIDE_TASKS",mode?"1":"0",1);memset(ym.data(),0xa5,ym.size());
   check(ggml_graph_compute(g,&plan)==GGML_STATUS_SUCCESS,"compute");
   if(!mode)memcpy(expected.data(),y->data,ggml_nbytes(y));
   else {check(!memcmp(expected.data(),y->data,ggml_nbytes(y)),"scheduler output mismatch");
    uint8_t*p=(uint8_t*)y->data;for(int i=0;i<64;++i)check(p[-1-i]==0xa5 && p[ggml_nbytes(y)+i]==0xa5,"canary");}
  }
  ++cases;values+=expected.size();ggml_free(ctx);
 }
 printf("PASS task scheduler %zu cases %zu byte-identical outputs, tails and canaries\n",cases,values);
}
