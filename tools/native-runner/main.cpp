#include "knc-mq.h"
// PhiChat text runner. Host builds exist ONLY as explicitly labelled references.
#include "llama.h"
#include "ggml-backend.h"
#include <algorithm>
#include <cerrno>
#include <climits>
#include <cstdint>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
#include <sys/resource.h>
#include <sys/utsname.h>
#include <unistd.h>
#ifdef _OPENMP
#include <omp.h>
#endif

#ifndef PHI_PROFILE
#define PHI_PROFILE "HOST_REFERENCE"
#endif
#ifndef PHI_UPSTREAM
#define PHI_UPSTREAM "4413a192410fad1f054e9216114087a3e01527a0"
#endif
#ifdef PHI_KNC_KERNELS
extern "C" void ggml_knc_trace_enable(int);
extern "C" void ggml_knc_trace_report(void);
extern "C" void ggml_knc_optimized_enable(int);
extern "C" void ggml_knc_extended_enable(int);
#endif

struct options {
    std::string model, file, dump;
    std::vector<llama_token> stop_tokens;
    int context=2048, batch=32, threads=4, prompt_threads=4, predict=128, cycles=1;
    bool count=false, trace=false, validate=false, scalar=false, baseline=false;
};
static double now() { return llama_time_us()/1000.0; }
static long peak_kib() { struct rusage r; return getrusage(RUSAGE_SELF,&r)==0?r.ru_maxrss:-1; }
static long rss_kib() {
    std::ifstream f("/proc/self/status"); std::string k; long n=0;
    while(f>>k) { if(k=="VmRSS:") {f>>n;return n;} std::getline(f,k); } return -1;
}
static void require(bool yes,const char * why) { if(!yes) throw std::runtime_error(why); }
static int integer(const char * s) {
    char * end=nullptr; errno=0; long n=strtol(s,&end,10);
    require(!errno&&s!=end&&!*end&&n>=0&&n<=INT_MAX,"Invalid integer option"); return int(n);
}
static std::string read_text(const std::string & name) {
    std::ifstream f(name,std::ios::binary);require(bool(f),"Cannot open input file");
    f.seekg(0,std::ios::end);const auto size=f.tellg();
    require(size>=0&&size<=1048576,"Prompt exceeds 1 MiB input bound");
    std::string s(size_t(size),'\0');f.seekg(0);if(size) f.read(&s[0],size);
    require(bool(f),"Cannot read complete input");return s;
}
static options parse(int argc,char **argv) {
    options o;
    for(int i=1;i<argc;++i) {
        std::string a=argv[i];
        if(a=="--help") {
            puts("Phi Chat native text runner; shared mmap required.\n"
                 "-m MODEL -f FORMATTED_UTF8 -c CONTEXT -b BATCH -t THREADS -tb THREADS -n TOKENS\n"
                 "auto-resources-v1 (model capacity and allocated RAM)\n"
                 "--verbose-prompt (numeric count only) --print-token-count 1\n"
                 "--validate-state DIRECTORY --cycles N --trace-kernels\n"
                 "--stop-token ID (repeatable, at most 16 additional stop tokens)\n"
                 "--no-mmap: explicitly rejected; no copy-mode fallback\n"
                 "--describe: runtime identity; not model acceptance");exit(0);
        }
        if(a=="--describe") {ggml_knc_mq_report();printf("{\"version\":\"1.4.2\",\"profile\":\"%s\",\"upstream\":\"%s\",\"kernels\":\"0.2.1\",\"imci_extension\":\"1.4.2 (Q2_K,Q3_K,Q4_K,Q6_K)\",\"hardware_validation\":\"pending unless locally tested\"}\n",PHI_PROFILE,PHI_UPSTREAM);exit(0);}
        if(a=="--trace-kernels") {o.trace=true;continue;}
        if(a=="--baseline-kernels") {o.baseline=true;continue;}
        if(a=="--scalar-kernels") {o.scalar=true;continue;}
        if(a=="--verbose-prompt") {o.count=true;continue;}
        if(a=="--no-display-prompt"||a=="--log-enable") continue;
        require(i+1<argc,"Option value missing");const char *v=argv[++i];
        if(a=="--stop-token") {require(o.stop_tokens.size()<16,"Too many stop tokens");o.stop_tokens.push_back(integer(v));}
        else if(a=="-m")o.model=v;else if(a=="-f")o.file=v;
        else if(a=="-c")o.context=integer(v);else if(a=="-b")o.batch=integer(v);
        else if(a=="-t")o.threads=integer(v);else if(a=="-tb")o.prompt_threads=integer(v);
        else if(a=="-n")o.predict=integer(v);else if(a=="--cycles")o.cycles=integer(v);
        else if(a=="--validate-state") {o.validate=true;o.dump=v;}
        else if(a=="-ngl")require(integer(v)==0,"Offload is not permitted");
        else if(a=="--temp")require(std::string(v)=="0","This deterministic runner currently requires temperature zero");
        else if(a=="--seed") {integer(v); /* greedy sampling has no RNG */}
        else if(a=="--print-token-count")require(integer(v)==1,"Invalid progress interval");
        else throw std::runtime_error("Unsupported runtime option: "+a);
    }
    require(!o.model.empty()&&!o.file.empty(),"Model and prompt file required");
    require(o.context>=128&&o.batch>=1&&o.batch<=o.context&&o.predict<o.context&&o.cycles>=1&&o.cycles<=20,"Unsupported context/batch/output/cycle setting");
    require(o.threads>=1&&o.threads<=240&&o.prompt_threads>=1&&o.prompt_threads<=240,"Invalid worker count");
#ifndef PHI_HOST_REFERENCE
    struct utsname u;require(uname(&u)==0&&std::string(u.machine)=="k1om","Native K1OM required; no host fallback");
    const int cores=std::string(PHI_PROFILE)=="3120A"?56:std::string(PHI_PROFILE)=="5110P"?59:60;
    require(o.threads%cores==0&&o.threads<=4*cores&&o.prompt_threads%cores==0&&o.prompt_threads<=4*cores,"Worker count disagrees with compiled SKU profile");
#else
    fprintf(stderr,"HOST_REFERENCE_ONLY: no hardware acceptance\n");
#endif
    return o;
}

struct session {
    llama_model * model=nullptr;
    llama_context * context=nullptr;
    llama_batch batch{};
    bool batch_live=false;
    std::vector<llama_token> tokens;
    int vocab_size=0;
    double load_ms=0;
    explicit session(const options &o,const std::string &prompt) {
      try {
        const double start=now();
        auto mp=llama_model_default_params();mp.n_gpu_layers=0;
#ifdef PHI_LATEST_REFERENCE
        mp.load_mode=LLAMA_LOAD_MODE_MMAP;
#else
        mp.use_mmap=true;mp.use_mlock=false;
#endif
        model=llama_model_load_from_file(o.model.c_str(),mp);require(model,"GGUF model load failed");
        char arch[64]={0};llama_model_meta_val_str(model,"general.architecture",arch,sizeof arch);
        require(std::string(arch)=="lfm2"||std::string(arch)=="llama","Architecture is outside this text runner's scope");
        require(o.context<=llama_model_n_ctx_train(model),"Context exceeds model training capacity");
        const auto*vocab=llama_model_get_vocab(model);vocab_size=llama_vocab_n_tokens(vocab);
        for (auto stop:o.stop_tokens) require(stop<vocab_size,"Stop token outside vocabulary");
        int n=llama_tokenize(vocab,prompt.data(),int(prompt.size()),nullptr,0,false,true);
        require(n<0,"Empty prompt or tokenizer sizing failed");tokens.resize(-n);
        n=llama_tokenize(vocab,prompt.data(),int(prompt.size()),tokens.data(),int(tokens.size()),false,true);
        require(n>0,"Tokenization failed");tokens.resize(n);
        if(int64_t(n)+o.predict>o.context-(o.count?4:0)) fprintf(stderr,"PHI_PROMPT_REJECTED %d\n",n);
        else fprintf(stderr,"PHI_PROMPT_TOKENS %d\n",n);
        require(int64_t(n)+o.predict<=o.context-(o.count?4:0),"Prompt plus reply exceeds allocated context; state shifting is disabled");
        auto cp=llama_context_default_params();cp.n_ctx=o.context;cp.n_batch=o.batch;cp.n_ubatch=o.batch;
        cp.n_seq_max=1;cp.n_threads=o.threads;cp.n_threads_batch=o.prompt_threads;
        cp.flash_attn_type=LLAMA_FLASH_ATTN_TYPE_DISABLED;cp.offload_kqv=false;cp.op_offload=false;
        cp.type_k=GGML_TYPE_F16;cp.type_v=GGML_TYPE_F16;cp.no_perf=false;
        context=llama_init_from_model(model,cp);require(context,"Context allocation failed");
        batch=llama_batch_init(o.batch,0,1);batch_live=true;
        load_ms=now()-start;
      } catch(...) {release();throw;}
    }
    void release() {
        if(batch_live){llama_batch_free(batch);batch_live=false;}
        if(context){llama_free(context);context=nullptr;}
        if(model){llama_model_free(model);model=nullptr;}
    }
    ~session(){release();}
    void reset(){llama_memory_clear(llama_get_memory(context),true);llama_perf_context_reset(context);}
    void decode(const llama_token * t,int count,int pos,bool all) {
        batch.n_tokens=count;
        for(int i=0;i<count;++i){batch.token[i]=t[i];batch.pos[i]=pos+i;batch.n_seq_id[i]=1;batch.seq_id[i][0]=0;batch.logits[i]=all||i==count-1;}
        require(llama_decode(context,batch)==0,"Decode failed; session must be reset");
    }
    llama_token greedy() {
        const float*p=llama_get_logits_ith(context,-1);require(p,"Missing logits");
        int best=0;for(int i=0;i<vocab_size;++i){require(std::isfinite(p[i]),"Non-finite logits");if(p[i]>p[best])best=i;}return best;
    }
};

static void write_floats(const std::string &file,const std::vector<float>&v) {
    std::ofstream f(file,std::ios::binary);require(bool(f),"Cannot create validation output");
    f.write(reinterpret_cast<const char*>(v.data()),v.size()*sizeof(float));require(bool(f),"Validation write failed");
}
static std::vector<float> logits_run(session&s,int chunk) {
    s.reset();std::vector<float> out;out.reserve(s.tokens.size()*s.vocab_size);
    for(size_t pos=0;pos<s.tokens.size();) {
        int n=std::min(size_t(chunk),s.tokens.size()-pos);s.decode(s.tokens.data()+pos,n,int(pos),true);
        for(int i=0;i<n;++i){auto p=llama_get_logits_ith(s.context,i);require(p,"Missing validation logits");out.insert(out.end(),p,p+s.vocab_size);}pos+=n;
    }
    return out;
}
static void compare(const std::vector<float>&a,const std::vector<float>&b,const char* label) {
    require(a.size()==b.size(),"Validation shape mismatch");double sq=0,ref=0,max_abs=0;size_t bad=0;
    for(size_t i=0;i<a.size();++i){require(std::isfinite(a[i])&&std::isfinite(b[i]),"Non-finite validation logits");double d=double(a[i])-b[i];sq+=d*d;ref+=double(a[i])*a[i];max_abs=std::max(max_abs,std::abs(d));if(std::abs(d)>0.03+0.005*std::abs(double(a[i])))++bad;}
    const double nr=std::sqrt(sq/std::max(ref,1e-30));
    fprintf(stderr,"PHI_NUMERICS %s count=%zu max_abs=%.9g nrmse=%.9g outliers=%zu\n",label,a.size(),max_abs,nr,bad);
    require(nr<=0.002&&bad==0,"State/prefill numerical tolerance exceeded");
}
static void validate(session&s,const options&o,int cycle) {
    require(s.tokens.size()<=64,"Validation prompt must be at most 64 tokens");
    auto prefill=logits_run(s,o.batch);auto incremental=logits_run(s,1);
    std::string base=o.dump+"/cycle-"+std::to_string(cycle);
    write_floats(base+"-prefill.f32",prefill);write_floats(base+"-incremental.f32",incremental);
    compare(prefill,incremental,"prefill_vs_incremental");
    // Poison both attention and convolution states, then clear and rerun.
    llama_token poison=0;for(int i=0;i<4;++i)s.decode(&poison,1,int(s.tokens.size())+i,false);
    auto reset=logits_run(s,o.batch);compare(prefill,reset,"reset_vs_fresh");
    auto chunked=logits_run(s,std::min(3,o.batch));compare(prefill,chunked,"three_token_chunks");
    write_floats(base+"-chunked.f32",chunked);
    write_floats(base+"-prefill.f32",prefill);write_floats(base+"-incremental.f32",incremental);write_floats(base+"-reset.f32",reset);
    std::ofstream ids(base+"-tokens.txt");for(auto t:s.tokens)ids<<t<<'\n';
    require(bool(ids),"Token evidence write failed");
    fprintf(stderr,"PHI_VALIDATION cycle=%d tokens=%zu vocab=%d peak_rss_kib=%ld rss_kib=%ld\n",cycle,s.tokens.size(),s.vocab_size,peak_kib(),rss_kib());
}
static void generate(session&s,const options&o) {
    s.reset();const double start=now();
    for(size_t pos=0;pos<s.tokens.size();) {
        int n=std::min(size_t(o.batch),s.tokens.size()-pos);s.decode(s.tokens.data()+pos,n,int(pos),false);pos+=n;
        fprintf(stderr,"Tokens consumed so far = %zu\n",pos);
    }
    const double prefill_ms=now()-start;double ttft_ms=0,decode_ms=0;int produced=0,evals=0;
    const auto*vocab=llama_model_get_vocab(s.model);
    char piece[32768];
    for(int i=0;i<o.predict;++i) {
        llama_token t=s.greedy();if(llama_vocab_is_eog(vocab,t)||std::find(o.stop_tokens.begin(),o.stop_tokens.end(),t)!=o.stop_tokens.end())break;
        int n=llama_token_to_piece(vocab,t,piece,sizeof piece,0,false);require(n>=0,"Token piece exceeds reusable output buffer");
        if(!produced)ttft_ms=now()-start;
        require(fwrite(piece,1,n,stdout)==size_t(n),"Output stream failed");fflush(stdout);++produced;
        if(i+1<o.predict){double t0=now();s.decode(&t,1,int(s.tokens.size())+i,false);decode_ms+=now()-t0;++evals;}
        fprintf(stderr,"Tokens consumed so far = %zu\n",s.tokens.size()+produced);
    }
    fprintf(stderr,"llama_print_timings: load time = %.3f ms\n",s.load_ms);
    fprintf(stderr,"llama_print_timings: prompt eval time = %.3f ms / %zu tokens ( %.3f ms per token, %.3f tokens per second)\n",prefill_ms,s.tokens.size(),prefill_ms/std::max(size_t(1),s.tokens.size()),1000*s.tokens.size()/std::max(prefill_ms,1e-9));
    fprintf(stderr,"llama_print_timings: eval time = %.3f ms / %d runs ( %.3f ms per token, %.3f tokens per second)\n",decode_ms,evals,decode_ms/std::max(1,evals),1000*evals/std::max(decode_ms,1e-9));
    fprintf(stderr,"PHI_METRICS {\"load_ms\":%.3f,\"prefill_ms\":%.3f,\"ttft_after_load_ms\":%.3f,\"ttft_with_load_ms\":%.3f,\"decode_eval_ms\":%.3f,\"decode_evals\":%d,\"generated_tokens\":%d,\"peak_rss_kib\":%ld,\"trace_enabled\":%s}\n",s.load_ms,prefill_ms,ttft_ms,s.load_ms+ttft_ms,decode_ms,evals,produced,peak_kib(),o.trace?"true":"false");
}
int main(int argc,char **argv) {
    try {
        options o=parse(argc,argv);
#ifdef _OPENMP
        omp_set_dynamic(0);omp_set_nested(0);omp_set_max_active_levels(1);
#endif
        ggml_knc_mq_init();
        llama_backend_init();
#ifdef PHI_KNC_KERNELS
        ggml_knc_trace_enable(o.trace?1:0);
        ggml_knc_optimized_enable(o.scalar?0:1);
        ggml_knc_extended_enable(o.baseline?0:1);
        ggml_knc_mq_report();
#endif
        const std::string prompt=read_text(o.file);
        for(int cycle=0;cycle<o.cycles;++cycle) {
            { session s(o,prompt); if(o.validate)validate(s,o,cycle);else if(o.predict&&!o.count)generate(s,o); }
            fprintf(stderr,"PHI_UNLOADED cycle=%d rss_kib=%ld peak_rss_kib=%ld\n",cycle,rss_kib(),peak_kib());
        }
#ifdef PHI_KNC_KERNELS
        if(o.trace){ggml_knc_trace_report();ggml_knc_mq_report();}
#endif
        llama_backend_free();if(o.validate)puts("VALIDATION_COMPLETE: fixed-input numerical evidence written; compare with the pinned reference.");return 0;
    }catch(const std::exception&e){fprintf(stderr,"PHI_ERROR: %s\n",e.what());return 1;}
}
