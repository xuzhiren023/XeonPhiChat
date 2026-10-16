// SPDX-License-Identifier: MIT. Native arithmetic and bounds regression checks.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
extern "C" void knc_f32_pair(size_t,const float*,const float*,const float*,float*,float*);
extern "C" void knc_f32_tile2x2(size_t,const float*,const float*,const float*,const float*,float*);
extern "C" void ggml_knc_mq_panel8(size_t,size_t,const uint8_t*,size_t,const uint8_t*,size_t,float*,size_t);
extern "C" void ggml_knc_mq_panel16(size_t,size_t,const uint8_t*,size_t,const uint8_t*,size_t,float*,size_t);
extern "C" void ggml_knc_mq_panel(int,size_t,size_t,const uint8_t*,size_t,const uint8_t*,size_t,float*,size_t);
extern "C" void ggml_knc_mq_wide(int,size_t,size_t,const uint8_t*,size_t,const uint8_t*,size_t,float*,size_t);
static void check(bool ok,const char*s){if(!ok){fprintf(stderr,"FAIL %s\n",s);exit(1);}}
static uint32_t state=1729;
static uint32_t rnd(){state^=state<<13;state^=state>>17;state^=state<<5;return state;}
static void* align(std::vector<uint8_t>&v){return (void*)(((uintptr_t)v.data()+63)&~(uintptr_t)63);}
int main(){
 size_t values=0;
 for(size_t k:{16,32,48,64,80,96,256,512,2704}) {
  std::vector<uint8_t> mem(k*4*4+256);float*a=(float*)align(mem),*b=a+k,*x=b+k,*y=x+k;
  for(size_t i=0;i<k*4;++i)a[i]=(int(rnd()%65537)-32768)/8192.f;
  alignas(64) float ref[4][16],out[4][16];
  knc_f32_pair(k,a,b,x,ref[0],ref[1]);knc_f32_pair(k,a,b,y,ref[2],ref[3]);
  knc_f32_tile2x2(k,a,b,x,y,&out[0][0]);
  check(!memcmp(ref,out,sizeof(ref)),"F32 chain result differs");values+=64;
 }
 for(size_t blocks:{1,2,5,17})for(size_t rows:{1,3,7,8})for(int mode=0;mode<4;++mode){
  const size_t ws=blocks*210+3,ys=blocks*292+5;
  std::vector<uint8_t>w(rows*ws+1),y(16*ys+1);uint8_t*wp=w.data()+1,*yp=y.data()+1;
  for(auto &v:w)v=rnd();for(auto&v:y)v=rnd();
  for(size_t r=0;r<rows;++r)for(size_t b=0;b<blocks;++b){
   uint8_t*p=wp+r*ws+b*210;p[208]=0;p[209]=mode==3?0:0x3c;
   if(mode==1){memset(p,0,192);memset(p+192,128,16);}
   if(mode==2){memset(p,255,192);memset(p+192,127,16);}
  }
  for(size_t c=0;c<16;++c)for(size_t b=0;b<blocks;++b){
   uint8_t*p=yp+c*ys+b*292;float d=0.03125f;memcpy(p,&d,4);
   if(mode==1)memset(p+4,128,256);if(mode==2)memset(p+4,127,256);
  }
  float ref[16*19],out[16*19];for(float&v:ref)v=-9876;for(float&v:out)v=-9876;
  ggml_knc_mq_panel8(blocks,rows,wp,ws,yp,ys,ref,19);
  ggml_knc_mq_panel8(blocks,rows,wp,ws,yp+8*ys,ys,ref+8*19,19);
  ggml_knc_mq_panel16(blocks,rows,wp,ws,yp,ys,out,19);
  check(!memcmp(ref,out,sizeof(ref)),"Q6 panel or output canary differs");
  for(float v:out)check(std::isfinite(v),"nonfinite Q6");values+=rows*16;
 }
 for(int bits=3;bits<=6;++bits)for(size_t blocks:{1,3,17})for(size_t rows:{1,3,7,8}){
  int stride=bits==3?110:bits==4?144:bits==5?176:210;
  size_t ws=blocks*stride+1,ys=blocks*292+3;
  std::vector<uint8_t>w(ws*rows+1),y(ys*16+1);uint8_t*wp=w.data()+1,*yp=y.data()+1;
  for(auto&v:w)v=rnd();for(auto&v:y)v=rnd();
  for(size_t r=0;r<rows;++r)for(size_t b=0;b<blocks;++b){uint8_t*p=wp+r*ws+b*stride;
   int half=bits==3?108:bits==6?208:0;p[half]=0;p[half+1]=0x3c;
   if(bits==4||bits==5){p[2]=0;p[3]=0x38;}
  }
  for(size_t c=0;c<16;++c)for(size_t b=0;b<blocks;++b){float d=0.015625f;memcpy(yp+c*ys+b*292,&d,4);}
  float ref[16*19],out[16*19];for(float&v:ref)v=-9876;for(float&v:out)v=-9876;
  for(int c=0;c<16;c+=4)ggml_knc_mq_panel(bits,blocks,rows,wp,ws,yp+c*ys,ys,ref+c*19,19);
  ggml_knc_mq_wide(bits,blocks,rows,wp,ws,yp,ys,out,19);
  check(!memcmp(ref,out,sizeof(ref)),"wide quant panel or canary differs");values+=rows*16;
 }
 printf("PASS exact F32/Q3-Q6 tiles: %zu values, unaligned packed input, signed extremes and output canaries\n",values);
}
