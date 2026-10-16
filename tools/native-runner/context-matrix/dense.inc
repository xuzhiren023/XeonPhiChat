/* SPDX-License-Identifier: MIT. Unsupported layouts use existing GGML paths. */
extern void knc_f32_pair(size_t, const float *, const float *, const float *, float *, float *);
extern void knc_f16_products_pair(size_t, const ggml_fp16_t *, const ggml_fp16_t *, const ggml_fp16_t *, float *, float *);
static bool knc_option(const char * name) {
    const char * value=getenv(name);
    return value && strcmp(value,"1")==0;
}
static bool ggml_knc_dense_matmul(const struct ggml_compute_params * params, struct ggml_tensor * dst) {
    const struct ggml_tensor * w=dst->src[0], * x=dst->src[1];
    const bool half=w->type==GGML_TYPE_F16;
    if (params->use_ref || !knc_option(half ? "GGML_KNC_F16_CONV" : "GGML_KNC_F32_ATTN") ||
        (!half && w->type!=GGML_TYPE_F32) || dst->type!=GGML_TYPE_F32 ||
        (x->type!=GGML_TYPE_F32 && !(half && x->type==GGML_TYPE_F16)) || !ggml_is_contiguous(dst)) return false;
    const int64_t k=w->ne[0], rows=w->ne[1], cols=x->ne[1];
    if (k<=0 || k>INT_MAX || rows<2 || cols<1 || k%(half?32:16) || x->ne[0]!=k ||
        w->nb[0]!=(half?2:4) || x->nb[0]!=(x->type==GGML_TYPE_F16?2:4) ||
        w->ne[2]<=0 || w->ne[3]<=0 || x->ne[2]%w->ne[2] || x->ne[3]%w->ne[3] ||
        dst->ne[0]!=rows || dst->ne[1]!=cols || dst->ne[2]!=x->ne[2] || dst->ne[3]!=x->ne[3]) return false;
    if (((uintptr_t)w->data|w->nb[1]|w->nb[2]|w->nb[3])&63) return false;
    const bool pack=half && x->type==GGML_TYPE_F32;
    if (pack && (((uintptr_t)x->data|x->nb[1]|x->nb[2]|x->nb[3])&3)) return false;
    if (!pack && (((uintptr_t)x->data|x->nb[1]|x->nb[2]|x->nb[3])&63)) return false;
    if (x->ne[2]<=0 || x->ne[3]<=0 || x->ne[2]>INT64_MAX/x->ne[3]) return false;
    const int64_t heads=x->ne[2]*x->ne[3];
    if (cols>INT64_MAX/heads || rows>INT64_MAX-15) return false;
    const int64_t columns=cols*heads, tiles=(rows+15)/16;
    if (columns>INT64_MAX/tiles || (uint64_t)columns>SIZE_MAX/(size_t)k/2) return false;
    if (pack) {
        if (!params->wdata || ((uintptr_t)params->wdata&63) || params->wsize<(size_t)columns*k*2) return false;
        const int64_t blocks=k/32, total=columns*blocks;
        const int64_t first=total/params->nth*params->ith+total%params->nth*params->ith/params->nth;
        const int64_t last=total/params->nth*(params->ith+1)+total%params->nth*(params->ith+1)/params->nth;
        for (int64_t job=first;job<last;) {
            const int64_t c=job/blocks, b=job%blocks, count=MIN(last-job,blocks-b);
            const int64_t col=c%cols, h=c/cols, h2=h%x->ne[2], h3=h/x->ne[2];
            ggml_cpu_fp32_to_fp16((const float*)((const char*)x->data+col*x->nb[1]+h2*x->nb[2]+h3*x->nb[3])+b*32,
                                 (ggml_fp16_t*)params->wdata+c*k+b*32,count*32);
            job+=count;
        }
        ggml_barrier(params->threadpool);
    }
    if (params->ith==0 && knc_option("GGML_KNC_DENSE_TRACE")) {
        fprintf(stderr,"KNC_DENSE_PATH type=%s k=%lld rows=%lld cols=%lld heads=%lld\n",
                half?"f16":"f32",(long long)k,(long long)rows,(long long)cols,(long long)heads);
    }
    const int64_t total=columns*tiles;
    const int64_t first=total/params->nth*params->ith+total%params->nth*params->ith/params->nth;
    const int64_t last=total/params->nth*(params->ith+1)+total%params->nth*(params->ith+1)/params->nth;
    for (int64_t job=first;job<last;++job) {
        const int64_t row0=job%tiles*16, row_end=MIN(rows,row0+16), c=job/tiles;
        const int64_t col=c%cols, h=c/cols, h2=h%x->ne[2], h3=h/x->ne[2];
        const char * weights=(const char*)w->data+(h2/(x->ne[2]/w->ne[2]))*w->nb[2]+(h3/(x->ne[3]/w->ne[3]))*w->nb[3];
        const char * input=pack ? (const char*)params->wdata+c*k*2 : (const char*)x->data+col*x->nb[1]+h2*x->nb[2]+h3*x->nb[3];
        float * result=(float*)((char*)dst->data+col*dst->nb[1]+h2*dst->nb[2]+h3*dst->nb[3]);
        for (int64_t row=row0;row<row_end;row+=2) {
            const int64_t other=MIN(row+1,row_end-1);
            if (half) {
                const ggml_fp16_t * a=(const ggml_fp16_t*)(weights+row*w->nb[1]);
                const ggml_fp16_t * b=(const ggml_fp16_t*)(weights+other*w->nb[1]);
                float products[2][256] __attribute__((aligned(64)));
                ggml_float sums[2]={0,0};
                for (int64_t i=0;i<k;i+=256) {
                    const size_t count=MIN((int64_t)256,k-i);
                    knc_f16_products_pair(count,a+i,b+i,(const ggml_fp16_t*)input+i,products[0],products[1]);
                    // Preserve the scalar dot's product order and wide accumulation.
                    for (size_t j=0;j<count;++j) { sums[0]+=(ggml_float)products[0][j]; sums[1]+=(ggml_float)products[1][j]; }
                }
                result[row]=sums[0]; if(other!=row)result[other]=sums[1];
            } else {
                float lanes[2][16] __attribute__((aligned(64)));
                knc_f32_pair(k,(const float*)(weights+row*w->nb[1]),(const float*)(weights+other*w->nb[1]),
                             (const float*)input,lanes[0],lanes[1]);
                float a=0,b=0;
                for (int i=0;i<16;++i) {a+=lanes[0][i]; b+=lanes[1][i];}
                result[row]=a; if(other!=row)result[other]=b;
            }
        }
    }
    return true;
}
