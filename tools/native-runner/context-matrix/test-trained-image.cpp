// One resident context, bounded four-prefill image correctness/latency screen.
#define main candidate_runner_main
#include "knc.cpp"
#undef main
int main(int argc,char**argv){
 try{
    options o=parse(argc,argv);require(o.images.size()==1&&!o.mmproj.empty(),"One image/projector required");
    o.serve="test-only-no-request-files";o.predict=4;o.image_cache_mib=64;
#ifdef _OPENMP
    omp_set_dynamic(0);omp_set_nested(0);omp_set_max_active_levels(1);
#endif
#ifdef PHI_KNC_KERNELS
    ggml_knc_mq_init();
#endif
    llama_backend_init();
#ifdef PHI_KNC_KERNELS
    ggml_knc_optimized_enable(1);ggml_knc_extended_enable(1);ggml_knc_mq_optimized(1);
#endif
    session s(o,"");
    std::string base=read_text(o.file);
    std::string follow=base+"\n</think>\nLeft: red square; Right: blue circle.<|im_end|>\n<|im_start|>user\nWhat color is the circle?<|im_end|>\n<|im_start|>assistant\n<think>\n";
    auto evaluate=[&](const char*label,const std::string&prompt,bool reuse){
        s.reuse_enabled=reuse;options request=o;
        const double start=now();s.prepare(request,prompt);const double ready=now();s.prefill(o.batch);
        const float*p=llama_get_logits_ith(s.context,-1);require(p,"Missing image logits");
        printf("IMAGE_SCREEN case=%s prepare_ms=%.6f prefill_ms=%.6f encode_ms=%.6f image_decode_ms=%.6f text_ms=%.6f reused=%zu new=%zu image_reused=%zu\n",
            label,ready-start,now()-ready,s.encode_ms,s.image_decode_ms,s.text_prefill_ms,s.reused.tokens,s.evaluated_tokens,s.reused.images);fflush(stdout);
        return std::vector<float>(p,p+s.vocab_size);
    };
    for(const char*key:{"GGML_KNC_Q6_PANEL8","GGML_KNC_F16_CONV","GGML_KNC_F32_ATTN"})setenv(key,"0",1);
    auto reference_base=evaluate("baseline-cold-image",base,false);
    auto reference_follow=evaluate("baseline-fresh-followup",follow,false);
    std::vector<llama_token> greedy;
    for(int i=0;i<3;++i){auto*p=llama_get_logits_ith(s.context,-1);llama_token t=std::max_element(p,p+s.vocab_size)-p;greedy.push_back(t);s.decode(&t,1,s.prompt_pos+i,false);}
    // Discard only this test's embeddings; force the new encoder paths to run.
    s.image_cache.configure(s.cache_limit);s.reset();
    for(const char*key:{"GGML_KNC_Q6_PANEL8","GGML_KNC_F16_CONV","GGML_KNC_F32_ATTN"})setenv(key,"1",1);
    auto candidate_base=evaluate("candidate-cold-image",base,false);
    compare(reference_base,candidate_base,"trained_image_candidate_vs_baseline");
    auto candidate_follow=evaluate("candidate-cached-followup",follow,true);
    compare(reference_follow,candidate_follow,"trained_image_reuse_vs_fresh");
    require(s.reused.images>0&&s.encode_ms==0&&s.image_decode_ms==0,"Followup recomputed image");
    for(int i=0;i<3;++i){auto*p=llama_get_logits_ith(s.context,-1);llama_token t=std::max_element(p,p+s.vocab_size)-p;require(t==greedy[i],"Greedy image followup differs");s.decode(&t,1,s.prompt_pos+i,false);}
    printf("IMAGE_EXACT_FLOAT_VALUES cold=%d followup=%d\n",reference_base==candidate_base,reference_follow==candidate_follow);
    puts("PASS trained image logits, greedy followup, and whole-image state reuse; single timing screen only");return 0;
 }catch(const std::exception&e){fprintf(stderr,"FAIL trained image %s\n",e.what());return 1;}
}
