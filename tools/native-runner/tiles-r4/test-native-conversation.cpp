// Test-only executable: exercise the same session implementation as the runner.
#define main candidate_runner_main
#include "knc.cpp"
#undef main
int main(int argc,char **argv) {
    try {
        options o=parse(argc,argv);
        require(o.context<=1024,"Conversation oracle is restricted to tiny fixtures");
        o.serve="test-only-no-request-files";o.predict=4;o.image_cache_mib=8;
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
        session fresh(o,""),cached(o,"");fresh.reuse_enabled=false;cached.reuse_enabled=true;
        const std::string base=read_text(o.file);
        int cases=0;
        auto run=[&](const char *label,const std::string &prompt,bool expect_reuse) {
            options a=o,b=o;fresh.prepare(a,prompt);cached.prepare(b,prompt);
            fresh.prefill(o.batch);cached.prefill(o.batch);
            const float *p=llama_get_logits_ith(fresh.context,-1),*q=llama_get_logits_ith(cached.context,-1);
            require(p&&q,"Missing test logits");
            compare(std::vector<float>(p,p+fresh.vocab_size),std::vector<float>(q,q+cached.vocab_size),label);
            require(std::max_element(p,p+fresh.vocab_size)-p==std::max_element(q,q+cached.vocab_size)-q,"Greedy token changed");
            require(cached.evaluated_tokens+cached.reused.tokens==cached.prompt_tokens,"Token accounting");
            if(expect_reuse)require(cached.reused.tokens>0,"Append did not reuse");
            if(expect_reuse&&!o.images.empty())require(cached.reused.images>0&&cached.encode_ms==0&&cached.image_decode_ms==0,"Image followup was recomputed");
            printf("CONVERSATION case=%s reason=%s reused=%zu new=%zu image_reused=%zu\n",label,cached.reused.reason,cached.reused.tokens,cached.evaluated_tokens,cached.reused.images);
            ++cases;
        };
        run("cold",base,false);
        run("append",base+"\nnew question\n",true);
        run("regenerate",base+"\nnew question\n",false);
        // Preserve any image marker; changing the first text token invalidates history.
        run("edited-history","changed\n"+base,false);
        run("append-after-edit","changed\n"+base+"\ncontinue\n",true);
        for(int step=0;step<3;++step) {
            const float*p=llama_get_logits_ith(fresh.context,-1),*q=llama_get_logits_ith(cached.context,-1);
            llama_token t=std::max_element(p,p+fresh.vocab_size)-p;
            require(t==std::max_element(q,q+cached.vocab_size)-q,"Generated token changed");
            for(session*s:{&fresh,&cached}) {s->decode(&t,1,s->prompt_pos+step,false);prefix_atom atom;atom.token=t;s->retained.push_back(atom);}
        }
        run("rollback-after-generation","changed\n"+base+"\ncontinue again\n",false);
        cached.reset();run("reset-cold",base,false);require(cached.reused.tokens==0,"Reset leaked state");
        printf("PASS native-session conversation cases=%d image=%d\n",cases,!o.images.empty());
        return 0;
    }catch(const std::exception&e){fprintf(stderr,"FAIL conversation %s\n",e.what());return 1;}
}
